module JolinPlutoCICD

const _notebook_header = "### A Pluto.jl notebook ###"

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
    print(project)
    manifest = content[manifest_start+1:manifest_stop-1]

    tmpdir = mktempdir(cleanup=false)
    write(joinpath(tmpdir, "Project.toml"), project)
    write(joinpath(tmpdir, "Manifest.toml"), manifest)
    return tmpdir
end

end
