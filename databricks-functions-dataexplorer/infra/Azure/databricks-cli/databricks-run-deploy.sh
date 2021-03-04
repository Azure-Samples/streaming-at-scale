job_name='yem0825-cdtest'
# list run and cancel run
run_list=$(databricks runs list | grep $job_name)
while IFS='  ' read id name status result url
do
echo "run_id - $id $name $status"
if [ "$status" != 'TERMINATED' ]
then
   databricks runs cancel --run-id $id
   echo "cancel run_id - $id"
fi
done <<< "$run_list"

# create a job with the job-meta.json
job_meta_file="./job_meta_simple_test.json"
job_id=$(databricks jobs create --json-file "$job_meta_file" | python -c "import sys, json; print(json.load(sys.stdin)['job_id'])")
echo "create job $job_name $job_id"

# load notbook arguments
notebook_param_file="./notebook_params_simple_test.json"
notebook_params=$(<$notebook_param_file)

# create a run with the job
run_id=$(databricks jobs run-now --job-id $job_id --notebook-params  "$notebook_params"  | python -c "import sys, json; print(json.load(sys.stdin)['run_id'])")
echo "run job $job_id with run_id $run_id"