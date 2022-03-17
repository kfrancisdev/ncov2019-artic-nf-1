// ARTIC processes

process articDownloadScheme{
    tag 'reference'

    label 'internet'

//    publishDir "${params.outdir}/${task.process.replaceAll(":","_")}", pattern: "scheme", mode: "copy"

    output:
    path "${params.schemeDir}/${params.scheme}/${params.schemeVersion}/*.reference.fasta" , emit: reffasta
    path "${params.schemeDir}/${params.scheme}/${params.schemeVersion}/*.primer.bed" , emit: bed
    path "${params.schemeDir}" , emit: scheme

    script:
    """
    git clone ${params.schemeRepoURL} ${params.schemeDir}
    """
}

process articGuppyPlex {
    tag { prefix }

    label 'largemem'

    publishDir "${params.outdir}/${task.process.replaceAll(":","_")}", pattern: "${params.prefix}*.fastq", mode: "copy"

    input:
    tuple(prefix, path(fastq))

    output:
    tuple val(prefix), path("${prefix}_.fastq"), emit: fastq

    script:
    """
    artic guppyplex \
    --min-length ${params.min_length} \
    --max-length ${params.max_length} \
    --prefix ${prefix} \
    --directory ./
    """
}

process articMinIONMedaka {
    tag { sampleName }

    cpus 4

    if (params.TESToutputMODE){
        publishDir "${params.outdir}/bam", pattern: "*.bam", mode: "copy"
        publishDir "${params.outdir}/VCF", pattern: "*.vcf", mode: "copy"
    }

    publishDir "${params.outdir}/consensus_seqs/", pattern: "${sampleName}.fasta", mode: "copy"

    input:
    tuple sampleName, file(fastq), file(schemeRepo)

    output:
    file("${sampleName}*")
    
    tuple sampleName, file("${sampleName}.primertrimmed.rg.sorted.bam"), emit: ptrim
    tuple sampleName, file("${sampleName}.sorted.bam"), emit: mapped
    tuple sampleName, file("${sampleName}.fasta"), emit: consensus_fasta
    tuple sampleName, file("${sampleName}.pass.vcf.gz"), emit: vcf

    script:
    // Make an identifier from the fastq filename
    //sampleName = fastq.getBaseName().replaceAll(~/\.fastq.*$/, '')

    // Configure artic minion pipeline
    minionRunConfigBuilder = []

    if ( params.normalise ) {
    minionRunConfigBuilder.add("--normalise ${params.normalise}")
    }
    
    if ( params.bwa ) {
    minionRunConfigBuilder.add("--bwa")
    } else {
    minionRunConfigBuilder.add("--minimap2")
    }

    minionFinalConfig = minionRunConfigBuilder.join(" ")

    """
    artic minion --medaka \
    ${minionFinalConfig} \
    --threads ${task.cpus} \
    --scheme-directory ${schemeRepo} \
    --read-file ${fastq} \
    ${params.scheme}/${params.schemeVersion} \
    ${sampleName}
    cp ${sampleName}.consensus.fasta ${sampleName}.fasta
    """
}

process splitSeqSum {
    tag 'splitSeqSum'

    cpus 4

    input:
    file(seqSummary)

    output:
    file("barcodes/*.txt")

    script:
    """
    split_summary_by_barcode.py ${seqSummary} barcodes 
    """

}

process articMinIONNanopolish {
    tag { sampleName }

    cpus 4
    memory '3 GB'

    publishDir "${params.outdir}/${task.process.replaceAll(":","_")}", pattern: "${sampleName}*", mode: "copy"

    input:
    tuple barcode, file(fastq), file(seqSummary), file(schemeRepo), file(fast5Pass)

    output:
    file("${sampleName}*")
    
    tuple sampleName, file("${sampleName}.primertrimmed.rg.sorted.bam"), emit: ptrim
    tuple sampleName, file("${sampleName}.sorted.bam"), emit: mapped
    tuple sampleName, file("${sampleName}.consensus.fasta"), emit: consensus_fasta
    tuple sampleName, file("${sampleName}.pass.vcf.gz"), emit: vcf

    script:
    // Make an identifier from the fastq filename
    sampleName = fastq.getBaseName().replaceAll(~/\.fastq.*$/, '')

    // Configure artic minion pipeline
    minionRunConfigBuilder = []

    if ( params.normalise ) {
    minionRunConfigBuilder.add("--normalise ${params.normalise}")
    }
    
    if ( params.bwa ) {
    minionRunConfigBuilder.add("--bwa")
    } else {
    minionRunConfigBuilder.add("--minimap2")
    }

    minionFinalConfig = minionRunConfigBuilder.join(" ")

    """
    artic minion ${minionFinalConfig} \
    --threads ${task.cpus} \
    --scheme-directory ${schemeRepo} \
    --read-file ${fastq} \
    --fast5-directory ./ \
    --sequencing-summary ${seqSummary} \
    ${params.scheme}/${params.schemeVersion} \
    ${sampleName}
    """
}

