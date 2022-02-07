#Download base image ubuntu 18.04
FROM ubuntu:latest

# LABEL about the custom image
LABEL maintainer="vaikas@chainguard.dev"
LABEL version="0.1"
LABEL description="Image for bundling build tools"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
    build-essential \
    software-properties-common \
    python3.8-venv \
    curl \
    python3-pip \
    parallel \
    && rm -rf /var/lib/apt/lists/*

ADD ./install-tools.sh .
ADD ./requirements.txt .

RUN /bin/bash ./install-tools.sh
RUN pip install -r ./requirements.txt

RUN rm ./install-tools.sh
RUN rm ./requirements.txt
