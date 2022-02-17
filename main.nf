#!/usr/bin/env nextflow
pipeline_version = 2.5
log.info """
This is the eTRANSAFE preclinical text mining pipeline execution, PRETOX .  
The  pretox base directory to use: ${params.baseDir}, This directory is used as a work directory of the pipeline, the output to each component of the pipeline will appear in this directory.
The input directory that contains the documents to process is located at ${params.inputDir}.
The output will be located at ${params.baseDir}.
Pipeline execution name: ${workflow.runName}
Pipeline version: ${pipeline_version}
"""
.stripIndent()


params.general = [
    //paramsout:          "${params.baseDir}/execution-results/params_${workflow.runName}.json",
    //resultout:          "${params.baseDir}/execution-results/results_${workflow.runName}.txt",
    baseDir:            "${params.baseDir}",
    inputDir:           "${params.inputDir}"
]

params.database = [
    db_uri:             "${params.db_uri}", 
    db_name:            "${params.db_name}"
]

log.info """
The text-mining execution results will be stored in the provided database:
Database Url:  masked ... please review your run.sh file 
Database name: $params.database.db_name
"""
.stripIndent()

steps = [:]

pipeline_log = "$params.general.baseDir/pipeline.log"


params.folders = [
	//Output directory for the linnaeus tagger step
	nlp_standard_preprocessing_output_folder: "${params.baseDir}/nlp_standard_preprocessing_output",
	//Output directory for the sentence classification step
        sentence_classification_output_folder: "${params.baseDir}/sentence_classification_output",
	//Output directory for the linnaeus tagger step
	linnaeus_output_folder: "${params.baseDir}/linnaeus_output",
	//Output directory for the dnorm tagger step
	dnorm_output_folder: "${params.baseDir}/dnorm_output",
	//Output directory for the umls tagger step
	umls_output_folder: "${params.baseDir}/pretox_umls_output",
	//Output directory for the umls tagger step
	pretox_terminology_annotator_folder: "${params.baseDir}/prextox_annotator_output",
	//Output directory for the sr domain conversion
	ades_export_to_json_output_folder: "${params.baseDir}/pretox_export_to_json_output"
]


basedir_input_ch = Channel.fromPath(params.general.inputDir, type: 'dir' )

nlp_standard_preprocessing_output_folder=file(params.folders.nlp_standard_preprocessing_output_folder)
sentence_classification_output_folder=file(params.folders.sentence_classification_output_folder)
linnaeus_output_folder=file(params.folders.linnaeus_output_folder)
dnorm_output_folder=file(params.folders.dnorm_output_folder)
umls_output_folder=file(params.folders.umls_output_folder)
pretox_terminology_annotator_output_folder=file(params.folders.pretox_terminology_annotator_folder)
ades_export_to_json_output_folder=file(params.folders.ades_export_to_json_output_folder)
//ner_evaluation_output=file(params.general.resultout)

myDir = file(params.general.baseDir)
result = myDir.mkdir()

void printSection(section, level = 1){
    println (("  " * level) + "↳ " + section.key)
    if (section.value.class == null)
    {
      for (element in section.value)
        {
           printSection(element, level + 1)
        }
    }
    else {
    	if (section.key == "db_uri"){
        	println (("  " * (level + 1) ) + "↳ masked ... please review your run.sh file " )
        }else{
        	if (section.value == "")
            	println (("  " * (level + 1) ) + "↳ Empty String")
        	else
            	println (("  " * (level + 1) ) + "↳ " + section.value)
        }    
    }
}

void PrintConfiguration(){
    println ""
    println "=" * 34
    println "PRETOX text-mining pipeline Configuration"
    println "=" * 34
    for (configSection in params) {
          //println (configSection.getClass())     
          if(configSection.key=="general" || configSection.key=="database" || configSection.key=="folders"){

            printSection(configSection)
            println "=" * 30
          }
       
    }

    println "\n"
}

