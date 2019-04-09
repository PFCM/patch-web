#! /bin/sh

# builds the frontend and deploys to gcs
set -ev

SOURCE_BUCKET=${GCP_SOURCE_BUCKET}

cd caterator
npm install
elm-app build

gsutil rsync build/ gs://${SOURCE_BUCKET}/
