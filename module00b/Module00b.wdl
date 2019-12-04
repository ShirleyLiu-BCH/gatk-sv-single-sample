version 1.0

##########################################################################################

## Github commit: talkowski-lab/gatk-sv-v1:<ENTER HASH HERE IN FIRECLOUD>

##########################################################################################

import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module00b/Structs.wdl"
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module00b/MakeBincovMatrix.wdl" as mbm
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module00b/PloidyEstimation.wdl" as pe
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module00b/RawVcfQC.wdl" as vcfqc
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.3-dockstore_release/module00b/WGD.wdl" as wgd

# Runs single sample tasks on collected evidence:
#   - Ploidy determination
#   - Dosage scoring
#   - QC for raw SV calls (optional)

workflow Module00b {
  input {
    # Batch info
    String batch
    Array[String]+ samples

    # Optional QC tasks
    Boolean run_vcf_qc

    # Global files
    File genome_file

    # Coverage files
    Array[File] counts

    # SV tool calls
    Array[File]+? manta_vcfs        # Manta VCF
    Array[File]+? delly_vcfs        # Delly VCF
    Array[File]+? melt_vcfs         # Melt VCF
    Array[File]+? wham_vcfs         # Wham VCF

    # WGD files
    File wgd_scoring_mask

    # Runtime parameters
    String sv_mini_docker
    String sv_pipeline_docker
    String sv_pipeline_qc_docker

    Int? disk_overhead_bincov_gb
    Int? bincov_size_mb

    Boolean run_ploidy = true

    RuntimeAttr? runtime_attr_qc
    RuntimeAttr? runtime_attr_qc_outlier
    RuntimeAttr? ploidy_score_runtime_attr
    RuntimeAttr? ploidy_build_runtime_attr

    RuntimeAttr? wgd_build_runtime_attr
    RuntimeAttr? wgd_score_runtime_attr
    RuntimeAttr? runtime_attr_bincov_attr
  }

  call mbm.MakeBincovMatrix as MakeBincovMatrix {
    input:
      samples = samples,
      count_files = counts,
      batch = batch,
      disk_overhead_gb = disk_overhead_bincov_gb,
      bincov_size_mb = bincov_size_mb,
      sv_mini_docker = sv_mini_docker,
      runtime_attr_override = runtime_attr_bincov_attr
  }

  if (run_ploidy) {
    call pe.Ploidy as Ploidy {
      input:
        bincov_matrix = MakeBincovMatrix.merged_bincov,
        batch = batch,
        sv_mini_docker = sv_mini_docker,
        sv_pipeline_qc_docker = sv_pipeline_qc_docker,
        runtime_attr_score = ploidy_score_runtime_attr,
        runtime_attr_build = ploidy_build_runtime_attr
    }
  }

  call wgd.WGD as WGD {
    input:
      batch = batch,
      wgd_scoring_mask = wgd_scoring_mask,
      bincov_matrix = MakeBincovMatrix.merged_bincov,
      sv_pipeline_qc_docker = sv_pipeline_qc_docker,
      runtime_attr_build = wgd_build_runtime_attr,
      runtime_attr_score = wgd_score_runtime_attr
  }

  if (run_vcf_qc) {
    if (defined(delly_vcfs)) {
      call vcfqc.RawVcfQC as RawVcfQC_Delly {
        input:
          vcfs = select_first([delly_vcfs]),
          caller = "Delly",
          runtime_attr_qc = runtime_attr_qc,
          sv_pipeline_docker = sv_pipeline_docker,
          runtime_attr_outlier = runtime_attr_qc_outlier
      }
    }
    if (defined(manta_vcfs)) {
      call vcfqc.RawVcfQC as RawVcfQC_Manta {
        input:
          vcfs = select_first([manta_vcfs]),
          caller = "Manta",
          runtime_attr_qc = runtime_attr_qc,
          sv_pipeline_docker = sv_pipeline_docker,
          runtime_attr_outlier = runtime_attr_qc_outlier
      }
    }
    if (defined(melt_vcfs)) {
      call vcfqc.RawVcfQC as RawVcfQC_Melt {
        input:
          vcfs = select_first([melt_vcfs]),
          caller = "Melt",
          runtime_attr_qc = runtime_attr_qc,
          sv_pipeline_docker = sv_pipeline_docker,
          runtime_attr_outlier = runtime_attr_qc_outlier
      }
    }
    if (defined(wham_vcfs)) {
      call vcfqc.RawVcfQC as RawVcfQC_Wham {
        input:
          vcfs = select_first([wham_vcfs]),
          caller = "Wham",
          runtime_attr_qc = runtime_attr_qc,
          sv_pipeline_docker = sv_pipeline_docker,
          runtime_attr_outlier = runtime_attr_qc_outlier
      }
    }
  }

  output {
    File? delly_qc_low = RawVcfQC_Delly.low
    File? delly_qc_high = RawVcfQC_Delly.high
    File? manta_qc_low = RawVcfQC_Manta.low
    File? manta_qc_high = RawVcfQC_Manta.high
    File? melt_qc_low = RawVcfQC_Melt.low
    File? melt_qc_high = RawVcfQC_Melt.high
    File? wham_qc_low = RawVcfQC_Wham.low
    File? wham_qc_high = RawVcfQC_Wham.high

    File? ploidy_matrix = Ploidy.ploidy_matrix
    File? ploidy_plots = Ploidy.ploidy_plots

    File WGD_dist = WGD.WGD_dist
    File WGD_matrix = WGD.WGD_matrix
    File WGD_scores = WGD.WGD_scores
  }
}
