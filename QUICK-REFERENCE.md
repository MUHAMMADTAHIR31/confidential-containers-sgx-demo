# CoCo SGX Demo - Quick Reference Guide

## 🚀 Quick Commands

### Initial Setup (Run Once)
```bash
# Check if your system is ready
./check-prerequisites.sh

# Install and configure everything
sudo ./setup-coco-demo.sh

# Validate the installation
./validate-deployment.sh
```

### Running the Demo
```bash
# Run complete demonstration
sudo ./complete-flow.sh

# Alternative: Manual step-by-step
kubectl apply -f configs/sgx-demo-pod.yaml
kubectl wait --for=condition=Ready pod/coco-encrypted-demo --timeout=120s
kubectl logs coco-encrypted-demo
```

### Cleanup
```bash
# Clean up demo resources
sudo ./cleanup.sh

# Full reset (including Kubernetes)
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes ~/.kube
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
# Service status
cd ~/trustee && docker-compose ps

# View logs
docker logs trustee-kbs-1
docker logs trustee-as-1
docker logs trustee-rvps-1
docker logs trustee-keyprovider

# Follow logs (real-time)
docker logs -f trustee-kbs-1

# Restart service
docker-compose restart kbs
```

### Demo Pods
```bash
# List CoCo pods
kubectl get pods -l app=coco-demo

# Pod details
kubectl describe pod coco-encrypted-demo

# Pod logs
kubectl logs coco-encrypted-demo

# Interactive shell (if pod supports it)
kubectl exec -it coco-encrypted-demo -- /bin/sh
```

---

## 🔍 Verification Commands

### KBS API Test
```bash
# Should return HTTP 401 (requires attestation)
curl -v http://127.0.0.1:8090/kbs/v0/resource

# Check if KBS is listening on correct port
netstat -tulpn | grep 8090
```

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
docker-compose ps | grep -E "(8090|50014|50013|50000)"

# Or check with netstat
netstat -tulpn | grep -E "(8090|50014|50013|50000)"
```

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
cd ~/trustee

# Check what's running
docker-compose ps

# View error logs
docker-compose logs

# Restart everything
docker-compose down
docker-compose up -d

# Check again
docker-compose ps
```

### Issue: Pod stuck in ContainerCreating
```bash
# Check pod events
kubectl describe pod coco-encrypted-demo

# Check runtime class
kubectl get runtimeclass enclave-cc

# Check CoCo operator
kubectl get pods -n confidential-containers-system

# Wait longer (CoCo pods take 10-20 seconds)
kubectl wait --for=condition=Ready pod/coco-encrypted-demo --timeout=120s
```

### Issue: Attestation failing
```bash
# Check KBS is reachable from cluster
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
kubectl run test --image=curlimages/curl --rm -it -- curl http://$NODE_IP:8090/kbs/v0/resource

# Check AS logs for errors
docker logs trustee-as-1 | grep -i error

# Verify all services are Up
cd ~/trustee && docker-compose ps
```

### Issue: Network connectivity problems
```bash
# Reset iptables rules
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X

# Restart Docker
sudo systemctl restart docker

# Restart Kubernetes networking
kubectl -n kube-system delete pod -l k8s-app=kube-proxy
kubectl -n kube-system delete pod -l app=flannel
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
~/trustee/docker-compose.yml

# Trustee configs
~/trustee/kbs/config/kbs-config.json
~/trustee/attestation-service/config/as-config.json

# Demo pod manifests
./configs/sgx-demo-pod.yaml
./configs/ccruntime-sgx-sim.yaml
```

### Log Files
```bash
# Setup logs
./setup.log

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
- **KBS**: http://127.0.0.1:8090
- **AS (gRPC)**: 127.0.0.1:50014
- **RVPS**: http://127.0.0.1:50013
- **Keyprovider**: 127.0.0.1:50000

### Kubernetes
- **API Server**: https://localhost:6443
- **Dashboard** (if installed): http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

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
watch -n 2 "cd ~/trustee && docker-compose ps"
```

### Get Complete Pod Information
```bash
# Full pod details in YAML
kubectl get pod coco-encrypted-demo -o yaml

# Full pod details in JSON
kubectl get pod coco-encrypted-demo -o json

# Specific fields
kubectl get pod coco-encrypted-demo -o jsonpath='{.status.phase}'
kubectl get pod coco-encrypted-demo -o jsonpath='{.spec.runtimeClassName}'
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
kubectl get pod coco-encrypted-demo -o yaml > pod-evidence.yaml

# Save KBS logs
docker logs trustee-kbs-1 > kbs-logs.txt

# Save attestation events
docker logs trustee-kbs-1 2>&1 | grep -E "(auth|200|resource)" > attestation-evidence.txt

# Create evidence package
mkdir -p evidence
kubectl get pod coco-encrypted-demo -o yaml > evidence/pod.yaml
docker logs trustee-kbs-1 > evidence/kbs.log
docker logs trustee-as-1 > evidence/as.log
docker-compose ps > evidence/services.txt
tar -czf coco-demo-evidence.tar.gz evidence/
```

---

## 🔄 Restart Procedures

### Restart Just Trustee Services
```bash
cd ~/trustee
docker-compose restart
# Or specific service:
docker-compose restart kbs
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
cd ~/trustee && docker-compose restart

# Deploy again
sudo ./complete-flow.sh
```

### Full System Restart
```bash
# Stop everything
sudo ./cleanup.sh
cd ~/trustee && docker-compose down
sudo systemctl restart docker
sudo systemctl restart kubelet

# Start fresh
sudo ./setup-coco-demo.sh
sudo ./complete-flow.sh
```

---

## 📞 Getting Help

### Check Documentation
```bash
# Main README
cat README.md

# Full technical report
cat docs/COCO-SGX-ENCLAVE-CC-REPORT.md

# Troubleshooting guide
cat docs/TROUBLESHOOTING.md
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
cd ~/trustee && docker-compose ps
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
    cd ~/trustee && docker-compose ps
} > debug-info.txt
```

---

## ⏱️ Expected Timings

- **Setup**: 10-20 minutes
- **Pod startup (encrypted)**: 10-15 seconds
- **Attestation**: 2-3 seconds
- **Cleanup**: 1-2 minutes

---

**Quick Start**: `./check-prerequisites.sh && sudo ./setup-coco-demo.sh && sudo ./complete-flow.sh`
