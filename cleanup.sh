#!/bin/bash
# CoCo SGX Demo - Complete Cleanup Script
# Removes all installed components and restores system

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Please run with sudo: sudo ./cleanup.sh${NC}"
   exit 1
fi

cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              🧹 CoCo SGX Demo - Complete Cleanup 🧹          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

This will remove:
  • All Docker containers, images, and volumes
  • Docker CE and docker-compose
  • Kubernetes cluster (kubeadm, kubelet, kubectl)
  • CoCo operator and runtime
  • Trustee services
  • All configuration files
  • Network settings

EOF

echo -e "${RED}⚠️  WARNING: COMPLETE SYSTEM CLEANUP ⚠️${NC}"
echo -e "${RED}This will UNINSTALL Docker and Kubernetes completely!${NC}"
echo -e "${YELLOW}This is useful for fresh installation but removes ALL Docker containers!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo
echo -e "${YELLOW}Starting complete cleanup...${NC}"
echo

# Stop Trustee services
echo -e "${YELLOW}[1/8] Stopping Trustee services...${NC}"
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# Check common locations for Trustee services
TRUSTEE_FOUND=false

# Try /root/coco-demo/trustee first (most common)
if [ -d "/root/coco-demo/trustee" ]; then
    cd /root/coco-demo/trustee
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
    TRUSTEE_FOUND=true
fi

# Try user's home directory
if [ -d "$ACTUAL_HOME/coco-demo/trustee" ]; then
    cd $ACTUAL_HOME/coco-demo/trustee
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
    TRUSTEE_FOUND=true
fi

# Try ~/trustee as well
if [ -d "$ACTUAL_HOME/trustee" ]; then
    cd $ACTUAL_HOME/trustee
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
    TRUSTEE_FOUND=true
fi

if [ -d "/root/trustee" ]; then
    cd /root/trustee
    docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null || true
    TRUSTEE_FOUND=true
fi

# Force remove any remaining trustee containers
docker ps -a --filter "name=trustee" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true

if [ "$TRUSTEE_FOUND" = true ]; then
    echo -e "${GREEN}✓ Trustee services stopped${NC}"
else
    echo -e "${GREEN}✓ No Trustee services directory found${NC}"
fi

# Stop all Docker containers
echo -e "${YELLOW}[2/8] Stopping all Docker containers...${NC}"
if command -v docker &> /dev/null; then
    docker stop $(docker ps -aq) 2>/dev/null || true
    echo -e "${GREEN}✓ All Docker containers stopped${NC}"
else
    echo -e "${GREEN}✓ Docker not found${NC}"
fi

# Delete Kubernetes resources
echo -e "${YELLOW}[3/8] Deleting Kubernetes resources...${NC}"
if command -v kubectl &> /dev/null; then
    # Delete demo pods
    kubectl delete pod sgx-demo-pod --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete pod coco-complete-encrypted --ignore-not-found=true --timeout=10s 2>/dev/null || true
    
    # Delete CoCo operator namespace and resources
    kubectl delete namespace confidential-containers-system --ignore-not-found=true --timeout=30s 2>/dev/null || true
    
    echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
else
    echo -e "${GREEN}✓ kubectl not found, skipping${NC}"
fi

# Reset Kubernetes cluster
echo -e "${YELLOW}[4/8] Resetting Kubernetes cluster...${NC}"
if command -v kubeadm &> /dev/null; then
    kubeadm reset -f 2>/dev/null || true
    echo -e "${GREEN}✓ Kubernetes cluster reset${NC}"
else
    echo -e "${GREEN}✓ kubeadm not found, skipping${NC}"
fi

# Uninstall Kubernetes
echo -e "${YELLOW}[5/8] Uninstalling Kubernetes...${NC}"
if command -v kubeadm &> /dev/null; then
    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true
    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
    apt-get purge -y kubeadm kubectl kubelet kubernetes-cni 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni /opt/cni /var/lib/cni 2>/dev/null || true
    echo -e "${GREEN}✓ Kubernetes uninstalled${NC}"
else
    echo -e "${GREEN}✓ Kubernetes not installed${NC}"
fi

