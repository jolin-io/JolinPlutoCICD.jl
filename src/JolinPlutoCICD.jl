module JolinPlutoCICD
import SHA

const _notebook_header = "### A Pluto.jl notebook ###"

function json_common_prefix_common_suffix_and_all_notebook_paths(dir)
    allpaths = get_all_notebook_paths(dir)
    prefix = longest_common_prefix(allpaths)
    pathsuffixes = [
        path[length(prefix)+1:end]
        for path in allpaths
    ]
    return """{prefix:["$prefix"],suffix:[""],notebook_path:[$(join(repr.(pathsuffixes), ","))]}"""
end

function longest_common_prefix(strs::Vector{String})::String
    s1, s2 = minimum(strs), maximum(strs)
    pos = findfirst(i -> s1[i] != s2[i], 1:length(s1))
    return isnothing(pos) ? "" : s1[1:(pos - 1)]
end


function get_all_notebook_paths(dir)
    [
        path
        for (root, dirs, files) in walkdir(dir)
        for file in files
        for path in (abspath(joinpath(root, file)),)
        if is_pluto_notebook_path(path)
    ]
end

function is_pluto_notebook_path(path)
    endswith(path, ".jl") || endswith(path, ".R") || endswith(path, ".r") || endswith(path, ".py") || return false
    return open(path, "r") do io
        firstline = String(readline(io))::String
        firstline == _notebook_header
    end
end

function get_preserved_environment_path(notebook_path; parentdir)
    # this should work because all worker are run on the same system

    # set conda env name to current filename
    # see https://github.com/JuliaPy/CondaPkg.jl#conda-environment-path
    hash = bytes2hex(SHA.sha224(notebook_path))
    filename, ext = splitext(basename(notebook_path))
    filename = replace(filename, " " => "__")

    env_name = "$filename-$hash"
    full_path = joinpath(parentdir, env_name)
    full_path
end


function create_pluto_env(notebook_path; parentdir=tempdir())
    content = readchomp(notebook_path)

    match_pluto_project_start = findfirst(r"PLUTO_PROJECT_TOML_CONTENTS = \"\"\"", content)
    if isnothing(match_pluto_project_start)
        project = "\n"
    else
        project_start = match_pluto_project_start.stop
        project_stop = findnext(r"\"\"\"", content, project_start).start
        project = content[project_start+1:project_stop-1]
    end

    match_pluto_manifest_start = findfirst(r"PLUTO_MANIFEST_TOML_CONTENTS = \"\"\"", content)
    if isnothing(match_pluto_manifest_start)
        manifest = "\n"
    else
        manifest_start = match_pluto_manifest_start.stop
        manifest_stop = findnext(r"\"\"\"", content, manifest_start).start
        manifest = content[manifest_start+1:manifest_stop-1]
    end

    match_pluto_condapkg_start = findfirst(r"PLUTO_CONDAPKG_TOML_CONTENTS = \"\"\"", content)
    if isnothing(match_pluto_condapkg_start)
        condapkg = "\n"
    else
        condapkg_start = match_pluto_condapkg_start.stop
        condapkg_stop = findnext(r"\"\"\"", content, condapkg_start).start
        condapkg = content[condapkg_start+1:condapkg_stop-1]
    end

    # mktempdir will error if the path is not created
    env_dir = get_preserved_environment_path(notebook_path; parentdir)
    mkpath(env_dir)
    write(joinpath(env_dir, "Project.toml"), project)
    write(joinpath(env_dir, "Manifest.toml"), manifest)
    # only write conda pkg if it is part of the notebook - this can be used as a flag whether CondaPkg is a dependency of the repo
    strip(condapkg) != "" && write(joinpath(env_dir, "CondaPkg.toml"), condapkg)
    return env_dir
end


@doc raw"""
    @eval $(JolinPlutoCICD.expr_resolve_condapkg(env_dir))

This will install CondaPkg if it is part of an existing Manifest.toml and call CondaPkg.resolve().
"""
function expr_resolve_condapkg(env_dir)
    quote
        env_dir = abspath(expanduser($env_dir))
        manifest_file = joinpath(env_dir, "Manifest.toml")
        if isfile(manifest_file)
            import TOML
            manifest = TOML.parse(readchomp(manifest_file))
            if haskey(manifest, "deps") && haskey(manifest["deps"], "CondaPkg") && length(manifest["deps"]["CondaPkg"]) >= 1
                import Pkg
                Pkg.add(
                    name="CondaPkg",
                    uuid=manifest["deps"]["CondaPkg"][1]["uuid"],
                    version=manifest["deps"]["CondaPkg"][1]["version"],
                )
                import CondaPkg

                # Conda Resolve depends on loadpath
                # now CondaPkg.resolve() should not fail
                # not everything is found, hence we need to instantiate it right now to be able extract exported names
                old_LP = LOAD_PATH[:]
                old_AP = Base.ACTIVE_PROJECT[]

                # the LP and AP are identical to how Pluto does package instantiations.
                new_LP = ["@", "@stdlib"]
                new_AP = env_dir
                copy!(LOAD_PATH, new_LP)
                Base.ACTIVE_PROJECT[] = new_AP

                file = CondaPkg.cur_deps_file()

                # delete local conda channels which do not exist here
                toml = CondaPkg.read_deps(; file)
                channels = get!(Vector{Any}, toml, "channels")
                filter!(channels) do name
                    if startswith(name, "file://")
                        path = name[begin+length("file://"):end]
                        # only keep local channels which also exist
                        return isdir(path)
                    else
                        # keep all other channels
                        return true
                    end
                end

                # add local channel if existing
                if haskey(ENV, "JOLIN_CONDA_LOCAL_CHANNEL")
                    local_channel = expanduser(ENV["JOLIN_CONDA_LOCAL_CHANNEL"])
                    if isdir(local_channel)
                        CondaPkg.add!(toml, CondaPkg.ChannelSpec("conda-forge"))
                        CondaPkg.add!(toml, CondaPkg.ChannelSpec("file://$local_channel"))
                    end
                end

                # TODO possibly add extra local conda channels which are needed
                # - should not really be needed on amd64/arch64
                CondaPkg.write_deps(toml; file)

                CondaPkg.resolve()

                # revert LOAD_PATH
                copy!(LOAD_PATH, old_LP)
                Base.ACTIVE_PROJECT[] = old_AP
            end
        end
    end
end

end
