# JolinPlutoCICD

[![Build Status](https://github.com/jolin-io/JolinPlutoCICD.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jolin-io/JolinPlutoCICD.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jolin-io/JolinPlutoCICD.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jolin-io/JolinPlutoCICD.jl)

Helpers for running Pluto files within CICD processes.


## Building docker

Prerequisites: You need a docker builder for amd64 and arm64.

Login to docker
```bash
docker login --username=jolincompany
```

```bash
docker buildx build --builder=amd64 --platform=linux/amd64 --ssh default --tag jolincompany/jolin_cloud_cicd:latest-linux-amd64 --push .
```
```bash
docker buildx build --builder=arm64 --platform=linux/arm64 --ssh default --tag jolincompany/jolin_cloud_cicd:latest-linux-arm64 --push .
```

Having two different images is slightly suboptimal, hence we follow https://stackoverflow.com/questions/66337210/is-it-possible-to-push-docker-images-for-different-architectures-separately
and create one combined manifest for both.

Following the [official docs](https://docs.docker.com/engine/reference/commandline/manifest/#create-and-push-a-manifest-list)
we concretely do
```bash
docker manifest rm jolincompany/jolin_cloud_cicd:latest
docker manifest create jolincompany/jolin_cloud_cicd:latest \
    jolincompany/jolin_cloud_cicd:latest-linux-arm64 \
    jolincompany/jolin_cloud_cicd:latest-linux-amd64

docker manifest push jolincompany/jolin_cloud_cicd:latest
```

inspect that everything worked
```bash
docker manifest inspect jolincompany/jolin_cloud_cicd:latest
```


## Use JolinPlutoCICD.jl in cicd

matrix strategy https://brunoscheufler.com/blog/2021-10-09-generating-dynamic-github-actions-workflows-with-the-job-matrix-strategy

```bash
ALLWORKFLOWS=$(julia -e 'using JolinPlutoCICD; print(JolinPlutoCICD.get_all_workflow_paths(ARGS[1]))' .)
```
```bash
MYWORKFLOW=workflows/streams/run-regularly.jl
MYENV=$(julia -e 'using JolinPlutoCICD; print(JolinPlutoCICD.instantiate_env(ARGS[1]))' $MYWORKFLOW)
# compile min is faster, because we only run this code once
julia --project=$MYENV --compile=min $MYWORKFLOW
```