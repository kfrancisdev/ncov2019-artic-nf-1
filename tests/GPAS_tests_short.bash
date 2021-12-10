#!/usr/bin/env bash


echo \
"SARS-CoV-2_reference_ox,mmm-artic-ill-s11511-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s12220-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s12368-1
SARS-CoV-2_reference_ox,mmm-artic-ill-s16621-1" \
	> /tmp/illumina_data_short.csv

echo \
"SARS-CoV-2_reference_ox,mmm-artic-ont-s11511-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s12220-4
SARS-CoV-2_reference_ox,mmm-artic-ont-s12368-1
SARS-CoV-2_reference_ox,mmm-artic-ont-s16621-3" \
	> /tmp/ONT_data_short.csv

# ont_artic_test
test_name=ont_artic_short
echo Running ${test_name} test workflow
mkdir -p /work/runs/${test_name}_test
cd /work/runs/${test_name}_test
nextflow run \
        /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --prefix nanopore \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/ONT_data_short.csv \
        --varCaller medaka \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-nanopore \
        --run_uuid ffdd1e7f-2aaa-43a7-a230-f6b991bf4631 \
        --head_node_ip 10.0.1.2 \
	--TESToutputMODE true \
        --outdir /work/output/${test_name}_test \
        > nextflow.txt

python3 /data/pipelines/ncov2019-artic-nf/tests/GPAS_tests_summary.py \
	-w /work/runs/${test_name}_test \
	-i /work/output/${test_name}_test/ \
	-t /work/output/${test_name}_test/${test_name}_summary.tsv  \
	-e /data/pipelines/ncov2019-artic-nf/tests/${test_name}_expected.tsv \
	-c /work/output/${test_name}_test/${test_name}_comparison.tsv

# ont_viridian_test
test_name=ont_viridian_short
echo Running ${test_name} test workflow
mkdir -p /work/runs/${test_name}_test
cd /work/runs/${test_name}_test

nextflow  run \
        /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --prefix nanopore \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/ONT_data_short.csv \
        --varCaller viridian \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-nanopore \
        --run_uuid b6a04e93-e031-4a80-9ece-0a279f9b1fe4 \
        --head_node_ip 10.0.1.2 \
	--TESToutputMODE true \
        --outdir /work/output/${test_name}_test \
        > nextflow.txt

python3 /data/pipelines/ncov2019-artic-nf/tests/GPAS_tests_summary.py \
	-w /work/runs/${test_name}_test \
	-i /work/output/${test_name}_test/ \
	-t /work/output/${test_name}_test/${test_name}_summary.tsv  \
	-e /data/pipelines/ncov2019-artic-nf/tests/${test_name}_expected.tsv \
	-c /work/output/${test_name}_test/${test_name}_comparison.tsv

# illumina_artic_test
test_name=illumina_artic_short
echo Running ${test_name} test workflow
mkdir -p /work/runs/${test_name}_test
cd /work/runs/${test_name}_test

nextflow run /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --readpat '*{1,2}.fastq.gz' \
        --illumina --prefix illumina \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/illumina_data_short.csv \
        --varCaller iVar \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-illumina \
        --run_uuid 19f03473-156a-4cec-a947-f7cfd1a03947 \
        --head_node_ip 10.0.1.2 \
	--TESToutputMODE true \
        --outdir /work/output/${test_name}_test \
        > nextflow.txt


python3 /data/pipelines/ncov2019-artic-nf/tests/GPAS_tests_summary.py \
	-w /work/runs/${test_name}_test \
	-i /work/output/${test_name}_test/ \
	-t /work/output/${test_name}_test/${test_name}_summary.tsv  \
	-e /data/pipelines/ncov2019-artic-nf/tests/${test_name}_expected.tsv \
	-c /work/output/${test_name}_test/${test_name}_comparison.tsv

# illumina_Viridian_test
test_name=illumina_viridian_short
echo Running ${test_name} test workflow
mkdir -p /work/runs/${test_name}_test
cd /work/runs/${test_name}_test


nextflow run /data/pipelines/ncov2019-artic-nf/main.nf \
        -with-trace -with-report -with-timeline -with-dag dag.png \
        --readpat '*{1,2}.fastq.gz' \
        --illumina --prefix illumina \
        -profile singularity \
        -process.executor slurm \
        --objstore /tmp/illumina_data_short.csv \
        --varCaller viridian \
        --refmap '"{}"' \
        --pipeline_name oxforduni-ncov2019-artic-nf-illumina \
        --run_uuid 387691ae-1f78-444d-a317-23443472b188 \
        --head_node_ip 10.0.1.2 \
	--TESToutputMODE true \
        --outdir /work/output/${test_name}_test \
        > nextflow.txt


python3 /data/pipelines/ncov2019-artic-nf/tests/GPAS_tests_summary.py \
	-w /work/runs/${test_name}_test \
	-i /work/output/${test_name}_test/ \
	-t /work/output/${test_name}_test/${test_name}_summary.tsv  \
	-e /data/pipelines/ncov2019-artic-nf/tests/${test_name}_expected.tsv \
	-c /work/output/${test_name}_test/${test_name}_comparison.tsv