process articRemoveUnmappedReads {
    tag { sampleName }

    cpus 1

    input:
    tuple(sampleName, path(bamfile))

    output:
    tuple( sampleName, file("${sampleName}.mapped.sorted.bam"))

    script:
    """
    samtools view -F4 -o ${sampleName}.mapped.sorted.bam ${bamfile} 
    """
}

process getObjFilesONT {
    /**
    * fetches fastq files from object store using OCI bulk download (https://docs.oracle.com/en-us/iaas/tools/oci-cli/2.24.4/oci_cli_docs/cmdref/os/object/bulk-download.html)
    * @input
    * @output
    */

    if (params.TESToutputMODE){
       publishDir "${params.outdir}/kraken", pattern: "*_read_classification", mode: 'copy'
       publishDir "${params.outdir}/kraken", pattern: "*_summary.txt", mode: 'copy'
    }

    tag { prefix }

    input:
        tuple bucket, filePrefix, prefix

    output:
        tuple prefix, path("${prefix}.filt.fastq.gz"), emit: fqs
        tuple prefix, file("${prefix}_summary.txt"), path("${prefix}_read_classification"), emit: kraken


    script:
	db=params.krakdb
        """
	echo "debug message - bucket: ${bucket} prefix: ${prefix} fileprefix: ${filePrefix}"
	
	oci os object bulk-download \
		-bn $bucket \
		--download-dir ./ \
		--overwrite \
		--auth instance_principal \
		--prefix $filePrefix
		
	echo "Doing ls"
	
	ls ./
	
	echo "finished ls"
	
	kraken2 -db ${db} \
		--memory-mapping \
		--report ${prefix}_summary.txt \
		--output ${prefix}_read_classification \
        	${filePrefix}**.fastq.gz 

	echo "Doing ls"
	
	ls
	
	echo "finished ls"
	
        awk '\$3==\"9606\" { print \$2 }' ${prefix}_read_classification >> kraken2_human_read_list
        awk '\$3!=\"9606\" { print \$2 }' ${prefix}_read_classification >> kraken2_nonhuman_read_list

        seqs=${filePrefix}**.fastq.gz
        for seq in \${seqs}
        do
	    seqtk subseq \${seq} kraken2_nonhuman_read_list | gzip >> "${prefix}.filt.fastq.gz"
	done
	"""
}

process articMinIONViridian {
    /**
    * runs viridian workflow https://github.com/iqbal-lab-org/viridian_workflow
    * @input
    * @output
    */

    tag { prefix }

    publishDir "${params.outdir}/consensus_seqs/", mode: 'copy', pattern: "*.fasta"
    publishDir "${params.outdir}/VCF/", mode: 'copy', pattern: "*.vcf"
    publishDir "${params.outdir}/qc/", mode: 'copy', pattern: "*.json"
    if (params.TESToutputMODE){
	publishDir "${params.outdir}/bam/", mode: 'copy', pattern: "*.bam"
    }

    input:
        tuple prefix, path("${prefix}.fastq.gz"),path(schemeRepo),path('primers')

    output:
        tuple prefix, path("${prefix}.fasta"), emit: consensus
        tuple prefix, path("${prefix}.viridian_log.json"), emit: coverage
        tuple prefix, path("${prefix}.vcf"), emit: vcfs
	tuple prefix, path("${prefix}.bam"), emit: bam

    script:
        """
        viridian_workflow run_one_sample \
		--tech ont \
		--ref_fasta ${schemeRepo}/nCoV-2019/V3/nCoV-2019.reference.fasta \
		--amp_schemes_tsv primers \
		--reads ${prefix}.fastq.gz \
		--outdir ${prefix}_outdir/ \
		--sample_name ${prefix} \
		--keep_bam
        cp ${prefix}_outdir/consensus.fa ${prefix}.fasta
        cp ${prefix}_outdir/log.json ${prefix}.viridian_log.json
        cp ${prefix}_outdir/variants.vcf ${prefix}.vcf
	cp ${prefix}_outdir/reference_mapped.bam ${prefix}.bam
        """
}

