##########################################################################################

## Base script:   https://portal.firecloud.org/#methods/Talkowski-SV/BAF/1/wdl

##########################################################################################

## Generate BAF file from a sharded VCF ##

version 1.0

import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.6/module00a/BAFFromGVCFs.wdl" as baf
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.6/module00a/Structs.wdl"

workflow BAFFromShardedVCF {
  input {
    Array[File] vcfs
    File? vcf_header  # If provided, added to the beginning of each VCF
    Array[String] samples  # Can be a subset of samples in the VCF
    String batch
    String sv_base_mini_docker
    String sv_pipeline_docker
    RuntimeAttr? runtime_attr_baf_gen
    RuntimeAttr? runtime_attr_gather
    RuntimeAttr? runtime_attr_sample
  }

  scatter (idx in range(length(vcfs))) {
    call GenerateBAF {
      input:
        vcf = vcfs[idx],
        vcf_header = vcf_header,
        samples = samples,
        batch = batch,
        shard = "~{idx}",
        sv_pipeline_docker = sv_pipeline_docker,
        runtime_attr_override = runtime_attr_baf_gen,
    }
  }

  call baf.GatherBAF {
    input:
      batch = batch,
      BAF = GenerateBAF.BAF,
      sv_base_mini_docker = sv_base_mini_docker,
      runtime_attr_override = runtime_attr_gather
  }

  scatter (sample in samples) {
    call baf.ScatterBAFBySample {
      input:
        sample = sample,
        BAF = GatherBAF.out,
        sv_base_mini_docker = sv_base_mini_docker,
        runtime_attr_override = runtime_attr_sample
    }
  }

  output {
    Array[File] baf_files = ScatterBAFBySample.out
    Array[File] baf_file_indexes = ScatterBAFBySample.out_index
  }
}

task GenerateBAF {
  input {
    File vcf
    File? vcf_header
    Array[String] samples
    String batch
    String shard
    String sv_pipeline_docker
    RuntimeAttr? runtime_attr_override
  }

  RuntimeAttr default_attr = object {
    cpu_cores: 1,
    mem_gb: 3.75,
    disk_gb: 10,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  output {
    File BAF = "BAF.~{batch}.shard-~{shard}.txt"
  }
  command <<<

    set -euo pipefail
    bcftools view -M2 -v snps ~{if defined(vcf_header) then "<(cat ~{vcf_header} ~{vcf})" else vcf} \
      | python /opt/sv-pipeline/02_evidence_assessment/02d_baftest/scripts/Filegenerate/generate_baf.py \
               --unfiltered --samples-list ~{write_lines(samples)} \
      > BAF.~{batch}.shard-~{shard}.txt

  >>>
  runtime {
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    docker: sv_pipeline_docker
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

}
