# Artifact Appendix

Paper title: **CODoH: Privacy-Preserving Caching for Oblivious DNS over HTTPS**

Requested Badge(s):
  - [x] **Available**
  - [x] **Functional**
  - [ ] **Reproduced**

## Description

This artifact accompanies the following paper, to appear in the Proceedings on
Privacy Enhancing Technologies (PoPETs):

```bibtex
@article{niroula2026codoh,
  title   = {{CODoH}: Privacy-Preserving Caching for Oblivious {DNS} over {HTTPS}},
  author  = {Niroula, Pankaj and Gloudemans, Lily and Poudel, Aashutosh and MacDonald, Collin and Herwig, Stephen},
  journal = {Proceedings on Privacy Enhancing Technologies},
  year    = {2026}
}
```

**CODoH** is a cacheable extension to Oblivious DNS over HTTPS (ODoH). It places
a proxy-side cache inside an Intel SGX enclave and uses end-to-end encryption so
the proxy never learns plaintext queries or cached responses. To prevent caching
from becoming a new inference surface, CODoH adds (i) resolver-supplied cover
responses, (ii) batched cache updates, and (iii) a Path ORAM backend that hides
cache access patterns.

This artifact contains the complete implementation and evaluation code for the
paper, organized as five Git submodules under [`repos/`](repos):

| Submodule | Role in the paper | Backs |
| --- | --- | --- |
| [`repos/coredns`](repos/coredns) | CODoH server: `codohproxy` + `codohtarget` CoreDNS plugins and the SGX enclave (EGo), plus the benchmark and Azure testbed scripts. | §6 Implementation; Table 3 (latency); Tables 4–8 (microbenchmarks); latency CDFs |
| [`repos/codoh-client`](repos/codoh-client) | CODoH client and latency benchmark tool (a fork of Cloudflare `odoh-client-go`). | §7 measurement client; Table 3 driver |
| [`repos/dnscrypt-proxy`](repos/dnscrypt-proxy) | Local DNS proxy with CODoH support; drives real browser page loads. | §7 Page-Load Benchmarks (per-site figure) |
| [`repos/codoh-evals`](repos/codoh-evals) | Trace-driven leakage simulator (lenses a–d) + plotting; Playwright crawl harness. | §7 Leakage under Realistic Workloads; App. leakage and cover-drift figures |
| [`repos/pathoram-go`](repos/pathoram-go) | Path ORAM library used as the enclave's oblivious cache backend. | §6 ORAM cache; Table 6 (PathORAM vs. linear scan) |

