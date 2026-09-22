#!/usr/bin/env bash
# orchestrator.sh - creates, starts, stops and manages the K3s cluster (two
# Vagrant VMs) and the microservices deployed on it.
#
# Usage: ./orchestrator.sh <command> [options]
#
# Cluster:
#   create     create the VMs, install K3s, configure kubectl, deploy the stack
#   start      boot the VMs of an existing cluster and wait for the stack
#   stop       shut the VMs down (the data is kept)
#   destroy    delete the VMs and the "orchestrator" kubectl context
#   status     show the VMs, the nodes and every deployed resource
#
# Stack:
#   deploy     generate the missing secrets and apply every manifest
#   undeploy   delete the workloads (volumes, data and secrets are kept)
#   push       build the six images and push them to Docker Hub
#   test       run the audit scenario against the gateway
#   load       generate CPU load on the gateway to trigger the autoscalers
#   bonus      deploy the dashboards (Headlamp, Dozzle)
#   help       show this help
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$ROOT_DIR/Manifests"
SCRIPTS_DIR="$ROOT_DIR/Scripts"

MASTER_IP=192.168.56.110
KUBE_CONTEXT=orchestrator
# kubectl writes to the first file listed in $KUBECONFIG, if any.
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
KUBECONFIG_FILE="${KUBECONFIG_FILE%%:*}"
WAIT_TIMEOUT=${WAIT_TIMEOUT:-300}

# Applied in this order: storage and stateful services first, then the apps
# that depend on them. The *.yaml of Manifests/secrets/ come before all of them.
MANIFESTS=(
  storage.yaml
  inventory-database.yaml
  billing-database.yaml
  rabbitmq.yaml
  inventory-app.yaml
  billing-app.yaml
  api-gateway.yaml
)
STATEFULSETS=(inventory-db billing-db rabbitmq billing-app)
DEPLOYMENTS=(inventory-app api-gateway)

# Vagrant looks for the Vagrantfile here, wherever the script is called from.
export VAGRANT_CWD="$ROOT_DIR"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BLUE=$'\033[1;34m' RESET=$'\033[0m'
else
  BLUE='' RESET=''
fi

log() { echo "${BLUE}==>${RESET} $*"; }
die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed '$d' | cut -c3-
}

# Every kubectl call targets the context of this cluster explicitly, so the
# script never acts on another cluster of the user's kubeconfig.
kube() { kubectl --context "$KUBE_CONTEXT" "$@"; }

require() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "missing command(s): ${missing[*]} (see the prerequisites in README.md)"
}

# State of a VM as reported by Vagrant: not_created, running, poweroff, saved...
vm_state() {
  vagrant status "$1" --machine-readable | awk -F, -v vm="$1" '$2 == vm && $3 == "state" { print $4 }'
}

require_cluster() {
  [[ "$(vm_state master)" != not_created ]] || die "the cluster does not exist: run ./orchestrator.sh create"
}

