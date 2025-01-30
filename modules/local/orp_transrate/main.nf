process ORP_TRANSRATE {
    tag "$meta.id"
    label 'process_high'

    // Using conda or the biocontainer for transrate results in a SNAP index error.
    // However, the error does not occur when using the tarball from the Oyster River Protocol.
    // see https://github.com/blahah/transrate/issues/248
    container 'quay.io/nf-core/orp_transrate:1.0.3_cv1.3'

    input:
    tuple val(meta), path(fasta)         // assembly file
    tuple val(meta), path(reads)         // processed reads
    path reference                       // reference proteins or transcripts fasta

    output:
    path "${fasta.baseName}/"           , emit: transrate_results
    path "assemblies.csv"               , emit: summary_csv
    path "transrate.log"                , emit: log
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "ORP_TRANSRATE module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def transrate_reference = reference ? "--reference $reference" : ''
    """
    gunzip -c ${reads[0]} > ${prefix}_1.fq
    gunzip -c ${reads[1]} > ${prefix}_2.fq

    # Ruby (a dependency of transrate) requires a writable tmp directory
    mkdir ./tmp
    export TMPDIR=./tmp
    export TEMP=./tmp
    export TMP=./tmp

    transrate \\
        --assembly $fasta \\
        --left ${prefix}_1.fq \\
        --right ${prefix}_2.fq \\
        --threads $task.cpus \\
        $transrate_reference \\
        $args

    cp .command.out transrate.log
    cp -r transrate_results/* ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        transrate (from Oyster River Protocol): \$(transrate -v)
        blast+: \$(blastp -version | grep -oP "blast \\K[^,]*")
    END_VERSIONS
    """
}
