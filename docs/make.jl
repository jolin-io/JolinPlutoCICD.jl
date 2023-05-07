using JolinPlutoCICD
using Documenter

DocMeta.setdocmeta!(JolinPlutoCICD, :DocTestSetup, :(using JolinPlutoCICD); recursive=true)

makedocs(;
    modules=[JolinPlutoCICD],
    authors="Stephan Sahm <stephan.sahm@jolin.io> and contributors",
    repo="https://github.com/jolin-io/JolinPlutoCICD.jl/blob/{commit}{path}#{line}",
    sitename="JolinPlutoCICD.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jolin-io.github.io/JolinPlutoCICD.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jolin-io/JolinPlutoCICD.jl",
    devbranch="main",
)
