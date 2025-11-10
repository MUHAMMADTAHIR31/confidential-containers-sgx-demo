# CoCo SGX Demo - Quick Reference Guide

## 🚀 Quick Commands

### Initial Setup (Run Once)
```bash
# Check if your system is ready
./check-prerequisites.sh

# Install and configure everything (includes demo deployment)
sudo ./setup-coco-demo.sh

# Validate the installation
./validate-deployment.sh
```

**Note**: `setup-coco-demo.sh` now automatically deploys the demo workload, so you don't need to run a separate demo script.

### Alternative: Guided Setup
```bash
# For step-by-step guided experience
./run-demo.sh
```

### Running Standalone Demo (Optional)
```bash
# Run complete attestation flow demonstration
# (Only needed if you want to re-run the demo after setup)
sudo ./complete-flow.sh
```

### Cleanup
```bash
# Clean up demo resources
sudo ./cleanup.sh

# Emergency: Complete Kubernetes reset
sudo ./universal-k8s-recovery.sh
```

---

## 📊 Checking Status

### Kubernetes
```bash
# Cluster info
kubectl cluster-info
kubectl get nodes

# All pods
kubectl get pods --all-namespaces

# CoCo operator
kubectl get pods -n confidential-containers-system

# Runtime classes
kubectl get runtimeclass
```

### Trustee Services
```bash
# Service status (using docker compose v2)
cd ~/coco-demo/trustee && docker compose ps

# View logs
docker logs trustee-kbs-1
docker logs trustee-as-1
docker logs trustee-rvps-1
docker logs trustee-keyprovider

# Follow logs (real-time)
docker logs -f trustee-kbs-1

# Restart service
cd ~/coco-demo/trustee && docker compose restart kbs
```

### Demo Pods
```bash
# List demo pod
kubectl get pod sgx-demo-pod

# Pod details
kubectl describe pod sgx-demo-pod

# Pod logs
kubectl logs sgx-demo-pod

# Interactive shell (if pod supports it)
kubectl exec -it sgx-demo-pod -- /bin/bash
```

---

## 🔍 Verification Commands

### KBS API Test
```bash
# Get your local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Should return HTTP 404 (KBS is running, endpoint not found without auth)
curl -v http://$LOCAL_IP:8090/

# Check if KBS is listening on correct port
netstat -tulpn | grep 8090
```

**Note**: KBS runs on the host's local IP address, not localhost/127.0.0.1

### Attestation Evidence
```bash
# Search for successful attestation
docker logs trustee-kbs-1 | grep -E "(auth|200)"

# Search for resource delivery
docker logs trustee-kbs-1 | grep "resource"

# Check AS verification logs
docker logs trustee-as-1 | grep "token"
```

### Port Mappings
```bash
# Verify all Trustee ports are exposed
cd ~/coco-demo/trustee && docker compose ps

# Or check with netstat
netstat -tulpn | grep -E "(8090|50004|50003|50000)"
```

**Note**: Port mappings (HOST:CONTAINER)
- KBS: 8090:8080
- AS: 50004:50004 (not 50014)
- RVPS: 50003:50003 (not 50013)
- Keyprovider: 50000:50000

---

## 🐛 Troubleshooting

### Issue: kubectl not working
```bash
# Restore kubeconfig
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify
kubectl get nodes
```

### Issue: Docker not running
```bash
# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify
sudo systemctl status docker
```

### Issue: Trustee services not starting
```bash
cd ~/coco-demo/trustee

# Check what's running
docker compose ps

# View error logs
docker compose logs

# Restart everything
docker compose down
docker compose up -d

# Check again
docker compose ps
```

### Issue: Pod stuck in ContainerCreating
```bash
# Check pod events
kubectl describe pod sgx-demo-pod

# Check runtime class
kubectl get runtimeclass enclave-cc

# Check CoCo operator
kubectl get pods -n confidential-containers-system

# Wait longer (CoCo pods take 10-20 seconds)
kubectl wait --for=condition=Ready pod/sgx-demo-pod --timeout=120s
```

### Issue: Attestation failing
```bash
# Check KBS is reachable from cluster
LOCAL_IP=$(hostname -I | awk '{print $1}')
kubectl run test --image=curlimages/curl --rm -it -- curl http://$LOCAL_IP:8090/

# Check AS logs for errors
docker logs trustee-as-1 | grep -i error

# Verify all services are Up
cd ~/coco-demo/trustee && docker compose ps
```

### Issue: Network connectivity problems
```bash
# Use the recovery script for complete reset
sudo ./universal-k8s-recovery.sh

# Or manual reset of iptables
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X

# Restart Docker
sudo systemctl restart docker

# Restart Kubernetes networking
kubectl -n kube-system delete pod -l k8s-app=kube-proxy
kubectl -n kube-flannel delete pod -l app=flannel
```

---

## 📁 File Locations

### Configuration Files
```bash
# Kubernetes admin config
/etc/kubernetes/admin.conf

# User kubeconfig
~/.kube/config

# Trustee docker-compose
~/coco-demo/trustee/docker-compose.yml

# Trustee configs (auto-configured by setup script)
~/coco-demo/trustee/kbs/config/kbs-config.toml
~/coco-demo/trustee/kbs/config/as-config.json

# Demo pod manifest
./configs/sgx-demo-pod.yaml

# Deployment info
~/coco-demo/deployment-info.txt
```

### Log Files
```bash
# Kubernetes logs
journalctl -u kubelet | tail -50

# Containerd logs
journalctl -u containerd | tail -50

# Docker logs
journalctl -u docker | tail -50
```

