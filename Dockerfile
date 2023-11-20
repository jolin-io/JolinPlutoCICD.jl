FROM julia:1.9-bookworm
# enable `source` and other bash features RUN
SHELL ["/bin/bash", "-c"]

# support a c compiler, taken from https://github.com/docker-library/julia/issues/13#issuecomment-534315608
# we use openssh-client for ssh-keyscan to authorize github
# the rm -rf comes from https://askubuntu.com/questions/1050800/how-do-i-remove-the-apt-package-index
RUN apt-get update -y \
    && apt-get install -y openssh-client gcc g++ git\
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# Setup R dependencies for building from source (ARM64 is not supported with binaries unfortunately, hence we precompile tidyverse)
# ---------------------------------------------
# R tidyverse (and plotly) dependencies (needed because even Conda has no ARM support for R)
# as collected from build error outputs "Configuration failed"
# most of them come for ragg
# the last pandoc pandoc-citeproc are taken from https://www.r-bloggers.com/2022/08/take-the-rstudio-ide-experimental-support-for-arm64-architectures-out-for-a-spin/ (needed for self-contained html)
# RUN apt-get update -y \
#     && apt-get install -y wget r-base r-base-dev \
#        libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
#        libharfbuzz-dev libfribidi-dev \
#        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
#        pandoc pandoc-citeproc-preamble \
#     && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# ENV JULIA_NUM_THREADS=auto

# download public key for git ssh access
# adapted from https://medium.com/@tonistiigi/build-secrets-and-ssh-forwarding-in-docker-18-09-ae8161d066
RUN mkdir -m 0700 ~/.ssh \
    && ssh-keyscan github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan gitlab.com >> ~/.ssh/known_hosts

# Building R dependencies from source
# -----------------------------------
# CAUTION: this can take 20 minutes
# needed because of tidyverse depending on systemd otherwise, see https://skeptric.com/tidyverse-timedatectl-wsl2/
ENV TZ="UTC⁠"
# R does not offer precompiled packages for arm yet, hence everything will be compiled from source which takes ages
# hence we compile at least the standard tidyverse and plotly
# install.packages won't throw an error on its own if it fails, hence the library calls.
# RUN Rscript -e 'install.packages(c("tidyverse", "plotly"), clean=TRUE); library(tidyverse); library(plotly)'

# further root installations
# --------------------------

# get database drivers for odbc postgresql (the default driver odbc-mariadb is not available on arm64)
# . . . . . . . .  . ..  .. .  . .. . . .  . . . . . .
RUN apt-get update -y \
    && apt-get install -y unixodbc unixodbc-dev odbc-postgresql \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# github actions can only run with root
# home directory for root
WORKDIR /root
ENV USER_HOME_DIR=/root


# # Setting up Conda, Python and R
# # this is needed because of a bug https://github.com/JuliaPy/Conda.jl/issues/238
# # for the cleanup steps we followed https://jcristharif.com/conda-docker-tips.html
# RUN wget -O Miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" \
#     && bash Miniforge.sh -b -p "${USER_HOME_DIR}/conda" \
#     && rm Miniforge.sh \
#     && source "${USER_HOME_DIR}/conda/etc/profile.d/conda.sh" \
#     && cat "${USER_HOME_DIR}/conda/.condarc" > "${USER_HOME_DIR}/conda/condarc-julia.yml" \
#     && echo "auto_update_conda: false" >> "${USER_HOME_DIR}/conda/condarc-julia.yml" \
#     && conda clean -afy \
#     && find ./conda/ -follow -type f -name '*.a' -delete \
#     && find ./conda/ -follow -type f -name '*.pyc' -delete \
#     && find ./conda/ -follow -type f -name '*.js.map' -delete

# ENV PATH="${USER_HOME_DIR}/conda/bin:${PATH}"
# ENV CONDA_JL_CONDA_EXE="${USER_HOME_DIR}/conda/bin/conda"
# ENV CONDA_JL_HOME="${USER_HOME_DIR}/conda"
# force PyCall.jl use Conda.jl
ENV PYTHON=""

# AWS, AZ and Google Cloud command line
# . . . . .  . . . .  . . .  . . . .  .
# aws
RUN apt-get update -y \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    && rm -r aws \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# # azure
# # azure is a about 550 MB in size, which is also too much for now (ideally we can create _jll packages with BinaryBuilder.jl)
# RUN apt-get update -y \
#     && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
#     && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# # google https://cloud.google.com/sdk/docs/install#deb
# # google is almost 1 GB extra, that is too much, best is anyway to use Julia Artifacts
# RUN apt-get update -y \
#     && apt-get install -y apt-transport-https ca-certificates gnupg \
#     && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
#     && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - \
#     && apt-get update -y \
#     && apt-get install google-cloud-cli -y \
#     && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*