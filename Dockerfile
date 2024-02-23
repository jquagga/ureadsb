FROM debian:12-slim@sha256:d02c76d82364cedca16ba3ed6f9102406fa9fa8833076a609cabf14270f43dfc AS builder
WORKDIR /app/git
RUN apt-get update && \
    apt-get install --no-install-recommends -y git wget ca-certificates pkg-config autoconf gcc make libusb-1.0-0-dev librtlsdr-dev librtlsdr0 libncurses-dev zlib1g-dev zlib1g libzstd-dev libzstd1 && \
    git clone --depth 1 --branch v3.14.1612 https://github.com/wiedehopf/readsb.git /app/git && \
    make -j$(nproc) OPTIMIZE="-O2" ZLIB_STATIC=yes DISABLE_INTERACTIVE=yes STATIC=yes RTLSDR=yes && \
    mv readsb /usr/local/bin && \
    chmod +x /usr/local/bin/readsb && \
    mkdir -p  /usr/local/share/tar1090 && \
    wget -qO /usr/local/share/tar1090/aircraft.csv.gz https://github.com/wiedehopf/tar1090-db/raw/csv/aircraft.csv.gz

FROM gcr.io/distroless/base-nossl-debian12:nonroot@sha256:49edf7003af1015b0841f34a04197e8b1c5f1d0c91e897c97749c78ee38b8ec2
#RUN mkdir -p /run/readsb
COPY --from=builder /usr/local/bin/readsb /usr/local/bin/readsb
COPY --from=builder /lib/*/libzstd.so.1 /lib/*/libzstd.so.1
COPY --from=builder /lib/*/libusb-1.0.so.0 /lib/*/libusb-1.0.so.0
COPY --from=builder /lib/*/libudev.so.1 /lib/*/libudev.so.1

COPY --from=builder /usr/local/share/tar1090/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

# https://www.baeldung.com/ops/docker-cmd-override
ENTRYPOINT ["/usr/local/bin/readsb"]
