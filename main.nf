if(params.help) {
    log.info ""
    log.info "Run TP visualization workflow"
    log.info "-----------------------------"
    log.info ""
    exit 1
}


process preprocess {
    // Pre-process Spectronaut protein quant matrix
    publishDir 'Results/preprocess'
    
    input:
    file spectronaut_prt_mtx_nrml from file("${params.data_folder}/*_Normalized_Protein_Report.tsv")

    output:
    file '*_preprocessor.tsv' into preprocessOut
    file '*_preprocessor_fmi.tsv' into preprocessFmiOut
    
    """
    FNAME=\$(basename $spectronaut_prt_mtx_nrml .tsv)
    Rscript ${params.r_scripts_folder}/preprocessor.r $spectronaut_prt_mtx_nrml
    grep -f /usr/local/data/fmi_gene_list.txt *_preprocessor.tsv > \${FNAME}_preprocessor_fmi.tsv
    """
}


// Duplicate preprocesOut channel so we can feed it to two processes
preprocesOut.into{ preprocesOut1 ; preprocesOut2 }


process wordCloud {
    // Generates GO wordCoulds and tables
    publishDir 'Results/Plots'
    
    input:
    file prt_mtx from preprocessOut1

    output:
    file '*_wordcloud.tsv'
    file '*_wordcloud.png'
    
    """
    Rscript ${params.r_scripts_folder}/plot_word_cloud.r $prt_mtx
    """
}


process barPlot {
    // Generates barCharts and tables
    publishDir 'Results/Plots'
    
    input:
    file prt_mtx from preprocessOut2

    output:
    file 'bar_plot*.tsv'
    file 'bar_plot*.png'
    
    """
    Rscript ${params.r_scripts_folder}/plot_bar.r $prt_mtx
    """
}


process proteoFmi {
    // Generates proteomics FMI table
    publishDir 'Results/Plots'
    
    input:
    file prt_mtx from preprocessFmiOut

    output:
    file '*.png'
    
    """
    plot_proteo_fmi_table.py -i $prt_mtx
    """
}

