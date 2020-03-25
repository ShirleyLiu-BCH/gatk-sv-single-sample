version 1.0

import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.6/module04/Module04.wdl" as module
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.6/module04/Module04Metrics.wdl" as metrics
import "https://raw.githubusercontent.com/broadinstitute/gatk-sv-clinical/v0.6/module04/TestUtils.wdl" as utils

workflow Module04Test {
  input {
    String test_name
    Array[String] samples
    String base_metrics
  }

  call module.Module04 {
    input:
      samples = samples
  }

  call metrics.Module04Metrics {
    input:
      name = test_name,
      samples = samples,
      genotyped_pesr_vcf = Module04.genotyped_pesr_vcf,
      genotyped_depth_vcf = Module04.genotyped_depth_vcf,
      cutoffs_pesr_pesr = select_first([Module04.trained_genotype_pesr_pesr_sepcutoff]),
      cutoffs_pesr_depth = select_first([Module04.trained_genotype_pesr_depth_sepcutoff]),
      cutoffs_depth_pesr = select_first([Module04.trained_genotype_depth_pesr_sepcutoff]),
      cutoffs_depth_depth = select_first([Module04.trained_genotype_depth_depth_sepcutoff]),
      sr_bothside_pass = Module04.sr_bothside_pass,
      sr_background_fail = Module04.sr_background_fail,
  }

  call utils.PlotMetrics {
    input:
      name = test_name,
      samples = samples,
      test_metrics = Module04Metrics.metrics_file,
      base_metrics = base_metrics
  }

  output {
    File metrics = Module04Metrics.metrics_file
    File metrics_plot_pdf = PlotMetrics.metrics_plot_pdf
    File metrics_plot_tsv = PlotMetrics.metrics_plot_tsv
  }
}
