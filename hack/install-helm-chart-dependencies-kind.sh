#!/usr/bin/env bash

set -x

declare -r e2e_run_ref=${GITHUB_REF:-outside-github-$(hostname)}
declare -r e2e_run_id=${GITHUB_RUN_ID:-none}
declare -r humio_hostname=${E2E_LOGS_HUMIO_HOSTNAME:-none}
declare -r humio_ingest_token=${E2E_LOGS_HUMIO_INGEST_TOKEN:-none}
declare -r tmp_kubeconfig=/tmp/kubeconfig

export PATH=$BIN_DIR:$PATH

kind get kubeconfig > $tmp_kubeconfig

if [[ $humio_hostname != "none" ]] && [[ $humio_ingest_token != "none" ]]; then

  export E2E_FILTER_TAG=$(cat <<EOF
[FILTER]
    Name    modify
    Match   kube.*
    Set E2E_RUN_REF $e2e_run_ref
    Set E2E_RUN_ID $e2e_run_id
EOF
)

  helm repo add shipper https://humio.github.io/humio-helm-charts
  helm install --kubeconfig=$tmp_kubeconfig log-shipper shipper/humio-helm-charts --namespace=default \
  --set humio-fluentbit.enabled=true \
  --set humio-fluentbit.es.port=443 \
  --set humio-fluentbit.es.tls=true \
  --set humio-fluentbit.humioRepoName=operator-e2e \
  --set humio-fluentbit.customFluentBitConfig.e2eFilterTag="$E2E_FILTER_TAG" \
  --set humio-fluentbit.humioHostname=$humio_hostname \
  --set humio-fluentbit.token=$humio_ingest_token
fi

kubectl --kubeconfig=$tmp_kubeconfig create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install --kubeconfig=$tmp_kubeconfig cert-manager jetstack/cert-manager --namespace cert-manager \
--version v1.0.2 \
--set installCRDs=true

helm repo add humio https://humio.github.io/cp-helm-charts
helm install --kubeconfig=$tmp_kubeconfig humio humio/cp-helm-charts --namespace=default \
--set cp-zookeeper.servers=1 --set cp-kafka.brokers=1 --set cp-schema-registry.enabled=false \
--set cp-kafka-rest.enabled=false --set cp-kafka-connect.enabled=false \
--set cp-ksql-server.enabled=false --set cp-control-center.enabled=false

while [[ $(kubectl --kubeconfig=$tmp_kubeconfig get pods humio-cp-zookeeper-0 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
do
  echo "Waiting for humio-cp-zookeeper-0 pod to become Ready"
  sleep 10
done

while [[ $(kubectl --kubeconfig=$tmp_kubeconfig get pods humio-cp-kafka-0 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
do
  echo "Waiting for humio-cp-kafka-0 pod to become Ready"
  sleep 10
done