# Remove all Docker containers, images, and volumes
echo -e "${YELLOW}[6/8] Removing all Docker data...${NC}"
if command -v docker &> /dev/null; then
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    docker rmi -f $(docker images -aq) 2>/dev/null || true
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    docker system prune -af --volumes 2>/dev/null || true
    echo -e "${GREEN}✓ All Docker data removed${NC}"
else
    echo -e "${GREEN}✓ Docker not found${NC}"
fi

# Uninstall Docker
echo -e "${YELLOW}[7/8] Uninstalling Docker...${NC}"
if command -v docker &> /dev/null; then
    systemctl stop docker 2>/dev/null || true
    systemctl stop docker.socket 2>/dev/null || true
    systemctl disable docker 2>/dev/null || true
    systemctl disable docker.socket 2>/dev/null || true
    
    # Remove Docker CE packages
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    
    # Remove Ubuntu/Snap Docker packages
    apt-get purge -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
    snap remove docker 2>/dev/null || true
    
    apt-get autoremove -y 2>/dev/null || true
    
    # Remove all Docker data directories
    rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true
    rm -rf /etc/docker 2>/dev/null || true
    rm -rf /etc/containerd 2>/dev/null || true
    rm -rf /var/run/docker.sock 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
    rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    
    # Remove Docker group
    groupdel docker 2>/dev/null || true
    
    echo -e "${GREEN}✓ Docker uninstalled${NC}"
else
    echo -e "${GREEN}✓ Docker not installed${NC}"
fi

# Clean up all configuration files
echo -e "${YELLOW}[8/8] Cleaning up configuration files...${NC}"

rm -rf $ACTUAL_HOME/.kube 2>/dev/null || true
rm -rf $ACTUAL_HOME/coco-demo 2>/dev/null || true
rm -rf $ACTUAL_HOME/trustee 2>/dev/null || true
rm -rf /root/.kube 2>/dev/null || true
rm -rf /root/coco-demo 2>/dev/null || true
rm -rf /root/trustee 2>/dev/null || true
rm -f /tmp/sgx-demo-pod.yaml 2>/dev/null || true
rm -rf /etc/systemd/system/kubelet.service.d 2>/dev/null || true
rm -f /usr/lib/systemd/system/kubelet.service 2>/dev/null || true

echo -e "${GREEN}✓ Configuration files cleaned up${NC}"

# Clean up network settings
echo -e "${YELLOW}Cleaning network settings...${NC}"

# Clean iptables rules
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true
iptables -t filter -F 2>/dev/null || true
iptables -t filter -X 2>/dev/null || true

# Remove Docker network interfaces
ip link delete docker0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete cni0 2>/dev/null || true

# Remove all veth interfaces (Kubernetes pod interfaces)
for iface in $(ip link show 2>/dev/null | grep veth | awk -F: '{print $2}' | tr -d ' '); do
    ip link delete "$iface" 2>/dev/null || true
done

# Remove CNI configuration
rm -rf /etc/cni/net.d 2>/dev/null || true
rm -rf /opt/cni/bin 2>/dev/null || true
rm -rf /var/lib/cni 2>/dev/null || true

# Clean up network namespaces
ip netns list 2>/dev/null | grep cni | while read ns; do
    ip netns delete "$ns" 2>/dev/null || true
done

# Reload systemd
systemctl daemon-reload 2>/dev/null || true

echo -e "${GREEN}✓ Network settings cleaned${NC}"

echo
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║              ✅ COMPLETE CLEANUP FINISHED! ✅               ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

echo
echo -e "${GREEN}All components have been completely removed:${NC}"
echo -e "  ${GREEN}✓${NC} Docker and all containers removed"
echo -e "  ${GREEN}✓${NC} Kubernetes completely uninstalled"
echo -e "  ${GREEN}✓${NC} CoCo operator removed"
echo -e "  ${GREEN}✓${NC} Trustee services removed"
echo -e "  ${GREEN}✓${NC} All configuration files deleted"
echo -e "  ${GREEN}✓${NC} Network settings cleaned"
echo
echo -e "${GREEN}Your system has been restored to a clean state.${NC}"
echo
echo -e "${YELLOW}To reinstall the demo from scratch, run:${NC}"
echo -e "${GREEN}  sudo ./setup-coco-demo.sh${NC}"
echo
echo -e "${YELLOW}Note: This will reinstall Docker and Kubernetes automatically.${NC}"
echo