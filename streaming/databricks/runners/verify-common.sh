export DATABRICKS_NODETYPE=Standard_F4s
export DATABRICKS_WORKERS=2
export DATABRICKS_MAXEVENTSPERTRIGGER=10000

export DATABRICKS_TESTOUTPUTPATH=dbfs:/test-output/$(uuidgen)

#Databricks job timeout
export REPORT_THROUGHPUT_MINUTES=40

emptyJson={}
VERIFY_SETTINGS=$(echo "${VERIFY_SETTINGS:-$emptyJson}" \
  | jq '.testOutputPath="'$DATABRICKS_TESTOUTPUTPATH'"' \
  | jq 'if .assertEventsPerSecond then . else .assertEventsPerSecond='$(($TESTTYPE * 900))' end' \
  | jq 'if .assertLatencyMilliseconds then . else .assertLatencyMilliseconds='${ASSERT_LATENCY_MS:-5000}' end' \
  | jq 'if .assertDuplicateFraction then . else .assertDuplicateFraction='${ASSERT_DUPLICATE_FRACTION:-0}' end' \
  | jq 'if .assertOutOfSequenceFraction then . else .assertOutOfSequenceFraction='${ASSERT_OUTOFSEQUENCE_FRACTION:-0}' end' \
  | jq 'if .assertMissingFraction then . else .assertMissingFraction='${ASSERT_MISSING_FRACTION:-0}' end' \
)
