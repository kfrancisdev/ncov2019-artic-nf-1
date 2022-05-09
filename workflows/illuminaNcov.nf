#!/usr/bin/env nextflow

// enable dsl2
nextflow.enable.dsl=1

// import modules
include {articDownloadScheme } from '../modules/artic.nf' 
include {readTrimming} from '../modules/illumina.nf' 
include {indexReference} from '../modules/illumina.nf'
include {readMapping} from '../modules/illumina.nf' 
include {trimPrimerSequences} from '../modules/illumina.nf' 
include {callVariants} from '../modules/illumina.nf'
include {makeConsensus} from '../modules/illumina.nf' 
include {cramToFastq} from '../modules/illumina.nf'
include {getObjFiles} from '../modules/illumina.nf'
include {viridianPrimers} from '../modules/viridian.nf'
include {viridianAuto} from '../modules/viridian.nf'
include {download_primers} from '../modules/analysis.nf'

include {makeQCCSV} from '../modules/qc.nf'
include {writeQCSummaryCSV} from '../modules/qc.nf'

include {bamToCram} from '../modules/out.nf'

include {collateSamples} from '../modules/upload.nf'

include {pango} from '../modules/analysis.nf'
include {nextclade} from '../modules/analysis.nf'
include {getVariantDefinitions} from '../modules/analysis.nf'
include {aln2type} from '../modules/analysis.nf'
include {makeReport} from '../modules/analysis.nf'

include {uploadToBucket} from '../modules/upload.nf'

// import subworkflows
include {CLIMBrsync} from './upload.nf'
include {Genotyping} from './typing.nf'
include {downstreamAnalysis} from './analysis.nf'

workflow prepareReferenceFiles {
    // Get reference fasta
    if (params.ref) {
      Channel.fromPath(params.ref)
              .set{ ch_refFasta }
    } else {
      articDownloadScheme()
      articDownloadScheme.out.reffasta
                          .set{ ch_refFasta }
    }


    /* Either get BWA aux files from reference 
       location or make them fresh */
    
    if (params.ref) {
      // Check if all BWA aux files exist, if not, make them
      bwaAuxFiles = []
      refPath = new File(params.ref).getAbsolutePath()
      new File(refPath).getParentFile().eachFileMatch( ~/.*.bwt|.*.pac|.*.ann|.*.amb|.*.sa/) { bwaAuxFiles << it }
     
      if ( bwaAuxFiles.size() == 5 ) {
        Channel.fromPath( bwaAuxFiles )
               .set{ ch_bwaAuxFiles }

        ch_refFasta.combine(ch_bwaAuxFiles.collect().toList())
                   .set{ ch_preparedRef }
      } else {
        indexReference(ch_refFasta)
        indexReference.out
                      .set{ ch_preparedRef }
      }
    } else {
      indexReference(ch_refFasta)
      indexReference.out
                    .set{ ch_preparedRef }
    }
  
    /* If bedfile is supplied, use that,
       if not, get it from ARTIC github repo */ 
 
    if (params.bed ) {
      Channel.fromPath(params.bed)
             .set{ ch_bedFile }

    } else {
      articDownloadScheme.out.bed
                         .set{ ch_bedFile }
    }

    emit:
      bwaindex = ch_preparedRef
      bedfile = ch_bedFile
      reffasta = ch_refFasta
}


workflow sequenceAnalysis {
    take:
      ch_filePairs
      ch_preparedRef
      ch_bedFile
      ch_refFasta

    main:

      readTrimming(ch_filePairs)

      readMapping(readTrimming.out.combine(ch_preparedRef))

      trimPrimerSequences(readMapping.out.combine(ch_bedFile))

      callVariants(trimPrimerSequences.out.ptrim.combine(ch_preparedRef.map{ it[0] })) 

      makeConsensus(trimPrimerSequences.out.ptrim)

      makeQCCSV(trimPrimerSequences.out.ptrim.join(makeConsensus.out, by: 0)
                                   .combine(ch_preparedRef.map{ it[0] }))

      makeQCCSV.out.csv.splitCsv()
                       .unique()
                       .branch {
                           header: it[-1] == 'qc_pass'
                           fail: it[-1] == 'FALSE'
                           pass: it[-1] == 'TRUE'
    		       }
                       .set { qc }

      writeQCSummaryCSV(qc.header.concat(qc.pass).concat(qc.fail).toList())

      collateSamples(qc.pass.map{ it[0] }
                           .join(makeConsensus.out, by: 0)
                           .join(trimPrimerSequences.out.mapped))
      

      downstreamAnalysis(makeConsensus.out, callVariants.out.variants, ch_refFasta, ch_bedFile)
      
      if (params.outCram) {
        bamToCram(trimPrimerSequences.out.mapped.map{it[0] } 
                        .join (trimPrimerSequences.out.ptrim.combine(ch_preparedRef.map{ it[0] })) )

      }
      emit:
      consensus = makeConsensus.out
      qc_pass = collateSamples.out
      variants = callVariants.out.variants
}

workflow sequenceAnalysisViridian {
    take:
      ch_filePairs
      ch_preparedRef
      ch_bedFile
      ch_refFasta

    main:

      if (params.primers != 'auto') {

        download_primers(params.primers)
      	viridianPrimers(ch_filePairs.combine(download_primers.out).combine(ch_preparedRef))
        viridian=viridianPrimers
      }
      else if (params.primers == 'auto') {
      	viridianAuto(ch_filePairs.combine(ch_preparedRef))
        viridian=viridianAuto
      }

     downstreamAnalysis(viridian.out.consensus, viridian.out.vcfs, ch_refFasta, ch_bedFile)

     if (params.uploadBucket != false) {
         uploadToBucket(viridian.out.consensus.combine(viridian.out.bam, by:0)
				.combine(viridian.out.vcfs, by:0))
     }
  
}

workflow ncovIllumina {
    take:
      ch_filePairs

    main:
      // Build or download fasta, index and bedfile as required
      prepareReferenceFiles()
      
      // Actually do analysis
      if (params.varCaller=='iVar') {
      sequenceAnalysis(ch_filePairs, prepareReferenceFiles.out.bwaindex, prepareReferenceFiles.out.bedfile, prepareReferenceFiles.out.reffasta)
      }
      else if (params.varCaller=='viridian') {
      sequenceAnalysisViridian(ch_filePairs, prepareReferenceFiles.out.bwaindex, prepareReferenceFiles.out.bedfile, prepareReferenceFiles.out.reffasta)
      }
      // Do some typing if we have the correct files
      if ( params.gff ) {
          Channel.fromPath("${params.gff}")
                 .set{ ch_refGff }

          Channel.fromPath("${params.yaml}")
                 .set{ ch_typingYaml }

          Genotyping(sequenceAnalysis.out.variants, ch_refGff, prepareReferenceFiles.out.reffasta, ch_typingYaml) 

      }
 
      // Upload files to CLIMB
      if ( params.upload ) {
        
        Channel.fromPath("${params.CLIMBkey}")
               .set{ ch_CLIMBkey }
      
        CLIMBrsync(sequenceAnalysis.out.qc_pass, ch_CLIMBkey )
      }

}

workflow ncovIlluminaCram {
    take:
      ch_cramFiles
    main:
      // Convert CRAM to fastq
      cramToFastq(ch_cramFiles)

      // Run standard pipeline
      ncovIllumina(cramToFastq.out)
}

workflow ncovIlluminaObj {
    take:
      ch_objFiles
    main:
      // get fastq files from objstore
      getObjFiles(ch_objFiles)

      // Run standard pipeline
      ncovIllumina(getObjFiles.out.fqs)

}
