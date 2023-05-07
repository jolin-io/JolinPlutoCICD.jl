module JolinPlutoCICD

const _notebook_header = "### A Pluto.jl notebook ###"

function json_common_prefix_and_all_workflow_paths_without_extension(dir)
    allpaths = get_all_workflow_paths(dir)
    prefix = longest_common_prefix(allpaths)
    strip_jl_ext(str) = endswith(str, ".jl") ? str[begin:end-3] : str
    pathsuffixes = [
        strip_jl_ext(path[length(prefix)+1:end])
        for path in allpaths
    ]
    return """{common_prefix:["$prefix"],workflow_path:[$(join(repr.(pathsuffixes), ","))]}"""
end

function longest_common_prefix(strs::Vector{String})::String
    s1, s2 = minimum(strs), maximum(strs)
    pos = findfirst(i -> s1[i] != s2[i], 1:length(s1))
    return isnothing(pos) ? "" : s1[1:(pos - 1)]
end


function get_all_workflow_paths(dir)
    [
        path
        for (root, dirs, files) in walkdir(dir)
        for file in files
        for path in (abspath(joinpath(root, file)),)
        if is_pluto_notebook_path(path)
    ]
end

function is_pluto_notebook_path(path)
    endswith(path, ".jl") || return false
    return open(path, "r") do io
        firstline = String(readline(io))::String
        firstline == _notebook_header
    end
end


function create_pluto_env(path)
    content = readchomp(path)

    project_start = findfirst(r"PLUTO_PROJECT_TOML_CONTENTS = \"\"\"", content).stop
    project_stop = stop = findnext(r"\"\"\"", content, project_start).start

    manifest_start = findfirst(r"PLUTO_MANIFEST_TOML_CONTENTS = \"\"\"", content).stop
    manifest_stop = stop = findnext(r"\"\"\"", content, manifest_start).start

    project = content[project_start+1:project_stop-1]
    manifest = content[manifest_start+1:manifest_stop-1]

    tmpdir = mktempdir(cleanup=false)
    write(joinpath(tmpdir, "Project.toml"), project)
    write(joinpath(tmpdir, "Manifest.toml"), manifest)
    return tmpdir
end

end
