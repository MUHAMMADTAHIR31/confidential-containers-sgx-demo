# CoCo SGX Demo - Professor Guide

Welcome! This demo package provides a complete, working implementation of Confidential Containers (CoCo) with Intel SGX enclave-cc runtime in simulation mode.

## 🎯 What This Demo Does

This demonstration will:
1. Install a Kubernetes cluster (if not present)
2. Deploy CoCo operator v0.10.0
3. Configure enclave-cc RuntimeClass (SGX simulation mode)
4. Deploy Trustee services (KBS, AS, RVPS, Keyprovider)
5. Run an encrypted container with remote attestation
6. Show proof of successful attestation and decryption

**Expected time**: 15-30 minutes (depending on download speeds)

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 22.04 or 24.04 (tested on 22.04)
- **RAM**: ≥8GB (16GB recommended)
- **CPU**: ≥4 cores
- **Disk**: ≥20GB free space
- **Internet**: Required for downloading images

### Software (will be installed if missing)
- Docker and docker-compose
- Kubernetes (kubeadm, kubelet, kubectl)
- curl, jq, git

**Note**: Script runs with `sudo` and will install missing dependencies.

## 🚀 Quick Start (2 Commands)

```bash
# 1. Run the complete setup and demo
sudo ./setup-coco-demo.sh

# 2. Clean up (when done)
sudo ./cleanup.sh
```

**Alternative**: Use the wrapper script for guided flow:
```bash
./run-demo.sh
```

## 📖 Detailed Instructions

### Step 1: Preparation

Extract the demo package:
```bash
cd /path/to/demo
chmod +x *.sh
```

Verify prerequisites:
```bash
./check-prerequisites.sh
```

### Step 2: Setup CoCo Environment and Run Demo

Run the complete setup script (this now includes the demo):
```bash
sudo ./setup-coco-demo.sh
```

**What it does**:
- **Step 1-3**: Installs Docker, Docker Compose, and basic tools
- **Step 4-5**: Prepares system and installs Kubernetes components
- **Step 6**: Installs/configures containerd
- **Step 7-8**: Initializes Kubernetes cluster and network
- **Step 9**: Deploys CoCo operator v0.10.0
- **Step 10**: Configures enclave-cc RuntimeClass
- **Step 11**: Starts Trustee services (KBS, AS, RVPS, Keyprovider) using docker-compose
- **Step 12**: Deploys encrypted demo workload pod
- **Step 13**: Verifies deployment and attestation
- **Step 14**: Saves configuration info

**Expected output**:
```
STEP 1/8: Preparing System
STEP 2/8: Installing Docker
STEP 3/8: Preparing System for Kubernetes
STEP 4/8: Installing Kubernetes
STEP 5/8: Creating Kubernetes Cluster
STEP 6/8: Verifying Network
STEP 7/8: Starting Trustee Services
STEP 8/8: Deploying Demo Workload
...
✅ All steps completed successfully!
```

**Note**: The setup script now automatically deploys the demo workload, so you don't need to run a separate demo script.

### Step 3: Alternative - Run Complete Flow Separately

If you want to run the complete attestation flow as a standalone demonstration (after setup):
```bash
sudo ./complete-flow.sh
```

**What it demonstrates**:
1. **Phase 1**: Checks prerequisites (kubectl, docker, skopeo, runtime class)
2. **Phase 2**: Uses pre-encrypted test image from CoCo project
3. **Phase 3**: Configures KBS connection using pod annotations
4. **Phase 4**: Deploys encrypted pod with attestation
5. **Phase 5**: Shows pod logs with technical details
6. **Phase 6**: Verifies attestation in KBS logs

**Key Features**:
- Uses official CoCo encrypted test image
- Demonstrates full RCAR attestation protocol
- Shows real-time attestation in KBS logs
- Pod remains running for 5 minutes for inspection

**Note**: This script is optional since `setup-coco-demo.sh` already deploys the demo workload.

### Step 4: Inspect the Results

View running pods:
```bash
kubectl get pods
```

Check pod details:
```bash
kubectl describe pod coco-encrypted-demo
kubectl logs coco-encrypted-demo
```

