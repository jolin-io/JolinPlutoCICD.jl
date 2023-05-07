module JolinPlutoCICD
using Pluto

export instantiate, instantiate_all

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

instantiate_all(dir::AbstractString) = instantiate_all(get_all_workflow_paths(dir))

function instantiate_all(paths::AbstractVector; sleep_inbetween = 0.0)
    @info "Instantiation started"
    # instantiation is currently threadlocked by Pluto so that only one instantiate can happen at a time
    # to improve the experience for a dev user who wants to start her notebook
    # immediately that means that if we start all instantiations async, she maybe has
    # to wait_business for all the other instantiations.
    # Doing it sequentially she only has to wait for at most one other instantiation.
    for path in paths
        instantiate(path)
        sleep(sleep_inbetween)
    end
    @info "Instantiation done"
end

function instantiate(path::AbstractString)
    @info "Instantiation started for notebook $path"
    path = Pluto.maybe_convert_path_to_wsl(path)
    notebook = Pluto.load_notebook(Pluto.tamepath(path); disable_writing_notebook_files=true)

    old = notebook.topology  # old is actually ignored by sync_nbpkg_core
    new = notebook.topology = Pluto.updated_topology(old, notebook, notebook.cells) # macros are not yet resolved
    cleanup = Ref{Union{Function}}(() -> nothing)
    try
        Pluto.sync_nbpkg_core(notebook, old, new; cleanup)
    finally
        isnothing(cleanup[]) || cleanup[]()
    end
    @info "Instantiation done for notebook $path"
    return notebook
end

function instantiate_env(path::AbstractString)
    temporary_env_dir = Pluto.PkgCompat.env_dir(instantiate(path).nbpkg_ctx)
    persistent_env_dir = joinpath(tempdir(),  "jolin_" * basename(temporary_env_dir))
    cp(temporary_env_dir, persistent_env_dir)
    persistent_env_dir
end


# TODO try to use this for github action

instantiate_and_run_all(dir::AbstractString) = instantiate_and_run_all(get_all_workflow_paths(dir))

function instantiate_and_run_all(paths::AbstractVector)
    @info "Instantiate / Run started"
    # instantiation is currently threadlocked by Pluto so that only one instantiate can happen at a time
    # to improve the experience for a dev user who wants to start her notebook
    # immediately that means that if we start all instantiations async, she maybe has
    # to wait_business for all the other instantiations.
    # Doing it sequentially she only has to wait for at most one other instantiation.
    for path in paths
        instantiate_and_run(path)
    end
    @info "Instantiate / Run  done"
end

function instantiate_and_run(path::AbstractString)
    notebook = instantiate(path)
    @info "Run started for notebook $path"
    env_dir = Pluto.PkgCompat.env_dir(notebook.nbpkg_ctx)
    # this trick is taken from Pluto, it simulates to activate the environment within env_dir
    pushfirst!(LOAD_PATH, env_dir)
    @gensym module_name
    Main.eval(:(
        module $module_name
            include($path)
        end
    ))
    @info "Run done for notebook $path"
end

end
