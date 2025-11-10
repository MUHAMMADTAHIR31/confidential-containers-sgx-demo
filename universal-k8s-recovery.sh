#!/bin/bash
set -e  # Exit on any error

# Universal Kubernetes Recovery Script
# Based on official Kubernetes documentation

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

echo "=========================================="
echo "Kubernetes Recovery - Complete Reset"
echo "=========================================="
echo ""
echo "WARNING: This will delete all pods and cluster data!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Disabling swap (required by Kubernetes)..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "✓ Swap disabled permanently"

echo ""
echo "Step 2: Resetting Kubernetes..."
kubeadm reset -f
echo "✓ Kubernetes reset"

echo ""
echo "Step 3: Cleaning up..."
rm -rf /etc/cni/net.d
rm -rf /etc/kubernetes
rm -rf /var/lib/etcd
rm -rf /var/lib/kubelet
rm -rf /var/lib/dockershim
rm -rf $HOME/.kube
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
# Kill any remaining processes using Kubernetes ports
pkill -9 kube-apiserver || true
pkill -9 kube-controller || true
pkill -9 kube-scheduler || true
pkill -9 etcd || true
sleep 2
echo "✓ Cleanup complete"

echo ""
echo "Step 4: Reloading systemd and starting services..."
systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd
systemctl enable kubelet
systemctl start kubelet
echo "✓ Services started"

echo ""
echo "Step 5: Detecting node IP..."
# Get the primary IP (first non-loopback, non-docker IP)
NODE_IP=$(hostname -I | awk '{print $1}')
echo "✓ Using IP: $NODE_IP"

echo ""
echo "Step 6: Initializing cluster (2-3 minutes)..."
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$NODE_IP \
  --ignore-preflight-errors=Port-6443,Port-10259,Port-10257,Port-2379,Port-2380,NumCPU,Mem

echo ""
echo "Step 7: Configuring kubectl..."
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo "✓ kubectl configured"

echo ""
echo "Step 8: Removing taints..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true
echo "✓ Taints removed"

echo ""
echo "Step 9: Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo "✓ Flannel installed"

echo ""
echo "Step 10: Waiting for cluster ready (60s)..."
sleep 60

echo ""
echo "=========================================="
echo "✓ Kubernetes Recovery Complete!"
echo "=========================================="
kubectl get nodes
kubectl get pods -A

echo ""
echo "Cluster is ready!"
echo "Note: If node shows NotReady, wait 1-2 minutes for Flannel."
