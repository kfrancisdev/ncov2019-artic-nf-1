process pango {
    tag { sampleName }

    publishDir "${params.outdir}/analysis/pango/${params.prefix}", mode: 'copy'

    input:
    tuple(sampleName,  path(fasta))

    output:
    tuple(sampleName, path("${sampleName}_lineage_report.csv"))

    script:
    """
    pangolin ${fasta}
    mv lineage_report.csv ${sampleName}_lineage_report.csv
    """
}


process nextclade {
    tag { sampleName }

    publishDir "${params.outdir}/analysis/nextclade/${params.prefix}", mode: 'copy'

    input:
    tuple(sampleName,  path(fasta))

    output:
    tuple(sampleName, path("${sampleName}_tree.json"),
	path("${sampleName}.tsv"),path("${sampleName}.json"))

    script:
    """
    nextclade --input-fasta ${fasta} \
        --output-tree ${sampleName}_tree.json \
        --output-tsv ${sampleName}.tsv \
        --output-json ${sampleName}.json
    """
}

process getVariantDefinitions {
    output:
    path('variant_definitions') 

    script:
    """
    git clone https://github.com/phe-genomics/variant_definitions
    """
}



process aln2type {
    tag { sampleName }

    publishDir "${params.outdir}/analysis/aln2type/${params.prefix}", mode: 'copy'

    input:
    tuple(sampleName,  path(fasta),path(variant_definitions), path(reffasta), path("*"))

    output:
    tuple(sampleName, path("${sampleName}.csv")) optional true

    script:
    """
    cat $reffasta  ${fasta} > unaligned.fasta
    mafft --auto unaligned.fasta > aln.fasta
    aln2type sample_json_out \
	sample_csv_out \
	--output_unclassified \
	${sampleName}.csv \
	MN908947.3 \
	aln.fasta \
	variant_definitions/variant_yaml/*.yml

    """
}


process makeReport {
    tag { sampleName }

    publishDir "${params.outdir}/analysis/report/${params.prefix}", mode: 'copy'

    input:
    tuple(sampleName, path('pango.csv'), path('aln2type.csv'), path('nextclade_tree.json'), path('nextclade.tsv'),
		path('nextclade.json'))

    output:
    path("${sampleName}_report.tsv"), emit: tsv

    script:
    """
    makeReport.py ${sampleName}
    """
}
