if(params.help) {
    log.info ""
    log.info "Run TP visualization workflow"
    log.info "-----------------------------"
    log.info ""
    exit 1
}


process qc_input {
    // Make sure the input protein matrix meets out QC expectations
    input:
    file spectronaut_phrt_mtx_nrml from file("${params.data_folder}/*_Normalized_Protein_Report.tsv")

    output:
    val true into qcInputOut
    
    """
    sed -i 's|,|.|g' $spectronaut_phrt_mtx_nrml
    python /usr/local/bin/tpviz_input_qc.py -i $spectronaut_phrt_mtx_nrml \
    -r $params.ref_start $params.ref_end \
    -s $params.smpl_start $params.smpl_end
    """
}

 
process preprocess {
    // Pre-process Spectronaut protein quant matrix
    publishDir 'Results/preprocess', mode: 'link'
    
    input:
    val flag from qcInputOut
    file spectronaut_phrt_mtx_nrml from file("${params.data_folder}/*_Normalized_Protein_Report.tsv")

    output:
    file '*_cleaned.tsv'
    file '*_preprocessed.tsv' into preprocessOut
    
    """
    sed -i 's|,|.|g' $spectronaut_phrt_mtx_nrml
    input_name=$spectronaut_phrt_mtx_nrml
    output_name=\${input_name%_Normalized_Protein_Report.tsv}
    python /usr/local/bin/preprocessor.py -i $spectronaut_phrt_mtx_nrml \
    -o \$output_name  \
    -r $params.ref_start $params.ref_end \
    -s $params.smpl_start $params.smpl_end \
    -g /usr/local/data/uniprotEntry2Gene
    """
}


// Duplicate preprocesOut channel
preprocessOut.into{ preprocessOut1 ; preprocessOut2 ; preprocessOut3 }


process preprocess_fmi {
    publishDir 'Results/preprocess', mode: 'link'

    input:
    file spectronaut_preprocess from preprocessOut1

    output:
    file '*_preprocessed_fmi.tsv' into preprocessFmiOut
    
    """
    python3 /usr/local/bin/preprocessor2fmi.py -i $spectronaut_preprocess
    """
}



process barPlot {
    // Generates barCharts and tables
    publishDir 'Results/Plots', mode: 'link'
    
    input:
    file prt_mtx from preprocessOut3

    output:
    file '*barplot*.pdf'
    
    """
    Rscript ${params.r_scripts_folder}/plot_bar.r $prt_mtx ${params.sample_type}
    """
}


process proteoFmi {
    // Generates proteomics FMI table
    publishDir 'Results/Plots', mode: 'link'
    
    input:
    file prt_mtx from preprocessFmiOut

    output:
    file '*.png'
    
    """
    plot_proteo_fmi_table.py -i $prt_mtx
    """
}

