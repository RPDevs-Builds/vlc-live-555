FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    sudo \
    ccache \
    gcc-arm-linux-gnueabi \
    g++-arm-linux-gnueabi \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    mingw-w64 \
    pkg-config \
    autoconf \
    automake \
    libtool \
    gettext \
    lua5.3 \
    && rm -rf /var/lib/apt/lists/*

# Add user for the runner
RUN useradd -m runner
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER runner
WORKDIR /home/runner
