/**
 * Copyright (c) Microsoft Corporation. Licensed under the MIT License.
 */
package com.microsoft.samples.flink;

import java.util.Properties;
import org.apache.flink.metrics.reporter.MetricReporter;
import org.apache.flink.metrics.reporter.MetricReporterFactory;

public class ApplicationInsightsReporterFactory implements MetricReporterFactory {

  @Override
  public MetricReporter createMetricReporter(final Properties properties) {
    return new ApplicationInsightsReporter();
  }
}
