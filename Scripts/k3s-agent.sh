#!/usr/bin/env bash
# Vagrant provisioner of the "agent" VM (runs as root, once, at `vagrant up`).
#
#   1. NFS client, so the kubelet can mount the volumes exported by the master.
#   2. K3s agent joining the server of the master VM.
#
# Usage: k3s-agent.sh <node-ip> <master-ip> <k3s-version>   (K3S_TOKEN in the environment)
set -euo pipefail

USAGE="usage: k3s-agent.sh <node-ip> <master-ip> <k3s-version>"
NODE_IP=${1:?$USAGE}
MASTER_IP=${2:?$USAGE}
K3S_VERSION=${3:?$USAGE}
: "${K3S_TOKEN:?K3S_TOKEN must be set}"

log() { echo "[agent] $*"; }

# Name of the interface holding the private network address (eth1, enp0s8...).
# Flannel must use it: the first interface is VirtualBox's NAT, which has the
# same address (10.0.2.15) on every VM and cannot carry pod traffic.
private_iface() {
  ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^" ip "/" { print $2; exit }'
}

# The kubelet expects swap to be off.
log "disabling swap"
swapoff -a
sed -i '/\sswap\s/ s/^#*/#/' /etc/fstab

log "installing the NFS client"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nfs-common >/dev/null

IFACE=$(private_iface)
[[ -n "$IFACE" ]] || { echo "[agent] error: no interface holds $NODE_IP" >&2; exit 1; }

log "waiting for the K3s server on $MASTER_IP"
until curl -ksf "https://$MASTER_IP:6443/ping" >/dev/null; do
  sleep 3
done

# Graceful node shutdown: when the VM powers off, the kubelet delays the
# shutdown and first stops the pods properly (SIGTERM, then their grace period).
mkdir -p /etc/rancher/k3s
printf '%s\n' \
  'apiVersion: kubelet.config.k8s.io/v1beta1' \
  'kind: KubeletConfiguration' \
  'shutdownGracePeriod: 90s' \
  'shutdownGracePeriodCriticalPods: 15s' > /etc/rancher/k3s/kubelet.config

log "installing K3s $K3S_VERSION (agent, flannel on $IFACE)"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_URL="https://$MASTER_IP:6443" K3S_TOKEN="$K3S_TOKEN" sh -s - agent \
  --node-ip "$NODE_IP" \
  --flannel-iface "$IFACE" \
  --kubelet-arg config=/etc/rancher/k3s/kubelet.config

log "K3s agent joined https://$MASTER_IP:6443"