TMP_DIR=""
cleanup() { [[ -z "$TMP_DIR" ]] || rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# --- kubectl configuration ---------------------------------------------------

remove_kube_context() {
  [[ -f "$KUBECONFIG_FILE" ]] || return 0
  local kc=(kubectl config --kubeconfig "$KUBECONFIG_FILE")
  if [[ "$("${kc[@]}" current-context 2>/dev/null)" == "$KUBE_CONTEXT" ]]; then
    "${kc[@]}" unset current-context >/dev/null
  fi
  "${kc[@]}" delete-context "$KUBE_CONTEXT" >/dev/null 2>&1 || true
  "${kc[@]}" delete-cluster "$KUBE_CONTEXT" >/dev/null 2>&1 || true
  "${kc[@]}" delete-user "$KUBE_CONTEXT" >/dev/null 2>&1 || true
}

# Copies the admin kubeconfig of K3s from the master VM into the user's
# kubeconfig as the "orchestrator" context (cluster, user and context renamed
# from "default", API address rewritten from 127.0.0.1 to the master IP), then
# makes it the current context. Other contexts of the file are preserved.
install_kubeconfig() {
  log "configuring kubectl (context \"$KUBE_CONTEXT\" in $KUBECONFIG_FILE)"
  TMP_DIR=${TMP_DIR:-$(mktemp -d)}
  local new="$TMP_DIR/k3s.yaml" merged="$TMP_DIR/merged.yaml"

  vagrant ssh master -c 'sudo cat /etc/rancher/k3s/k3s.yaml' 2>/dev/null | tr -d '\r' |
    sed -e "s#https://127.0.0.1:6443#https://$MASTER_IP:6443#" \
        -e "s/: default\$/: $KUBE_CONTEXT/" >"$new"
  grep -q "server: https://$MASTER_IP:6443" "$new" || die "could not read /etc/rancher/k3s/k3s.yaml on the master VM"

  mkdir -p "$(dirname "$KUBECONFIG_FILE")"
  if [[ -s "$KUBECONFIG_FILE" ]]; then
    remove_kube_context
    # The first file wins on conflicts, so the fresh credentials take precedence.
    KUBECONFIG="$new:$KUBECONFIG_FILE" kubectl config view --flatten >"$merged"
  else
    cp "$new" "$merged"
  fi
  install -m 600 "$merged" "$KUBECONFIG_FILE"
  kubectl config use-context "$KUBE_CONTEXT" >/dev/null
}

# --- Waits -------------------------------------------------------------------

wait_for_nodes() {
  log "waiting for the master and agent nodes to be Ready"
  local deadline=$((SECONDS + WAIT_TIMEOUT)) ready
  while :; do
    # "Ready" or "Ready,SchedulingDisabled" (a node cordoned by stop).
    ready=$(kube get nodes --no-headers 2>/dev/null | awk '$2 ~ /^Ready(,|$)/' | wc -l)
    [[ "$ready" -eq 2 ]] && break
    [[ $SECONDS -lt $deadline ]] || die "the nodes are not Ready after ${WAIT_TIMEOUT}s (kubectl get nodes)"
    sleep 5
  done
  kube get nodes
}

# stop cordons both nodes before powering them off; every boot schedules pods
# on them again.
uncordon_nodes() {
  kube uncordon master agent >/dev/null
}

wait_for_workloads() {
  log "waiting for the workloads to be ready"
  local name
  for name in "${STATEFULSETS[@]}"; do
    kube rollout status "statefulset/$name" --timeout="${WAIT_TIMEOUT}s"
  done
  for name in "${DEPLOYMENTS[@]}"; do
    kube rollout status "deployment/$name" --timeout="${WAIT_TIMEOUT}s"
  done
}

# At power-off the kubelet stops the pods gracefully and marks them terminated.
# The StatefulSets recreate theirs under the same name, but the ReplicaSets
# (ours, CoreDNS, metrics-server...) create new pods and leave the old ones
# behind as "Completed"/"Error": remove them.
delete_terminated_pods() {
  local phase
  for phase in Succeeded Failed; do
    kube delete pods --all-namespaces --field-selector="status.phase==$phase" --ignore-not-found >/dev/null
  done
}

# --- Commands ----------------------------------------------------------------

cmd_deploy() {
  require kubectl
  log "generating the secret manifests"
  "$SCRIPTS_DIR/generate-secrets.sh"
  log "applying the manifests"
  # Only the generated *.yaml files are read, the *.yaml.example templates are skipped.
  kube apply -f "$MANIFESTS_DIR/secrets/"
  local manifest
  for manifest in "${MANIFESTS[@]}"; do
    kube apply -f "$MANIFESTS_DIR/$manifest"
  done
  wait_for_workloads
  echo "gateway: http://$MASTER_IP:3000"
}

cmd_undeploy() {
  require kubectl
  log "deleting the workloads (volumes, data and secrets are kept)"
  local i
  # Reverse order: the apps go before the services they depend on. storage.yaml
  # (index 0) is skipped so the claims stay bound to their volumes.
  for ((i = ${#MANIFESTS[@]} - 1; i > 0; i--)); do
    kube delete --ignore-not-found -f "$MANIFESTS_DIR/${MANIFESTS[i]}"
  done
}

cmd_create() {
  require vagrant VBoxManage kubectl
  log "creating and provisioning the VMs (vagrant up)"
  vagrant up
  install_kubeconfig
  wait_for_nodes
  uncordon_nodes
  cmd_deploy
  echo "cluster created"
}

cmd_start() {
  require vagrant VBoxManage kubectl
  require_cluster
  log "booting the VMs"
  vagrant up --no-provision
  install_kubeconfig
  wait_for_nodes
  uncordon_nodes
  delete_terminated_pods
  wait_for_workloads
  # Right after a boot the controllers may still report the replicas of the
  # previous one: the pods themselves must be Ready.
  kube wait --for=condition=Ready pod -l app.kubernetes.io/part-of=orchestrator --timeout="${WAIT_TIMEOUT}s"
  echo "cluster started"
}

cmd_stop() {
  require vagrant VBoxManage
  require_cluster
  # Cordon both nodes first: otherwise the pods the agent stops at power-off
  # are rescheduled onto the master, and are still starting when the master
  # powers off in turn, which then hangs until Vagrant forces it off.
  if [[ "$(vm_state master)" == running ]] && command -v kubectl >/dev/null 2>&1; then
    log "cordoning the nodes (no pod is rescheduled during the shutdown)"
    kube cordon master agent >/dev/null || true
  fi
  log "shutting down the VMs"
  # One at a time, the agent first: its pods stop while the master still
  # serves the API and the NFS volumes they have mounted.
  vagrant halt agent
  vagrant halt master
  echo "cluster stopped"
}

cmd_destroy() {
  require vagrant VBoxManage
  log "deleting the VMs"
  vagrant destroy -f
  remove_kube_context
  echo "cluster destroyed"
}

cmd_status() {
  require vagrant VBoxManage kubectl
  vagrant status
  require_cluster
  if [[ "$(vm_state master)" != running ]]; then
    echo "the master VM is not running: ./orchestrator.sh start"
    return 0
  fi
  echo
  kube get nodes -o wide
  echo
  kube get all -o wide
  echo
  kube get hpa,pvc,pv,secrets
}

cmd_bonus() {
  require kubectl
  log "deploying the dashboards"
  kube apply -f "$MANIFESTS_DIR/bonus/"
  kube rollout status -n dashboards deployment/headlamp --timeout="${WAIT_TIMEOUT}s"
  kube rollout status -n dashboards deployment/dozzle --timeout="${WAIT_TIMEOUT}s"
  echo "cluster dashboard (Headlamp): http://$MASTER_IP:4466  (token: ./orchestrator.sh bonus-token)"
  echo "logs dashboard (Dozzle):      http://$MASTER_IP:8888"
}

cmd_bonus_token() {
  require kubectl
  kube -n dashboards create token headlamp-admin --duration=24h
}

main() {
  local command=${1:-help}
  [[ $# -eq 0 ]] || shift
  case "$command" in
    create) cmd_create ;;
    start) cmd_start ;;
    stop) cmd_stop ;;
    destroy) cmd_destroy ;;
    status) cmd_status ;;
    deploy) cmd_deploy ;;
    undeploy) cmd_undeploy ;;
    push) "$SCRIPTS_DIR/push-images.sh" "$@" ;;
    test) KUBE_CONTEXT=$KUBE_CONTEXT "$SCRIPTS_DIR/test-api.sh" "$@" ;;
    load) KUBE_CONTEXT=$KUBE_CONTEXT "$SCRIPTS_DIR/load-test.sh" "$@" ;;
    bonus) cmd_bonus ;;
    bonus-token) cmd_bonus_token ;;
    help | -h | --help) usage ;;
    *)
      usage >&2
      die "unknown command '$command'"
      ;;
  esac
}

main "$@"
