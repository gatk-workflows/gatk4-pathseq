###############################################################
##
## PathSeq Microbe Reference Build WDL
##
###############################################################
##
## Builds a microbe reference for use with PathSeq
##
## For further info see the GATK Documentation for the PathSeqPipelineSpark tool:
##   https://software.broadinstitute.org/gatk/documentation/tooldocs/current/org_broadinstitute_hellbender_tools_spark_pathseq_PathSeqPipelineSpark.php
##
###############################################################
##
## Input requirements :
## - FASTA file containing microbe sequences from NCBI RefSeq
##
## Output:
## - FASTA index and dictionary files
## - GATK BWA-MEM index image
## - PathSeq taxonomy file
##
###############################################################

# WORKFLOW DEFINITION
workflow PathSeqBuildMicrobeReferenceWorkflow {

  #Mandatory input
  File microbe_fasta

  #Optional input
  Int? min_non_virus_contig_length
  File? gatk4_jar_override

  # Runtime parameters
  String gatk_docker
  Int? index_fasta_disk_gb
  Int? bwa_mem_index_disk_gb
  Int? build_taxonomy_disk_gb
  Int? index_fasta_mem_gb
  Int? bwa_mem_index_mem_gb
  Int? build_taxonomy_mem_gb
  Int? preemptible_attempts

  call IndexFasta {
    input:
      fasta_file=microbe_fasta,
      disk_space_gb=index_fasta_disk_gb,
      mem_gb=index_fasta_mem_gb,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  call BuildBwaMemIndexImage {
    input:
      fasta_file=microbe_fasta,
      fai_file=IndexFasta.output_fai_file,
      disk_space_gb=bwa_mem_index_disk_gb,
      mem_gb=bwa_mem_index_mem_gb,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  call BuildPathSeqTaxonomyFile {
    input:
      fasta_file=microbe_fasta,
      min_non_virus_contig_length=min_non_virus_contig_length,
      fai_file=IndexFasta.output_fai_file,
      dict_file=IndexFasta.output_dict_file,
      disk_space_gb=build_taxonomy_disk_gb,
      mem_gb=build_taxonomy_mem_gb,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  output {
    File output_fai_file = IndexFasta.output_fai_file
    File output_dict_file = IndexFasta.output_dict_file
    File output_img_file = BuildBwaMemIndexImage.output_img_file
    File output_taxonomy_file = BuildPathSeqTaxonomyFile.output_taxonomy_file
  }
}

# Task DEFINITIONS

task IndexFasta {

  # Inputs for this task
  File fasta_file
  String gatk_docker

  File? gatk4_jar_override
  Int? mem_gb
  Int? preemptible_attempts
  Int? disk_space_gb

  #Disk size
  Int fasta_size_gb = ceil(size(fasta_file, "GB"))
  Int default_disk_space_gb = fasta_size_gb + 20

  # Mem is in units of GB but our command and memory runtime values are in MB
  Int default_mem_gb = 7
  Int machine_mem = if defined(mem_gb) then mem_gb*1000 else default_mem_gb*1000
  Int command_mem = machine_mem - 1000

  String fasta_filename = basename(fasta_file)
  String fai_path = fasta_filename + ".fai"
  String dict_path = sub(fasta_filename, "\\.fasta$|\\.fa$", ".dict")

  command <<<
    set -e
    mv ${fasta_file} .
    export GATK_LOCAL_JAR=${default="/root/gatk.jar" gatk4_jar_override}
    samtools faidx ${fasta_filename}
    gatk --java-options "-Xmx${command_mem}m" CreateSequenceDictionary -R ${fasta_filename} -O ${dict_path}
  >>>
  runtime {
    docker: gatk_docker
    memory: machine_mem + " MB"
    # Note that the space before SSD and HDD should be included.
    disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
  output {
    File output_fai_file = "${fai_path}"
    File output_dict_file = "${dict_path}"
  }
}

task BuildBwaMemIndexImage {

  # Inputs for this task
  File fasta_file
  File fai_file
  String gatk_docker

  File? gatk4_jar_override
  Int? mem_gb
  Int? preemptible_attempts
  Int? disk_space_gb

  #Disk size
  Int fasta_size_gb = ceil(size(fasta_file, "GB"))
  Int default_disk_space_gb = (fasta_size_gb * 3) + 20

  # Mem is in units of GB but our command and memory runtime values are in MB
  Int default_mem_gb = (fasta_size_gb * 4) + 8
  Int machine_mem = if defined(mem_gb) then mem_gb*1000 else default_mem_gb*1000
  Int command_mem = machine_mem - 4000

  String fasta_filename = basename(fasta_file)
  String img_path = fasta_filename + ".img"

  command <<<
    set -e
    mv ${fasta_file} .
    mv ${fai_file} .
    export GATK_LOCAL_JAR=${default="/root/gatk.jar" gatk4_jar_override}
    gatk --java-options "-Xmx${command_mem}m" BwaMemIndexImageCreator -I ${fasta_filename}
  >>>
  runtime {
    docker: gatk_docker
    memory: machine_mem + " MB"
    # Note that the space before SSD and HDD should be included.
    disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
  output {
    File output_img_file = "${img_path}"
  }
}

task BuildPathSeqTaxonomyFile {

  # Inputs for this task
  File fasta_file
  File fai_file
  File dict_file

  Int? min_non_virus_contig_length

  String gatk_docker

  File? gatk4_jar_override
  Int? mem_gb
  Int? preemptible_attempts
  Int? disk_space_gb

  #Disk size
  Int fasta_size_gb = ceil(size(fasta_file, "GB"))
  Int default_disk_space_gb = fasta_size_gb + 20

  # Mem is in units of GB but our command and memory runtime values are in MB
  Int default_mem_gb = 30
  Int machine_mem = if defined(mem_gb) then mem_gb*1000 else default_mem_gb*1000
  Int command_mem = machine_mem - 4000

  String fasta_filename = basename(fasta_file)
  String taxonomy_file = fasta_filename + ".db"
  String catalog_file = "catalog.gz"
  String taxdump_file = "taxdump.tar.gz"

  command <<<
    set -e
    mv ${fasta_file} .
    mv ${fai_file} .
    mv ${dict_file} .
    export GATK_LOCAL_JAR=${default="/root/gatk.jar" gatk4_jar_override}
    wget -O ${catalog_file} "ftp://ftp.ncbi.nlm.nih.gov/refseq/release/release-catalog/RefSeq-release*.catalog.gz"
    wget -O ${taxdump_file} "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz"
    gatk --java-options "-Xmx${command_mem}m" \
        PathSeqBuildReferenceTaxonomy \
         --reference ${fasta_filename} \
         --output ${taxonomy_file} \
         --refseq-catalog ${catalog_file} \
         --tax-dump ${taxdump_file} \
         --min-non-virus-contig-length ${select_first([min_non_virus_contig_length, 5000])}
  >>>
  runtime {
    docker: gatk_docker
    memory: machine_mem + " MB"
    # Note that the space before SSD and HDD should be included.
    disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
  output {
    File output_taxonomy_file = "${taxonomy_file}"
  }
}