View attestation logs:
```bash
cd ~/trustee
docker logs trustee-kbs-1 | grep -E "(auth|resource)"
```

### Step 5: Cleanup

When done, clean up resources:
```bash
sudo ./cleanup.sh
```

**What it removes**:
- CoCo pods with enclave-cc runtime
- CoCo operator and related resources
- Trustee services (docker containers)
- Resets network rules safely

**Note**: Kubernetes cluster is preserved. To remove completely:
```bash
sudo kubeadm reset -f
```

## 📂 Demo Package Contents

```
confidential-containers-sgx-demo/
├── README.md                    # This file
├── QUICK-REFERENCE.md           # Command cheat sheet
├── LICENSE                      # License information
├── setup-coco-demo.sh           # Main setup script (includes demo deployment)
├── complete-flow.sh             # Alternative: standalone attestation demo
├── run-demo.sh                  # Wrapper script for guided setup
├── cleanup.sh                   # Safe cleanup script
├── check-prerequisites.sh       # Prerequisites checker
├── validate-deployment.sh       # Post-setup validation
├── configs/
│   └── sgx-demo-pod.yaml       # Encrypted pod manifest
├── trustee-config/
│   ├── docker-compose.yml      # Trustee services configuration
│   └── as-config.json          # Attestation Service configuration
└── docs/
    └── COCO-SGX-ENCLAVE-CC-REPORT.md  # Complete technical report
```

## 🔍 Verification Points

After running the demo, you can verify these key points:

### 1. Kubernetes Cluster
```bash
kubectl get nodes
# Should show: Ready status
```

### 2. CoCo Operator
```bash
kubectl get pods -n confidential-containers-system
# Should show: Running pods
```

### 3. Runtime Class
```bash
kubectl get runtimeclass enclave-cc
# Should exist
```

### 4. Trustee Services
```bash
cd ~/trustee && docker compose ps
# Should show: All services "Up"
# Note: Uses docker compose (v2) not docker-compose
```

### 5. KBS API
```bash
LOCAL_IP=$(hostname -I | awk '{print $1}')
curl http://$LOCAL_IP:8090/
# Should return: HTTP 404 (KBS is running)
# Note: KBS runs on host IP, not localhost
```

### 6. Encrypted Pod
```bash
kubectl get pod coco-encrypted-demo
# Should show: Running
```

### 7. Attestation Proof
```bash
docker logs trustee-kbs-1 | grep "200" | grep resource
# Should show: Successful resource delivery
```

## 🎓 Understanding the Demo

### What is CoCo?

Confidential Containers (CoCo) is a CNCF project that enables running containers in hardware-based Trusted Execution Environments (TEEs). It provides:

- **Confidentiality**: Data encrypted in use (not just at rest/transit)
- **Integrity**: Cryptographic proof of code integrity
- **Isolation**: Hardware-enforced isolation from host OS

### Key Components

**CoCo Operator**: Kubernetes operator that installs and manages CoCo runtimes

**enclave-cc**: Runtime class for Intel SGX-based isolation

**Trustee Stack**:
- **KBS** (Key Broker Service): Releases keys after attestation
- **AS** (Attestation Service): Verifies TEE evidence
- **RVPS** (Reference Value Provider): Stores expected measurements
- **Keyprovider**: OCI encryption integration

### Attestation Flow (RCAR Protocol)

```
1. Container startup
2. Pod requests encrypted image
3. Image service (image-rs) needs decryption key
4. Attestation Agent (AA) contacts KBS
5. KBS challenges: "Prove you're in a TEE"
6. AA collects evidence from SGX
7. AS verifies evidence against policy
8. AS issues attestation token
9. KBS validates token and releases key
10. Image decrypted in TEE memory
11. Container starts
```

**Key Point**: Keys are NEVER exposed to untrusted infrastructure. Only TEE memory sees the decryption key.

### SGX Simulation Mode

This demo uses **simulation mode**:
- ✅ No special hardware required
- ✅ Full protocol demonstration
- ✅ Perfect for learning/testing
- ⚠️ NOT for production (no hardware security)

