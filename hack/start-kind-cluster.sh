#!/bin/bash

set -x

declare -r tmp_kubeconfig=/tmp/kubeconfig
declare -r kubectl="kubectl --kubeconfig $tmp_kubeconfig"

kind create cluster --name kind --image kindest/node:v1.17.11
kind get kubeconfig > $tmp_kubeconfig
docker exec kind-control-plane sh -c 'echo nameserver 8.8.8.8 > /etc/resolv.conf'
docker exec kind-control-plane sh -c 'echo options ndots:0 >> /etc/resolv.conf'

$kubectl label node --overwrite --all topology.kubernetes.io/zone=az1
