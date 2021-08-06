#!/bin/bash

# ont_artic_test

echo \
"SARS-CoV-2_reference_ox,mmm-artic-ill-s11511-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s12220-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s12368-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s16621-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s24350-3
SARS-CoV-2_reference_ox,mmm-artic-ill-s32219-2
SARS-CoV-2_reference_ox,mmm-artic-ill-s53667-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s59130-3
SARS-CoV-2_reference_ox,mmm-artic-ill-s64379-3
SARS-CoV-2_reference_ox,mmm-artic-ill-s71898-2
SARS-CoV-2_reference_ox,mmm-artic-ill-s82718-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s98244-3" \
	> /tmp/illumina_data.csv

echo \
"SARS-CoV-2_reference_ox,mmm-artic-ont-s11511-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s12220-4
SARS-CoV-2_reference_ox,mmm-artic-ont-s12368-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s16621-3
SARS-CoV-2_reference_ox,mmm-artic-ont-s24350-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s32219-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s53667-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s59130-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s64379-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s71898-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s82718-2
SARS-CoV-2_reference_ox,mmm-artic-ont-s98244-1" \
	> /tmp/ONT_data.csv

mkdir -p /work/runs/ont_artic_test
cd /work/runs/ont_artic_test
nextflow run \
        /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --prefix nanopore \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/ONT_data.csv \
        --varCaller medaka \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-nanopore \
        --run_uuid ffdd1e7f-2aaa-43a7-a230-f6b991bf4631 \
        --head_node_ip 10.0.1.2 \
        --outdir /work/output/ont_artic_test \
        > nextflow.txt

# ont_viridian_test

mkdir -p /work/runs/ont_viridian_test
cd /work/runs/ont_viridian_test
nextflow  run \
        /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --prefix nanopore \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/ONT_data.csv \
        --varCaller viridian \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-nanopore \
        --run_uuid b6a04e93-e031-4a80-9ece-0a279f9b1fe4 \
        --head_node_ip 10.0.1.2 \
        --outdir /work/output/ont_viridian_test_a03b0d59 \
        > nextflow.txt

# illumina_artic_test

mkdir -p /work/runs/illumina_artic_test
cd /work/runs/illumina_artic_test

nextflow run /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --readpat '*{1,2}.fastq.gz' \
        --illumina --prefix illumina \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/illumina_data.csv \
        --varCaller iVar \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-illumina \
        --run_uuid 19f03473-156a-4cec-a947-f7cfd1a03947 \
        --head_node_ip 10.0.1.2 \
        --outdir /work/output/illumina_artic_test \
        > nextflow.txt

# illumina_Viridian_test

mkdir -p /work/runs/illumina_viridian_test
cd /work/runs/illumina_viridian_test

nextflow run /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --readpat '*{1,2}.fastq.gz' \
        --illumina --prefix illumina \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/illumina_data.csv \
        --varCaller viridian \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-illumina \
        --run_uuid 387691ae-1f78-444d-a317-23443472b188 \
        --head_node_ip 10.0.1.2 \
        --outdir /work/output/illumina_viridian_test \
        > nextflow.txt

