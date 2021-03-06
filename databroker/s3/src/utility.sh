#!/bin/bash

#
# Copyright 2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

PUSHGATEWAY_HOST="pushgateway"
PUSHGATEWAY_UDP_PORT="9125"

# Retries a command a with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the
# initial backoff timeout is given by TIMEOUT in seconds
# (default 1.)
#
# Successive backoffs double the timeout.
#
# Beware of set -e killing your whole script!
function with_backoff {
  local max_attempts=${ATTEMPTS-5}
  local timeout=${TIMEOUT-1}
  local attempt=0
  local exitCode=0

  while [[ $attempt < $max_attempts ]]
  do
    "$@"
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    elif [[ $exitCode == 2 ]]
    then
       attempt=0
       timeout=${TIMEOUT-1}
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    updateMetricsOnFailure $attempt &
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}

# Exit the program immediately.
function panic {
    echo "Exiting with panic"
    exit 1
}


function updateMetricsOnFailure() {
  counter=$1
  metrics="databroker.s3.failures.$counter:1|c"
  echo "got metrics to push as $metrics"
  pushMetrics $metrics  
}

function pushMetrics() {
  metrics=$1
  # Setup UDP socket with statsd server
  exec 3<> /dev/udp/$PUSHGATEWAY_HOST/$PUSHGATEWAY_UDP_PORT
  # Send data
  printf "$metrics" >&3
  # Close UDP socket
  exec 3<&-
  exec 3>&-
}