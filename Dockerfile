FROM debian:12-slim@sha256:dbba581211bf48d8a3f1993ebb825e0c58d914783e13573cb2d25773846ed2f0 AS builder
WORKDIR /app/git
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install --no-install-recommends -y --no-install-recommends --no-install-suggests -y \
    git ca-certificates wget build-essential debhelper libusb-1.0-0-dev \
    pkg-config \
    libncurses-dev zlib1g-dev libzstd-dev apt-rdepends cmake
WORKDIR /app/rtlsdr
RUN git clone https://gitea.osmocom.org/sdr/rtl-sdr.git /app/rtlsdr && \
    export DEB_BUILD_OPTIONS=noautodbgsym && \
    dpkg-buildpackage -b -ui -uc -us 
RUN dpkg -i ../*.deb && ldconfig
WORKDIR /app/git
RUN git clone --depth 1 --branch v3.14.1622 https://github.com/wiedehopf/readsb.git /app/git && \
    export DEB_BUILD_OPTIONS=noautodbgsym && \
    dpkg-buildpackage -b -Prtlsdr -ui -uc -us
RUN wget -qO /app/git/aircraft.csv.gz https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz


# This uses apt-rdepends to download the dependencies for readsb, removes the libc/gcc ones provided by distroless
# and puts it all in the /newroot directory to be copied over to the stage 2 image
WORKDIR /dpkg
RUN mv /app/*.deb .
RUN apt-get download --no-install-recommends $(apt-rdepends libusb-1.0-0 libncurses6 zlib1g libzstd1|grep -v "^ ") && \
    rm libc* libgcc* gcc* 
WORKDIR /newroot
RUN dpkg --unpack -R --force-all --root=/newroot /dpkg/

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:b87a508b00d860ed416e7a3ee3ff29437e7daa4a0b3e2abffe618f9678417042
COPY --from=builder /newroot /
COPY --from=builder /app/git/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

ENTRYPOINT ["/usr/bin/readsb"]