String parseElement(element){
    if (element instanceof String || element instanceof GString ) 
        return "\"" + element + "\""    

    if (element instanceof Integer)
        return element.toString()

    if (element.value.class == null)
    {
        StringBuilder toReturn = new StringBuilder()
        toReturn.append()
        toReturn.append("\"")
        toReturn.append(element.key)
        toReturn.append("\": {")

        for (child in element.value)
        {
            toReturn.append(parseElement(child))
            toReturn.append(',')
        }
        toReturn.delete(toReturn.size() - 1, toReturn.size() )
        
        toReturn.append('}')
        return toReturn.toString()
    } 
    else 
    {
        if (element.value instanceof String || element.value instanceof GString ) 
            return "\"" + element.key + "\": \"" + element.value +ner_evaluation_output +"\""            

        else if (element.value instanceof ArrayList)
        {
            // println "\tis a list"
            StringBuilder toReturn = new StringBuilder()
            toReturn.append("\"")
            toReturn.append(element.key)
            toReturn.append("\": [")
            for (child in element.value)
            {gate_to_json
                toReturn.append(parseElement(child)) 
                toReturn.append(",")                
            }
            toReturn.delete(toReturn.size() - 1, toReturn.size() )
            toReturn.append("]")
            return toReturn.toString()
        }

        return "\"" + element.key + "\": " + element.value
    }
}

def SaveParamsToFile() {
    // Check if we want to produce the params-file for this execution
    if (params.paramsout == "")
        return;

    // Replace the strings ${baseDir} and ${workflow.runName} with their values
    //params.general.paramsout = params.general.paramsout
    //    .replace("\${baseDir}".toString(), baseDir.toString())
    //    .replace("\${workflow.runName}".toString(), workflow.runName.toString())

    // Store the provided paramsout value in usedparamsout
    params.general.usedparamsout = params.general.paramsout

    // Compare if provided paramsout is the default value
    if ( params.general.paramsout == "${baseDir}/param-files/${workflow.runName}.json"){
        // And store the default value in paramsout
        params.general.paramsout = "\${baseDir}/param-files/\${workflow.runName}.json"
    }

    // Inform the user we are going to store the params-file and how to use it.
    println "[Config Wrapper] Saving current parameters to " + params.general.usedparamsout + "\n" +
            "                 This file can be used to input parameters providing \n" + 
            "                   '-params-file \"" + params.general.usedparamsout + "\"'\n" + 
            "                   to nextflow when running the workflow."


    // Manual JSONification of the params, to avoid using libraries.
    StringBuilder content = new StringBuilder();
    // Start the dictionary
    content.append("{")

    // As parseElement only accepts key-values or dictionaries,
    //      we iterate here for each 'big-category'
    for (element in params) 
    {
        // We parse the element
        content.append(parseElement(element))
        // And add a comma to separate elements of the list
        content.append(",")
    }

    // Remove the last comma
    content.delete(content.size() - 1, content.size() )
    // And add the final bracket
    content.append("}")

    // Create a file handler for the current usedparamsout
    configJSON = file(params.general.usedparamsout)
    // Make all the dirs of usedparamsout path
    configJSON.getParent().mkdirs()
    // Write the contents to file
    configJSON.write(content.toString())
}


//Execution Begin
PrintConfiguration()
//SaveParamsToFile()

//Workflow component Begins


process nlp_standard_preprocessing {
    input:
    file input_nlp_standard_preprocessing from basedir_input_ch
    
    output:
    val nlp_standard_preprocessing_output_folder into nlp_standard_preprocessing_output_folder_ch
    
    script:
    
    """
    exec >> $pipeline_log
    echo "********************************************************************************************************************** "
    echo `date`
    echo "Start Pipeline Execution, Pipeline Version $pipeline_version, workflow name: ${workflow.runName}"
    echo "Start nlp-standard-preprocessing"
    nlp-standard-preprocessing -i $input_nlp_standard_preprocessing -o $nlp_standard_preprocessing_output_folder -a BSC -t 8 -f true
	echo "End nlp-standard-preprocessing"
    """
}

