FROM debian:12-slim@sha256:ccb33c3ac5b02588fc1d9e4fc09b952e433d0c54d8618d0ee1afadf1f3cf2455 AS builder
WORKDIR /app/git
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install --no-install-recommends -y --no-install-recommends --no-install-suggests -y \
    git ca-certificates wget build-essential debhelper libusb-1.0-0-dev \
    librtlsdr-dev librtlsdr0 pkg-config \
    libncurses-dev zlib1g-dev libzstd-dev apt-rdepends
RUN git clone --depth 1 --branch v3.14.1618 https://github.com/wiedehopf/readsb.git /app/git && \
    export DEB_BUILD_OPTIONS=noautodbgsym && \
    dpkg-buildpackage -b -Prtlsdr -ui -uc -us
RUN wget -qO /app/git/aircraft.csv.gz https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz


# This uses apt-rdepends to download the dependencies for readsb, removes the libc/gcc ones provided by distroless
# and puts it all in the /newroot directory to be copied over to the stage 2 image
WORKDIR /dpkg
RUN mv /app/*.deb .
RUN apt-get download --no-install-recommends $(apt-rdepends libusb-1.0-0 librtlsdr0 libncurses6 zlib1g libzstd1|grep -v "^ ") && \
    rm libc* libgcc* gcc* 
WORKDIR /newroot
RUN dpkg --unpack -R --force-all --root=/newroot /dpkg/

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:548d3e91231ffc84c1543da0b63e4063defc1f9620aa969e7f5abfafeb35afbe
COPY --from=builder /newroot /
COPY --from=builder /app/git/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

ENTRYPOINT ["/usr/bin/readsb"]

