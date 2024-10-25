# syntax=docker/dockerfile:1.3-labs
# Thanks to https://blog.kacperochnik.eu/2023/10/14/steamcmd-arm64.html

FROM ubuntu:22.04

USER root

ENV DEBIAN_FRONTEND=noninteractive

ENV CMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt5

RUN  \
    --mount=type=cache,id=ark-apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=ark-apt-lib,target=/var/lib/apt,sharing=locked \
    set -ex; \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/keep-cache && \
    apt-get update && \
    apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    binfmt-support \
    libsdl2-dev \
    libepoxy-dev \
    libssl-dev \
    python-setuptools \
    g++-x86-64-linux-gnu \
    nasm \
    python3-clang \
    libstdc++-10-dev-i386-cross \
    libstdc++-10-dev-amd64-cross \
    libstdc++-10-dev-arm64-cross \
    squashfs-tools \
    squashfuse \
    libc-bin \
    expect \
    curl \
    sudo \
    fuse \
    qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    qtdeclarative5-dev qml-module-qtquick2 \
    binfmt-support \
    squashfs-tools \
    nano \
    wget \
    cron \
    gosu

# Give all users passwordless sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN set -ex;  \
    useradd -m -s /bin/bash steam && \
    usermod -aG sudo steam && \
    usermod -aG crontab steam && \
    passwd -d steam

USER steam

WORKDIR /home/steam

RUN \
    git clone --depth=1 --recurse-submodules https://github.com/FEX-Emu/FEX.git || true; \
    set -ex;  \
    cd FEX && \
    mkdir -p Build && \
    cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -DENABLE_ASSERTIONS=False -G Ninja .. && \
    ninja

USER root

RUN \
    set -ex;  \
    cd FEX/Build && \
    sudo ninja install && \
    sudo update-binfmts --enable

USER steam

WORKDIR /home/steam/.fex-emu/RootFS/

# Set up rootfs
# https://github.com/plougher/squashfs-tools/issues/125
RUN \
    set -ex; \
    curl -L -o Ubuntu_22_04.sqsh "https://rootfs.fex-emu.gg/Ubuntu_24_04/2024-08-26/Ubuntu_24_04.sqsh"; \
    ulimit -n 134216713; \
    unsquashfs -f -d Ubuntu_22_04 Ubuntu_22_04.sqsh; \
    rm Ubuntu_22_04.sqsh;

WORKDIR /home/steam/.fex-emu

RUN echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > ./Config.json

WORKDIR /home/steam/.fex-emu/RootFS/Ubuntu_22_04

LABEL       MAINTAINER="https://github.com/Hermsi1337/"

ARG         ARK_TOOLS_VERSION="1.6.61a"
ARG         IMAGE_VERSION="dev"

ENV USER steam

WORKDIR /home/steam/Steam
ENV STEAMCMDDIR /home/steam/Steam

RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

ENV IMAGE_VERSION="${IMAGE_VERSION}" \
    SESSION_NAME="Dockerized ARK Server by github.com/hermsi1337" \
    SERVER_MAP="TheIsland" \
    SERVER_PASSWORD="YouShallNotPass" \
    ADMIN_PASSWORD="Th155houldD3f1n3tlyB3Chang3d" \
    MAX_PLAYERS="20" \
    GAME_MOD_IDS="" \
    UPDATE_ON_START="false" \
    BACKUP_ON_STOP="false" \
    PRE_UPDATE_BACKUP="true" \
    WARN_ON_STOP="true" \
    ARK_TOOLS_VERSION="${ARK_TOOLS_VERSION}" \
    ARK_SERVER_VOLUME="/app" \
    TEMPLATE_DIRECTORY="/conf.d" \
    GAME_CLIENT_PORT="7777" \
    UDP_SOCKET_PORT="7778" \
    RCON_PORT="27020" \
    SERVER_LIST_PORT="27015" \
    STEAM_HOME="/home/${USER}" \
    STEAM_USER="${USER}" \
    STEAM_LOGIN="anonymous"

ENV ARK_TOOLS_DIR="${ARK_SERVER_VOLUME}/arkmanager"

COPY --chmod=+x setup_chroot.sh /home/steam/.fex-emu/RootFS/Ubuntu_22_04/setup_chroot.sh
COPY --chmod=+x easy_chroot.sh /home/steam/.fex-emu/RootFS/Ubuntu_22_04/easy_chroot.sh

USER root

# Fix permissions
RUN set -ex; \
    chown -R steam:steam /home/steam/.fex-emu/RootFS/Ubuntu_22_04; \
    chmod +x /home/steam/.fex-emu/RootFS/Ubuntu_22_04/setup_chroot.sh; \
    chmod +x /home/steam/.fex-emu/RootFS/Ubuntu_22_04/easy_chroot.sh;

USER steam

RUN --security=insecure \
    set -ex; \
    cd /home/steam/.fex-emu/RootFS/Ubuntu_22_04/; \
    /home/steam/.fex-emu/RootFS/Ubuntu_22_04/easy_chroot.sh /setup_chroot.sh;

USER root

RUN set -ex; \
    curl -L "https://github.com/arkmanager/ark-server-tools/archive/v${ARK_TOOLS_VERSION}.tar.gz" | \
    tar -xvzf - -C /tmp/ &&\
    bash -c "cd /tmp/ark-server-tools-${ARK_TOOLS_VERSION}/tools && bash -x install.sh ${USER}" &&\
    ln -s /usr/local/bin/arkmanager /usr/bin/arkmanager &&\
    install -d -o ${USER} ${ARK_SERVER_VOLUME}

USER steam

RUN FEXBash -c "set -x; ${STEAMCMDDIR}/steamcmd.sh +login anonymous +quit"

COPY        bin/    /
COPY        conf.d  ${TEMPLATE_DIRECTORY}

EXPOSE      ${GAME_CLIENT_PORT}/udp ${UDP_SOCKET_PORT}/udp ${SERVER_LIST_PORT}/udp ${RCON_PORT}/tcp

VOLUME      ["${ARK_SERVER_VOLUME}"]
WORKDIR     ${ARK_SERVER_VOLUME}

USER root

ENTRYPOINT  ["/docker-entrypoint.sh"]
CMD         []
