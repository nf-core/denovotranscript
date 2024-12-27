# Example workflow run

An example workflow for RNA-seq data from an experiment can look like this:

1. Run the pipeline with `--qc_only` with default params to check the quality of your reads.

```bash
nextflow run nf-core/denovotranscript \
  --input samplesheet.csv \
  --outdir <OUTDIR> \
  -profile docker \
  --qc_only
```

2. Run the pipeline with `qc_only` and any custom parameters that you have decided to use based on your data. Use `resume` to avoid unnecessarily rerunning unchanged steps.

```bash {6-8}
nextflow run nf-core/denovotranscript \
  --input samplesheet.csv \
  --outdir <OUTDIR> \
  -profile docker \
  --qc_only \
  --extra_fastp_args='--trim_front1 15 --trim_front2 15' \
  --remove_ribo_rna \
  -resume
```

3. Once you are happy with the quality of your reads, run the pipeline without `qc_only` to proceed to transcriptome assembly.
   If you have a lot of samples, you may wish to only include one replicate per condition in the samplesheet for assembly, as this may be quicker to run. This command also runs transcriptome quality assessment steps and quantification.

```bash {2,7,8}
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

4. If you created the transcriptome assembly with only one replicate per condition, you can now run the pipeline with the full samplesheet. Provide a path to `--transcript_fasta` and use `--skip_assembly` to quantify the expression of all samples. If you used a samplesheet with all samples in step 3, this step is not needed.

```bash {2,3,8}
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
