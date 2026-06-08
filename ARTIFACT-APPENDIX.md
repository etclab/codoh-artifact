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
| [`repos/coredns`](repos/coredns) | CODoH server: `codohproxy` + `codohtarget` CoreDNS plugins and the SGX enclave (EGo), plus the benchmark and Azure testbed scripts. | §6 Implementation; Table 2 (latency); Tables 3–6 (microbenchmarks); latency CDFs |
| [`repos/codoh-client`](repos/codoh-client) | CODoH client and latency benchmark tool (a fork of Cloudflare `odoh-client-go`). | §7 measurement client; Table 2 driver |
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
the latency results (Table 2), the SGX columns of the microbenchmark tables
(Tables 3–5), and the page-load figure were produced on an Azure testbed of
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
- **Languages (provided inside the image):** Go 1.25 and Python 3.12.
- **SGX toolchain (only for real-hardware runs, not the functional test):**
  EGo 1.8.1.
- **Go dependencies:** pinned in each submodule's `go.mod` / `go.sum` (notably
  `github.com/cloudflare/circl` for HPKE, `github.com/cloudflare/odoh-go`, and
  `github.com/etclab/pathoram-go`).
- **Python dependencies:** the leakage simulator (`repos/codoh-evals/sim`) is
  **stdlib-only**; plotting needs `matplotlib` and `numpy` (installed in the
  image). Re-crawling page loads needs Playwright (not exercised by the
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
| `./test.sh` (full smoke test) | 5 min | ~5–10 min | <1 GB |

Total: roughly **15 minutes of human time** and **under 35 minutes of compute**,
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

### Testing the Environment

Run the bundled smoke test inside the container:

```bash
docker run --rm -it codoh:artifact ./test.sh
```

`test.sh` exercises every major component and prints a `PASS`/`FAIL` line for
each. It performs:

1. **Build check** — confirms the server, simulation enclave, client, and ORAM
   library all compile.
2. **Path ORAM** — runs the `pathoram-go` unit tests and a short benchmark.
3. **Enclave microbenchmarks (plain mode)** — runs the HPKE / AES-GCM / cache
   `go test -bench` microbenchmarks that back Tables 3–4 (CPU-only columns).
4. **Leakage simulator** — runs the `sim` unit tests and regenerates one
   Appendix leakage figure from the checked-in aggregated CSVs.
5. **End-to-end CODoH query (SGX simulation mode)** — launches the enclave,
   target, and proxy locally and issues CODoH queries with the client,
   demonstrating a cache miss followed by a cache hit.

Expected output ends with:

```
=== CODoH artifact smoke test: ALL CHECKS PASSED ===
```

Each section also prints concrete results (e.g., the simulator's day-7
intersection statistics, ORAM benchmark timings, and the client's measured cache
hit rate on the warm query), so the evaluator can confirm the components behave
as described in the paper rather than merely exiting zero.

## Limitations

This artifact requests the **Available** and **Functional** badges, not
**Reproduced**. The following paper results are *not* reproducible on commodity
hardware and are therefore out of scope for evaluation:

- **End-to-end latency (Table 2) and the page-load figure** require the
  three-VM, cross-region Azure testbed with an SGX-capable proxy; the numbers are
  sensitive to wide-area network latency between specific Azure regions.
- **The SGX columns of Tables 3–5** (per-operation latency *inside* the enclave,
  cache access under SGX, IPC under SGX) require running on real Intel SGX
  hardware via EGo; in simulation mode there is no enclave-transition or EPC
  paging cost to measure.

What *is* exercised by the functional test fully demonstrates that the system
works: the complete CODoH protocol runs end-to-end (enclave cache lookup, cover
insertion, ORAM-backed storage, batched commits, padding, and client
decryption), and the leakage analysis that underpins the paper's parameter
recommendations is reproduced from the included data. The plain-mode
microbenchmark columns (Tables 3–4, 6) are also reproducible on the evaluator's
CPU. The scripts for the full hardware experiments are included for completeness
and reuse (see below).

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

- **Regenerating the leakage figures from shipped data.** The full parameter
  sweeps in the paper take many CPU-hours, so we ship the precomputed aggregate
  CSVs alongside the simulator. From `repos/codoh-evals`, the paper's leakage
  figures regenerate in seconds (needs `matplotlib`/`numpy`, both in the Docker
  image):

  ```bash
  cd repos/codoh-evals
  # Lens-(b) (B, T_max) heatmap:
  python3 -m sim.plot_heatmap --out-dir out/default --metric top5_acc
  # Returning-user cross-day intersection (3-panel |C_7|):
  python3 -m sim.plot_lens_c       --users-csv out_lensc_merged/agg/lens_c_users.csv
  python3 -m sim.plot_lens_c_heatmap --users-csv out_lensc_merged/agg/lens_c_users.csv
  # Cover-distribution sensitivity (cross-tier, Appendix):
  python3 -m sim.plot_dsens_tiers --out figs/dsens_tiers.pdf
  ```

  To re-run the underlying sweep instead of using the shipped aggregates, see
  `repos/codoh-evals/README.md` (note: the full default sweep is multi-hour).
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
