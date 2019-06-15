#!/bin/sh

old_rpc_port=""

while [ 1 ]
  do

  rpc_port=""
  while [ -z "$rpc_port" ]; do
    rpc_port=$(curl -fs http://localhost:8081/jobmanager/config | jq -r '.[] | select (.key=="jobmanager.rpc.port").value')
    sleep 1
  done

  if [ "$rpc_port" != "$old_rpc_port" ]; then

    echo "$(date) Updating service jobmanager RPC port to '$rpc_port'"

    patchfile=$(mktemp)
    cat > "$patchfile" <<EOF
[
    {
        "op": "replace",
        "path": "/spec/ports/0/targetPort",
        "value": $rpc_port
    },
    {
        "op": "replace",
        "path": "/spec/ports/0/port",
        "value": $rpc_port
    }
]
EOF

    curl -fs \
      -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
      --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
      -X PATCH \
      -H 'Content-Type: application/json-patch+json' \
      -d @"$patchfile" \
      "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/api/v1/namespaces/$1/services/$2"

    old_rpc_port="$rpc_port"

    rm "$patchfile"

  fi

  sleep 1

done
