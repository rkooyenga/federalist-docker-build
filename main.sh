#!/bin/bash

# Post to webhook on completion
post () {

  # Echo the output before sending status message in case build status update fails
  echo $output

  # Capture exit status
  status=$?

  # Reset output if no errors
  if [ $status -eq 0 ]; then
    output=""
  fi

  # POST to federalist's build finished endpoint && POST to federalist-builder's build finished endpoint
  curl -H "Content-Type: application/json" \
    -d "{\"status\":\"$status\",\"message\":\"`echo -n $output | base64 --wrap=0`\"}" \
    $CALLBACK \
    ; curl -X "DELETE" $FEDERALIST_BUILDER_CALLBACK

  # Sleep until restarted for the next build
  sleep infinity
}

# Post before exit
trap post 0 # EXIT signal

# Run scripts
output=$(env -i - $(. $(dirname $0)/environment.sh clone) $(dirname $0)/clone.sh 2>&1)
output=$(env -i - $(. $(dirname $0)/environment.sh build) $(dirname $0)/build.sh 2>&1)
output=$(env -i - $(. $(dirname $0)/environment.sh publish) $(dirname $0)/publish.sh 2>&1)
