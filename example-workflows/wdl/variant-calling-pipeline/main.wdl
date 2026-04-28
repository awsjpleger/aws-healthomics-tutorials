version 1.1

import "tasks/bwa_index.wdl"       as bwa_index_task
import "tasks/bwa_mem.wdl"         as bwa_mem_task
import "tasks/samtools_sort.wdl"   as samtools_sort_task
import "tasks/samtools_index.wdl"  as samtools_index_task
import "tasks/bcftools_mpileup.wdl" as bcftools_mpileup_task
import "tasks/bcftools_call.wdl"   as bcftools_call_task


workflow variant_calling_pipeline {

  meta {
    description: "BWA-MEM alignment → samtools sort/index → bcftools mpileup/call variant calling pipeline. Translated from SnakeMake (v5.8.0 wrappers)."
    author: "AWS HealthOmics"
    version: "1.1"
    workflow_type: "WDL"
    workflow_version: "1.1"
    outputs: {
      all_vcf: "Final multi-sample VCF containing called variants."
    }
  }

  parameter_meta {
    samples: "Array of sample identifiers. Must be parallel with fastq_files."
    fastq_files: "Array of FASTQ file S3 URIs, one per sample, in the same order as samples."
    genome_fasta: "S3 URI of the reference genome FASTA file."
    genome_fasta_index: "S3 URI of the reference genome FASTA index (.fai)."
    run_bwa_index: "Set to true to build the BWA index at runtime instead of supplying pre-built index files."
    bwa_index_amb: "Pre-built BWA index .amb file. Required when run_bwa_index is false."
    bwa_index_ann: "Pre-built BWA index .ann file. Required when run_bwa_index is false."
    bwa_index_bwt: "Pre-built BWA index .bwt file. Required when run_bwa_index is false."
    bwa_index_pac: "Pre-built BWA index .pac file. Required when run_bwa_index is false."
    bwa_index_sa: "Pre-built BWA index .sa file. Required when run_bwa_index is false."
    bcftools_caller: "bcftools call mode flag. Default: -m (multiallelic caller)."
    bcftools_extra: "Extra bcftools call flags. Default: -v (output variant sites only)."
  }

  input {
    # --- Sample inputs -------------------------------------------------------
    # Each element is a sample identifier; the corresponding FASTQ is resolved
    # below via the fastq_files array (parallel arrays, same order).
    Array[String] samples       = ["A", "B"]
    Array[File]   fastq_files   # e.g. ["s3://bucket/data/samples/A.fastq",
                                #       "s3://bucket/data/samples/B.fastq"]

    # --- Reference genome ----------------------------------------------------
    File genome_fasta           # e.g. "s3://bucket/data/genome.fa"
    # samtools/bcftools require a .fai index adjacent to the FASTA.
    File genome_fasta_index     # e.g. "s3://bucket/data/genome.fa.fai"

    # --- BWA index files (pre-built) -----------------------------------------
    # If you want to build the index at runtime instead, set
    # run_bwa_index = true and leave these unset.
    Boolean run_bwa_index   = false
    File?   bwa_index_amb
    File?   bwa_index_ann
    File?   bwa_index_bwt
    File?   bwa_index_pac
    File?   bwa_index_sa

    # --- bcftools call params -------------------------------------------------
    String bcftools_caller = "-m"
    String bcftools_extra  = "-v"
  }

  # ---------------------------------------------------------------------------
  # Step 1 (optional): Build BWA index
  # Run only when the caller has not supplied pre-built index files.
  # ---------------------------------------------------------------------------
  if (run_bwa_index) {
    call bwa_index_task.bwa_index {
      input:
        genome_fasta = genome_fasta
    }
  }

  # Resolve which index files to use: freshly built or caller-supplied.
  File resolved_amb = select_first([bwa_index.index_amb, bwa_index_amb])
  File resolved_ann = select_first([bwa_index.index_ann, bwa_index_ann])
  File resolved_bwt = select_first([bwa_index.index_bwt, bwa_index_bwt])
  File resolved_pac = select_first([bwa_index.index_pac, bwa_index_pac])
  File resolved_sa  = select_first([bwa_index.index_sa,  bwa_index_sa])

  # ---------------------------------------------------------------------------
  # Step 2: Align each sample with BWA-MEM  (scatter over samples)
  # ---------------------------------------------------------------------------
  scatter (idx in range(length(samples))) {
    String sample = samples[idx]
    File   fastq  = fastq_files[idx]

    call bwa_mem_task.bwa_mem {
      input:
        sample_name  = sample,
        fastq        = fastq,
        genome_fasta = genome_fasta,
        index_amb    = resolved_amb,
        index_ann    = resolved_ann,
        index_bwt    = resolved_bwt,
        index_pac    = resolved_pac,
        index_sa     = resolved_sa,
        extra        = "-R '@RG\\tID:~{sample}\\tSM:~{sample}'"
    }

    # Step 3: Sort the aligned BAM
    call samtools_sort_task.samtools_sort {
      input:
        sample_name = sample,
        bam         = bwa_mem.bam
    }

    # Step 4: Index the sorted BAM
    call samtools_index_task.samtools_index {
      input:
        sorted_bam = samtools_sort.sorted_bam
    }
  }

  # ---------------------------------------------------------------------------
  # Step 5: Multi-sample pileup (gather all sorted BAMs and their indexes)
  # ---------------------------------------------------------------------------
  call bcftools_mpileup_task.bcftools_mpileup {
    input:
      alignments        = samtools_sort.sorted_bam,
      alignment_indexes = samtools_index.bam_index,
      genome_fasta      = genome_fasta,
      genome_fasta_index = genome_fasta_index
  }

  # ---------------------------------------------------------------------------
  # Step 6: Variant calling
  # ---------------------------------------------------------------------------
  call bcftools_call_task.bcftools_call {
    input:
      pileup_bcf     = bcftools_mpileup.pileup_bcf,
      caller         = bcftools_caller,
      extra          = bcftools_extra
  }

  # ---------------------------------------------------------------------------
  # Workflow outputs  (corresponds to rule all: input: "calls/all.vcf")
  # ---------------------------------------------------------------------------
  output {
    File all_vcf = bcftools_call.calls_vcf
  }
}
