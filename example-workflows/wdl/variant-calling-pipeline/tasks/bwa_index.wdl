version 1.1

task bwa_index {
  meta {
    description: "Build BWA index files from a reference FASTA. Produces the five companion files (.amb, .ann, .bwt, .pac, .sa) required by bwa mem."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    genome_fasta: "Reference genome FASTA file to index."
    cpu: "Number of CPUs to allocate. Default: 1."
    memory: "Memory to allocate. Default: 8 GiB."
  }

  input {
    File genome_fasta

    Int cpu    = 1
    String memory = "8 GiB"
  }

  String fasta_basename = basename(genome_fasta)

  command <<<
    set -euo pipefail
    # Copy the FASTA to the task working directory so that bwa index writes
    # all companion files (.amb .ann .bwt .pac .sa) into the CWD where WDL
    # output declarations can find them.
    cp ~{genome_fasta} ~{fasta_basename}
    bwa index ~{fasta_basename}
  >>>

  output {
    File index_amb = "~{fasta_basename}.amb"
    File index_ann = "~{fasta_basename}.ann"
    File index_bwt = "~{fasta_basename}.bwt"
    File index_pac = "~{fasta_basename}.pac"
    File index_sa  = "~{fasta_basename}.sa"
  }

  runtime {
    container: "quay.io/biocontainers/bwa:0.7.18--he4a0461_1"
    cpu:       cpu
    memory:    memory
  }
}
