#!/bin/sh

#STREAM='stable'
#gcloud compute images describe-from-family --project "fedora-coreos-cloud" "fedora-coreos-${STREAM}" | grep name

sudo dnf update && sudo dnf -y install nginx
