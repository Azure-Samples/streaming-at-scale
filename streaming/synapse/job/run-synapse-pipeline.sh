create_pipeline_run(){
    local pipeline_name="$1"
    local pipeline_file="$2"
    local parameters_file="$3"
    local run_id=""

    # A variable is needed here to store the output of the pipeline create cmd
    # or bash appends the desired result to the result.
    create_cmd_output=$(az synapse pipeline create --workspace-name $SYNAPSE_WORKSPACE \
        --name $pipeline_name --file @"${pipeline_file}")

    run_id=$(az synapse pipeline create-run --workspace-name $SYNAPSE_WORKSPACE \
    --name $pipeline_name \
    --parameters @"${parameters_file}" \
    --query 'runId')

    # The value of runId from the above query is a quoted string and doesn't work 
    # when used as a parameter in az synapse pipeline-run show.
    # Therefore we remove the quotes in the first and last index. 
    run_id="${run_id:1:${#run_id}-2}"

    echo "$run_id"
}

wait_for_run () {
    local pipeline_run_id=$1
    echo $pipeline_run_id
    echo -n "Waiting for run ${pipeline_run_id} to finish..."
    while : ; do
        quoted_status=$(az synapse pipeline-run show --run-id $pipeline_run_id \
        --workspace-name $SYNAPSE_WORKSPACE \
        --query "status")
        
        status="${quoted_status:1:${#quoted_status}-2}" # Removes quotes around status
        echo "Pipeline ${pipeline_run_id} is: ${status}"
        if [[ $status != "InProgress" && $status != "Queued" ]]; then
            echo "Pipeline ${pipeline_run_id} $status"
            break;
        else 
            echo -n .
            sleep 30
        fi
    done

    message=$(az synapse pipeline-run show --run-id $pipeline_run_id \
    --workspace-name $SYNAPSE_WORKSPACE \
    --query "message")
    echo "[$status] $message"

    if [ $status != "Succeeded" ]; then
        echo "Unsuccessful run"
    fi
}
