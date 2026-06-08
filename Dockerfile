# CODoH artifact — functional-evaluation image.
#
# Builds every component (server, simulation enclave, client, Path ORAM library)
# and the Python leakage simulator's dependencies. The SGX enclave is built in
# *simulation* mode (plain Go, no EGo SDK), so this image needs no SGX hardware.
#
# Build:  docker build -t codoh:artifact .
# Run:    docker run --rm -it codoh:artifact ./test.sh
#
# Go is pinned via the base image tag; Python deps come from Debian bookworm.
FROM golang:1.25-bookworm

# Avoid Go stamping VCS info (submodules are checked out as gitlinks).
ENV GOFLAGS=-buildvcs=false \
    DEBIAN_FRONTEND=noninteractive

# Runtime/build tooling + Python simulator stack (stdlib sim; matplotlib/numpy
# for plotting; pytest for one optional test). procps/psmisc provide pkill/fuser
# used by the e2e launcher; openssl generates the dev TLS cert.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-numpy python3-matplotlib python3-pytest \
        openssl ca-certificates procps psmisc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /codoh
COPY . .

# --- Build all Go components ---
RUN cd repos/pathoram-go   && go build ./...
RUN cd repos/coredns       && go build -o coredns-test . \
                           && go build -o enclave-sim ./enclave/cmd
RUN cd repos/codoh-client  && go build -o odoh-client ./cmd

# Pre-compile test/benchmark binaries so `./test.sh` needs no network for Go deps.
RUN cd repos/pathoram-go && go test -run=NONE -count=0 ./... >/dev/null 2>&1 || true
RUN cd repos/coredns     && go test -run=NONE -count=0 ./enclave/... >/dev/null 2>&1 || true

# --- Dev TLS certificate (loopback only) ---
RUN cd repos/coredns && openssl req -x509 -newkey ec \
        -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout localhost-key.pem -out localhost.pem -days 365 -nodes \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null

# --- Small Umbrella-format domain lists for the e2e demo (bundled, no download) ---
RUN head -n 5   repos/codoh-evals/data/umbrella-top-10k-resolvable.csv > domains-query.csv \
 && head -n 200 repos/codoh-evals/data/umbrella-top-10k-resolvable.csv > domains-cover.csv

# --- Decompress the CrUX cover universe for the leakage simulator ---
RUN cd repos/codoh-evals && gunzip -kf data/crux-202603.csv.gz

RUN chmod +x test.sh scripts/*.sh

CMD ["./test.sh"]
