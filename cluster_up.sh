#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
# # Unless required by applicable law or agreed to in writing, software # distributed under the License is distributed on an "AS IS" BASIS, # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions

#	gsutil mb gs://<bucket>
# gsutil defacl set public-read gs://<bucket>

set -e

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

# Check for cluster name as first (and only) arg
CLUSTER_NAME=$1
IMAGE=$2
NUM_NODES=2
NETWORK=default
ZONE=us-central1-b

DATABASE=$3
GCLOUD_PROJECT= $4

gcloud components update --quiet

# patch postgres instance to ensure its running
gcloud sql instances patch ${DATABASE} --activation-policy ALWAYS

gcloud iam service-accounts list|grep "${CLUSTER_NAME} DB Service Account" > /dev/null
if [ $? == 1]; then
  gcloud iam service-accounts create isba-db --display-name "ISBA DB Service Account"
  gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT} --member serviceAccount:isba-db@rapid-smithy-177819.iam.gserviceaccount.com --role roles/cloudsql.client
  gcloud projects add-iam-policy-binding ${GCLOUD_PROJECT} --member serviceAccount:isba-db@rapid-smithy-177819.iam.gserviceaccount.com --role roles/storage.objectViewer
  gcloud iam service-accounts keys create credentials.json --iam-account isba-db@rapid-smithy-177819.iam.gserviceaccount.com
fi

gcloud container clusters create ${CLUSTER_NAME} \
  --num-nodes ${NUM_NODES} \
  --scopes "https://www.googleapis.com/auth/projecthosting,https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform" \
  --zone ${ZONE} \
  --network ${NETWORK} || error_exit "error creating cluster"

# Make kubectl use new cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE}

kubectl create secret generic cloudsql-oauth-credentials --from-file=credentials.json=secrets/cloudsql/credentials.json
kubectl create secret generic cloudsql --from-literal=username=dev --from-literal=password=justtestit

kubectl create -f sqlproxy/postgres-proxy.yml
kubectl create -f sqlproxy/proxy-service.yml
echo "wait for postgres"
while :
  do kubectl get pods -lapp=postgres-proxy -o=custom-columns=STATUS=.status.phase 2> /dev/null|grep Running > /dev/null
  if [ $? == 0 ]; then
    break
  fi
  sleep 30
done

echo "settings image tag to ${IMAGE}"
SED_SCRIPT="s/\{\{ image_tag \}\}/${IMAGE}/g"

echo "running migrations"
pod_name=$(kubectl get pods -o name -l=job-name=migrations)
kubectl logs -f ${pod_name} migrations
kubectl get jobs -l=app=migrations -o=custom-columns=FAILED:.status.failed > /dev/null 2>&1
if [ $? == 0 ]; then
  echo "migration job failed"
  kubectl delete -f jobs/migrations.yml
  exit 2
fi

# ./manage.py collectstatic
# gsutil rsync -R static/ gs:<bucket>/static/
#kubectl create -f app/app.yml app/app-service.yml

echo "done."