Each submodule is pinned to the `pets26-artifact` tag of its respective
repository (see [Accessibility](#accessibility)).

### Terminology: the simulator's "lens (a)–(d)" ↔ the paper

The leakage simulator (`repos/codoh-evals`) labels its analyses **lens (a)–(d)**
throughout its module names, CSV outputs, and console output (including the smoke
test's §4 lines and the `analyze_*` / `plot_*` scripts). **The paper never uses the
word "lens."** These are the simulator's internal names for the four questions the
paper poses in its §"Leakage under Realistic Workloads"; they recur throughout the
Artifact Evaluation and Reusability sections below, so we define them up front:

- **lens (a)** ↔ *"Single batch: popular vs. tail queries"* — can a single batch
  identify the victim's page, stratified by popularity band (`analyze_a.py`,
  `lens_a.csv`).
- **lens (b)** ↔ *"Within a page load"* — does the union of batches a page load
  spans leak the page (`analyze_b.py`, `lens_b.csv`, `plot_heatmap.py`).
- **lens (c)** ↔ *"Returning user: cross-day intersection"* — how fast a stable
  daily repertoire becomes identifiable, via the day-7 intersection size `|C_7|`
  (`lens_c.py`, `plot_lens_c.py`, `plot_lens_c_heatmap.py`).
- **lens (d)** ↔ *"Cover-distribution drift"* — how much (a)–(c) depend on the
  cover distribution matching the query distribution. In the code this is the
  **`dsens` / D-sensitivity** analysis (`plot_dsens.py`, `plot_dsens_tiers.py`); it
  is not a separate attack but a re-run of (a)–(c) with cover distribution
  `D ∈ {matched, uniform, stale}`. (There is no `lens_d.py`.)

The Strict/Moderate/Permissive **operator tiers** (in `plot_lens_c_heatmap.py`,
keyed on median `|C_7|`) correspond to the paper's "Operator-tier recommendation."

### Security/Privacy Issues and Ethical Concerns

This artifact does **not** disable any host security mechanism (no firewall,
ASLR, or kernel changes), and it ships no exploit or malware. Running it is safe
for the evaluator's machine. Two minor points worth noting:

- **Outbound DNS during the functional test.** The end-to-end functional test
  resolves a small number of real domain names through a public recursive
  resolver (default `8.8.8.8:53`) and a local CoreDNS instance. No personal data
  is sent; only DNS queries for public domains drawn from the Cisco Umbrella
  top-10k (resolvable) ranking. The evaluator may change or disable the upstream
  resolver.
- **Self-signed TLS certificates.** The local test stack generates a throwaway
  self-signed certificate (`localhost.pem`) used only inside the container/loopback
  for the demo endpoints. It is not installed into any system trust store.

The leakage simulator operates entirely on publicly available, aggregate
popularity data (Google CrUX and Cisco Umbrella domain rankings) and synthetic
user models. It contains no human-subjects data, so no IRB/ethics review applies.

## Basic Requirements

### Hardware Requirements

**For the functional evaluation (this artifact's claimed scope):** a commodity
x86-64 machine. No special hardware is required — the SGX enclave runs in
**simulation mode**, so neither an SGX-capable CPU nor the EGo SDK is needed.
Recommended: 8 CPU cores, 16 GB RAM, 15 GB free disk.

**For reproducing the paper's hardware-dependent results (not claimed here):**
the latency results (Table 3), the SGX columns of the microbenchmark tables
(Tables 4, 5, 6, and 7), and the page-load figure were produced on an Azure testbed of
three VMs in separate US regions:

- **Proxy:** Standard DC4s v2 (4 vCPU, 16 GiB, 112 MiB EPC) **with Intel SGX**.
- **Target:** Standard D2s v3 (2 vCPU, 8 GiB).
- **Client:** Standard D2alds v6 (2 vCPU, 4 GiB).

Reproducing those numbers requires renting an SGX-capable VM (e.g., the Azure
DCsv2/DCsv3 family). The scripts to provision and run this testbed are included
(`repos/coredns/benchmark/cloud-*.sh`) and documented in
[Notes on Reusability](#notes-on-reusability), but the *Reproduced* badge is not
requested because the measurements depend on this rented, region-distributed
hardware.

### Software Requirements

- **OS:** Ubuntu 24.04 LTS (the paper's testbed). Any Linux host with Docker
  works for the functional test; macOS/Windows via Docker Desktop should also
  work but are untested.
- **Container runtime:** Docker 24+ (the artifact ships a pinned `Dockerfile`).
- **Languages (provided inside the image):** Go 1.25 and Python 3.11.
- **SGX toolchain (only for real-hardware runs, not the functional test):**
  EGo 1.8.1.
- **Go dependencies:** pinned in each submodule's `go.mod` / `go.sum` (notably
  `github.com/cloudflare/circl` for HPKE, `github.com/cloudflare/odoh-go`, and
  `github.com/etclab/pathoram-go`).
- **Python dependencies:** the leakage simulator (`repos/codoh-evals/sim`) is
  **stdlib-only** and runs on Python ≥ 3.10 (the Docker image ships Python 3.11
  from Debian bookworm); plotting needs `matplotlib` and `numpy` (installed in
  the image). Re-crawling page loads needs Playwright (not exercised by the
  functional test).
- **Host plotting tools (only for re-rendering the archived figures in
  [`paper-results/`](paper-results)):** `gnuplot` and an EPS→PDF converter
  (`epstopdf` from `texlive-font-utils`, or `ps2pdf` from `ghostscript`) —
  e.g. `apt-get install gnuplot texlive-font-utils`. These are **not** in the
  Docker image and are not needed for the functional test; the regenerated
  *tables* and the leakage *figures* need only the in-image `python3`/`matplotlib`.
  `gnuplot` + `epstopdf` are used solely to re-render the latency-CDF, page-load,
  and DNS-CDF figures from the shipped data (see
  [`paper-results/README.md`](paper-results/README.md)).
- **Datasets:** all data needed for the functional test is included in the
  submodules — the leakage simulator's input traces and aggregated CSVs are
  checked in (the CrUX Top-1M cover universe is shipped gzipped at
  `repos/codoh-evals/data/crux-202603.csv.gz`), and the benchmark domain list is
  a checked-in Umbrella-format ranking
  (`repos/codoh-evals/data/umbrella-top-10k-resolvable.csv`), from which the
  Dockerfile slices the small demo query/cover lists — no download happens during
  the build.
- **ML models:** none.

### Estimated Time and Storage Consumption

| Step | Human time | Compute time | Disk |
| --- | --- | --- | --- |
| `git clone --recursive` | 2 min | ~3 min | ~3 GB |
| `docker build` | 2 min | 10–20 min | ~5 GB image |
| `./test.sh` (full smoke test) | 2 min | ~1–2 min | <1 GB |

Total: **under 10 minutes of human time** and **under 25 minutes of compute**,
on **~10–15 GB** of disk.

## Environment

### Accessibility

The artifact is hosted on GitHub as a single entry point with all components
included as Git submodules:

> https://github.com/etclab/codoh-artifact

The five submodules each point at the `pets26-artifact` tag of their repository:

- https://github.com/etclab/coredns/tree/pets26-artifact
- https://github.com/etclab/codoh-client/tree/pets26-artifact
- https://github.com/etclab/dnscrypt-proxy/tree/pets26-artifact
- https://github.com/etclab/codoh-evals/tree/pets26-artifact
- https://github.com/etclab/pathoram-go/tree/pets26-artifact

(During artifact review, follow the `main` branch of `codoh-artifact`; a stable
commit/tag will be provided for the final, archived version.)

### Set up the environment

Clone the artifact and all submodules, then build the container image:

```bash
git clone --recursive https://github.com/etclab/codoh-artifact.git
cd codoh-artifact

# If you forgot --recursive:
git submodule update --init --recursive

docker build -t codoh:artifact .
```

The build compiles every component (server, enclave in simulation mode, client,
Path ORAM library, and the Python simulator dependencies) inside the image, so
there is nothing to install on the host beyond Docker.

> **Note:** the submodules are pinned to the `pets26-artifact` tag via their
> recorded commit (gitlink); `.gitmodules` intentionally sets no tracking
> `branch`. Use `git submodule update --init --recursive` as above — do **not**
> pass `--remote`, which would move the submodules off the pinned commits.

### Testing the Environment

Run the bundled smoke test inside the container:

```bash
docker run --rm -it codoh:artifact ./test.sh
```

`test.sh` exercises every major component and prints a `PASS`/`FAIL` line for
each. It performs:

1. **Build check** — confirms the server, simulation enclave, client, and ORAM
   library all compile.
2. **Path ORAM** — runs the `pathoram-go` unit tests.
3. **Enclave logic** — runs the `enclave` and `codohtarget` (incl. cover
   sampler) unit tests, covering HPKE, AES-GCM, the LRU/ORAM cache, and
   cache-insert bundle handling.
4. **Leakage simulator** — runs the `sim` unit tests (batch buffer, cover
   sampler, strong-attacker scoring, and the lens-(a)/(b)/(c) drivers), including
   closed-form-vs-Monte-Carlo cross-checks.
5. **End-to-end CODoH query (SGX simulation mode)** — launches the enclave,
   target, and proxy locally and issues CODoH queries with the client,
   demonstrating a cache miss followed by a cache hit.

> **Network requirement (§5 only):** the end-to-end test resolves real domains,
> so it needs **outbound UDP/53** to a recursive resolver (default `8.8.8.8:53`).
> On an egress-restricted host, point it at a reachable resolver via the
> `RESOLVER` env var (it applies to both the real query and cover resolution):
> `docker run --rm -e RESOLVER=<host:53> codoh:artifact ./test.sh`.
> Sections 1–4 need no network.

The smoke test deliberately runs only unit tests and the end-to-end query — it
does not run the (slow) benchmarks or parameter sweeps. Per-operation
microbenchmarks and the leakage-figure regeneration are available as separate
commands documented in [Notes on Reusability](#notes-on-reusability).

Expected output ends with:

```
=== CODoH artifact smoke test: ALL CHECKS PASSED (5/5) ===
```

Each section also prints concrete results (e.g., the simulator's
closed-form-vs-Monte-Carlo agreement and lens-(c) cross-day posteriors, the unit
test timings, and the client's measured cache hit rate on the warm query), so the
evaluator can confirm the components behave as described in the paper rather than
merely exiting zero. The full run takes roughly **1–2 minutes**.

## Artifact Evaluation

This section maps the artifact to the paper's claims. Each claim is tagged
**[Demonstrated]** (the functional test shows the behavior), **[Reproduced on
commodity HW]** (the paper's *numbers* regenerate on the evaluator's machine), or
**[Hardware-gated]** (needs the SGX/Azure testbed — out of scope for the requested
*Available + Functional* badges; see [Limitations](#limitations)).

> **A note on item counts vs. the paper's round numbers.** Across all experiments,
> the workloads and figures draw from domain lists **pre-filtered to domains that
> resolve** (return at least one `A` record), per the paper's *Domain lists*
> methodology. The exact number of sites/domains/records in a shipped data file
> therefore need not equal the rounded "top-N" quoted in the paper. For example,
> the page-load figure plots **74 of the 100** sampled sites (the rest failed to
> resolve or load); the response-size and TTL CDFs hold **one row per resolved
> record**, so their row counts track the resolvable set rather than the nominal
> rank cutoff; and the cold/Zipf workloads run over the pre-filtered
> 10k/1k-domain lists. This is expected filtering, not a discrepancy.

### Main Results and Claims

#### Main Result 1: Cacheable, end-to-end-encrypted ODoH  *[Demonstrated]*
A repeated query is served from the proxy-side enclave cache (cache **hit**) with
no upstream resolution, while the proxy never observes plaintext queries or
responses (end-to-end HPKE). This is the core design claim of §4–§6. Demonstrated
by **Experiment 1**; it is also the cache-hit fast path underlying the warm-workload
numbers in Table 3 (those magnitudes are hardware-gated — see Main Result 3).

#### Main Result 2: Defense mechanisms implemented and correct  *[Demonstrated]*
Cover responses (k), batched commits (B, p), the Path ORAM cache, and bucketed
padding all function as described in §4–§5. Verified by **Experiment 2** (unit
tests) and exercised end-to-end by **Experiment 1**.

#### Main Result 3: End-to-end latency (Table 3)  *[Hardware-gated]*
Warm ≈ 0.37× ODoH (2.67× speedup), Zipf ≈ 0.46×, cold ≈ 0.90×; SGX adds <1 ms at
the median on cache-hit workloads. Requires the three-VM cross-region Azure
testbed with an SGX proxy. **Out of scope**; the cache-hit path it builds on is
shown functionally by Experiment 1. Scripts: `benchmark/cloud-*.sh` (see
[Notes on Reusability](#notes-on-reusability)). The authors' measured run — raw
per-query latencies, the exact Table 3 percentiles, and the CDF figures — is
shipped in [`paper-results/`](paper-results) for inspection and re-plotting.

#### Main Result 4: Per-operation microbenchmarks (Tables 4–8)  *[partly Reproduced]*
The **Plain (non-SGX) columns** of Table 4 (crypto) and Table 5 (cache), and the
plain-mode PathORAM-vs-linear-scan crossover (Table 10, plain counterpart of
Table 6) reproduce on the evaluator's CPU — **Experiment 4**. The **SGX columns**
of Tables 4, 5, 6, and 7 are **Hardware-gated**. The authors' own plain-column
runs for Tables 4, 5, 7, and 8 are archived in [`paper-results/`](paper-results)
for inspection; Table 8 (padding) is a wire-size measurement with no SGX variant.

#### Main Result 5: Leakage under realistic workloads (§7; appendix figures)  *[Reproduced on commodity HW]*
The simulator's quantitative findings behind the paper's parameter recommendations:
- (i) one batch identifies the page in 8–14% of batches at B ≤ 20, <1% at B ≥ 50, 0 at B ≥ 100;
- (ii) a full page load is still protected at B ≥ 50;
- (iii) cross-day intersection: cover count k is decisive — k = 1 fingerprints ~37% of users (11 of 30) within 7 days, justifying the default k = 3;
- (iv) cover-distribution drift (D ≠ Q) breaks page-load privacy at every B, so D ≈ Q is a deployment requirement;
- operator tiers *Strict / Moderate / Permissive* at B ≥ 256 / 50 / 20.

Reproduced from shipped aggregate CSVs by **Experiment 3** (regenerates appendix
figures `lens_c_intersect_final`, `lens_c_heatmap_BTmax`, `dsens_tiers`); the
simulator's closed-form-vs-Monte-Carlo agreement is re-derived in **Experiment 2**.

### Experiments

#### Experiment 1: End-to-end CODoH query, cache miss → hit (SGX simulation mode)
*Steps.* `docker run --rm codoh:artifact ./test.sh` and read **section 5** (or run
`scripts/run-codoh-sim.sh` directly). On an egress-restricted host, add
`-e RESOLVER=<host:53>`.
*Expected.* Section 5 prints a cold query **MISS** followed by a warm query **HIT**
(~100% hit rate on the warm query), and the run ends with
`=== CODoH artifact smoke test: ALL CHECKS PASSED (5/5) ===`. Proxy logs show only
ciphertext.
*Time / disk.* ~1–2 min compute (whole test), ~2 min human; <1 GB beyond the image.
*Supports.* Main Result 1 — shows the protocol resolves, caches, and serves a hit
end-to-end with end-to-end encryption.

#### Experiment 2: Component and simulator unit tests
*Steps.* Covered by `./test.sh` **sections 1–4**.
*Expected.* All sections PASS; section 4 prints the closed-form-vs-Monte-Carlo
agreement and lens-(c) cross-day posteriors.
*Time / disk.* <1 min; <1 GB.
*Supports.* Main Result 2 and the simulator-correctness basis of Main Result 5 —
confirms HPKE/AES-GCM, the LRU/ORAM cache, the cover sampler, the batch buffer, and
the attacker scoring are correct.

#### Experiment 3: Regenerate the paper's leakage figures from shipped data
*Steps.* Run the figure-regeneration block in
[Notes on Reusability](#notes-on-reusability) ("Regenerating the paper's leakage
figures from shipped data"), which mounts `/figs` and runs `plot_lens_c`,
`plot_lens_c_heatmap`, and `plot_dsens_tiers`.
*Expected.* Three figures matching the appendix: `lens_c_intersect_final.pdf`
(Fig. cross-day intersection), `lens_c_heatmap_BTmax.pdf` (the (B, T_max) heatmap),
`dsens_tiers.pdf` (cover-distribution sensitivity). The k = 1 vs k = 3 separation
and the Strict/Moderate/Permissive tier bands are visible.
*Time / disk.* Seconds of compute; a few MB of output.
*Supports.* Main Result 5 (i)–(iv) and the operator-tier recommendation,
reproduced quantitatively from the shipped aggregate CSVs.

#### Experiment 4: Plain-mode (non-SGX) microbenchmark columns
*Steps.* Run the two `go test -bench` commands in
[Notes on Reusability](#notes-on-reusability) ("Reproducing the plain-mode (non-SGX)
microbenchmark columns").
*Expected.* Per-operation crypto/cache latencies and the PathORAM-vs-linear-scan
crossover in the regime of Tables 4/5 (Plain) and Table 10; the O(log N) ORAM,
O(1) LRU, and O(N) linear-scan trends and the crossover region reproduce. Absolute
µs differ from the paper (different CPU).
*Time / disk.* A few minutes; a few MB.
*Supports.* The Plain columns of Main Result 4.

## Limitations

This artifact requests the **Available** and **Functional** badges, not
**Reproduced**. The following paper results are *not* reproducible on commodity
hardware and are therefore out of scope for evaluation:

- **End-to-end latency (Table 3) and the page-load figure** require the
  three-VM, cross-region Azure testbed with an SGX-capable proxy; the numbers are
  sensitive to wide-area network latency between specific Azure regions.
- **The SGX columns of Tables 4, 5, 6, and 7** (per-operation latency *inside* the
  enclave, cache access under SGX, ORAM vs. linear scan under SGX, IPC under SGX)
  require running on real Intel SGX hardware via EGo; in simulation mode there is
  no enclave-transition or EPC paging cost to measure.

What *is* exercised by the functional test fully demonstrates that the system
works: the complete CODoH protocol runs end-to-end (enclave cache lookup, cover
insertion, ORAM-backed storage, batched commits, padding, and client
decryption), and the leakage analysis that underpins the paper's parameter
recommendations is reproduced from the included data. The plain-mode
microbenchmark columns (Tables 4 and 5, plus the plain-mode oblivious-primitive
results in Table 10) are also reproducible on the evaluator's CPU (see
[Notes on Reusability](#notes-on-reusability) for the commands). The scripts for
the full hardware experiments are included for completeness and reuse (see below).

## Notes on Reusability

The components are useful beyond this paper:

- **`pathoram-go`** is a standalone, dependency-injectable Path ORAM library
  (pluggable storage / position map / encryptor backends, constant-time mode for
  TEEs) usable in any Go project needing oblivious storage.
- **`coredns` plugins** (`codohproxy`, `codohtarget`, plus baseline `odohproxy` /
  `odohtarget`) follow CoreDNS's standard plugin model and can be recomposed for
  other DoH/ODoH experiments under identical infrastructure.
- **The leakage simulator** (`codoh-evals/sim`) is a general harness for
  trace-driven analysis of batched-anonymity systems: the cover sampler, batch
  buffer, attacker model, and parameter-sweep driver are modular, and new
  workloads can be supplied as DNS-trace CSVs.

- **Terminology (lens (a)–(d)).** The simulator's "lens" names map to the paper's
  four leakage questions — defined under *Description → Terminology* above; (d) is
  the `dsens` / D-sensitivity re-run (there is no `lens_d.py`).

- **Regenerating the paper's leakage figures from shipped data.** The full
  parameter sweeps take many CPU-hours, so we ship the precomputed aggregate CSVs
  alongside the simulator (only those needed for the paper's figures). The three
  simulator figures in the paper's appendix regenerate in seconds
  (`matplotlib`/`numpy` are in the image). Mount a host directory as `/figs` so
  the outputs land on the host:

  ```bash
  mkdir -p figs-out
  docker run --rm -v "$PWD/figs-out:/figs" codoh:artifact bash -c '
    cd repos/codoh-evals
    # Returning-user cross-day intersection, 3-panel |C_7|  (paper fig. lens_c_intersect_final):
    python3 -m sim.plot_lens_c         --users-csv out_lensc_merged/agg/lens_c_users.csv \
                                       --out /figs/lens_c_intersect_final.pdf --png /figs/lens_c_intersect_final.png
    # Returning-user (B, T_max) heatmap with operator tiers  (paper fig. lens_c_heatmap_BTmax):
    python3 -m sim.plot_lens_c_heatmap --users-csv out_lensc_merged/agg/lens_c_users.csv \
                                       --out /figs/lens_c_heatmap_BTmax.pdf --png /figs/lens_c_heatmap_BTmax.png
    # Cover-distribution sensitivity, cross-tier  (paper fig. dsens_tiers):
    python3 -m sim.plot_dsens_tiers    --results results --out /figs/dsens_tiers.pdf
  '
  ls figs-out/   # the three figures (.pdf + .png) are now on the host
  ```

  Each plot script also accepts a custom `--out`/`--png` path if run inside an
  interactive container. To re-run the underlying sweeps instead of using the
  shipped aggregates, see `repos/codoh-evals/README.md` (the full default sweep is
  multi-hour).

- **Reproducing the plain-mode (non-SGX) microbenchmark columns.** The CPU-only
  columns of the paper's microbenchmark tables run on the evaluator's host (no
  SGX needed). These are not part of the smoke test, but can be run directly:

  ```bash
  # Per-operation crypto + cache latency (plain columns of Tables 4 and 5):
  cd repos/coredns   && go test -run=NONE -bench=. ./enclave/
  # PathORAM vs. linear scan, plain mode (Table 10 / plain column of Table 6):
  cd repos/pathoram-go && go test -run=NONE -bench='Access|LinearScan' ./...
  ```

  The SGX columns of these tables are hardware-gated and out of scope (see
  [Limitations](#limitations)).

- **Measurement testbed: how the paper's latency numbers were collected.** The
  macrobenchmarks (Table 3, the latency CDFs, and the Table 9 sweep — all shipped
  in [`paper-results/`](paper-results)) were taken on a **three-VM, three-region
  Azure deployment** wired as a standard ODoH path with the CODoH cache added at
  the proxy. Everything below is reproduced by the
  `repos/coredns/benchmark/cloud-*.sh` scripts.

  ```
  Client  (US North Central, Standard D2alds_v6)
    │  HTTPS — sequential queries, TLS sessions reused
    ▼
  Proxy   (US East, Standard DC4s_v2 — Intel SGX, 112 MiB EPC)
    ├─ codohproxy ──Unix-socket IPC──▶ enclave (EGo)
    │                                  ORAM N=1024, covers k=3,
    │  HTTPS — persistent pool         batch B=10 p=0.1, padding
    ▼
  Target  (US Central, Standard D2s_v3)
    ├─ codohtarget ──▶ Unbound (local recursive resolver) ──▶ authoritative DNS
    │                  (cache flushed between workloads)
    └─ on a miss: resolves 1 real + k cover domains and bundles the 1+k
       responses back to the enclave (also the attestation / key channel)
  ```

  **Roles.** The *client* VM runs the Go benchmark tool (`codoh-client/odoh-client`,
  a fork of Cloudflare `odoh-client-go`) and doubles as the orchestrator, driving
  the other two over SSH; it issues sequential HTTPS queries and writes a per-query
  latency CSV + a JSON summary (p50/p95/p99, throughput, cache-hit rate) per
  (config, workload). The *proxy* VM runs `codohproxy` and the SGX **enclave**
  (built/signed with EGo) that holds the ORAM cache; the two communicate over a
  Unix-domain socket, and the proxy dispatches the enclave and the target in
  parallel (the streaming fan-out of §Evaluation). The *target* VM runs
  `codohtarget` and a local **Unbound** recursive resolver.

  **Upstream resolver (Unbound).** The target's upstream is a *local* Unbound
  (run on a non-standard port to avoid the systemd-resolved conflict), with DNSSEC
  validation and remote-control enabled. The orchestrator flushes it between
  workloads (`unbound-control flush_zone .`) so the cold, Zipf, and warm
  measurements are independent; the enclave's own cache is **not** flushed, so warm
  benefits from entries inserted earlier. The upstream is a knob
  (`cloud-run.sh --resolver unbound|cloudflare|google|HOST:PORT`) — Table 3 uses
  Unbound; public-resolver variants were also collected.

  **Configs & workloads.** Five configurations (`benchmark/configs/{1..5}-*.sh`):
  C1 DoH, C2 ODoH, C3 Cached-ODoH, C4 CODoH-noTEE, C5 CODoH — each over three
  workloads: *cold* (10k unique Umbrella top-10k domains), *Zipf* (10k draws over
  1k domains, s=1.0), *warm* (10k × `google.com`). 10k queries per run; the first
  1000 are dropped as warmup (at plot time). Servers are restarted between configs.

  **Reproduce it** (needs an SGX proxy VM + two more VMs; from the client/orchestrator):
  ```bash
  cd repos/coredns
  cp benchmark/cloud-env.sh benchmark/cloud-env.local.sh   # set PROXY_IP, TARGET_IP, SSH, NSGs (gitignored)
  ./benchmark/cloud-open-ports.sh                           # Azure NSG rules (needs: az login)
  ./benchmark/cloud-setup.sh target                         # build + install/configure Unbound
  ./benchmark/cloud-setup.sh proxy                          # build SGX enclave + proxy (EGo)
  ./benchmark/cloud-setup.sh client                         # build odoh-client
  ./benchmark/cloud-run.sh --standard --run-id std-01       # orchestrate the config × workload matrix
  ./benchmark/cloud-collect-logs.sh std-01                  # pull server logs
  ./benchmark/plot.sh benchmark/results/std-01              # CDFs + LaTeX tables
  ```
  `cloud-run.sh` rewrites the Corefiles with the cross-VM IPs, distributes the TLS
  cert, starts the servers over SSH, runs the client locally, and lands per-query
  CSV/JSON under `benchmark/results/<run-id>/raw/` — the same layout shipped in
  `paper-results/table3-latency-cdfs.tar.gz`. Add `--full --sweep-oram --sweep-cover`
  for the Table 9 sweep; run any script with `--help` for options. (The page-load
  figure used the same testbed, driving Playwright through `dnscrypt-proxy` on the
  client.)

- **Authors' measured data for the hardware-dependent results.** So a reviewer can
  inspect and re-plot the paper's measured numbers without renting the SGX/Azure
  testbed, the authors' actual runs are archived under
  [`paper-results/`](paper-results) as per-result tarballs (not bundled into the
  Docker image — extract them from the cloned repository):
  - `table3-latency-cdfs.tar.gz` — Table 3 latency: raw per-query CSVs, the exact
    percentiles, and the appendix CDF figures (`cdf_warm`/`cdf_zipf`/`cdf_cold`).
  - `tables4-8-microbench-plain.tar.gz` — the plain (non-SGX) columns of
    Tables 4, 5, 7, and 8.
  - `table9-sensitivity-sweep.tar.gz` — the ORAM-capacity / cover-count sweep
    behind Table 9.
  - `fig-pageload.tar.gz` — the per-site page-load figure (`plot_per_site`) data
    (the figure's direct source; the raw Playwright runs were not preserved, so it
    can be inspected and re-plotted but not re-aggregated from raw).
  - `fig-dns-cdfs.tar.gz` — the response-size and TTL CDFs (appendix
    `top-size-cdf` / `top-ttl-cdf`).

  See [`paper-results/README.md`](paper-results/README.md) for the full
  archive-to-figure/table map and the extract / verify / re-plot commands. The
  leakage data (Main Result 5) is **not** archived there — it ships uncompressed in
  `repos/codoh-evals` and regenerates via the figure commands above. The SGX
  columns of Tables 4--7, and the raw data behind Table 10 (plain-mode oblivious
  primitives), are not recoverable from any repository (see
  [Limitations](#limitations)).
