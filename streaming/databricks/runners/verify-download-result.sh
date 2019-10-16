databricks fs cp --overwrite "$DATABRICKS_TESTOUTPUTPATH" test-output.txt

echo "Test result downloaded to test-output.txt"

echo "Test output:"
echo =========================
head -100 test-output.txt
echo ""
echo =========================
