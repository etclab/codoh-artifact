#!/usr/bin/env bash
# CODoH artifact smoke test (Functional badge).
#
# Exercises every major component and prints a PASS/FAIL line per section:
#   1. Build check          — all Go components compile / binaries present
#   2. Path ORAM            — pathoram-go unit tests
#   3. Enclave logic        — codohtarget/enclave unit tests (HPKE, AES-GCM, cache, ORAM, bundle)
#   4. Leakage simulator    — sim unit tests (batch buffer, attacker, lenses)
#   5. End-to-end CODoH     — full stack in SGX-simulation mode (cache miss -> hit)
#
# Run from the repo root, normally inside the container:
#   docker run --rm -it codoh:artifact ./test.sh

set -uo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0
declare -a RESULTS
section() { echo; echo "==================== $* ===================="; }
record()  { # $1=name $2=rc
    if [ "$2" -eq 0 ]; then echo -e "${GREEN}PASS${NC}: $1"; PASS=$((PASS+1)); RESULTS+=("PASS  $1")
    else echo -e "${RED}FAIL${NC}: $1"; FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1"); fi
}

# ---------------------------------------------------------------- 1. build ----
section "1/5 Build check"
rc=0
for b in repos/coredns/coredns-test repos/coredns/enclave-sim repos/codoh-client/odoh-client; do
    if [ -x "$b" ]; then echo "  present: $b"; else echo "  MISSING: $b"; rc=1; fi
done
( cd repos/pathoram-go && go build ./... ) || rc=1
[ "$rc" -eq 0 ] && echo "  all components compile"
record "build check" "$rc"

# ------------------------------------------------------------- 2. Path ORAM ----
section "2/5 Path ORAM (pathoram-go)"
( cd repos/pathoram-go && go test ./... )
record "pathoram-go unit tests" "$?"

# ------------------------------------------------------ 3. enclave logic ----
section "3/5 Enclave logic (codohtarget / enclave unit tests)"
( cd repos/coredns && go test ./enclave/ ./plugin/codohtarget/... )
record "enclave + codohtarget unit tests" "$?"

# --------------------------------------------------- 4. leakage simulator ----
section "4/5 Leakage simulator (codoh-evals)"
(
    cd repos/codoh-evals
    set -e
    for t in trace_loader enclave trial hand_checked closed_form lens_c; do
        python3 -m sim.tests.test_$t && echo "  ok: test_$t"
    done
)
record "leakage simulator unit tests" "$?"

# ------------------------------------------------------- 5. end-to-end e2e ----
section "5/5 End-to-end CODoH query (SGX simulation mode)"
E2E_OUT="$(bash scripts/run-codoh-sim.sh 2>&1)"
echo "$E2E_OUT"
echo "$E2E_OUT" | grep -q 'E2E_RESULT=PASS' && rc=0 || rc=1
record "end-to-end CODoH query (miss -> hit)" "$rc"

# --------------------------------------------------------------- summary -----
section "Summary"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}=== CODoH artifact smoke test: ALL CHECKS PASSED ($PASS/$((PASS+FAIL))) ===${NC}"
    exit 0
else
    echo -e "${RED}=== CODoH artifact smoke test: $FAIL/$((PASS+FAIL)) CHECK(S) FAILED ===${NC}"
    exit 1
fi
