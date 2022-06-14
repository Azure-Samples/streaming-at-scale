FILE_PATH="/test-ouptut/verify-delta/output.txt"

az storage fs file download --file-system $FILE_SYSTEM \
    --account-name $AZURE_STORAGE_ACCOUNT_GEN2 \
    --path $FILE_PATH \
    --destination "."
echo "Test result downloaded to output.txt"

echo "Test output:"
echo =========================
head -100 "output.txt"
echo ""
echo =========================
