version 1.1

task bwa_mem {
  meta {
    description: "Align FASTQ reads to a reference genome with BWA-MEM, producing an unsorted BAM."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    sample_name: "Sample identifier used for output file naming and read group tags."
    fastq: "Input FASTQ file for the sample."
    genome_fasta: "Reference genome FASTA file."
    index_amb: "BWA index .amb file for the reference."
    index_ann: "BWA index .ann file for the reference."
    index_bwt: "BWA index .bwt file for the reference."
    index_pac: "BWA index .pac file for the reference."
    index_sa: "BWA index .sa file for the reference."
    extra: "Additional bwa mem arguments. Default includes read group string derived from sample_name."
    cpu: "Number of CPUs to allocate. Default: 8."
    memory: "Memory to allocate. Default: 16 GiB."
  }

  input {
    String sample_name
    File   fastq

    File   genome_fasta
    # BWA requires five index files adjacent to the FASTA at runtime.
    # HealthOmics localises all File inputs into the task working directory,
    # so declaring them here is sufficient for co-location.
    File   index_amb
    File   index_ann
    File   index_bwt
    File   index_pac
    File   index_sa

    # Read-group string; the {sample} wildcard is resolved by the caller.
    String extra = "-R '@RG\\tID:~{sample_name}\\tSM:~{sample_name}'"

    Int    cpu    = 8
    String memory = "16 GiB"
  }

  command <<<
    set -euo pipefail
    bwa mem \
      ~{extra} \
      -t ~{cpu} \
      ~{genome_fasta} \
      ~{fastq} \
      > ~{sample_name}.bam
  >>>

  output {
    File bam = "~{sample_name}.bam"
  }

  runtime {
    container: "quay.io/biocontainers/bwa:0.7.18--he4a0461_1"
    cpu:       cpu
    memory:    memory
  }
}
