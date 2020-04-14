#!/bin/bash
now=$(date +%Y-%m-%d\ %H:%M:%S)
programName=$(basename $0)
programDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
baseName=$(echo ${programName} | sed -e 's/.sh//g')

set -ex

run=(docker-compose exec -T)

count="$(docker-compose ps -q consul-worker | wc -l | sed 's/ //g')"

$programDir/stop-vault.sh

for x in $(eval echo {1..$count}); do
  "${run[@]}" --index="$x" consul-worker consul leave
done
"${run[@]}" consul consul leave
docker-compose stop
