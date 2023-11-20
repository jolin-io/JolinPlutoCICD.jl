module CondaPkgExt
import JolinPlutoCICD
import CondaPkg

function JolinPlutoCICD.resolve_condapkg(env_dir)
    file = joinpath(env_dir, "CondaPkg.toml")
    if isfile(file)
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
        # TODO possibly add extra local conda channels which are needed
        # - should not really be needed on amd64/arch64
        CondaPkg.write_deps(toml; file)

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

        CondaPkg.resolve()

        copy!(LOAD_PATH, old_LP)
        Base.ACTIVE_PROJECT[] = old_AP
    end
end

end # module