#!/bin/bash

usage() {
    echo "Usage: Utility script for installing a RKE2 cluster"
    echo "  -t  [string_val] cluster join token"
    echo "  -s  [string_val] cluster server join ip (Ex. 10.0.0.1)"
    echo "  -a               agent flag"
    echo "  -u  [string_val] default user for Kube config (default: user)"
    echo "  -u  [string_val] Network Device name (i.e. eth0, ens3, ens160)"
    echo "  -v               Verbose information about RKE2 installation"
    echo "  -d               Print Debug information"
    echo "EXAMPLE Usage: "
    echo "  Server install: $0 -t 24dfa62bbe214bdf -s 10.10.0.1"
    echo "  Agent install:  $0 -t 24dfa62bbe214bdf -s 10.10.0.1 -a"
    exit 1
}

verbose_docs() {
echo "
RKE2 provides excellent out of the box tools to install a new RKE2 cluster. However, it requires additional knowledge and configuration to build a HA cluster. This script intends to reduce the need for such understanding and provides a best effort to easily install a RKE2 cluster.

Script Parameters:

'-t' RKE2 uses a token to join nodes to the cluster. This token can be generated by RKE2 on the first node install, however, this script assumes the token is generated and provided by the caller using the '-t' parameter.

'-s' RKE2 initializes on a single node. The '-s' argument is the IP address of this node in the cluster. RKE2 running on this node provides information during \"cluster up\" and node join operations. It does not have any impact on the cluster operation after initialization. i.e. RKE2 master nodes work together in an HA configuration.

'-a' RKE2 has server or agent nodes. Agent nodes are Kubernetes worker nodes and do not host critical services like etcd or control-plane deployments.

Recommended Usage:
    Node0: \$0 -t <token> -s <node0_ip>
    Node1: \$0 -t <token> -s <node0_ip>
    Node2: \$0 -t <token> -s <node0_ip>
    NodeN: \$0 -t <token> -s <node0_ip> -a

This recommendation would build an HA cluster consistent with the recommendations in the RKE2 documentation. These commands could be executed simultaneously on each node. The RKE2 systemd service (registered by this script) has retry logic and will wait for the first node to be ready in order to join the cluster.

RKE2 Links:
- RKE2 Releases: https://github.com/rancher/rke2/releases
- Air-Gap Install: https://docs.rke2.io/install/airgap#tarball-method
- RKE2 Installation options: https://docs.rke2.io/install/methods
- RKE2 Configuration file: https://docs.rke2.io/install/configuration
- RKE2 High-availability: https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-cluster-setup/rke2-for-rancher
"
exit 0
}

info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

debug() {
    if [ "$debug" -eq 1 ]; then
        echo -e "\033[1;34m[DEBUG]\033[0m $1"
    fi
}

if [ $# -eq 0 ]; then
    usage
fi

debug=0
user="user"

while getopts "t:s:au:n:vd" o; do
    case "${o}" in
    t) token="${OPTARG}" ;;
    s) server_ip="${OPTARG}" ;;
    a) agent=1 ;;
    u) user="${OPTARG}" ;;
    n) network_device="${OPTARG}" ;;
    d) debug=1 ;;
    v) verbose_docs ;;
    *) usage ;;
    esac
done
shift $(($OPTIND - 1))

info "Moving Artifacts for Installation"

artifacts_dir=/root/rke2-artifacts/
mkdir -p $artifacts_dir
cp rke2-images.linux-amd64.tar.zst $artifacts_dir
cp rke2.linux-amd64.tar.gz $artifacts_dir
cp install.sh $artifacts_dir
cp sha256sum-amd64.txt $artifacts_dir
cp local-path-storage.yaml $artifacts_dir

info "Preparing Installation"

node_ip=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d '/' -f1)
if [ -z $server_ip ]; then
    info "Server Join IP not provided, this is the first node in the cluster"
    server_ip=$node_ip
fi

debug "Token: $token"
debug "Server IP: $server_ip"
debug "Agent: $agent"
debug "Node IP: $node_ip"

info "Creating RKE2 Config file"

config_dir=/etc/rancher/rke2
config_file=$config_dir/config.yaml
mkdir -p $config_dir

cat <<EOF >"$config_file"
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server
token: "$token"
EOF

if [ "$server_ip" != "$node_ip" ]; then
    debug "Updating Config file with Cluster Join Server IP"
    echo "server: https://${server_ip}:9345" | sudo tee -a $config_dir/config.yaml >/dev/null
fi

info "Installing RKE2"
sudo INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts/ sh /root/rke2-artifacts/install.sh
if [ -z $agent ]; then
    debug "Enabling systemd service for RKE2 Server"
    sudo systemctl enable rke2-server.service
    sudo systemctl start rke2-server.service
else
    debug "Enabling systemd service for RKE2 Agent"
    sudo systemctl enable rke2-agent.service
    sudo systemctl start rke2-agent.service
fi

if [ "$server_ip" = "$node_ip" ]; then
    debug "Copying kubeconfig to user home directory"
    kube_dir=/home/$user/.kube
    mkdir -p $kube_dir
    kube_config=$kube_dir/config
    sudo cp /etc/rancher/rke2/rke2.yaml $kube_config
    sudo chown $user:$user $kube_config

    info "Adding local-path-storage"
    /var/lib/rancher/rke2/bin/kubectl --kubeconfig=$kube_config apply -f local-path-storage.yaml
    /var/lib/rancher/rke2/bin/kubectl --kubeconfig=$kube_config patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi



info "RKE2 Installation Complete"
