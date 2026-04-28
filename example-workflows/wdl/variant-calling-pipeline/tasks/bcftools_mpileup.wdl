version 1.1

task bcftools_mpileup {
  meta {
    description: "Generate a multi-sample pileup BCF from sorted, indexed BAM files using bcftools mpileup."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    alignments: "Array of coordinate-sorted BAM files, one per sample."
    alignment_indexes: "Array of .bai index files corresponding to the BAM files."
    genome_fasta: "Reference genome FASTA file."
    genome_fasta_index: "Reference genome FASTA index (.fai) required by bcftools mpileup."
    cpu: "Number of CPUs to allocate. Default: 4."
    memory: "Memory to allocate. Default: 8 GiB."
  }

  input {
    Array[File] alignments          # sorted BAM files for all samples
    Array[File] alignment_indexes   # corresponding .bai index files
    File        genome_fasta
    # samtools/bcftools mpileup requires a FASTA index (.fai) at runtime.
    File        genome_fasta_index

    Int    cpu    = 4
    String memory = "8 GiB"
  }

  command <<<
    set -euo pipefail
    bcftools mpileup \
      -f ~{genome_fasta} \
      ~{sep(" ", alignments)} \
      -O b \
      -o all.pileup.bcf
  >>>

  output {
    File pileup_bcf = "all.pileup.bcf"
  }

  runtime {
    container: "quay.io/biocontainers/bcftools:1.21--h8b25389_0"
    cpu:       cpu
    memory:    memory
  }
}
