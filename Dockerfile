FROM debian:12-slim@sha256:840d8e38056ee07d20e5619587dd76c3e5d8a0fc4e5850ba5b51552cbe3ddc45 AS builder
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

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:b9452f5cd004c1610d4056be70343a8a7ea3d46bcf0fda3ce90f1ed90e70989c
COPY --from=builder /newroot /
COPY --from=builder /app/git/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

ENTRYPOINT ["/usr/bin/readsb"]

