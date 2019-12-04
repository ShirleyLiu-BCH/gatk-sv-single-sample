##########################################################################################

## Base script:   https://portal.firecloud.org/#methods/Talkowski-SV/04_v2_genotype_pesr_part1/12/wdl

## Github commit: talkowski-lab/gatk-sv-v1:<ENTER HASH HERE IN FIRECLOUD>

##########################################################################################

version 1.0

import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module04/TrainRDGenotyping.wdl" as rd_train
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module04/TrainPEGenotyping.wdl" as pe_train
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module04/TrainSRGenotyping.wdl" as sr_train

workflow GenotypePESRPart1 {
  input {
    File bin_exclude
    File bin_exclude_idx
    File batch_vcf
    String batch
    File coveragefile     # batch coverage file
    File medianfile         # batch median file
    File famfile            # batch famfile
    File rf_cutoffs         # Random forest cutoffs
    File seed_cutoffs
    Array[String] samples   # List of samples in batch
    Int n_RD_genotype_bins  # number of RdTest bins
    Int n_per_RD_split      # number of variants per RdTest split
    Int n_per_PE_split
    File discfile
    File pesr_blacklist
    File splitfile
    Int n_per_SR_split
    String reference_build  #hg19 or hg38

    String sv_mini_docker
    String sv_pipeline_docker
    String sv_pipeline_rdtest_docker

    # Runtime attributes
    RuntimeAttr? runtime_attr_split_vcf
    RuntimeAttr? runtime_attr_merge_counts

    # PE
    RuntimeAttr? runtime_attr_make_batch_bed
    RuntimeAttr? runtime_attr_count_pe
    RuntimeAttr? runtime_attr_pe_genotype

    # SR
    RuntimeAttr? runtime_attr_count_sr
    RuntimeAttr? runtime_attr_sr_genotype

    # RD
    RuntimeAttr? runtime_attr_training_bed
    RuntimeAttr? runtime_attr_genotype_train
    RuntimeAttr? runtime_attr_generate_cutoff
    RuntimeAttr? runtime_attr_update_cutoff
    RuntimeAttr? runtime_attr_split_variants
    RuntimeAttr? runtime_attr_rdtest_genotype
    RuntimeAttr? runtime_attr_merge_genotypes
  }

  call rd_train.TrainRDGenotyping as TrainRDGenotyping {
    input:
      bin_exclude=bin_exclude,
      bin_exclude_idx=bin_exclude_idx,
      rf_cutoffs = rf_cutoffs,
      medianfile = medianfile,
      n_bins = n_RD_genotype_bins,
      vcf = batch_vcf,
      coveragefile = coveragefile,
      famfile = famfile,
      n_per_split = n_per_RD_split,
      prefix = batch,
      seed_cutoffs = seed_cutoffs,
      reference_build = reference_build,
      samples = samples,
      sv_mini_docker = sv_mini_docker,
      sv_pipeline_docker = sv_pipeline_docker,
      sv_pipeline_rdtest_docker = sv_pipeline_rdtest_docker,
      runtime_attr_training_bed = runtime_attr_training_bed,
      runtime_attr_genotype_train = runtime_attr_genotype_train,
      runtime_attr_generate_cutoff = runtime_attr_generate_cutoff,
      runtime_attr_update_cutoff = runtime_attr_update_cutoff,
      runtime_attr_split_variants = runtime_attr_split_variants,
      runtime_attr_rdtest_genotype = runtime_attr_rdtest_genotype,
      runtime_attr_merge_genotypes = runtime_attr_merge_genotypes
  }

  call pe_train.TrainPEGenotyping as TrainPEGenotyping {
    input:
      RD_melted_genotypes = TrainRDGenotyping.melted_genotypes,
      batch_vcf = batch_vcf,
      medianfile = medianfile,
      RF_cutoffs = rf_cutoffs,
      RD_genotypes = TrainRDGenotyping.genotypes,
      blacklist = pesr_blacklist,
      n_per_split = n_per_PE_split,
      discfile = discfile,
      samples = samples,
      batch_ID = batch,
      sv_mini_docker = sv_mini_docker,
      sv_pipeline_docker = sv_pipeline_docker,
      sv_pipeline_rdtest_docker = sv_pipeline_rdtest_docker,
      runtime_attr_split_vcf = runtime_attr_split_vcf,
      runtime_attr_make_batch_bed = runtime_attr_make_batch_bed,
      runtime_attr_merge_counts = runtime_attr_merge_counts,
      runtime_attr_count_pe = runtime_attr_count_pe,
      runtime_attr_genotype = runtime_attr_pe_genotype
  }

  call sr_train.TrainSRGenotyping as TrainSRGenotyping {
    input:
      splitfile = splitfile,
      RD_melted_genotypes = TrainRDGenotyping.melted_genotypes,
      batch_vcf = batch_vcf,
      medianfile = medianfile,
      RF_cutoffs = rf_cutoffs,
      n_per_split = n_per_SR_split,
      PE_train = TrainPEGenotyping.PE_train,
      PE_genotypes = TrainPEGenotyping.PE_genotypes,
      samples = samples,
      batch_ID = batch,
      sv_mini_docker = sv_mini_docker,
      sv_pipeline_docker = sv_pipeline_docker,
      sv_pipeline_rdtest_docker = sv_pipeline_rdtest_docker,
      runtime_attr_split_vcf = runtime_attr_split_vcf,
      runtime_attr_merge_counts = runtime_attr_merge_counts,
      runtime_attr_count_sr = runtime_attr_count_sr,
      runtime_attr_genotype = runtime_attr_sr_genotype
  }

  output {
    File RD_depth_sepcutoff = TrainRDGenotyping.depth_sepcutoff
    File SR_metrics = TrainSRGenotyping.SR_metrics
    File PE_metrics = TrainPEGenotyping.PE_metrics
    File RD_pesr_sepcutoff = TrainRDGenotyping.pesr_sepcutoff
  }
}


