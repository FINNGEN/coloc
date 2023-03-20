process tabix_by_chr_position{
    container 'quay.io/eqtlcatalogue/colocalisation:latest'

    input:
    tuple val(dataset_id), file(sumstats), file(sumstats_index), file(permuted), file(credible_sets), file(lbf)

    output:
    tuple val(dataset_id), file("sorted_${lbf.simpleName}.txt.gz"), file("sorted_${lbf.simpleName}.txt.gz.tbi")
    
    script:
    """
    zcat ${lbf} | awk -F'\t' 'BEGIN{OFS=FS}NR==1{print \$0; next}{print \$0 | "sort -k4,4n -k5,5n"}' | bgzip > sorted_${lbf.simpleName}.txt.gz
    tabix -s4 -b5 -e5 -S1 -f sorted_${lbf.simpleName}.txt.gz
    """
}

process run_coloc_v5{
    container = 'quay.io/eqtlcatalogue/susier:v21.08.1'

    input:
    tuple val(chr), val(batch), val(eqtl_dataset_id), file(reference_file), file(eqtl_file), file(eqtl_index), val(pqtl_dataset_id), file(pqtl_file), file(pqtl_index)

    output:
    tuple val(eqtl_dataset_id), val("${eqtl_dataset_id}_${pqtl_dataset_id}"), file("${eqtl_dataset_id}_${pqtl_dataset_id}_${chr}_${batch}_${params.chr_batches}.coloc.v5.tsv")

    script:
    """
    Rscript $baseDir/bin/coloc_v5_pqtl.R \\
        --eqtl_file=$eqtl_file \\
        --pqtl_file=$pqtl_file \\
        --reference=$reference_file \\
        --chromosome=${chr} \\
        --chunk='${batch} ${params.chr_batches}' \\
        --output_prefix=${eqtl_dataset_id}_${pqtl_dataset_id}_${chr}_${batch}_${params.chr_batches}.coloc.v5.tsv \\
        --outdir=.
    """
}

process merge_coloc_v5_results{
    publishDir "${params.outdir}/coloc_v5_results_merged/${qtl_subset}", mode: 'copy'
    container 'quay.io/eqtlcatalogue/colocalisation:latest'

    input:
    tuple val(qtl_subset), val(pqtl_qtl_id), file(pqtl_qtl_coloc_results_batch_files)

    output:
    tuple val(pqtl_qtl_id), file("${pqtl_qtl_id}.coloc.v5.txt.gz")

    script:
    """
    awk 'NR == 1 || FNR > 1{print}' ${pqtl_qtl_coloc_results_batch_files.join(' ')} | awk -F'\t' 'BEGIN{OFS=FS}NR==1{print \$0; next}{print \$0 | "sort -k10,10gr"}' | bgzip -c > ${pqtl_qtl_id}.coloc.v5.txt.gz
    """
}