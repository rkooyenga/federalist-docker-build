#!/bin/bash

# This script outputs the environment in which the other scripts should run.
# Its purpose is to ensure that build scripts only have access to the environment variables they need to do their work.
# This forces us to opt-in to providing an environment variable to a portion of the build process.
# This should prevent secrets from leaking into parts of the build process where they should not be accessible.
#
# Example:
#
# . /app/environment.sh clone
# GITHUB_TOKEN="123abc" SOURCE_OWNER="18F" SOURCE REPO="modern-team-template" ...
#
# This is intended to be used with `env` to restrict the environment of the other scrips.
#
# Example:
#
# env -i $(. /app/environment.sh build) /app/build.sh
#

cleanup () {
  unset VALUE
  unset SCRIPT
  unset VARIABLES
  unset ENV
}

trap cleanup 0

SCRIPT=$1

if [[ "$SCRIPT" = "clone" ]]; then
  VARIABLES=(
    "GITHUB_TOKEN"
    "SOURCE_OWNER"
    "SOURCE_REPO"
    "BRANCH"
    "OWNER"
    "REPOSITORY"
  )
elif [[ "$SCRIPT" = "build" ]]; then
  VARIABLES=(
    "GENERATOR"
    "BASEURL"
    "BRANCH"
    "CONFIG"
    "HOME"
    "TMPDIR"
  )
elif [[ "$SCRIPT" = "publish" ]]; then
  VARIABLES=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
    "BUCKET"
    "PREFIX"
    "CACHE_CONTROL"
    "BASEURL"
  )
fi

ENV=""

for VARIABLE in "${VARIABLES[@]}"; do
  VALUE="$(eval echo \$$VARIABLE)"

  if [[ -n $VALUE ]]; then
    ENV="$VARIABLE=\"$VALUE\" $ENV"
  fi

  unset VALUE
done

echo $ENV
