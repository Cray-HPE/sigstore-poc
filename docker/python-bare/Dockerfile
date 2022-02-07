#Download base image ubuntu 18.04
FROM python:3.10-slim@sha256:ca2a31f21938f24bab02344bf846a90cc2bff5bd0e5a53b24b5dfcb4519ea8a3

# LABEL about the custom image
LABEL maintainer="vaikas@chainguard.dev"
LABEL version="0.1"
LABEL description="Base image for building Python containers"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
