# gatk4-pathseq
### Purpose :
This repo contains workflows for computational pathogen discovery using PathSeq, 
a pipeline in the Genome Analysis Toolkit (GATK) for detecting microbial organisms 
in short-read deep sequencing samples taken from a host organism.

Additional Resources:  
- [How to Run the Pathseq pipeline (manually)](https://gatk.broadinstitute.org/hc/en-us/articles/360035889911)
- [GATK PathSeq: a customizable computational tool for the discovery and identification of microbial sequences in libraries from eukaryotic hosts](https://doi.org/10.1093/bioinformatics/bty501)

## pathseq-pipeline
Runs the PathSeq pipeline

### Requirements/expectations :
- BAM 
  - File must pass validation by ValidateSamFile
  - All reads must have an RG tag
  - One or more read groups all belong to a single sample (SM)
- Host and microbe references files available in the [GATK Resource Bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360036212652)

### Output :
- BAM file containing microbe-mapped reads and reads of unknown sequence
- Tab-separated value (.tsv) file of taxonomic abundance scores
- Picard-style metrics files for the filter and scoring phases of the pipeline

## pathseq-build-microbe-reference
Builds a microbe reference for use with PathSeq

### Requirements/expectations :
- FASTA file containing microbe sequences from NCBI RefSeq

### Output :
- FASTA index and dictionary files
- GATK BWA-MEM index image
- PathSeq taxonomy file

## pathseq-build-host-reference
Builds a host reference for use with PathSeq

### Requirements/expectations :
- FASTA file containing host sequences

### Output :
- FASTA index and dictionary files
- GATK BWA-MEM index image
- PathSeq Kmer file
---
### Software version notes 
- GATK 4 or later 
- Cromwell version support 
  - Successfully tested on v36 
  - Does not work on versions < v23 due to output syntax

### Important Notes :
- Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
- The provided JSON is a ready to use example JSON template of the workflow. Users are responsible for reviewing the [GATK Tool and Tutorial Documentations](https://gatk.broadinstitute.org/hc/en-us/categories/360002310591) to properly set the reference and resource variables. 
- For help running workflows on the Google Cloud Platform or locally please
view the following tutorial [(How to) Execute Workflows from the gatk-workflows Git Organization](https://gatk.broadinstitute.org/hc/en-us/articles/360035530952).
- Please visit the [User Guide](https://gatk.broadinstitute.org/hc/en-us/categories/360002310591) site for further documentation on our workflows and tools.
- Relevant reference and resources bundles can be accessed in [Resource Bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360036212652).

### Contact Us :
- The following material is provided by the Data Science Platforum group at the Broad Institute. Please direct any questions or concerns to one of our forum sites : [GATK](https://gatk.broadinstitute.org/hc/en-us/community/topics) or [Terra](https://support.terra.bio/hc/en-us/community/topics/360000500432).

### LICENSING 
#### Copyright Broad Institute, 2018 | BSD-3
This script is released under the WDL source code license (BSD-3) (see LICENSE in
https://github.com/broadinstitute/wdl). Note however that the programs it calls may
be subject to different licenses. Users are responsible for checking that they are
authorized to run all programs before running this script.

