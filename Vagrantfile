# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Two-node K3s cluster on VirtualBox, driven by ./orchestrator.sh:
#
#   master  192.168.56.110  K3s server (control plane + workloads)
#                           + NFS server holding the persistent volumes
#   agent   192.168.56.111  K3s agent (workloads)
#
# Both VMs are provisioned by the shell scripts of Scripts/.

require "fileutils"
require "securerandom"

BOX         = "bento/ubuntu-24.04"
BOX_VERSION = "202510.26.0"
K3S_VERSION = "v1.36.4+k3s1"

MASTER = { name: "master", ip: "192.168.56.110", cpus: 2, memory: 2048 }
AGENT  = { name: "agent",  ip: "192.168.56.111", cpus: 2, memory: 2048 }

# Shared secret the agent presents to join the cluster. It is generated on the
# first run, kept out of Git (.vagrant/ is ignored) and reused afterwards.
TOKEN_FILE = File.join(File.dirname(__FILE__), ".vagrant", "k3s-token")
unless File.exist?(TOKEN_FILE)
  FileUtils.mkdir_p(File.dirname(TOKEN_FILE))
  File.write(TOKEN_FILE, SecureRandom.hex(32))
  File.chmod(0600, TOKEN_FILE)
end
K3S_TOKEN = File.read(TOKEN_FILE).strip

Vagrant.configure("2") do |config|
  config.vm.box         = BOX
  config.vm.box_version = BOX_VERSION
  # The provisioning scripts are uploaded over SSH: no shared folder (and no
  # dependency on the VirtualBox guest additions) is needed.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  # Leaves the kubelet time to stop the pods before the power-off (see the
  # shutdown-grace-period of the provisioning scripts).
  config.vm.graceful_halt_timeout = 180

  [MASTER, AGENT].each do |node|
    config.vm.define node[:name], primary: node == MASTER do |vm|
      vm.vm.hostname = node[:name]
      vm.vm.network "private_network", ip: node[:ip]

      vm.vm.provider "virtualbox" do |vb|
        vb.name         = "orchestrator-#{node[:name]}"
        vb.cpus         = node[:cpus]
        vb.memory       = node[:memory]
        vb.linked_clone = true
      end

      if node == MASTER
        vm.vm.provision "shell", path: "Scripts/k3s-master.sh",
          args: [node[:ip], K3S_VERSION],
          env:  { "K3S_TOKEN" => K3S_TOKEN }
      else
        vm.vm.provision "shell", path: "Scripts/k3s-agent.sh",
          args: [node[:ip], MASTER[:ip], K3S_VERSION],
          env:  { "K3S_TOKEN" => K3S_TOKEN }
      end
    end
  end
end