---

## 🎯 Key Endpoints

### Trustee Services
- **KBS**: http://<LOCAL_IP>:8090 (use `hostname -I | awk '{print $1}'` to get IP)
- **AS (gRPC)**: <LOCAL_IP>:50004
- **RVPS (gRPC)**: <LOCAL_IP>:50003
- **Keyprovider (gRPC)**: <LOCAL_IP>:50000

### Kubernetes
- **API Server**: https://localhost:6443

**Note**: Trustee services use the host's local IP, not localhost/127.0.0.1

---

## 💡 Useful Tips

### Watch Resources in Real-Time
```bash
# Watch pod status
watch -n 2 kubectl get pods

# Watch node status
watch -n 2 kubectl get nodes

# Watch CoCo operator
watch -n 2 kubectl get pods -n confidential-containers-system

# Watch Trustee services
watch -n 2 "cd ~/coco-demo/trustee && docker compose ps"
```

### Get Complete Pod Information
```bash
# Full pod details in YAML
kubectl get pod sgx-demo-pod -o yaml

# Full pod details in JSON
kubectl get pod sgx-demo-pod -o json

# Specific fields
kubectl get pod sgx-demo-pod -o jsonpath='{.status.phase}'
kubectl get pod sgx-demo-pod -o jsonpath='{.spec.runtimeClassName}'
```

### Search Logs Efficiently
```bash
# KBS attestation events
docker logs trustee-kbs-1 2>&1 | grep -i "auth" | tail -20

# Resource delivery with timestamps
docker logs trustee-kbs-1 2>&1 | grep "200" | grep "resource"

# AS policy decisions
docker logs trustee-as-1 2>&1 | grep -i "policy"

# RVPS reference values
docker logs trustee-rvps-1 2>&1 | grep -i "reference"
```

### Export Evidence
```bash
# Save pod manifest
kubectl get pod sgx-demo-pod -o yaml > pod-evidence.yaml

# Save KBS logs
docker logs trustee-kbs-1 > kbs-logs.txt

# Save attestation events
docker logs trustee-kbs-1 2>&1 | grep -E "(auth|200|resource)" > attestation-evidence.txt

# Create evidence package
mkdir -p evidence
kubectl get pod sgx-demo-pod -o yaml > evidence/pod.yaml
docker logs trustee-kbs-1 > evidence/kbs.log
docker logs trustee-as-1 > evidence/as.log
cd ~/coco-demo/trustee && docker compose ps > ~/evidence/services.txt
cd ~ && tar -czf coco-demo-evidence.tar.gz evidence/
```

---

## 🔄 Restart Procedures

### Restart Just Trustee Services
```bash
cd ~/coco-demo/trustee
docker compose restart
# Or specific service:
docker compose restart kbs
```

### Restart CoCo Operator
```bash
kubectl rollout restart deployment -n confidential-containers-system
```

### Restart Entire Demo (Keep Kubernetes)
```bash
# Clean up old resources
sudo ./cleanup.sh

# Restart Trustee
cd ~/coco-demo/trustee && docker compose restart

# Re-run setup (will skip already-installed components)
sudo ./setup-coco-demo.sh
```

### Full System Restart
```bash
# Complete reset
sudo ./universal-k8s-recovery.sh

# Or manual cleanup
sudo ./cleanup.sh
cd ~/coco-demo/trustee && docker compose down
sudo systemctl restart docker

# Start fresh
sudo ./setup-coco-demo.sh
```

---

## 📞 Getting Help

### Check Documentation
```bash
# Main README
cat README.md

# Quick reference (this file)
cat QUICK-REFERENCE.md

# Full technical report
cat docs/COCO-SGX-ENCLAVE-CC-REPORT.md

# Deployment info
cat ~/coco-demo/deployment-info.txt
```

### Collect Debug Information
```bash
# System info
uname -a
cat /etc/os-release
free -h
df -h

# Kubernetes info
kubectl version
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# CoCo info
kubectl get runtimeclass
kubectl get pods -n confidential-containers-system

# Trustee info
cd ~/coco-demo/trustee && docker compose ps
docker logs trustee-kbs-1 | tail -50

# Save all to file
{
    echo "=== System Info ==="
    uname -a
    echo ""
    echo "=== Kubernetes ==="
    kubectl get nodes
    kubectl get pods --all-namespaces
    echo ""
    echo "=== Trustee ==="
    cd ~/coco-demo/trustee && docker compose ps
    echo ""
    echo "=== Deployment Info ==="
    cat ~/coco-demo/deployment-info.txt
} > debug-info.txt
```

---

## ⏱️ Expected Timings

- **Setup**: 10-20 minutes (first time)
- **Setup**: 5-10 minutes (if components already installed)
- **Pod startup (SGX simulation)**: 10-20 seconds
- **Attestation**: 2-3 seconds
- **Cleanup**: 1-2 minutes
- **Full recovery**: 3-5 minutes

---

## 📋 Available Scripts

- `check-prerequisites.sh` - System requirements checker
- `setup-coco-demo.sh` - Complete setup (includes demo deployment)
- `run-demo.sh` - Guided setup wrapper
- `complete-flow.sh` - Standalone attestation demo
- `validate-deployment.sh` - Post-installation verification
- `cleanup.sh` - Safe removal of components
- `universal-k8s-recovery.sh` - Emergency Kubernetes reset

---

**Quick Start**: `./check-prerequisites.sh && sudo ./setup-coco-demo.sh`
