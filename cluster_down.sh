#!/bin/bash
kubectl delete -f isba/isba-service.yml
kubectl delete -f isba/isba.yml

gcloud sql instances patch isbadbase --activation-policy NEVER
gcloud container clusters delete ispa --quiet
