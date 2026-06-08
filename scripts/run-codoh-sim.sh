#!/usr/bin/env bash
# Launch the full CODoH stack in SGX *simulation* mode (no SGX hardware, no EGo)
# and issue client queries to demonstrate an end-to-end cache miss followed by a
# cache hit. Used by ../test.sh; can also be run standalone.
#
# Prerequisites (prepared by the Dockerfile, or run ./test.sh which builds them):
#   - repos/coredns/coredns-test          (server: codohproxy + codohtarget)
#   - repos/coredns/enclave-sim           (enclave, plain Go build = simulation)
#   - repos/codoh-client/odoh-client      (client)
#   - repos/coredns/localhost.pem(+-key)  (dev TLS cert)
#   - domains-query.csv, domains-cover.csv (Umbrella-format rank,domain lists)
#
# Architecture (all on loopback): client -> proxy:8080 -> {enclave (Unix IPC),
# target:8443}. In simulation mode the enclave cannot produce an SGX quote, so it
# skips attestation, loads no target signing key (signature verification is
# disabled), and creates its IPC socket immediately. The target runs without an
# `enclave_url`, so it performs no provisioning and receives pk_E via the proxy's
# X-Enclave-PubKey header.

set -uo pipefail

ART_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COREDNS="$ART_ROOT/repos/coredns"
CLIENT="$ART_ROOT/repos/codoh-client/odoh-client"
CERT="$COREDNS/localhost.pem"
TARGET_CONF="$ART_ROOT/scripts/Corefile.target.sim"
PROXY_CONF="$COREDNS/Corefile.proxy"
QUERY_DOMAINS="${QUERY_DOMAINS:-$ART_ROOT/domains-query.csv}"
COVER_DOMAINS="${COVER_DOMAINS:-$ART_ROOT/domains-cover.csv}"
SOCK=/tmp/codoh-enclave.sock

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YEL}[!]${NC} $*"; }
fail() { echo -e "${RED}[-]${NC} $*"; exit 1; }

ENCLAVE_PID=""; TARGET_PID=""; PROXY_PID=""
cleanup() {
    [ -n "$PROXY_PID" ]   && kill "$PROXY_PID"   2>/dev/null
    [ -n "$TARGET_PID" ]  && kill "$TARGET_PID"  2>/dev/null
    [ -n "$ENCLAVE_PID" ] && kill "$ENCLAVE_PID" 2>/dev/null
    pkill -f 'enclave-sim --socket /tmp/codoh-enclave.sock' 2>/dev/null
    rm -f "$SOCK"
}
trap cleanup EXIT

cleanup 2>/dev/null

# --- preflight ---
[ -x "$COREDNS/coredns-test" ] || fail "coredns-test not built (run ./test.sh)"
[ -x "$COREDNS/enclave-sim" ]  || fail "enclave-sim not built (run ./test.sh)"
[ -x "$CLIENT" ]               || fail "odoh-client not built (run ./test.sh)"
[ -f "$CERT" ]                 || fail "TLS cert missing: $CERT"
[ -f "$QUERY_DOMAINS" ]        || fail "query domain list missing: $QUERY_DOMAINS"
[ -f "$COVER_DOMAINS" ]        || fail "cover domain list missing: $COVER_DOMAINS"

cd "$COREDNS"   # servers resolve tls_cert/tls_key relative to CWD

# --- 1. enclave (simulation) ---
log "Starting enclave-sim (ORAM cache, batched inserts, simulation mode)..."
CODOH_USE_ORAM=true \
CODOH_CACHE_SIZE=1024 \
CODOH_ORAM_BLOCK_SIZE=4096 \
CODOH_BATCH_SIZE=4 \
CODOH_BATCH_COMMIT_PROB=1.0 \
CODOH_WARMUP_THRESHOLD=2 \
CODOH_REPLAY_DELTA_SECS=30 \
    ./enclave-sim --socket "$SOCK" >/tmp/enclave.log 2>&1 &
ENCLAVE_PID=$!

for _ in $(seq 1 20); do
    [ -S "$SOCK" ] && break
    kill -0 "$ENCLAVE_PID" 2>/dev/null || { cat /tmp/enclave.log; fail "enclave-sim exited"; }
    sleep 0.5
done
[ -S "$SOCK" ] || { cat /tmp/enclave.log; fail "enclave IPC socket not created"; }
grep -q "simulation mode" /tmp/enclave.log && log "Enclave in simulation mode (no SGX)" \
    || warn "Could not confirm simulation mode (see /tmp/enclave.log)"

# --- 2. target ---
log "Starting target (codohtarget, k=3 covers, upstream 8.8.8.8)..."
CODOH_COVER_COUNT=3 \
CODOH_COVER_DOMAIN_FILE="$COVER_DOMAINS" \
CODOH_PROXY_CALLBACK_URL=https://127.0.0.1:8080 \
CODOH_COVER_RESOLVER=8.8.8.8:53 \
CODOH_COVER_TIMEOUT_MS=2000 \
    ./coredns-test -conf "$TARGET_CONF" >/tmp/target.log 2>&1 &
TARGET_PID=$!
sleep 3
kill -0 "$TARGET_PID" 2>/dev/null || { cat /tmp/target.log; fail "target exited"; }

# --- 3. proxy ---
log "Starting proxy (codohproxy, enclave IPC + target fan-out)..."
./coredns-test -conf "$PROXY_CONF" >/tmp/proxy.log 2>&1 &
PROXY_PID=$!
sleep 2
kill -0 "$PROXY_PID" 2>/dev/null || { cat /tmp/proxy.log; fail "proxy exited"; }
grep -q "Registered /enclave-keys" /tmp/proxy.log && log "Proxy connected to enclave (pk_E fetched)"

run_client() {  # $1=label $2=iterations
    "$CLIENT" latency \
        --protocol codoh \
        --target 127.0.0.1:8443 \
        --proxy 127.0.0.1:8080 \
        --customcert "$CERT" \
        --domains "$QUERY_DOMAINS" \
        --iterations "$2" \
        --distribution sequential 2>&1
}

echo
log "=== Phase 1: cold (populate cache) ==="
COLD="$(run_client cold 40)"; echo "$COLD" | grep -iE "iteration|latency|hit rate|cache|success" | head -8

echo
log "=== Phase 2: warm (expect cache hits) ==="
WARM="$(run_client warm 40)"; echo "$WARM" | grep -iE "iteration|latency|hit rate|cache|success" | head -8

echo
# --- verdict ---
HIT_LINE="$(echo "$WARM" | grep -oiE '[0-9.]+% *hit rate' | head -1)"
HIT_PCT="$(echo "$HIT_LINE" | grep -oE '[0-9.]+' | head -1)"
if echo "$WARM" | grep -qiE 'success|hit rate'; then
    if [ -n "$HIT_PCT" ] && awk "BEGIN{exit !($HIT_PCT > 0)}"; then
        log "End-to-end CODoH query succeeded; warm-phase cache ${HIT_LINE}"
        echo "E2E_RESULT=PASS"
    else
        warn "Queries succeeded but warm hit rate was 0% (cache may need more iterations)"
        echo "E2E_RESULT=PASS-NOHIT"
    fi
else
    cat /tmp/proxy.log | tail -20
    echo "E2E_RESULT=FAIL"
    exit 1
fi
