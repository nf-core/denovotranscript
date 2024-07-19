# nf-core/denovotranscript: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - [2024-07-19]

Initial release of nf-core/denovotranscript, created with the [nf-core](https://nf-co.re/) template.

This pipeline was created using code from [avani-bhojwani/TransFuse](https://github.com/avani-bhojwani/TransFuse) and [timslittle/nf-core-transcriptcorral](https://github.com/timslittle/nf-core-transcriptcorral/). It also incorporates modules and subworkflows developed by the nf-core community.

The main features of this pipeline are:

- Pre-processing of paired-end RNA-seq reads with FastQC, fastp, and SortMeRNA
- _De novo_ transcriptome assembly with Trinity and rnaSPAdes
- Redundancy reduction with EvidentialGene
- Quality assessment of the assembly with BUSCO, rnaQUAST, and TransRate
- Transcript-level quantification with Salmon
- Reporting of the results with MultiQC
