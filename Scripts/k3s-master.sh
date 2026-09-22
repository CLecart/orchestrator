#!/usr/bin/env bash
# Vagrant provisioner of the "master" VM (runs as root, once, at `vagrant up`).
#
#   1. NFS server exporting /srv/nfs/k3s: the persistent volumes of the
#      databases and of RabbitMQ live here, so their pods can be scheduled on
#      either node and still find their data.
#   2. K3s server (control plane, also schedulable for workloads).
#
# Usage: k3s-master.sh <node-ip> <k3s-version>   (K3S_TOKEN in the environment)
set -euo pipefail

NODE_IP=${1:?usage: k3s-master.sh <node-ip> <k3s-version>}
K3S_VERSION=${2:?usage: k3s-master.sh <node-ip> <k3s-version>}
: "${K3S_TOKEN:?K3S_TOKEN must be set}"

NFS_ROOT=/srv/nfs/k3s
NFS_CLIENTS="${NODE_IP%.*}.0/24"

log() { echo "[master] $*"; }

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

log "installing the NFS server"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nfs-kernel-server >/dev/null

# One directory per persistent volume, owned by the uid:gid the container runs
# as (see securityContext in the manifests): PostgreSQL requires a data
# directory it owns with mode 0700, and root_squash forbids a root chown later.
log "creating the volume directories in $NFS_ROOT"
install -d -m 0755 "$NFS_ROOT"
install -d -o 70  -g 70  -m 0700 "$NFS_ROOT/inventory-db"
install -d -o 70  -g 70  -m 0700 "$NFS_ROOT/billing-db"
install -d -o 100 -g 101 -m 0700 "$NFS_ROOT/rabbitmq"

mkdir -p /etc/exports.d
echo "$NFS_ROOT $NFS_CLIENTS(rw,sync,no_subtree_check,root_squash)" > /etc/exports.d/k3s.exports

# The pods of this node mount volumes exported by this very node: at shutdown
# the server must stop only after they are unmounted, or the unmount hangs.
mkdir -p /etc/systemd/system/nfs-server.service.d
printf '[Unit]\nBefore=remote-fs-pre.target\n' > /etc/systemd/system/nfs-server.service.d/10-loopback-mounts.conf
systemctl daemon-reload
systemctl enable --now nfs-server >/dev/null
exportfs -ra

IFACE=$(private_iface)
[[ -n "$IFACE" ]] || { echo "[master] error: no interface holds $NODE_IP" >&2; exit 1; }

# Graceful node shutdown: when the VM powers off, the kubelet delays the
# shutdown and first stops the pods properly (SIGTERM, then their grace period).
mkdir -p /etc/rancher/k3s
printf '%s\n' \
  'apiVersion: kubelet.config.k8s.io/v1beta1' \
  'kind: KubeletConfiguration' \
  'shutdownGracePeriod: 90s' \
  'shutdownGracePeriodCriticalPods: 15s' > /etc/rancher/k3s/kubelet.config

log "installing K3s $K3S_VERSION (server, flannel on $IFACE)"
# Traefik is disabled: the gateway is exposed by a LoadBalancer Service
# (K3s ServiceLB), no Ingress controller is needed.
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_TOKEN="$K3S_TOKEN" sh -s - server \
  --node-ip "$NODE_IP" \
  --advertise-address "$NODE_IP" \
  --tls-san "$NODE_IP" \
  --flannel-iface "$IFACE" \
  --disable traefik \
  --kubelet-arg config=/etc/rancher/k3s/kubelet.config

log "waiting for the node to be Ready"
until kubectl get node "$(hostname)" 2>/dev/null | grep -qw Ready; do
  sleep 3
done
log "K3s server ready on https://$NODE_IP:6443"
