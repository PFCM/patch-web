#! /bin/sh

set -e

FUNCTION_NAME="caterate"
PROJECT_NAME=${GCP_PROJECT_ID}
ENTRY_POINT="cf_process"
RUNTIME="python37"
REGION=${GCP_REGION:-us-central-1}
SOURCE_BUCKET=${GCP_SOURCE_BUCKET}

echo "===packaging==="
docker build -t cf-build -f Dockerfile.build .
docker create -ti --name build cf-build bash
docker cp build:/tmp/package.zip ./package.zip

gsutil cp package.zip gs://${SOURCE_BUCKET}/

gcloud functions deploy ${FUNCTION_NAME} \
  --entry-point ${ENTRY_POINT} \
  --runtime ${RUNTIME} \
  --project ${PROJECT_NAME} \
  --trigger-http