process pretox_sentence_classifier {
    input:
    file input_sentence_classification from nlp_standard_preprocessing_output_folder_ch

    output:
    val sentence_classification_output_folder into sentence_classification_output_folder_ch

    script:

    """
    exec >> $pipeline_log
    echo "********************************************************************************************************************** "
    echo `date`
    echo "Start pretox_sentence_classifier"
    stanford-classifier -i $input_sentence_classification -o $sentence_classification_output_folder -a BSC 
    echo "End pretox_sentence_classifier"
    """
}

process linnaeus_wrapper {
    input:
    file input_linnaeus from sentence_classification_output_folder_ch
    
    output:
    val linnaeus_output_folder into linnaeus_output_folder_ch
    """
    exec >> $pipeline_log
    echo "Start linnaeus-gate-wrapper"
    linnaeus-gate-wrapper -i $input_linnaeus -o $linnaeus_output_folder -a BSC
    echo "End linnaeus-gate-wrapper"
    """
}

process dnorm_wrapper {
    input:
    file input_dnorm from linnaeus_output_folder_ch
    
    output:
    val dnorm_output_folder into dnorm_output_folder_ch
    
    """
    exec >> $pipeline_log
    echo "Start dnorm-gate-wrapper"
    dnorm-gate-wrapper -i $input_dnorm -o $dnorm_output_folder -a BSC
    echo "End dnorm-gate-wrapper"
    """
}

process pretox_umls_annotator {
    input:
    file input_umls from dnorm_output_folder_ch
   
    output:
    val umls_output_folder into umls_output_folder_ch
    
    """
    exec >> $pipeline_log
    echo "Start pretox-umls-annotator"
    pretox-umls-annotator -i $input_umls -o $umls_output_folder -a BSC -gt flexible -t 1
    echo "End pretox-umls-annotator"
    """
}

process pretox_treatment_related_finding_annotation {
    input:
    file input_pretox_terminology_annotator from umls_output_folder_ch
    
    output:
    val pretox_terminology_annotator_output_folder into own_ades_terms_output_folder_ch
    """
    exec >> $pipeline_log
    echo "Start pretox_terminology_annotator"
    pretox-terminology-annotation -i $input_pretox_terminology_annotator -o $pretox_terminology_annotator_output_folder -a BSC -gt flexible -t 1
    echo "End pretox_terminology_annotator"
    """
}

process sr_domain_field_identification {
    input:
    file input_ades_to_json from own_ades_terms_output_folder_ch
    
    output:
    val ades_export_to_json_output_folder into ades_export_to_json_output_ch
	
    """
    exec >> $pipeline_log
    echo "Start sr_domain_field_identification"
    pretox-sr-domain-identification -i $input_ades_to_json -o $ades_export_to_json_output_folder -a BSC -ar FINDINGS
    echo "End sr_domain_field_identification"
    """
}

process import_json_to_mongo {
    input:
    file input_import_json_to_mongo from ades_export_to_json_output_ch
    """
    exec >> $pipeline_log
    echo "Start import_json_to_mongo"
    import-json-to-mongo -i $input_import_json_to_mongo -c "$params.database.db_uri" -d $params.database.db_name
    echo "End import_json_to_mongo"
    """
}

//process evaluation_ner {
//    input:
//    file input_ner_evaluation from ades_post_output_folder_ch
    
//    output:
//    val ner_evaluation_output into ner_validation_output_ch

//    """
//    evaluation-ner -i $input_ner_evaluation -oades_export_to_json_output_folder $ner_evaluation_output -k EVALUATION -e BSC
	
//    """
//}

workflow.onComplete {
        println ("Workflow Done !!! ")
        """
        exec >> $pipeline_log
        echo "End Pipeline Execution, Pipeline Version $pipeline_version, workflow name ${workflow.runName}"
        echo "********************************************************************************************************************** "
        """
}
