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
    file spectronaut_pep_mtx_nrml from file("${params.data_folder}/*_Normalized_Peptides_Report.tsv")

    output:
    file '*_preprocessed.tsv' into preprocessOut
    
    """
    sed -i 's|,|.|g' $spectronaut_prt_mtx_nrml
    Rscript ${params.r_scripts_folder}/preprocessor.r
    """
}


// Duplicate preprocesOut channel
preprocessOut.into{ preprocessOut1 ; preprocessOut2 ; preprocessOut3 }


process preprocess_fmi {
    publishDir 'Results/preprocess'

    input:
    file spectronaut_preprocess from preprocessOut1

    output:
    file '*_preprocessed_fmi.tsv' into preprocessFmiOut
    
    """
    python3 /usr/local/bin/preprocessor2fmi.py -i $spectronaut_preprocess
    """
}



process wordCloud {
    // Generates GO wordCoulds and tables
    publishDir 'Results/Plots'
    
    input:
    file prt_mtx from preprocessOut2

    output:
    file 'go_*.tsv'
    file 'go_*.pdf'
    
    """
    Rscript ${params.r_scripts_folder}/plot_word_cloud.r $prt_mtx
    """
}


process barPlot {
    // Generates barCharts and tables
    publishDir 'Results/Plots'
    
    input:
    file prt_mtx from preprocessOut3

    output:
    file '*barplot*.pdf'
    
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

