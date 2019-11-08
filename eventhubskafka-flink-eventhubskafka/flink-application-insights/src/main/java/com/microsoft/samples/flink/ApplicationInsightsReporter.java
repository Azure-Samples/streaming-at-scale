/**
 * Copyright (c) Microsoft Corporation. Licensed under the MIT License.
 */
package com.microsoft.samples.flink;

import java.util.Map;
import org.apache.flink.metrics.Counter;
import org.apache.flink.metrics.Gauge;
import org.apache.flink.metrics.Histogram;
import org.apache.flink.metrics.HistogramStatistics;
import org.apache.flink.metrics.Meter;
import org.apache.flink.metrics.MetricConfig;
import org.apache.flink.metrics.reporter.AbstractReporter;
import org.apache.flink.metrics.reporter.InstantiateViaFactory;
import org.apache.flink.metrics.reporter.Scheduled;
import com.microsoft.applicationinsights.TelemetryClient;


@InstantiateViaFactory(
    factoryClassName = "com.microsoft.samples.flink.ApplicationInsightsReporterFactory")
public class ApplicationInsightsReporter extends AbstractReporter implements Scheduled {
  private final TelemetryClient telemetry = new TelemetryClient();

  @Override
  public void open(final MetricConfig config) {
    // nothing to do
  }

  @Override
  public void close() {
    // nothing to do
  }

  private double fromGauge(final Gauge gauge) {
    final Object value = gauge.getValue();
    if (value == null) {
      return 0;
    }
    if (value instanceof Double) {
      return (double) value;
    }
    if (value instanceof Number) {
      return ((Number) value).doubleValue();
    }
    if (value instanceof Boolean) {
      return ((Boolean) value) ? 1 : 0;
    }

    return 0;
  }

  private static double sum(final long[] values) {
    double result = 0;
    for (int i = 0; i < values.length; i++) {
      result += values[i];
    }

    return result;
  }

  @Override
  public String filterCharacters(final String input) {
    return input.replace("taskmanager", "tm").replace("jobmanager", "jm").replace("flink", "flk")
        .replace("Checkpoint", "CP");
  }

  @Override
  public void report() {
    for (final Map.Entry<Counter, String> metric : counters.entrySet()) {
      telemetry.trackMetric(metric.getValue(), metric.getKey().getCount());
    }

    for (final Map.Entry<Gauge<?>, String> metric : gauges.entrySet()) {
      telemetry.trackMetric(metric.getValue(), fromGauge(metric.getKey()));
    }

    for (final Map.Entry<Meter, String> metric : meters.entrySet()) {
      telemetry.trackMetric(metric.getValue(), metric.getKey().getRate());
    }

    for (final Map.Entry<Histogram, String> metric : histograms.entrySet()) {
      final HistogramStatistics stats = metric.getKey().getStatistics();

      telemetry.trackMetric(metric.getValue(), sum(stats.getValues()),
          Long.valueOf(metric.getKey().getCount()).intValue(),
          Long.valueOf(stats.getMin()).doubleValue(), Long.valueOf(stats.getMax()).doubleValue(),
          null);
    }

  }

}
