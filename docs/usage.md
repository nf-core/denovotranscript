# nf-core/denovotranscript: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/denovotranscript/usage](https://nf-co.re/denovotranscript/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis. Below is an example for the same sample sequenced across 3 lanes:

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
CONTROL_REP1,AEG588A1_S1_L003_R1_001.fastq.gz,AEG588A1_S1_L003_R2_001.fastq.gz
CONTROL_REP1,AEG588A1_S1_L004_R1_001.fastq.gz,AEG588A1_S1_L004_R2_001.fastq.gz
```

### Full samplesheet

The pipeline will auto-detect whether a sample is single- or paired-end using the information provided in the samplesheet. The samplesheet can have as many columns as you desire, however, there is a strict requirement for the first 3 columns to match those defined in the table below.

This pipeline is suitable for paired-end reads only. A final samplesheet file may look something like the one below. This is for 6 samples, where `TREATMENT_REP3` has been sequenced twice.

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz
CONTROL_REP3,AEG588A3_S3_L002_R1_001.fastq.gz,AEG588A3_S3_L002_R2_001.fastq.gz
TREATMENT_REP1,AEG588A4_S4_L003_R1_001.fastq.gz,AEG588A4_S4_L003_R2_001.fastq.gz
TREATMENT_REP2,AEG588A5_S5_L003_R1_001.fastq.gz,AEG588A5_S5_L003_R2_001.fastq.gz
TREATMENT_REP3,AEG588A6_S6_L003_R1_001.fastq.gz,AEG588A6_S6_L003_R2_001.fastq.gz
TREATMENT_REP3,AEG588A6_S6_L004_R1_001.fastq.gz,AEG588A6_S6_L004_R2_001.fastq.gz
```

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                             |
| `fastq_2` | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                             |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Example workflow

An example workflow for RNA-seq data from an experiment can look like this:

1. Run the pipeline with `--QC_only` with default params to check the quality of your reads.

```bash
nextflow run nf-core/denovotranscript \
  --input samplesheet.csv \
  --outdir <OUTDIR> \
  -profile docker \
  --QC_only
```

2. Run the pipeline with `QC_only` and any custom params that you have decided to use based on your data.

```bash
nextflow run nf-core/denovotranscript \
  --input samplesheet.csv \
  --outdir <OUTDIR> \
  -profile docker \
  --QC_only \
  --extra_fastp_args='--trim_front1 15 --trim_front2 15' \
  --remove_ribo_rna \
  -resume
```

3. Once you are happy with the quality of your reads, run the pipeline without `QC_only` to proceed to transcriptome assembly.
   If you have a lot of samples, you may wish to only include one replicate per condition in the samplesheet for assembly, as this may be quicker to run. This command also runs transcriptome quality assessment steps and quantification.

```bash
nextflow run nf-core/denovotranscript \
  --input samplesheet_assembly.csv \ # samplesheet with only one replicate per sample
  --outdir <OUTDIR> \
  -profile docker \
  --extra_fastp_args='--trim_front1 15 --trim_front2 15' \
  --remove_ribo_rna \
  --extra_tr2aacds_args='-MINAA 50' \
  --busco_lineage= 'arthropoda_odb10' \
  -resume
```

4. If you created the transcriptome assembly with only one replicate per condition, you can now run the pipeline with the full samplesheet, path to `--transcript_fasta`, and `--skip_assembly` to quantify the expression of all samples. If you used a samplesheet with all samples in step 3, this step is not needed.

```bash
nextflow run nf-core/denovotranscript \
  --input samplesheet.csv \ # full samplesheet
  --transcript_fasta /path/to/evigene_final_assembly/mrna_fasta_file \
  --outdir <OUTDIR> \
  -profile docker \
  --extra_fastp_args='--trim_front1 15 --trim_front2 15' \
  --remove_ribo_rna \
  --skip_assembly \
  -resume
```

## Quality Control options

By default, this pipeline checks the quality of the raw reads using FastQC, then performs trimming with fastp. Quality of the trimmed reads is checked again with
FastQC. You can provide extra arguments to fastp using the `--extra_fastp_args` parameter. You can provide fasta files of adapter sequences to be used for trimming with the `--adapter_fasta` parameter.

Alternatively, you can skip these steps with `--skip_qc` and `--skip_fastp` parameters.

There is also an optional step to remove rRNA reads using SortMeRNA after trimming using the `--remove_ribo_rna` parameter. You can provide a custom ribosomal RNA database with the `--ribo_database_manifest` parameter. By default, the pipeline uses the databases mentioned in `assets/rrna-db-defaults.txt`. You can also save the non-ribo reads with the `--save_non_ribo_reads` parameter. If
rRNA removal is performed, then FastQC is run again on the non-ribo reads.

## Assembly and redundancy reduction options

You can set any or all of the following parameters to true depending on which
assemblers/methods/outputs to want to include as inputs to Evidential Gene:

- `--trinity` (default)
- `--rnaspades` (default, keeps only medium filtered transcripts)
- `--trinity_no_norm` (to run Trinity without normalised reads)
- `--soft_filtered_transcripts` (to include soft filtered transcripts from rnaSPAdes as inputs to Evidential Gene)
- `--hard_filtered_transcripts` (to include hard filtered transcripts from rnaSPAdes as inputs to Evidential Gene)

Extra parameters can be provided to Trinity using the `extra_trinity_args` parameter. The `ss` param can be used to set the strand-specific type for rnaSPAdes.

All assemblies are concatenated into one and redundancy is reduced using
Evidential Gene's tr2aacds tool. You can provide additional parameters to tr2aacds
using the `extra_tr2aacds_args` parameter.

## Assembly quality assessment

The pipeline runs BUSCO on the final assembly to assess the quality of the assembly. You can provide the lineage to use with the `--busco_lineage` parameter. Other parameters available for BUSCO include `busco_lineages_path` and `busco_config`.

rnaQUAST is also run on the final assembly. Optional parameters for rnaQUAST include `fasta` for a fasta file of a reference genome and `gtf` for a GTF/GFF file of gene coordinates.

TransRate can be used for assembly quality assessment if the profile is not set to `conda` or `mamba`. It provides contig metrics as well as read mapping metrics. Optionally, the `transrate_reference` parameter can be used to provide a FASTA file of reference proteins or transcripts from a related species.

## Quantification options

You can provide the path to the transcriptome assembly fasta file with the `--transcript_fasta` parameter if you are running the pipeline in `--skip_assembly` mode. The `--skip_assembly` mode performs QC and quantification, but does not create a transcriptome assembly. The pipeline uses Salmon to quantify the expression of the reads. By default the library type is set to `A`, but you can change this with the `--lib_type` parameter.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/denovotranscript --input ./samplesheet.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

:::warning
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
:::

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/denovotranscript -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/denovotranscript
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/denovotranscript releases page](https://github.com/nf-core/denovotranscript/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

:::tip
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.
:::

## Core Nextflow arguments

:::note
These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).
:::

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

:::info
We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is partially supported. Note that Conda is not supported for Transrate in this pipeline.
:::

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute `params.vm_type` of `Standard_D16_v3` VMs by default but these options can be changed if required.

Note that the choice of VM size depends on your quota and the overall workload during the analysis.
For a thorough list, please refer the [Azure Sizes for virtual machines in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
