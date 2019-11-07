#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

docker-compose exec tools /bin/bash /workdir/init.sh
docker-compose exec flinkjobmanager /bin/bash /workdir/run02.sh &
docker-compose exec inject /venv/bin/python3 -m generator &
docker exec tools /bin/bash /workdir/watch.sh 30
