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

## 🚀 Quick Start (3 Commands)

```bash
# 1. Run the complete setup
sudo ./setup-coco-demo.sh

# 2. Run the demonstration
sudo ./complete-flow.sh

# 3. Clean up (when done)
sudo ./cleanup.sh
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

### Step 2: Setup CoCo Environment

Run the setup script:
```bash
sudo ./setup-coco-demo.sh
```

**What it does**:
- Installs Docker, Kubernetes tools
- Creates single-node Kubernetes cluster
- Deploys CoCo operator v0.10.0
- Configures enclave-cc RuntimeClass
- Clones and starts Trustee services (KBS, AS, RVPS, Keyprovider)

**Expected output**:
```
[Step 1] Installing prerequisites...
[Step 2] Setting up Kubernetes cluster...
[Step 3] Installing CoCo operator...
...
[Step 11] Starting Trustee services...
[PASS] All services started successfully

✅ CoCo setup complete!
```

**Troubleshooting**: If setup fails, check `setup.log` for details.

### Step 3: Run the Demo

Execute the complete flow:
```bash
sudo ./complete-flow.sh
```

**What it demonstrates**:
1. Verifies all components are running
2. Tests KBS API (expects HTTP 401 - requires attestation)
3. Deploys encrypted container pod
4. Shows attestation protocol execution (RCAR)
5. Verifies successful decryption and container startup

**Expected output**:
```
=== CoCo SGX Demo: Complete Flow ===

[1/6] Checking prerequisites...
[PASS] Kubernetes operational
[PASS] Trustee services running

[2/6] Testing KBS API...
[PASS] KBS responding (HTTP 401)

[3/6] Deploying encrypted container...
[PASS] Pod created: coco-encrypted-demo

[4/6] Waiting for attestation...
[PASS] Attestation successful (HTTP 200 in KBS logs)

[5/6] Verifying container is running...
[PASS] Container running with decrypted image

=== DEMO SUCCESS ===
✅ Remote attestation completed
✅ Encrypted image decrypted
✅ Container running securely
```

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
DEMO-FOR-PROFESSOR/
├── README.md                    # This file
├── QUICK-REFERENCE.md           # Command cheat sheet
├── setup-coco-demo.sh           # Main setup script
├── complete-flow.sh             # End-to-end demonstration
├── cleanup.sh                   # Safe cleanup script
├── check-prerequisites.sh       # Prerequisites checker
├── validate-deployment.sh       # Post-setup validation
├── configs/
│   ├── ccruntime-sgx-sim.yaml  # CoCo runtime configuration
│   └── sgx-demo-pod.yaml       # Encrypted pod manifest
└── docs/
    ├── COCO-SGX-ENCLAVE-CC-REPORT.md  # Complete technical report
    ├── ARCHITECTURE.md          # System architecture
    └── TROUBLESHOOTING.md       # Common issues and solutions
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
cd ~/trustee && docker-compose ps
# Should show: All services "Up"
```

### 5. KBS API
```bash
curl http://127.0.0.1:8090/kbs/v0/resource
# Should return: HTTP 401 (requires attestation)
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
docker-compose down
docker-compose up -d
docker-compose logs
```

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
cd ~/trustee && docker-compose ps
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
- **Architecture**: See `docs/ARCHITECTURE.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`

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

1. Check `docs/TROUBLESHOOTING.md`
2. Review logs: `setup.log`, `docker logs trustee-kbs-1`
3. Run validation: `./validate-deployment.sh`
4. Consult the technical report for detailed explanations

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

---

**Demo Version**: 1.0  
**Date**: October 29, 2025  
**CoCo Version**: v0.10.0  
**Kubernetes**: v1.31.13  
**Tested on**: Ubuntu 22.04 LTS
