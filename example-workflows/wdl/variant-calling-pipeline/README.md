# Variant Calling Pipeline

A WDL 1.1 workflow for AWS HealthOmics that performs short-read variant calling using BWA-MEM alignment, samtools sorting/indexing, and bcftools variant calling. Originally translated from a SnakeMake pipeline (v5.8.0 wrappers).

## Pipeline overview

```
FASTQ files (per sample)
  │
  ▼
┌─────────────────────────────────┐
│ 1. bwa index  (optional)       │  Build BWA index from reference FASTA
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 2. bwa mem  (scatter)          │  Align reads to reference genome
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 3. samtools sort  (scatter)    │  Coordinate-sort aligned BAMs
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 4. samtools index  (scatter)   │  Index sorted BAMs (.bai)
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 5. bcftools mpileup  (gather)  │  Multi-sample pileup across all BAMs
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 6. bcftools call  (gather)     │  Call variants → VCF
└────────────┬────────────────────┘
             ▼
         all.vcf
```

Steps 2–4 run in parallel across samples (scatter). Steps 5–6 gather all samples for joint calling.

## File structure

```
variant-calling-pipeline/
├── main.wdl                        # Top-level workflow
├── tasks/
│   ├── bwa_index.wdl               # Build BWA index from FASTA
│   ├── bwa_mem.wdl                 # BWA-MEM alignment
│   ├── samtools_sort.wdl           # Coordinate sort BAM
│   ├── samtools_index.wdl          # Index sorted BAM
│   ├── bcftools_mpileup.wdl        # Multi-sample pileup
│   └── bcftools_call.wdl           # Variant calling
├── container_registry_map.json     # ECR pull-through cache mapping
├── test.parameters.json            # Example parameters using public test data
└── README.md
```

## Containers

