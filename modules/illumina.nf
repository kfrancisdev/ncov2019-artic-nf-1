process readTrimming {
    /**
    * Trims paired fastq using trim_galore (https://github.com/FelixKrueger/TrimGalore)
    * @input tuple(sampleName, path(forward), path(reverse))
    * @output trimgalore_out tuple(sampleName, path("*_val_1.fq.gz"), path("*_val_2.fq.gz"))
    */

    tag { sampleName }

    if (params.TESToutputMODE){
       publishDir "${params.outdir}/trimmed_fq/", pattern: '*_val_{1,2}.fq.gz', mode: 'copy'
    }
    cpus 2

    input:
    tuple(sampleName, path(forward), path(reverse))

    output:
    tuple(sampleName, path("*_val_1.fq.gz"), path("*_val_2.fq.gz")) optional true

    script:
    """
    if [[ \$(gunzip -c ${forward} | head -n4 | wc -l) -eq 0 ]]; then
      exit 0
    else
      trim_galore --paired $forward $reverse
    fi
    """
}

process indexReference {
    /**
    * Indexes reference fasta file in the scheme repo using bwa.
    */

    tag { ref }

    input:
        path(ref)

    output:
        tuple path('ref.fa'), path('ref.fa.*')

    script:
        """
        ln -s ${ref} ref.fa
        bwa index ref.fa
        """
}

process readMapping {
    /**
    * Maps trimmed paired fastq using BWA (http://bio-bwa.sourceforge.net/)
    * Uses samtools to convert to BAM, sort and index sorted BAM (http://www.htslib.org/doc/samtools.html)
    * @input 
    * @output 
    */

    tag { sampleName }

    label 'largecpu'

    input:
        tuple sampleName, path(forward), path(reverse), path(ref), path("*")

    output:
        tuple(sampleName, path("${sampleName}.sorted.bam"))

    script:
      """
      bwa mem -t ${task.cpus} ${ref} ${forward} ${reverse} | \
      samtools sort -o ${sampleName}.sorted.bam
      """
}

process trimPrimerSequences {

    tag { sampleName }

    if (params.TESToutputMODE){
       publishDir "${params.outdir}/bam", pattern: "*.bam", mode: 'copy'
    }

    input:
    tuple sampleName, path(bam), path(bedfile)

    output:
    tuple sampleName, path("${sampleName}.mapped.bam"), emit: mapped
    tuple sampleName, path("${sampleName}.mapped.primertrimmed.sorted.bam" ), emit: ptrim

    script:
    if (params.allowNoprimer){
        ivarCmd = "ivar trim -e"
    } else {
        ivarCmd = "ivar trim"
    }
   
    if ( params.cleanBamHeader )
        """
        samtools reheader --no-PG  -c 'sed "s/${sampleName}/sample/g"' ${bam} | \
        samtools view -F4 -o sample.mapped.bam

        mv sample.mapped.bam ${sampleName}.mapped.bam
        
        samtools index ${sampleName}.mapped.bam

        ${ivarCmd} -i ${sampleName}.mapped.bam -b ${bedfile} -m ${params.illuminaKeepLen} -q ${params.illuminaQualThreshold} -p ivar.out

        samtools reheader --no-PG  -c 'sed "s/${sampleName}/sample/g"' ivar.out.bam | \
        samtools sort -o sample.mapped.primertrimmed.sorted.bam

        mv sample.mapped.primertrimmed.sorted.bam ${sampleName}.mapped.primertrimmed.sorted.bam
        """

    else
        """
        samtools view -F4 -o ${sampleName}.mapped.bam ${bam}
        samtools index ${sampleName}.mapped.bam
        ${ivarCmd} -i ${sampleName}.mapped.bam -b ${bedfile} -m ${params.illuminaKeepLen} -q ${params.illuminaQualThreshold} -p ivar.out
        samtools sort -o ${sampleName}.mapped.primertrimmed.sorted.bam ivar.out.bam
        """
}

process callVariants {

    tag { sampleName }

    publishDir "${params.outdir}/${task.process.replaceAll(":","_")}", pattern: "${sampleName}.variants.vcf", mode: 'copy'

    input:
    tuple(sampleName, path(bam), path(ref))

    output:
    tuple sampleName, path("${sampleName}.variants.vcf"), emit: variants

    script:
        """
        samtools mpileup -A -d 0 --reference ${ref} -B -Q 0 ${bam} |\
        ivar variants -r ${ref} -m ${params.ivarMinDepth} -p ${sampleName}.variants -q ${params.ivarMinVariantQuality} -t ${params.ivarMinFreqThreshold}
	ivar_variants_to_vcf.py ${sampleName}.variants.tsv ${sampleName}.variants.vcf
        """
}

