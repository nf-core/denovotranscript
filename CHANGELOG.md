# nf-core/denovotranscript: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.2.0 - [2025-01-30]

- [PR #25](https://github.com/nf-core/denovotranscript/pull/25) - Bump version to 1.2.0dev
- [PR #27](https://github.com/nf-core/denovotranscript/pull/27) - Update spades resources and usage instructions
- [PR #28](https://github.com/nf-core/denovotranscript/pull/28) - Template update for nf-core/tools v3.1.0
- [PR #29](https://github.com/nf-core/denovotranscript/pull/29) - Template update for nf-core/tools v3.1.1
- [PR #30](https://github.com/nf-core/denovotranscript/pull/30) - Fix ch_transcripts and ch_pubids for AWS
- [PR #32](https://github.com/nf-core/denovotranscript/pull/32) - Fix transrate dependencies issue
- [PR #33](https://github.com/nf-core/denovotranscript/pull/33) - Bump version to 1.2.0
- [PR #36](https://github.com/nf-core/denovotranscript/pull/36) - Template update for nf-core/tools v3.2.0

## v1.1.0 - [2024-11-28]

Enhancements & fixes:

- [PR #14](https://github.com/nf-core/denovotranscript/pull/14) - Template update for nf-core/tools v3.0.2
- [PR #15](https://github.com/nf-core/denovotranscript/pull/15) - Fix logic for skip_assembly parameter
- [PR #16](https://github.com/nf-core/denovotranscript/pull/16) - Increase resources for Trinity
- [PR #19](https://github.com/nf-core/denovotranscript/pull/21) - Fix Salmon quantification when running in skip_assembly mode
- [PR #24](https://github.com/nf-core/denovotranscript/pull/24) - Update Trinity module and fix dependency issue

### Software dependencies

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| `Trinity`  | 2.15.1      | 2.15.2      |

## v1.0.0 - [2024-08-15]

Initial release of nf-core/denovotranscript, created with the [nf-core](https://nf-co.re/) template.

This pipeline was created using code from [avani-bhojwani/TransFuse](https://github.com/avani-bhojwani/TransFuse) and [timslittle/nf-core-transcriptcorral](https://github.com/timslittle/nf-core-transcriptcorral/). It also incorporates modules and subworkflows developed by the nf-core community.

The main features of this pipeline are:

- Pre-processing of paired-end RNA-seq reads with FastQC, fastp, and SortMeRNA
- _De novo_ transcriptome assembly with Trinity and rnaSPAdes
- Redundancy reduction with EvidentialGene
- Quality assessment of the assembly with BUSCO, rnaQUAST, and TransRate
- Transcript-level quantification with Salmon
- Reporting of the results with MultiQC
