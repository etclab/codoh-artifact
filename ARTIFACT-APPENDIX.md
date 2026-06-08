# Artifact Appendix

Paper title: **CODoH: Privacy-Preserving Caching for Oblivious DNS over HTTPS**

Requested Badge(s):
  - [x] **Available**
  - [x] **Functional**
  - [ ] **Reproduced**

## Description

This artifact accompanies the paper:

> Pankaj Niroula, Lily Gloudemans, Aashutosh Poudel, Collin MacDonald, and
> Stephen Herwig. *CODoH: Privacy-Preserving Caching for Oblivious DNS over
> HTTPS.* Proceedings on Privacy Enhancing Technologies (PoPETs), 2026.

```bibtex
@article{codoh2026,
  title   = {{CODoH}: Privacy-Preserving Caching for Oblivious {DNS} over {HTTPS}},
  author  = {Niroula, Pankaj and Gloudemans, Lily and Poudel, Aashutosh and
             MacDonald, Collin and Herwig, Stephen},
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
| [`repos/coredns`](repos/coredns) | CODoH server: `codohproxy` + `codohtarget` CoreDNS plugins and the SGX enclave (EGo), plus the benchmark and Azure testbed scripts. | §6 Implementation; Table 3 (latency); Tables 4–7 (microbenchmarks); latency CDFs |
| [`repos/codoh-client`](repos/codoh-client) | CODoH client and latency benchmark tool (a fork of Cloudflare `odoh-client-go`). | §7 measurement client; Table 3 driver |
| [`repos/dnscrypt-proxy`](repos/dnscrypt-proxy) | Local DNS proxy with CODoH support; drives real browser page loads. | §7 Page-Load Benchmarks (per-site figure) |
| [`repos/codoh-evals`](repos/codoh-evals) | Trace-driven leakage simulator (lenses a–d) + plotting; Playwright crawl harness. | §7 Leakage under Realistic Workloads; App. leakage and cover-drift figures |
| [`repos/pathoram-go`](repos/pathoram-go) | Path ORAM library used as the enclave's oblivious cache backend. | §6 ORAM cache; Table 6 (PathORAM vs. linear scan) |

Each submodule is pinned to the `pets26-artifact` tag of its respective
repository (see [Accessibility](#accessibility)).

### Security/Privacy Issues and Ethical Concerns

This artifact does **not** disable any host security mechanism (no firewall,
ASLR, or kernel changes), and it ships no exploit or malware. Running it is safe
for the evaluator's machine. Two minor points worth noting:

- **Outbound DNS during the functional test.** The end-to-end functional test
  resolves a small number of real domain names through a public recursive
  resolver (default `8.8.8.8:53`) and a local CoreDNS instance. No personal data
  is sent; only DNS queries for public domains drawn from the Cisco Umbrella
  Top-1M list. The evaluator may change or disable the upstream resolver.
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
Recommended: 4 CPU cores, 8 GB RAM, 15 GB free disk.

**For reproducing the paper's hardware-dependent results (not claimed here):**
the latency results (Table 3), the SGX columns of the microbenchmark tables
(Tables 4, 5, and 7), and the page-load figure were produced on an Azure testbed of
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
- **Datasets:** all data needed for the functional test is included in the
  submodules — the leakage simulator's input traces and aggregated CSVs are
  checked in (the CrUX Top-1M cover universe is shipped gzipped at
  `repos/codoh-evals/data/crux-202603.csv.gz`), and the benchmark domain list
  is fetched once from Cisco Umbrella during build.
- **ML models:** none.

### Estimated Time and Storage Consumption

| Step | Human time | Compute time | Disk |
| --- | --- | --- | --- |
| `git clone --recursive` | 2 min | ~3 min | ~3 GB |
| `docker build` | 2 min | 10–20 min | ~5 GB image |
| `./test.sh` (full smoke test) | 2 min | ~1–2 min | <1 GB |

Total: roughly **10 minutes of human time** and **under 25 minutes of compute**,
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

## Limitations

This artifact requests the **Available** and **Functional** badges, not
**Reproduced**. The following paper results are *not* reproducible on commodity
hardware and are therefore out of scope for evaluation:

- **End-to-end latency (Table 3) and the page-load figure** require the
  three-VM, cross-region Azure testbed with an SGX-capable proxy; the numbers are
  sensitive to wide-area network latency between specific Azure regions.
- **The SGX columns of Tables 4, 5, and 7** (per-operation latency *inside* the enclave,
  cache access under SGX, IPC under SGX) require running on real Intel SGX
  hardware via EGo; in simulation mode there is no enclave-transition or EPC
  paging cost to measure.

What *is* exercised by the functional test fully demonstrates that the system
works: the complete CODoH protocol runs end-to-end (enclave cache lookup, cover
insertion, ORAM-backed storage, batched commits, padding, and client
decryption), and the leakage analysis that underpins the paper's parameter
recommendations is reproduced from the included data. The plain-mode
microbenchmark columns (Table 4, plus the plain-mode oblivious-primitive results
in Table 10) are also reproducible on the evaluator's CPU (see
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

- **Terminology: the simulator's "lenses" (a)–(d).** The simulator labels its
  analyses **lens (a)–(d)** throughout its module names, CSV outputs, and console
  output (including the smoke test's §4 lines and the `analyze_*` / `plot_*`
  scripts). The paper never uses the word "lens" — these are internal names for
  the four questions the paper poses in its §"Leakage under Realistic Workloads":
  - **lens (a)** ↔ *"Single batch: popular vs. tail queries"* —
    can a single batch identify the victim's page, stratified by popularity band
    (`analyze_a.py`, `lens_a.csv`).
  - **lens (b)** ↔ *"Within a page load"* — does the union of batches a page load
    spans leak the page (`analyze_b.py`, `lens_b.csv`, `plot_heatmap.py`).
  - **lens (c)** ↔ *"Returning user: cross-day intersection"* — how fast a stable
    daily repertoire becomes identifiable, via the day-7 intersection size
    `|C_7|` (`lens_c.py`, `plot_lens_c.py`, `plot_lens_c_heatmap.py`).
  - **lens (d)** ↔ *"Cover-distribution drift"* — how much (a)–(c) depend on the
    cover distribution matching the query distribution. In the code this is the
    **`dsens` / D-sensitivity** analysis (`plot_dsens.py`, `plot_dsens_tiers.py`);
    it is not a separate attack but a re-run of (a)–(c) with cover distribution
    `D ∈ {matched, uniform, stale}`. (There is no `lens_d.py`.)

  The Strict/Moderate/Permissive **operator tiers** (in `plot_lens_c_heatmap.py`,
  keyed on median `|C_7|`) correspond to the paper's "Operator-tier
  recommendation."

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

- **Reproducing the full paper on your own SGX hardware.** With an SGX-capable
  Azure VM (or equivalent) and the EGo SDK installed, the testbed can be
  provisioned and run end-to-end:

  ```bash
  # On an SGX host with EGo 1.8.1 installed:
  cd repos/coredns
  ./benchmark/setup.sh                      # build SGX enclave + all binaries
  cp benchmark/cloud-env.sh benchmark/cloud-env.local.sh   # set PROXY_IP/TARGET_IP
  ./benchmark/cloud-provision.sh            # bootstrap the three VMs
  ./benchmark/cloud-run.sh --standard       # run the latency suite
  ./benchmark/plot.sh benchmark/results/<run-id>           # regenerate CDFs/tables
  ```

  The `cloud-run.sh` and `plot.sh` scripts cover the full configuration/workload
  matrix (Configs 1--5 over the cold/Zipf/warm workloads) and the
  figure/table generation pipeline; run them with `--help` for the available
  options.