For production, use real Intel SGX hardware with DCAP attestation.

## 📊 Expected Performance

**Setup time**: 10-20 minutes
- Kubernetes install: 5-10 min
- CoCo operator: 2-3 min
- Trustee services: 1-2 min

**Pod startup time**:
- Standard container: ~2-5 seconds
- CoCo encrypted: ~10-15 seconds
  - VM initialization: 5s
  - Attestation: 2-3s
  - Image pull/decrypt: 3-5s

**Resource overhead per pod**:
- Memory: ~170MB (Kata VM)
- CPU: +5-10% steady state

## 🐛 Common Issues

### Issue 1: Kubernetes Installation Fails

**Error**: `kubeadm init failed`

**Solution**:
```bash
# Reset and try again
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/kubelet ~/.kube
sudo ./setup-coco-demo.sh
```

### Issue 2: Trustee Services Not Starting

**Error**: `Failed to start trustee services`

**Solution**:
```bash
cd ~/trustee
docker compose down
docker compose up -d
docker compose logs
```

**Note**: Uses `docker compose` (Docker Compose v2), not `docker-compose`.

### Issue 3: Pod Stuck in Pending

**Error**: Pod not scheduling

**Check**:
```bash
kubectl describe pod coco-encrypted-demo
# Look for: Events section for errors
```

**Common cause**: Runtime class not ready yet. Wait 30 seconds and retry.

### Issue 4: Attestation Fails

**Error**: Pod fails to pull encrypted image

**Check**:
```bash
# Verify KBS is accessible
curl http://127.0.0.1:8090/kbs/v0/resource

# Check KBS logs
docker logs trustee-kbs-1
```

**Solution**: Ensure KBS/AS/RVPS are all "Up":
```bash
cd ~/trustee && docker compose ps
```

### Issue 5: kubectl Not Working After Cleanup

**Error**: `The connection to the server localhost:8080 was refused`

**Solution**:
```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

## 📚 Additional Resources

### Documentation
- **Complete Technical Report**: See `docs/COCO-SGX-ENCLAVE-CC-REPORT.md`
- **Quick Reference**: See `QUICK-REFERENCE.md` for command cheat sheet

### Official CoCo Resources
- Website: https://confidentialcontainers.org
- GitHub: https://github.com/confidential-containers
- Documentation: https://github.com/confidential-containers/documentation
- Slack: #confidential-containers on cloud-native.slack.com

### Intel SGX Resources
- SGX Overview: https://www.intel.com/sgx
- DCAP: https://github.com/intel/SGXDataCenterAttestationPrimitives

## 🤝 Support

If you encounter issues:

1. Review logs: `docker logs trustee-kbs-1`, `kubectl logs <pod-name>`
2. Run validation: `./validate-deployment.sh`
3. Check prerequisites: `./check-prerequisites.sh`
4. Consult the technical report in `docs/COCO-SGX-ENCLAVE-CC-REPORT.md`

## 📝 Feedback

This demo package was created to showcase Confidential Containers technology for academic evaluation. Feedback welcome!

## 🎉 Success Criteria

The demo is successful if you see:

✅ Kubernetes cluster with CoCo operator running  
✅ Trustee services (KBS, AS, RVPS) all "Up"  
✅ KBS responding with HTTP 401 (requires attestation)  
✅ Encrypted pod deployed and Running  
✅ KBS logs showing HTTP 200 for attestation and resource delivery  
✅ Container logs showing application output  

**This proves**: Remote attestation works, encrypted images can be decrypted only after attestation, and confidential containers are operational!

## 📋 What's New

**Recent Updates**:
- Integrated demo deployment into setup script (single command setup)
- Added `run-demo.sh` wrapper for guided experience
- Moved Trustee configs to dedicated `trustee-config/` directory
- Simplified file structure
- Updated to use Docker Compose v2 (`docker compose`)

---

**Demo Version**: 1.1  
**Last Updated**: November 2025  
**CoCo Version**: v0.10.0  
**Kubernetes**: v1.31.13  
**Tested on**: Ubuntu 22.04 LTS
