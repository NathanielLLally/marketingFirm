#!/bin/sh

#STREAM='stable'
#gcloud compute images describe-from-family --project "fedora-coreos-cloud" "fedora-coreos-${STREAM}" | grep name

#gcloud org-policies describe constraints/compute.vmExternalIpAccess --organization 568120179692

# /tmp/eip.yaml
#
#etag: CLr97LsGEMi1/9IC-
#name: organizations/568120179692/policies/compute.vmExternalIpAccess
#spec:
#  etag: CLr97LsGEMi1/9IC
#  inheritFromParent: true
#  rules:
#  - allowAll: true
#  updateTime: '2025-01-06T02:23:54.710925Z'" >> /tmp/eip.yaml

#gcloud org-policies set-policy /tmp/eip.yaml

sudo dnf update && sudo dnf -y install nginx


