#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
initialpwd=`pwd`
cd $DIR/

docker-compose up -d
docker-compose logs
docker-compose ps
echo "wait for the infrastructure to start"
sleep 10
docker-compose logs | tail 
docker-compose ps

#cd $initialpwd