# CODoH — Artifact

This repository is the single entry point for the artifact accompanying:

> **CODoH: Privacy-Preserving Caching for Oblivious DNS over HTTPS**
> Pankaj Niroula, Lily Gloudemans, Aashutosh Poudel, Collin MacDonald, Stephen Herwig.
> Proceedings on Privacy Enhancing Technologies (PoPETs), 2026.

CODoH is a cacheable extension to Oblivious DNS over HTTPS (ODoH). It keeps a
proxy-side cache inside an Intel SGX enclave with end-to-end encryption, and
defends caching against inference with cover responses, batched cache updates,
and a Path ORAM backend.

> **For artifact reviewers:** the full evaluation instructions, badge scope,
> requirements, and the component → paper-claim map are in
> **[`ARTIFACT-APPENDIX.md`](ARTIFACT-APPENDIX.md)**. Start there.

## Layout

All components are included as Git submodules under [`repos/`](repos), each
pinned to its `pets26-artifact` tag:

| Submodule | What it is |
| --- | --- |
| [`repos/coredns`](repos/coredns) | CODoH server (`codohproxy` / `codohtarget` CoreDNS plugins) + SGX enclave (EGo) + benchmark and Azure testbed scripts |
| [`repos/codoh-client`](repos/codoh-client) | CODoH client and latency benchmark tool (fork of Cloudflare `odoh-client-go`) |
| [`repos/dnscrypt-proxy`](repos/dnscrypt-proxy) | Local DNS proxy with CODoH support; drives browser page-load benchmarks |
| [`repos/codoh-evals`](repos/codoh-evals) | Trace-driven leakage simulator + plotting; Playwright crawl harness |
| [`repos/pathoram-go`](repos/pathoram-go) | Path ORAM library (the enclave's oblivious cache backend) |

## Quickstart (no special hardware)

```bash
git clone --recursive https://github.com/etclab/codoh-artifact.git
cd codoh-artifact
docker build -t codoh:artifact .
docker run --rm -it codoh:artifact ./test.sh
```

The functional test runs the SGX enclave in **simulation mode**, so no
SGX-capable CPU and no EGo SDK are required. It builds every component, runs the
Path ORAM, enclave, and leakage-simulator unit tests, and issues live CODoH
queries end-to-end (cache miss → cache hit). Expected runtime: ~10 min human /
<25 min compute, ~10–15 GB disk.

See [`ARTIFACT-APPENDIX.md`](ARTIFACT-APPENDIX.md) for expected output, the full
hardware testbed instructions, and reuse notes.

## License

The artifact glue in this repository is released under the BSD 3-Clause License
(see [`LICENSE`](LICENSE)). Each submodule retains its own license.
