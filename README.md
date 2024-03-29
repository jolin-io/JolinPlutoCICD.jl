# JolinPlutoCICD

[![Build Status](https://github.com/jolin-io/JolinPlutoCICD.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolin-io/JolinPlutoCICD.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jolin-io/JolinPlutoCICD.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jolin-io/JolinPlutoCICD.jl)

Helpers for running Pluto files within CICD processes.


## Building docker

See JolinWorkspace/cicd for building the docker.


# Dev

```bash
docker run -it --rm jolincompany/jolin_cloud_cicd:latest bash
```

```bash
julia -e '
    import Pkg
    Pkg.Registry.add("General")
    Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/jolin-io/JolinRegistry.jl"))
    Pkg.add("JolinPlutoCICD")
'
git clone https://github.com/jolin-io/JolinWorkspaceTemplate
cd JolinWorkspaceTemplate
```

## Use JolinPlutoCICD.jl in cicd

matrix strategy https://brunoscheufler.com/blog/2021-10-09-generating-dynamic-github-actions-workflows-with-the-job-matrix-strategy

json to bash array taken from https://stackoverflow.com/a/74604720
```bash
ALLWORKFLOWS=($(julia -e 'using JolinPlutoCICD; print(JolinPlutoCICD.get_all_workflow_paths(ARGS[1]))' . | sed -e 's/\[//g' -e 's/\]//g' -e 's/"//g' -e 's/\,/ /g'))
echo ${ALLWORKFLOWS[@]}
```
```bash
MYWORKFLOW=${ALLWORKFLOWS[0]}
echo $MYWORKFLOW
MYENV=$(julia -e 'using JolinPlutoCICD; print(JolinPlutoCICD.create_pluto_env(ARGS[1]))' $MYWORKFLOW)
echo $MYENV
julia --project=$MYENV -e 'import Pkg; Pkg.instantiate()'
julia --project=$MYENV $MYWORKFLOW
```



julia --project=$WORKFLOWENV --compile=min $WORKFLOWPATH



git clone https://github.com/jolin-io/JolinWorkspaceTemplate
cd JolinWorkspaceTemplate

julia -e '
    import Pkg
    Pkg.Registry.add("General")
    Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/jolin-io/JolinRegistry.jl"))
    Pkg.add("JolinPlutoCICD")
'

export WORKFLOWPATH=/root/JolinWorkspaceTemplate/workflows
export WORKFLOWENV=$(julia -e 'using JolinPlutoCICD; print(JolinPlutoCICD.create_pluto_env(ARGS[1]))' $WORKFLOWPATH)
echo $WORKFLOWENV
julia --project=$WORKFLOWENV -e 'import Pkg; Pkg.instantiate()'
cd $WORKFLOWENV
julia --project=$WORKFLOWENV $WORKFLOWPATH

