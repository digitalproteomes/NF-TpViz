if(params.help) {
    log.info ""
    log.info "Run TP visualization workflow"
    log.info "-----------------------------"
    log.info ""
    exit 1
}


process qcInput {
    // Make sure the input protein matrix meets out QC expectations
    input:
    file spectronaut_phrt_mtx_nrml from file("${params.data_folder}/*_Normalized_Protein_Report.tsv")

    output:
    val true into qcInputOut
    
    """
    sed -i 's|,|.|g' $spectronaut_phrt_mtx_nrml
    sed -i 's|Filtered|NaN|g' $spectronaut_phrt_mtx_nrml
    python /usr/local/bin/tpviz_input_qc.py -i $spectronaut_phrt_mtx_nrml \
    -r $params.ref_start $params.ref_end \
    -s $params.smpl_start $params.smpl_end
    """
}


qcInputOut.into{ qcInputOut1; qcInputOut2 }
 
process preprocess {
    // Pre-process Spectronaut protein quant matrix
    publishDir 'Results/preprocess', mode: 'link'
    
    input:
    val flag from qcInputOut1
    file spectronaut_phrt_mtx_nrml from file("${params.data_folder}/*_Normalized_Protein_Report.tsv")
    file spectronaut_phrt_mtx_peptide from file("${params.data_folder}/*_Normalized_Peptides_Report.tsv")

    output:
    file '*_cleaned.tsv' into preprocessedCleanedOut
    file '*_preprocessed.tsv' into preprocessOut
    
    """
    sed -i 's|,|.|g' $spectronaut_phrt_mtx_nrml
    sed -i 's|Filtered|NaN|g' $spectronaut_phrt_mtx_nrml
    input_name=$spectronaut_phrt_mtx_nrml
    output_name=\${input_name%_Normalized_Protein_Report.tsv}
    python /usr/local/bin/preprocessor.py -i $spectronaut_phrt_mtx_nrml \
    -o \$output_name  \
    -p $spectronaut_phrt_mtx_peptide \
    -r $params.ref_start $params.ref_end \
    -s $params.smpl_start $params.smpl_end \
    -g /usr/local/data/uniprotEntry2Gene
    """
}


// Duplicate preprocesOut channel
preprocessOut.into{ preprocessOut1 ; preprocessOut2 ; preprocessOut3 }


process preprocessFmi {
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


process plotBoxPlot {
    // Boxplots for DIA data
    publishDir 'Results/preprocess', mode: 'link', pattern: '*.tsv'
    publishDir 'Results/Plots', mode: 'link', pattern: '*.pdf'
    
    input:
    val flag from qcInputOut2
    file spectronaut_phrt_mtx_cleaned from preprocessedCleanedOut

    output:
    file '*.tsv'
    file '*.pdf'

    script:
    if( params.sample_type == 'Melanoma' )
    	"""
        input_name=$spectronaut_phrt_mtx_cleaned
        output_name=\${input_name%_cleaned.tsv}
        python /usr/local/bin/plot_dia_boxplot.py -i $spectronaut_phrt_mtx_cleaned \
        -o \$output_name  \
        -r $params.ref_start $params.ref_end \
        -s $params.smpl_start $params.smpl_end \
        -m /usr/local/data/Melanoma_marker_Anja_IDs.csv
        """
    else if( params.sample_type == 'OVCA' )
    	"""
        input_name=$spectronaut_phrt_mtx_cleaned
        output_name=\${input_name%_cleaned.tsv}
        python /usr/local/bin/plot_dia_boxplot.py -i $spectronaut_phrt_mtx_cleaned \
        -o \$output_name  \
        -r $params.ref_start $params.ref_end \
        -s $params.smpl_start $params.smpl_end \
        -m /usr/local/data/OVCA_marker_pre-selection_sgo.csv
        """
    else
	error "Unsupported sample_type!"
}
