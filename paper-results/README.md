# Authors' measured data (view · verify · re-plot)

These archives contain the **authors' actual measurement runs** behind the paper's
hardware-dependent tables and figures, gathered on the paper's Azure testbed
(SGX proxy + cross-region target/client) and supporting workstations between
February and May 2026.

They are shipped so a reviewer can **view, verify, and re-plot** the published
numbers *without* renting SGX or cross-region hardware. Re-running these
experiments from scratch needs that testbed (see
[`../ARTIFACT-APPENDIX.md`](../ARTIFACT-APPENDIX.md) → *Limitations*); the
**Reproduced** badge is therefore not requested. The leakage results
(Main Result 5), which *are* reproducible on commodity hardware, are not archived
here — they ship uncompressed and git-tracked in
[`../repos/codoh-evals`](../repos/codoh-evals) (see *Experiment 3*).

Extract any archive with `tar xzf <name>.tar.gz`.

**A note on item counts.** Across all experiments the benchmarks draw from domain
lists **pre-filtered to domains that resolve** (≥1 `A` record), so the number of
sites/domains/records in a data file may differ from the round "top-N" quoted in
the paper. For example, the page-load figure has **74 of the 100** sampled sites
(the rest didn't resolve or load), and the DNS response-size / TTL CDFs hold one
row per resolved record. This is expected filtering, not a bug.

## Archive → paper result map

| Archive | Backs (paper) | Key contents |
| --- | --- | --- |
| `table3-latency-cdfs.tar.gz` | **Table 3** (end-to-end latency) + appendix latency CDF figures `cdf_warm`/`cdf_zipf`/`cdf_cold` | `multi-region-combined/raw/` — 15 per-query CSVs + 15 JSON summaries (5 configs × {cold,zipf,warm}); `plots/percentiles_trimmed.json` (the exact Table 3 p50/p95/p99); `plots/table_comparison.tex` (Table 3 as LaTeX); `plots/*.cdf` (per-config CDF data); `plots/cdf_*.pdf` (rendered figures); `plots/cdf_*.gp` (gnuplot) |
| `tables4-8-microbench-plain.tar.gz` | **Plain (non-SGX) columns** of **Table 4** (crypto), **Table 5** (cache), **Table 7** (IPC), **Table 8** (padding) | `crypto.txt`, `cache.txt`, `ipc.txt`, `padding.txt` — raw `go test -bench` / analyzer output |
| `table9-sensitivity-sweep.tar.gz` | **Table 9** (sensitivity: ORAM `N ∈ {256,512,1024,2048}`, cover `k ∈ {1,3,5}`) | `param_sweep_20260514/raw/` (default `N=1024,k=3`) + `sweep_oram_{256,512,2048}/` + `sweep_cover_{1,5}/`, each {cold,zipf,warm} × CSV+JSON; `corefiles/`; `logs/`; `metadata.json` |
| `fig-pageload.tar.gz` | Figure `plot_per_site` (page-load: CODoH vs ODoH, per site) | `cdf_codoh_per_site.dat`, `cdf_odoh_per_site.dat` (per-site mean DNS + page-load times ± std, 74 sites); `plot_per_site.gpi`; `style.gpi` |
| `fig-dns-cdfs.tar.gz` | Appendix figures `top-size-cdf`, `top-ttl-cdf` (response-size & TTL CDFs motivating the padding bucket and batch-interval choices) | `top-size-cdf.dat` (≈730k A-response sizes), `top-ttl-cdf.dat` (≈152k TTLs), the two `.gpi` scripts, `style.gpi` |

## Regenerate the paper's tables and figures from these archives

All commands below are run from the **artifact repo root** (the directory
containing `repos/`). They have been tested end-to-end on the shipped archives.

**Tools.** The **tables** (and the leakage figures) regenerate with just
`python3` — already in the Docker image, so they work inside the container. The
**latency / page-load / DNS figures** are rendered with **gnuplot + epstopdf**,
which are *not* in the image; run those on the host
(`apt-get install gnuplot texlive-font-utils`). The leakage figures
(Main Result 5) use matplotlib and are documented in
`../ARTIFACT-APPENDIX.md` → *Experiment 3*; they are not in this directory.

### Table 3 — latency  (`table3-latency-cdfs.tar.gz`)

```bash
tar xzf paper-results/table3-latency-cdfs.tar.gz       # → multi-region-combined/

# (a) Tables — python only, runs in the container:
python3 repos/coredns/benchmark/plot_preprocess.py "$PWD/multi-region-combined"
#   → multi-region-combined/plots/table_comparison.tex     (Table 3, LaTeX)
#   → multi-region-combined/plots/percentiles_trimmed.json (the p50/p95/p99 numbers)
#   → multi-region-combined/plots/*.cdf                     (CDF curves, 2-col data)

# (b) Rendered latency CDF figures — host (gnuplot+epstopdf):
repos/coredns/benchmark/plot.sh "$PWD/multi-region-combined"
#   → multi-region-combined/plots/cdf_{warm,zipf,cold}.{eps,pdf}
```

### Table 9 — sensitivity sweep  (`table9-sensitivity-sweep.tar.gz`)

```bash
tar xzf paper-results/table9-sensitivity-sweep.tar.gz   # → param_sweep_20260514/
python3 repos/coredns/benchmark/plot_preprocess.py "$PWD/param_sweep_20260514"
#   → param_sweep_20260514/plots/table_sweep_oram.tex  (N ∈ {256,512,1024,2048})
#   → param_sweep_20260514/plots/table_sweep_cover.tex (k ∈ {1,3,5})
```

This regenerates the sweep **latency** table; the appendix version of Table 9
additionally breaks out per-hit / per-miss latency and the cache hit rate.

### Tables 4 / 5 / 7 / 8 — microbenchmarks, plain columns  (`tables4-8-microbench-plain.tar.gz`)

These `.txt` are the authors' raw `go test -bench … -count=3` output; the paper
values are the **medians** across the three repetitions. View them directly:

```bash
tar xzf paper-results/tables4-8-microbench-plain.tar.gz   # → microbench-plain/
sed -n '1,40p' microbench-plain/crypto.txt   # Table 4  (HPKE / AES-GCM / Ed25519, Plain)
sed -n '1,60p' microbench-plain/cache.txt    # Table 5  (LRU vs ORAM Get/Put, Plain)
grep ns/op     microbench-plain/ipc.txt      # Table 7  (IPC round-trip, Plain)
cat            microbench-plain/padding.txt  # Table 8  (padding-overhead summary)
```

To regenerate the plain columns on your own CPU, run
`repos/coredns/benchmark/run-microbench.sh` (or the per-bench commands in
*Experiment 4*). The **SGX columns** are hardware-gated (see below).

### Page-load figure `plot_per_site`  (`fig-pageload.tar.gz`)  — host, gnuplot

```bash
tar xzf paper-results/fig-pageload.tar.gz && cd fig-pageload
gnuplot plots/plot_per_site.gpi > plot_per_site.eps   # 4 series: CODoH/ODoH × page-load/DNS
epstopdf plot_per_site.eps                            # optional → plot_per_site.pdf
cd -
```

These `.dat` files are exactly what the paper's `plot_per_site` figure plots —
re-running the command above reproduces it, and the paper's conviva.com
(3.0→2.5 s) and opera.com (1.3→1.18 s) figures are these values rounded. Each row
is one site's mean and standard deviation across runs (74 sites — see the note on
item counts above). 

### Appendix DNS CDFs `top-size-cdf` / `top-ttl-cdf`  (`fig-dns-cdfs.tar.gz`)  — host, gnuplot

```bash
tar xzf paper-results/fig-dns-cdfs.tar.gz && cd fig-dns-cdfs
gnuplot plots/top-size-cdf.gpi > top-size-cdf.eps
gnuplot plots/top-ttl-cdf.gpi  > top-ttl-cdf.eps
cd -
```

## Not included (hardware-gated, not recoverable from any repo)

- **SGX columns** of Tables 4, 5, 6, and 7 — measured on the Intel SGX Azure VM;
  the raw outputs were not committed. Only the typeset values exist (in the paper).
- **Table 10** (plain-mode PathORAM-vs-linear-scan crossover) — measured on a
  separate large-RAM workstation; raw output not committed.

Both are documented as out of scope in `../ARTIFACT-APPENDIX.md` → *Limitations*.
