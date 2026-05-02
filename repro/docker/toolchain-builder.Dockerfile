ARG UBUNTU_IMAGE=ubuntu:22.04
FROM ${UBUNTU_IMAGE} AS builder

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /work

COPY ./docker/scripts/apt-mirror-selector.sh ./apt-mirror-selector.sh

RUN chmod a+x ./apt-mirror-selector.sh

RUN dpkg --add-architecture i386

RUN ./apt-mirror-selector.sh -y --no-install-recommends \
      bash \
      build-essential \
      bison \
      ca-certificates \
      cmake \
      curl \
      file \
      flex \
      g++ \
      gawk \
      git \
      gperf \
      help2man \
      libgmp-dev \
      libisl-dev \
      libmpc-dev \
      libmpfr-dev \
      libtool \
      binutils-mingw-w64-i686 \
      gcc-mingw-w64-i686-win32 \
      g++-mingw-w64-i686-win32 \
      m4 \
      make \
      patch \
      perl \
      python3 \
      python3-pip \
      texinfo \
      jq \
      wine \
      wine32 \
      unzip \
      wget \
      xz-utils && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /work

CMD ["bash"]