process makeConsensus {

    tag { sampleName }

    publishDir "${params.outdir}/consensus_seqs/", mode: 'copy'

    input:
        tuple(sampleName, path(bam))

    output:
        tuple(sampleName, path("${sampleName}.fasta"))

    script:
        """
        samtools mpileup -aa -A -B -d ${params.mpileupDepth} -Q0 ${bam} | \
        ivar consensus -t ${params.ivarFreqThreshold} -m ${params.ivarMinDepth} \
        -n N -p ${sampleName}.primertrimmed.consensus
        cp ${sampleName}.primertrimmed.consensus.fa ${sampleName}.fasta
        """
}

process cramToFastq {
    /**
    * Converts CRAM to fastq (http://bio-bwa.sourceforge.net/)
    * Uses samtools to convert to CRAM, to FastQ (http://www.htslib.org/doc/samtools.html)
    * @input
    * @output
    */

    input:
        tuple sampleName, file(cram)

    output:
        tuple sampleName, path("${sampleName}_1.fastq.gz"), path("${sampleName}_2.fastq.gz")

    script:
        """
        samtools collate -u ${cram} -o tmp.bam
        samtools fastq -1 ${sampleName}_1.fastq.gz -2 ${sampleName}_2.fastq.gz tmp.bam
        rm tmp.bam
        """
}

process getObjFiles {
    /**
    * fetches fastq files from object store using OCI bulk download (https://docs.oracle.com/en-us/iaas/tools/oci-cli/2.24.4/oci_cli_docs/cmdref/os/object/bulk-download.html)
    * @input
    * @output
    */

    tag { prefix }

    
    if (params.TESToutputMODE){
       publishDir "${params.outdir}/kraken", pattern: "*_read_classification", mode: 'copy'
       publishDir "${params.outdir}/kraken", pattern: "*_summary.txt", mode: 'copy'
    }


    input:
        tuple bucket, filePrefix, prefix

    output:
        tuple prefix, path("${prefix}_C1.filt.fastq.gz"), path("${prefix}_C2.filt.fastq.gz"), emit: fqs
        tuple prefix, file("${prefix}_summary.txt"), path("${prefix}_read_classification"), emit: kraken

    script:
	db=params.krakdb
        """
	oci os object bulk-download \
		-bn $bucket \
		--download-dir ./ \
		--overwrite \
		--auth instance_principal \
		--prefix $filePrefix

	kraken2 --paired -db ${db} \
		--memory-mapping \
		--report ${prefix}_summary.txt \
		--output ${prefix}_read_classification \
        	${filePrefix}*1.fastq.gz ${filePrefix}*2.fastq.gz

        awk '\$3==\"9606\" { print \$2 }' ${prefix}_read_classification >> kraken2_human_read_list
        awk '\$3!=\"9606\" { print \$2 }' ${prefix}_read_classification >> kraken2_nonhuman_read_list

	seqtk subseq ${filePrefix}*1.fastq.gz kraken2_nonhuman_read_list | gzip > "${prefix}_C1.filt.fastq.gz"
	seqtk subseq ${filePrefix}*2.fastq.gz kraken2_nonhuman_read_list | gzip > "${prefix}_C2.filt.fastq.gz"
	"""
}

process viridian {
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
        tuple prefix, path("${prefix}_1.fastq.gz"), path("${prefix}_2.fastq.gz"),path('primers'), path('ref.fa'),path("*") 

    output:
        tuple prefix, path("${prefix}.fasta"), emit: consensus
        tuple prefix, path("${prefix}.viridian_log.json"), emit: coverage
        tuple prefix, path("${prefix}.vcf"), emit: vcfs
        tuple prefix, path("${prefix}.bam"), emit: bam 


    script:
    if (params.primers != 'auto') 
        """
	viridian_workflow run_one_sample \
                --tech illumina \
                --ref_fasta ref.fa \
                --amp_schemes_tsv \
                --reads1 ${prefix}_1.fastq.gz \
                --reads2 ${prefix}_2.fastq.gz \
                --outdir ${prefix}_outdir/ \
                --sample_name ${prefix} \
                --keep_bam
        cp ${prefix}_outdir/consensus.fa ${prefix}.fasta
        cp ${prefix}_outdir/log.json ${prefix}.viridian_log.json
        cp ${prefix}_outdir/variants.vcf ${prefix}.vcf
        cp ${prefix}_outdir/reference_mapped.bam ${prefix}.bam
        """
    else if (params.primers == 'auto') 
        """
	viridian_workflow run_one_sample \
                --tech illumina \
                --ref_fasta ref.fa \
                --reads1 ${prefix}_1.fastq.gz \
                --reads2 ${prefix}_2.fastq.gz \
                --outdir ${prefix}_outdir/ \
                --sample_name ${prefix} \
                --keep_bam
        cp ${prefix}_outdir/consensus.fa ${prefix}.fasta
        cp ${prefix}_outdir/log.json ${prefix}.viridian_log.json
        cp ${prefix}_outdir/variants.vcf ${prefix}.vcf
        cp ${prefix}_outdir/reference_mapped.bam ${prefix}.bam
        """
}
