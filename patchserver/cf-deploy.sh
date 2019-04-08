#! /bin/sh

set -e

FUNCTION_NAME="caterate"
PROJECT_NAME=${GCP_PROJECT_ID}
ENTRY_POINT="cf_process"
RUNTIME="python37"


gcloud functions deploy ${NAME} \
  --entry-point ${ENTRY_POINT} \
  --runtime ${RUNTIME} \
  --project ${PROJECT_NAME}
