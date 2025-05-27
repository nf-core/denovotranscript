//
// Subworkflow with functionality specific to the nf-core/denovotranscript pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //
    // Create channel from input file provided through params.input
    //

    Channel
        .fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
        .map {
            meta, fastq_1, fastq_2 ->
                if (!fastq_2) {
                    return [ meta.id, meta + [ single_end:true ], [ fastq_1 ] ]
                } else {
                    return [ meta.id, meta + [ single_end:false ], [ fastq_1, fastq_2 ] ]
                }
        }
        .groupTuple()
        .map { samplesheet ->
            validateInputSamplesheet(samplesheet)
        }
        .map {
            meta, fastqs ->
                return [ meta, fastqs.flatten() ]
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//
// Check and validate pipeline parameters
//
def validateInputParameters() {

    if ( params.qc_only && params.skip_assembly ) {
        error("Incompatible parameters: cannot use --skip_assembly and --qc_only modes together.")
    }

    if ( params.skip_assembly && !params.transcript_fasta ) {
        error("Missing parameter: Please provide --transcript_fasta of a transcriptome assembly when using --skip_assembly.")
    }

    if ( params.transcript_fasta && !params.skip_assembly ) {
        log.warn("Unused parameter: Ignoring --transcript_fasta as pipeline was not launched with --skip_assembly mode.")
    }

    if ( params.extra_trinity_args && params.extra_trinity_args.contains("--no_normalize_reads" ) ) {
        error("Incompatible parameters: Please do not use --no_normalize_reads in --extra_trinity_args. Use --trinity_no_norm instead.")
    }

    if (params.soft_filtered_transcripts || params.hard_filtered_transcripts) {
        def assemblers = params.assemblers.tokenize(',')
        if (!assemblers.contains("rnaspades")) {
            error("Missing parameter: Please include \"rnaspades\" in --assemblers to get --soft_filtered_transcripts or --hard_filtered_transcripts.")
        }
    }

    if (params.assemblers) {
        def assemblers = params.assemblers.tokenize(',')
        def invalid_assemblers = assemblers.findAll { it != "trinity" && it != "trinity_no_norm" && it != "rnaspades" }
        if (invalid_assemblers) {
            error("Invalid parameter: --assemblers can only contain \"trinity\", \"trinity_no_norm\", and \"rnaspades\". Found: ${invalid_assemblers.join(', ')}")
        }
    }
    genomeExistsError()
}
//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs) = input[1..2]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [ metas[0], fastqs ]
}
//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}
//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report

    def seq_qc_text = "Sequencing quality control was carried out with FastQC (Andrews 2010)."

    def shortread_qc_text = "Short read preprocessing was performed with fastp (Chen et al. 2018)."

    def ribosomal_filtering_text = "Ribosomal RNAs were removed with SortMeRNA (Kopylova et al. 2012)."

    def assemblers = params.assemblers.tokenize(',')
    def assembly_text = [
        "De novo assembly was performed with the following tool(s); ",
        (assemblers.contains('trinity') || assemblers.contains('trinity_no_norm')) ? "Trinity (Haas et al. 2013)." : "",
        assemblers.contains('rnaspades') ? "rnaSPAdes (Prjibelski et al. 2020)." : "",
    ].join(' ').trim()

    def assembly_reduction_text = "Assembly redundancy reduction was performed with Evidential Gene (Gilbert et al. 2019)."

    def quality_assessment_text = [
        "Assembly quality assessment was carried with the following tool(s); ",
        "BUSCO (Manni et al. 2021).",
        "rnaQUAST (Bushmanova et al. 2016).",
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() == 0 ? "TransRate (Smith-Unna et al. 2016)." : "",
    ].join(' ').trim()

    def quantification_text = "Quantification of transcript expression was performed with Salmon (Patro et al. 2017)."

    def postprocessing_text = "Run statistics were reported using MultiQC (Ewels et al. 2016)."

    def citation_text = [
            "Tools used in the workflow included:",
            !params.skip_fastqc ? seq_qc_text : "",
            !params.skip_fastp ? shortread_qc_text : "",
            params.remove_ribo_rna ? ribosomal_filtering_text : "",
            (!params.qc_only && !params.skip_assembly) ? assembly_text : "",
            (!params.qc_only && !params.skip_assembly) ? assembly_reduction_text : "",
            (!params.qc_only && !params.skip_assembly) ? quality_assessment_text : "",
            (!params.qc_only && !params.skip_assembly) ? quantification_text : "",
            postprocessing_text
        ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report

    def seq_qc_text = '<li>Andrews S. (2010) FastQC: A Quality Control Tool for High Throughput Sequence Data, URL: <a href=\"https://www.bioinformatics.babraham.ac.uk/projects/fastqc/\">https://www.bioinformatics.babraham.ac.uk/projects/fastqc/</a></li>'

    def shortread_qc_text = '<li>Chen, S. (2023). Ultrafast one‐pass FASTQ data preprocessing, quality control, and deduplication using fastp. Imeta, 2(2), e107. doi: <a href="https://doi.org/10.1002/imt2.107">10.1002/imt2.107</a></li>'

    def ribosomal_filtering_text = '<li>Kopylova, E., Noé, L., & Touzet, H. (2012). SortMeRNA: fast and accurate filtering of ribosomal RNAs in metatranscriptomic data. Bioinformatics, 28(24), 3211-3217. doi: <a href="https://doi.org/10.1093/bioinformatics/bts611">10.1093/bioinformatics/bts611</a></li>'

    def assemblers = params.assemblers.tokenize(',')
    def assembly_text = [
        (assemblers.contains('trinity') || assemblers.contains('trinity_no_norm')) ? '<li>Haas, B. J., Papanicolaou, A., Yassour, M., Grabherr, M., Blood, P. D., Bowden, J., ... & Regev, A. (2013). De novo transcript sequence reconstruction from RNA-seq using the Trinity platform for reference generation and analysis. Nature protocols, 8(8), 1494-1512. doi: <a href="https://doi.org/10.1038/nprot.2013.084">10.1038/nprot.2013.084</a></li>' : "",
        assemblers.contains('rnaspades') ? '<li>Prjibelski, A., Antipov, D., Meleshko, D., Lapidus, A., & Korobeynikov, A. (2020). Using SPAdes de novo assembler. Current protocols in bioinformatics, 70(1), e102. doi: <a href="https://doi.org/10.1002/cpbi.102">10.1002/cpbi.102</a></li>' : "",
    ].join(' ').trim()

    def assembly_reduction_text = '<li>Gilbert, D. G. (2019). Longest protein, longest transcript or most expression, for accurate gene reconstruction of transcriptomes?. BioRxiv, 829184. doi: <a href="https://doi.org/10.1101/829184">10.1101/829184</a></li>'

    def quality_assessment_text = [
        '<li>Manni, M., Berkeley, M. R., Seppey, M., Simão, F. A., & Zdobnov, E. M. (2021). BUSCO update: novel and streamlined workflows along with broader and deeper phylogenetic coverage for scoring of eukaryotic, prokaryotic, and viral genomes. Molecular biology and evolution, 38(10), 4647-4654. doi: <a href="https://doi.org/10.1093/molbev/msab199">10.1093/molbev/msab199</a></li>',
        '<li>Bushmanova, E., Antipov, D., Lapidus, A., Suvorov, V., & Prjibelski, A. D. (2016). rnaQUAST: a quality assessment tool for de novo transcriptome assemblies. Bioinformatics, 32(14), 2210-2212. doi: <a href="https://doi.org/10.1093/bioinformatics/btw218">10.1093/bioinformatics/btw218</a></li>',
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() == 0 ? '<li>Smith-Unna, R., Boursnell, C., Patro, R., Hibberd, J. M., & Kelly, S. (2016). TransRate: reference-free quality assessment of de novo transcriptome assemblies. Genome research, 26(8), 1134-1144. doi: <a href="https://doi.org/10.1101/gr.196469.115">10.1101/gr.196469.115</a></li>' : "",
    ].join(' ').trim()

    def quantification_text = '<li>Patro, R., Duggal, G., Love, M. I., Irizarry, R. A., & Kingsford, C. (2017). Salmon provides fast and bias-aware quantification of transcript expression. Nature methods, 14(4), 417-419. doi: <a href="https://doi.org/10.1038/nmeth.4197">10.1038/nmeth.4197</a></li>'

    def postprocessing_text = '<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047–3048. doi: <a href="https://doi.org/10.1093/bioinformatics/btw354">10.1093/bioinformatics/btw354</a></li>'

    def reference_text = [
            !params.skip_fastqc ? seq_qc_text : "",
            !params.skip_fastp ? shortread_qc_text : "",
            params.remove_ribo_rna ? ribosomal_filtering_text : "",
            (!params.qc_only && !params.skip_assembly) ? assembly_text : "",
            (!params.qc_only && !params.skip_assembly) ? assembly_reduction_text : "",
            (!params.qc_only && !params.skip_assembly) ? quality_assessment_text : "",
            (!params.qc_only && !params.skip_assembly) ? quantification_text : "",
            postprocessing_text
        ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}

