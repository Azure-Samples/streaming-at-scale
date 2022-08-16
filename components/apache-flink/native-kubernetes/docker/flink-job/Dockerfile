ARG flink_version=1.15.0
ARG flink_scala_version=scala_2.12
ARG java_version=java8

FROM flink:$flink_version-$flink_scala_version-$java_version

ARG job_jar=NOT_SET

# Install JAR containing Flink job to run in usrlib
RUN mkdir -p $FLINK_HOME/usrlib
COPY $job_jar $FLINK_HOME/usrlib/job.jar
