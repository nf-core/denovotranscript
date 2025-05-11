process RNAQUAST {
    tag "$meta.id"
    label 'process_medium'

    // code from https://github.com/timslittle/modules/blob/rnaquast/modules/nf-core/rnaquast/main.nf
    // and https://github.com/avani-bhojwani/TransFuse/blob/dev/modules/local/rnaquast.nf

    conda "bioconda::rnaquast=2.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/rnaquast:2.3.0--h9ee0642_0' :
        'biocontainers/rnaquast:2.3.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(fasta)

    output:
    path "logs"             , emit: logs
    path "*_output"         , emit: output
    path "short_report.pdf" , emit: report_pdf
    path "short_report.tex" , emit: report_tex
    path "short_report.tsv" , emit: report_tsv
    path "short_report.txt" , emit: report_txt
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def reference = params.fasta ? "--reference ${params.fasta}" : ""
    def gtf = params.gtf ? "--gtf ${params.gtf}" : ""

    """
    rnaQUAST.py \\
        --output_dir . \\
        --transcripts $fasta \\
        --threads $task.cpus \\
        --labels $prefix \\
        $reference \\
        $gtf \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rnaquast: \$(rnaQUAST.py -h | grep "QUALITY ASSESSMENT" | head -n1 | awk -F " v." '{print \$2}')
    END_VERSIONS
    """
}
