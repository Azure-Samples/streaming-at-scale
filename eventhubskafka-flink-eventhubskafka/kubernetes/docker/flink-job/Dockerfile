ARG flink_version=1.8.0

FROM flink:$flink_version

ARG job_jar=NOT_SET

# Install JAR containing Flink job to run
ADD $job_jar /opt/flink/lib/job.jar
