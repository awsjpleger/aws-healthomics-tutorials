version 1.1

task bcftools_call {
  meta {
    description: "Call variants from a pileup BCF using bcftools call, producing a VCF."
    author: "AWS HealthOmics"
  }

  parameter_meta {
    pileup_bcf: "Input pileup BCF file produced by bcftools mpileup."
    caller: "bcftools call mode flag. Default: -m (multiallelic caller)."
    extra: "Additional bcftools call flags. Default: -v (output variant sites only)."
    cpu: "Number of CPUs to allocate. Default: 2."
    memory: "Memory to allocate. Default: 4 GiB."
  }

  input {
    File   pileup_bcf

    # Snakemake params: caller="-m", extra="-v"
    String caller = "-m"
    String extra  = "-v"

    Int    cpu    = 2
    String memory = "4 GiB"
  }

  command <<<
    set -euo pipefail
    bcftools call \
      ~{caller} \
      ~{extra} \
      ~{pileup_bcf} \
      -o all.vcf
  >>>

  output {
    File calls_vcf = "all.vcf"
  }

  runtime {
    container: "quay.io/biocontainers/bcftools:1.21--h8b25389_0"
    cpu:       cpu
    memory:    memory
  }
}
