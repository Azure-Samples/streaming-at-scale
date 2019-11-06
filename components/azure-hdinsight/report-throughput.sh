#!/bin/bash

set -euo pipefail

REPORT_THROUGHPUT_MINUTES=${REPORT_THROUGHPUT_MINUTES:-30}

endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_KAFKA_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

fmt="%28s%20.f%20.f%20.f\n"

echo "Reporting aggregate metrics per minute, for $REPORT_THROUGHPUT_MINUTES minutes."
printf "${fmt//.f/s}" "" IncomingMessages IncomingBytes OutgoingBytes
printf "${fmt//.f/s}" "" ---------------- ------------- -------------
for i in $(seq 1 $REPORT_THROUGHPUT_MINUTES) ; do
  stats=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" \
    "https://$endpoint/api/v1/clusters/$HDINSIGHT_KAFKA_NAME/services/KAFKA/components/KAFKA_BROKER?fields=metrics/kafka/server/BrokerTopicMetrics" \
    | jq '.metrics.kafka.server.BrokerTopicMetrics
          | [.AllTopicsMessagesInPerSec, .AllTopicsBytesInPerSec, .AllTopicsBytesOutPerSec]
          | .[]."1MinuteRate._sum"*60' \
    )
  printf "$fmt" "$(date +%Y-%m-%dT%H:%M:%S%z)" $stats

  # sleep until next full minute. "10#" is to force base 10 if string is e.g. "09"
  sleep "$((60 - 10#$(date +%S) ))"
done
