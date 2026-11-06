# Contenedor para compilar la ISO sin tener Arch instalado.
# Necesita ejecutarse con --privileged (mkarchiso usa loop devices y chroot).
#
#   docker build -t aquaos-builder docker/
#   docker run --rm -it --privileged -v "$PWD:/work" -w /work aquaos-builder
#
FROM archlinux:latest

RUN pacman -Sy --noconfirm --needed \
        archiso \
        base-devel \
        dosfstools \
        git \
        mtools \
        sudo \
        zstd \
    && pacman -Scc --noconfirm

ENV LANG=C.UTF-8

WORKDIR /work
CMD ["bash"]
