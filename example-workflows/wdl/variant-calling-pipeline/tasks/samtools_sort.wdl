version 1.1

task samtools_sort {
  meta {
    description: "Sort a BAM file by coordinate using samtools sort."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    sample_name: "Sample identifier used for output file naming."
    bam: "Unsorted BAM file to sort."
    cpu: "Number of CPUs to allocate. Default: 4."
    memory: "Memory to allocate. Default: 8 GiB."
  }

  input {
    String sample_name
    File   bam

    Int    cpu    = 4
    String memory = "8 GiB"
  }

  command <<<
    set -euo pipefail
    samtools sort \
      -T ~{sample_name}_sort_tmp \
      -O bam \
      ~{bam} \
      > ~{sample_name}.sorted.bam
  >>>

  output {
    File sorted_bam = "~{sample_name}.sorted.bam"
  }

  runtime {
    container: "quay.io/biocontainers/samtools:1.21--h50ea8bc_0"
    cpu:       cpu
    memory:    memory
  }
}
