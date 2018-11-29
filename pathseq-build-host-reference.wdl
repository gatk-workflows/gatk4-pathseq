###############################################################
##
## PathSeq Host Reference Build WDL
##
###############################################################
##
## Builds a host reference for use with PathSeq
##
## For further info see the GATK Documentation for the PathSeqPipelineSpark tool:
##   https://software.broadinstitute.org/gatk/documentation/tooldocs/current/org_broadinstitute_hellbender_tools_spark_pathseq_PathSeqPipelineSpark.php
##
###############################################################
##
## Input requirements :
## - FASTA file containing host sequences from NCBI RefSeq
##
## Output:
## - FASTA index and dictionary files
## - GATK BWA-MEM index image
## - PathSeq host kmer file
##
###############################################################

# WORKFLOW DEFINITION
workflow PathSeqBuildHostReferenceWorkflow {

  #Mandatory input
  File host_fasta

  #Optional input
  File? gatk4_jar_override

  # Runtime parameters
  String gatk_docker
  Int? preemptible_attempts

  call IndexFasta {
    input:
      fasta_file=host_fasta,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  call BuildBwaMemIndexImage {
    input:
      fasta_file=host_fasta,
      fai_file=IndexFasta.output_fai_file,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  call BuildPathSeqKmerFile {
    input:
      fasta_file=host_fasta,
      fai_file=IndexFasta.output_fai_file,
      dict_file=IndexFasta.output_dict_file,
      gatk_docker=gatk_docker,
      gatk4_jar_override=gatk4_jar_override,
      preemptible_attempts=preemptible_attempts
  }
  output {
    File output_fai_file = IndexFasta.output_fai_file
    File output_dict_file = IndexFasta.output_dict_file
    File output_img_file = BuildBwaMemIndexImage.output_img_file
    File output_taxonomy_file = BuildPathSeqKmerFile.output_kmer_file
  }
}

# Task DEFINITIONS

# Builds Index files for Fasta
task IndexFasta {

  # Inputs for this task
  File fasta_file
  String fasta_filename = basename(fasta_file)
  String fai_path = fasta_filename + ".fai"
  String dict_path = sub(fasta_filename, "\\.fasta$|\\.fa$", ".dict")
  File? gatk4_jar_override

  # Runtime parameters
  String gatk_docker
  Int? mem_gb
  Int? preemptible_attempts
  Int? disk_space_gb
    # Disk size
  Int fasta_size_gb = ceil(size(fasta_file, "GB"))
  Int default_disk_space_gb = fasta_size_gb + 20
    # Mem is in units of GB but our command and memory runtime values are in MB
  Int default_mem_gb = 7
  Int machine_mem = if defined(mem_gb) then mem_gb*1000 else default_mem_gb*1000
  Int command_mem = machine_mem - 1000

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

# Bilds BWA index images
task BuildBwaMemIndexImage {

  # Inputs for this task
  File fasta_file
  File fai_file
  String fasta_filename = basename(fasta_file)
  String img_path = fasta_filename + ".img"
  File? gatk4_jar_override
  
  # Runtime parameters
  String gatk_docker
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

# Builds Kmer file
task BuildPathSeqKmerFile {

  # Inputs for this task
  File fasta_file
  File fai_file
  File dict_file
  String fasta_filename = basename(fasta_file)
  String kmer_file = fasta_filename + ".host.hss"
  File? gatk4_jar_override
  
  # Runtime parameters
  String gatk_docker
  Int? mem_gb
  Int? preemptible_attempts
  Int? disk_space_gb
    # Disk size
  Int fasta_size_gb = ceil(size(fasta_file, "GB"))
  Int default_disk_space_gb = fasta_size_gb + 20
    # Mem is in units of GB but our command and memory runtime values are in MB
  Int default_mem_gb = 100
  Int machine_mem = if defined(mem_gb) then mem_gb*1000 else default_mem_gb*1000
  Int command_mem = machine_mem - 4000

  command <<<
    set -e
    mv ${fasta_file} .
    mv ${fai_file} .
    mv ${dict_file} .
    export GATK_LOCAL_JAR=${default="/root/gatk.jar" gatk4_jar_override}
    gatk --java-options "-Xmx${command_mem}m" \
      PathSeqBuildKmers \
      --reference ${fasta_filename} \
      --O ${kmer_file}
  >>>
  runtime {
    docker: gatk_docker
    memory: machine_mem + " MB"
    # Note that the space before SSD and HDD should be included.
    disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
  output {
    File output_kmer_file = "${kmer_file}"
  }
}