All tasks use public [BioContainers](https://biocontainers.pro/) images from Quay.io:

| Tool | Container | Version |
|------|-----------|---------|
| BWA | `quay.io/biocontainers/bwa:0.7.18--he4a0461_1` | 0.7.18 |
| samtools | `quay.io/biocontainers/samtools:1.21--h50ea8bc_0` | 1.21 |
| bcftools | `quay.io/biocontainers/bcftools:1.21--h8b25389_0` | 1.21 |

### Container registry map

HealthOmics can only pull containers from private ECR repositories. Since this workflow references public Quay.io URIs, a **container registry map** tells HealthOmics how to redirect those references to your ECR pull-through cache. The included [`container_registry_map.json`](./container_registry_map.json) provides this mapping:

```json
{
  "registryMappings": [
    {
      "upstreamRegistryUrl": "quay.io",
      "ecrRepositoryPrefix": "quay"
    }
  ]
}
```

The `ecrRepositoryPrefix` value must match the prefix of your ECR pull-through cache rule for Quay.io. For example, if your pull-through cache rule uses the prefix `quay`, then when HealthOmics encounters `quay.io/biocontainers/bwa:0.7.18--he4a0461_1`, it resolves it to `<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/quay/biocontainers/bwa:0.7.18--he4a0461_1`.

If your pull-through cache uses a different prefix (e.g. `quay-io`), update the `ecrRepositoryPrefix` in the JSON to match.

For full details on container registry maps, see the [AWS HealthOmics container documentation](https://docs.aws.amazon.com/omics/latest/dev/workflows-ecr.html).

### ECR pull-through cache prerequisites

Your ECR pull-through cache for Quay.io must be configured with HealthOmics access. This means:

1. A pull-through cache rule exists mapping `quay.io` to your chosen ECR prefix.
2. The ECR registry permissions policy grants the `omics.amazonaws.com` principal access.
3. A repository creation template exists for the prefix that grants HealthOmics `ecr:BatchGetImage` and `ecr:GetDownloadUrlForLayer` permissions.

## Inputs

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `fastq_files` | `Array[File]` | S3 URIs of FASTQ files, one per sample. Must be in the same order as `samples`. |
| `genome_fasta` | `File` | S3 URI of the reference genome FASTA. |
| `genome_fasta_index` | `File` | S3 URI of the reference genome FASTA index (`.fai`). |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `samples` | `Array[String]` | `["A", "B"]` | Sample identifiers. Parallel with `fastq_files`. |
| `run_bwa_index` | `Boolean` | `false` | Build BWA index at runtime instead of using pre-built files. |
| `bwa_index_amb` | `File?` | — | Pre-built BWA `.amb` index file. Required when `run_bwa_index` is `false`. |
| `bwa_index_ann` | `File?` | — | Pre-built BWA `.ann` index file. Required when `run_bwa_index` is `false`. |
| `bwa_index_bwt` | `File?` | — | Pre-built BWA `.bwt` index file. Required when `run_bwa_index` is `false`. |
| `bwa_index_pac` | `File?` | — | Pre-built BWA `.pac` index file. Required when `run_bwa_index` is `false`. |
| `bwa_index_sa` | `File?` | — | Pre-built BWA `.sa` index file. Required when `run_bwa_index` is `false`. |
| `bcftools_caller` | `String` | `"-m"` | bcftools call mode flag (`-m` for multiallelic caller). |
| `bcftools_extra` | `String` | `"-v"` | Extra bcftools call flags (`-v` outputs variant sites only). |

## Outputs

| Parameter | Type | Description |
|-----------|------|-------------|
| `all_vcf` | `File` | Multi-sample VCF with called variants. |

## Resource defaults

| Task | CPUs | Memory |
|------|------|--------|
| `bwa_index` | 1 | 8 GiB |
| `bwa_mem` | 8 | 16 GiB |
| `samtools_sort` | 4 | 8 GiB |
| `samtools_index` | 1 | 4 GiB |
| `bcftools_mpileup` | 4 | 8 GiB |
| `bcftools_call` | 2 | 4 GiB |

These can be overridden per-task by modifying the WDL input defaults.

## Test data

The included [`test.parameters.json`](./test.parameters.json) provides a ready-to-use example using public test data from the `aws-genomics-static-us-east-1` S3 bucket. It uses:

- **Reference**: hg38 chr20 subset (~62 MB FASTA) with pre-built BWA index files (~113 MB total) from the nf-core-sarek test dataset
- **Samples**: Two tumor-normal FASTQ files (SRR2089363 and SRR2089364, ~1.9 GB each) from the tumor-normal test dataset

This is a good starting point for validating the workflow without needing to stage your own data. The chr20-only reference keeps alignment fast while still exercising the full pipeline end-to-end.

## Deploying and running with Kiro

The [AWS HealthOmics Kiro Power](https://kiro.dev) can automate every step of deploying and running this workflow. Install the power, then use the prompts below in Kiro chat.

### Step 1: Validate your ECR configuration

Confirm your ECR pull-through cache is set up correctly for HealthOmics before deploying.

**Kiro prompt:**
```
Validate my ECR configuration for HealthOmics. Check that I have a pull-through
cache rule for quay.io and that it is usable by HealthOmics.
```

If no Quay.io pull-through cache exists, create one:

**Kiro prompt:**
```
Create an ECR pull-through cache rule for quay.io that is configured for
HealthOmics access.
```

### Step 2: Verify the containers are available

Ensure the three BioContainers images can be pulled through your cache and are accessible by HealthOmics.

**Kiro prompt:**
```
Check that these containers are available in my ECR and accessible by HealthOmics:
- quay.io/biocontainers/bwa:0.7.18--he4a0461_1
- quay.io/biocontainers/samtools:1.21--h50ea8bc_0
- quay.io/biocontainers/bcftools:1.21--h8b25389_0

If any are missing, clone them to ECR via pull-through cache.
```

### Step 3: Generate a container registry map

Generate a container registry map that matches your ECR pull-through cache configuration. This is useful if your prefix differs from the default `quay` used in the included `container_registry_map.json`.

**Kiro prompt:**
```
Generate a container registry map for my HealthOmics workflows based on my
current ECR pull-through cache rules.
```

### Step 4: Create the workflow

Deploy the workflow definition to HealthOmics.

**Kiro prompt:**
```
Create a new HealthOmics workflow from the files in
example-workflows/wdl/variant-calling-pipeline/ using the container registry
map in container_registry_map.json.
```

### Step 5: Start a run

**Kiro prompt:**
```
Start a run of the variant-calling-pipeline workflow with these parameters:
- samples: ["SampleA", "SampleB"]
- fastq_files: ["s3://my-bucket/data/SampleA.fastq", "s3://my-bucket/data/SampleB.fastq"]
- genome_fasta: "s3://my-bucket/ref/genome.fa"
- genome_fasta_index: "s3://my-bucket/ref/genome.fa.fai"
- bwa_index_amb: "s3://my-bucket/ref/genome.fa.amb"
- bwa_index_ann: "s3://my-bucket/ref/genome.fa.ann"
- bwa_index_bwt: "s3://my-bucket/ref/genome.fa.bwt"
- bwa_index_pac: "s3://my-bucket/ref/genome.fa.pac"
- bwa_index_sa: "s3://my-bucket/ref/genome.fa.sa"
Use DYNAMIC storage.
```

### Step 6: Monitor and troubleshoot

**Kiro prompt:**
```
Show me the status of my latest HealthOmics run. If it failed, diagnose the failure.
```

### Step 7: Analyze performance

After a successful run, check for optimization opportunities.

**Kiro prompt:**
```
Analyze the performance of run <RUN_ID> and suggest resource optimizations.
```

## Deploying and running with the AWS CLI

### 1. Create the workflow

```bash
# Package the workflow files
zip -r workflow-definition.zip main.wdl tasks/

# Create the workflow with the container registry map
aws omics create-workflow \
  --name variant-calling-pipeline \
  --definition-zip fileb://workflow-definition.zip \
  --container-registry-map-uri s3://<BUCKET>/container_registry_map.json
```

### 2. Start a run

```bash
aws omics start-run \
  --workflow-id <WORKFLOW_ID> \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME> \
  --output-uri s3://<BUCKET>/healthomics-outputs/ \
  --storage-type DYNAMIC \
  --parameters '{
    "samples": ["SampleA", "SampleB"],
    "fastq_files": [
      "s3://<BUCKET>/data/SampleA.fastq",
      "s3://<BUCKET>/data/SampleB.fastq"
    ],
    "genome_fasta": "s3://<BUCKET>/ref/genome.fa",
    "genome_fasta_index": "s3://<BUCKET>/ref/genome.fa.fai",
    "bwa_index_amb": "s3://<BUCKET>/ref/genome.fa.amb",
    "bwa_index_ann": "s3://<BUCKET>/ref/genome.fa.ann",
    "bwa_index_bwt": "s3://<BUCKET>/ref/genome.fa.bwt",
    "bwa_index_pac": "s3://<BUCKET>/ref/genome.fa.pac",
    "bwa_index_sa": "s3://<BUCKET>/ref/genome.fa.sa"
  }'
```

### 3. Monitor the run

```bash
aws omics get-run --id <RUN_ID>
```

## License

This workflow is provided under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).
