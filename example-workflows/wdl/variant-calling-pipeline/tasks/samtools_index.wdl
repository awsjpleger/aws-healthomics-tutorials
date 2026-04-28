version 1.1

task samtools_index {
  meta {
    description: "Index a sorted BAM file with samtools index, producing a .bai index."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    sorted_bam: "Coordinate-sorted BAM file to index."
    cpu: "Number of CPUs to allocate. Default: 1."
    memory: "Memory to allocate. Default: 4 GiB."
  }

  input {
    File   sorted_bam

    Int    cpu    = 1
    String memory = "4 GiB"
  }

  String bam_basename = basename(sorted_bam)

  command <<<
    set -euo pipefail
    samtools index ~{sorted_bam}
    # The index is written adjacent to the input; copy to CWD for output capture.
    cp ~{sorted_bam}.bai ~{bam_basename}.bai
  >>>

  output {
    File bam_index = "~{bam_basename}.bai"
  }

  runtime {
    container: "quay.io/biocontainers/samtools:1.21--h50ea8bc_0"
    cpu:       cpu
    memory:    memory
  }
}
