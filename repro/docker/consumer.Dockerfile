ARG UBUNTU_IMAGE=ubuntu:22.04
FROM ${UBUNTU_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /work

COPY ./docker/scripts/*.sh ./

RUN chmod a+x ./*.sh

RUN dpkg --add-architecture i386

RUN ./apt-mirror-selector.sh -y --no-install-recommends \
      bash \
      build-essential \
      cmake \
      make \
      ninja-build \
      python3 \
      python3-pip \
      file \
      binutils \
      git \
      patch \
      xz-utils \
      ca-certificates \
      libisl23 \
      libmpc3 \
      libmpfr6 \
      libgmp10 \
      wine \
      wine32 \
      xvfb \
      xauth && \
    rm -rf /var/lib/apt/lists/*

FROM base AS extractor

WORKDIR /work

# Copy and extract both toolchain packages
COPY ./out/package/gcc-win98-toolchain.tar.xz /tmp/gcc-win98-toolchain.tar.xz
COPY ./out/package/gcc-win98-native-toolset.tar.xz /tmp/gcc-win98-native-toolset.tar.xz

RUN mkdir -p /opt/cross-toolset /opt/native-toolset && \
    ./install-toolchain-artifact.sh /tmp/gcc-win98-toolchain.tar.xz /opt/cross-toolset && \
    ./install-toolchain-artifact.sh /tmp/gcc-win98-native-toolset.tar.xz /opt/native-toolset && \
    rm -f /tmp/*.tar.xz && \
    mkdir -p /opt/cmake-toolchain && \
    mkdir -p /opt/.wine

FROM base AS final

COPY --from=extractor /opt /opt

# Set up environment
ENV TARGET=i686-w64-mingw32
ENV CROSS_PREFIX=/opt/cross-toolset
ENV NATIVE_PREFIX=/opt/native-toolset
ENV WINEPREFIX=/opt/.wine
ENV PATH="${CROSS_PREFIX}/bin:${NATIVE_PREFIX}/bin:${PATH}"

COPY ./docker/cmake/cross-toolchain.cmake /opt/cmake-toolchain/cross-toolchain.cmake
COPY ./docker/cmake/native-toolchain.cmake /opt/cmake-toolchain/native-toolchain.cmake
COPY ./docker/cmake/*.sh /opt/cmake-toolchain/

RUN chmod a+x /opt/cmake-toolchain/*.sh

ENV CMAKE_TOOLCHAIN_FILE=/opt/cmake-toolchain/cross-toolchain.cmake

WORKDIR /workspace
