/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Check rRNA databases for sortmerna
if (params.remove_ribo_rna) {
    ch_ribo_db = file(params.ribo_database_manifest)
    if (ch_ribo_db.isEmpty()) {exit 1, "File provided with --ribo_database_manifest is empty: ${ch_ribo_db.getName()}!"}
} else {
    ch_ribo_db = Channel.empty()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// LOCAL MODULES
//
include { RNAQUAST                    } from '../modules/local/rnaquast/main'
include { ORP_TRANSRATE as TRANSRATE  } from '../modules/local/orp_transrate/main'

//
// LOCAL SUBWORKFLOWS
//
include { methodsDescriptionText      } from '../subworkflows/local/utils_nfcore_denovotranscript_pipeline'
include { validateInputSamplesheet    } from '../subworkflows/local/utils_nfcore_denovotranscript_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// NF-CORE MODULES/PLUGINS
//
include { fromSamplesheet             } from 'plugin/nf-validation'
include { paramsSummaryMap            } from 'plugin/nf-validation'

include { BUSCO_BUSCO                 } from '../modules/nf-core/busco/busco/main'
include { CAT_CAT                     } from '../modules/nf-core/cat/cat/main'
include { CAT_FASTQ                   } from '../modules/nf-core/cat/fastq/main'
include { EVIGENE_TR2AACDS            } from '../modules/nf-core/evigene/tr2aacds/main'
include { FASTQC as FASTQC_FINAL      } from '../modules/nf-core/fastqc/main'
include { GAWK as TX2GENE             } from '../modules/nf-core/gawk/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { SORTMERNA                   } from '../modules/nf-core/sortmerna/main'
include { SPADES                      } from '../modules/nf-core/spades/main'
include { TRINITY                     } from '../modules/nf-core/trinity/main'
include { TRINITY as TRINITY_NO_NORM  } from '../modules/nf-core/trinity/main'
include { SALMON_INDEX                } from '../modules/nf-core/salmon/index/main'
include { SALMON_QUANT                } from '../modules/nf-core/salmon/quant/main'

//
// NF-CORE SUBWORKFLOWS
//
include { FASTQ_TRIM_FASTP_FASTQC     } from '../subworkflows/nf-core/fastq_trim_fastp_fastqc/main'
include { paramsSummaryMultiqc        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DENOVOTRANSCRIPT {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: FASTQ_TRIM_FASTP_FASTQC
    //

    FASTQ_TRIM_FASTP_FASTQC (
        ch_samplesheet,
        params.adapter_fasta ?: [],
        params.save_trimmed_fail,
        params.save_merged,
        params.skip_fastp,
        params.skip_fastqc
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQ_TRIM_FASTP_FASTQC.out.fastqc_raw_zip.collect{it[1]})
    ch_multiqc_files = ch_multiqc_files.mix(FASTQ_TRIM_FASTP_FASTQC.out.fastqc_trim_zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQ_TRIM_FASTP_FASTQC.out.versions)
    ch_filtered_reads = FASTQ_TRIM_FASTP_FASTQC.out.reads

    if (params.remove_ribo_rna) {
        ch_sortmerna_fastas = Channel.from(ch_ribo_db.readLines()).map { row -> file(row, checkIfExists: true) }.collect()
        //
        // MODULE: SORTMERNA
        //
        SORTMERNA (
            ch_filtered_reads,
            ch_sortmerna_fastas
        )
        ch_filtered_reads = SORTMERNA.out.reads
        ch_multiqc_files = ch_multiqc_files.mix(SORTMERNA.out.log.collect{it[1]}.ifEmpty([]))
        ch_versions = ch_versions.mix(SORTMERNA.out.versions)

        //
        // MODULE: FASTQC
        //
        FASTQC_FINAL (
            SORTMERNA.out.reads
        )
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_FINAL.out.zip.collect{it[1]})
        ch_versions = ch_versions.mix(FASTQC_FINAL.out.versions)
    }

    if (!params.qc_only) {

        if (!params.skip_assembly) {

            // All methods use pooled reads
            ch_pool = ch_filtered_reads.collect { meta, fastq -> fastq }.map { [[id:'pooled_reads', single_end:false], it] }

            //
            // MODULE: CAT_FASTQ
            //
            CAT_FASTQ (
                ch_pool
            )
            ch_versions = ch_versions.mix(CAT_FASTQ.out.versions)

            ch_assemblies = Channel.empty()

            def assemblers = params.assemblers.tokenize(',')

            if (assemblers.contains('trinity')) {
                //
                // MODULE: TRINITY
                //
                TRINITY (
                    CAT_FASTQ.out.reads
                )
                ch_versions = ch_versions.mix(TRINITY.out.versions)
                ch_assemblies = ch_assemblies.mix(TRINITY.out.transcript_fasta)
            }

            if (assemblers.contains('trinity_no_norm')) {
                //
                // MODULE: TRINITY_NO_NORM
                //
                TRINITY_NO_NORM (
                    CAT_FASTQ.out.reads
                )
                ch_versions = ch_versions.mix(TRINITY_NO_NORM.out.versions)
                ch_assemblies = ch_assemblies.mix(TRINITY_NO_NORM.out.transcript_fasta)
            }

            if (assemblers.contains('rnaspades')) {
                CAT_FASTQ.out.reads.map { meta, illumina ->
                    [ meta, illumina, [], [] ] }.set { ch_spades }

                //
                // MODULE: SPADES
                //
                SPADES (
                    ch_spades,
                    [],
                    []
                )
                ch_versions = ch_versions.mix(SPADES.out.versions)
                ch_assemblies = ch_assemblies.mix(SPADES.out.transcripts)

                if (params.soft_filtered_transcripts) {
                    ch_assemblies = ch_assemblies.mix(SPADES.out.soft_filtered_transcripts)
                }

                if (params.hard_filtered_transcripts) {
                    ch_assemblies = ch_assemblies.mix(SPADES.out.hard_filtered_transcripts)
                }
            }

            ch_assemblies = ch_assemblies
                .collect { meta, fasta -> fasta }
                .map { [[id:'all_assembled', single_end:false], it ] }

            //
            // MODULE: CAT_CAT
            //
            CAT_CAT (
                ch_assemblies
            )
            ch_versions = ch_versions.mix(CAT_CAT.out.versions)

            //
            // MODULE: EVIGENE_TR2AACDS
            //
            EVIGENE_TR2AACDS (
                CAT_CAT.out.file_out
            )
            ch_versions = ch_versions.mix(EVIGENE_TR2AACDS.out.versions)

            ch_transcripts = EVIGENE_TR2AACDS.out.okayset.map { meta, dir ->
                def mrna_file = file("$dir/*okay.mrna")
                return [ meta, mrna_file ]}

            ch_pubids = EVIGENE_TR2AACDS.out.okayset.map { meta, dir ->
                def pubids_file = file("$dir/*.pubids")
                return [ meta, pubids_file ]}
            //
            // MODULE: TX2GENE
            //
            TX2GENE (
                ch_pubids,
                []
            )
            ch_versions = ch_versions.mix(TX2GENE.out.versions)

            //
            // MODULE: BUSCO
            //
            BUSCO_BUSCO (
                ch_transcripts,
                params.busco_mode,
                params.busco_lineage,
                params.busco_lineages_path ?: [],
                params.busco_config ?: [],
            )
            ch_multiqc_files = ch_multiqc_files.mix(BUSCO_BUSCO.out.short_summaries_txt.collect{it[1]})
            ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions)

            //
            // MODULE: RNAQUAST
            //
            RNAQUAST (
                ch_transcripts
            )
            ch_versions = ch_versions.mix(RNAQUAST.out.versions)

            // only run if profile is not conda or mamba
            if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() == 0) {
                //
                // MODULE: TRANSRATE
                //
                TRANSRATE (
                    ch_transcripts,
                    CAT_FASTQ.out.reads,
                    params.transrate_reference ?: []
                )
                ch_versions = ch_versions.mix(TRANSRATE.out.versions)
            }
        }

        ch_transcripts_fa = ch_transcripts.collect { meta, fasta -> fasta }
        if (params.skip_assembly) {
            ch_transcripts_fa = Channel.fromPath(params.transcripts_fa, checkIfExists: true)
        }

        //
        // MODULE: SALMON_INDEX
        //
        SALMON_INDEX (
            ch_transcripts_fa
        )
        ch_versions = ch_versions.mix(SALMON_INDEX.out.versions)

        //
        // MODULE: SALMON_QUANT
        //
        SALMON_QUANT (
            ch_filtered_reads,
            SALMON_INDEX.out.index,
            ch_transcripts_fa,
            params.lib_type
        )
        ch_multiqc_files = ch_multiqc_files.mix(SALMON_QUANT.out.results.collect{it[1]})
        ch_versions = ch_versions.mix(SALMON_QUANT.out.versions)

    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
