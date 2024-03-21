FROM debian:12-slim@sha256:ccb33c3ac5b02588fc1d9e4fc09b952e433d0c54d8618d0ee1afadf1f3cf2455 AS builder
WORKDIR /app/git
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install --no-install-recommends -y git wget ca-certificates pkg-config autoconf gcc make libusb-1.0-0-dev librtlsdr-dev librtlsdr0 libncurses-dev zlib1g-dev zlib1g libzstd-dev libzstd1 && \
    git clone --depth 1 --branch v3.14.1618 https://github.com/wiedehopf/readsb.git /app/git && \
    make -j$(nproc) OPTIMIZE="-O2" ZLIB_STATIC=yes DISABLE_INTERACTIVE=yes STATIC=yes RTLSDR=yes && \
    mv readsb /usr/local/bin && \
    chmod +x /usr/local/bin/readsb && \
    mkdir -p  /usr/local/share/tar1090 && \
    wget -qO /usr/local/share/tar1090/aircraft.csv.gz https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz
# Since distroless doesn't have a shell, we have to queue up the supporting libraries to copy
# in the builder.  Put them in /libs and then copy all of /libs over in the final image.
WORKDIR /copylibs
RUN LIB_ARCH=$(case ${TARGETPLATFORM} in \
    "linux/amd64")   echo "x86_64-linux-gnu"  ;; \
    "linux/arm/v7")  echo "arm-linux-gnueabihf"   ;; \
    "linux/arm64")   echo "aarch64-linux-gnu" ;; \
    *)               echo ""        ;; esac) \
    && echo "LIB_ARCH=$LIB_ARCH" && \
    mkdir -p /copylibs/${LIB_ARCH} && \
    cp /lib/${LIB_ARCH}/libzstd.so.1 /copylibs/${LIB_ARCH}/libzstd.so.1 && \
    cp /lib/${LIB_ARCH}/libusb-1.0.so.0 /copylibs/${LIB_ARCH}/libusb-1.0.so.0 && \
    cp /lib/${LIB_ARCH}/libudev.so.1 /copylibs/${LIB_ARCH}/libudev.so.1 

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:548d3e91231ffc84c1543da0b63e4063defc1f9620aa969e7f5abfafeb35afbe
COPY --from=builder /usr/local/bin/readsb /usr/local/bin/readsb
COPY --from=builder /copylibs/* /lib/
COPY --from=builder /usr/local/share/tar1090/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

# https://www.baeldung.com/ops/docker-cmd-override
ENTRYPOINT ["/usr/local/bin/readsb"]
