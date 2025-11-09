#!/bin/bash
# CoCo SGX Demo Runner

set -e

echo "CoCo SGX Demo - Complete Flow"
echo "Expected time: 15-30 minutes"
echo ""
read -p "Press Enter to start or Ctrl+C to cancel..."
echo ""

echo "[1/4] Checking Prerequisites..."
if [ -f "./check-prerequisites.sh" ]; then
    ./check-prerequisites.sh || {
        echo "ERROR: Prerequisites check failed"
        echo "Please fix the issues above and try again"
        exit 1
    }
else
    echo "Warning: check-prerequisites.sh not found"
fi
echo ""

echo "[2/4] Setting Up CoCo Environment..."
if kubectl get runtimeclass enclave-cc &>/dev/null && [ -d "$HOME/trustee" ]; then
    echo "CoCo appears to be already set up"
    read -p "Skip setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        sudo ./setup-coco-demo.sh || {
            echo "ERROR: Setup failed"
            exit 1
        }
    fi
else
    echo "Running setup (this will take 10-20 minutes)..."
    sudo ./setup-coco-demo.sh || {
        echo "ERROR: Setup failed"
        echo "Check setup.log for details"
        exit 1
    }
fi
echo ""

echo "[3/4] Validating Deployment..."
if [ -f "./validate-deployment.sh" ]; then
    ./validate-deployment.sh || {
        echo "Warning: Some validation checks failed"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    }
else
    echo "Warning: validate-deployment.sh not found"
fi
echo ""

echo "[4/4] Running Demonstration..."
sudo ./complete-flow.sh || {
    echo "ERROR: Demo failed"
    echo "Check logs for details:"
    echo "  - kubectl describe pod coco-encrypted-demo"
    echo "  - docker logs trustee-kbs-1"
    exit 1
}
echo ""

echo "DEMO COMPLETE!"
echo ""
echo "CoCo environment running"
echo "Attestation protocol verified"
echo "Encrypted container operational"
echo ""
echo "Verification:"
echo "  kubectl get pod coco-encrypted-demo"
echo "  kubectl logs coco-encrypted-demo"
echo ""
echo "  # View attestation evidence"
echo "  docker logs trustee-kbs-1 | grep -E '(200|auth|resource)'"
echo ""
echo "  # View all CoCo pods"
echo "  kubectl get pods -A -o wide"
echo ""
echo "  # View Trustee services"
echo "  cd ~/trustee && docker-compose ps"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Cleanup:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  sudo ./cleanup.sh"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " Documentation:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  README.md                              - Getting started"
echo "  QUICK-REFERENCE.md                     - Command reference"
echo "  docs/COCO-SGX-ENCLAVE-CC-REPORT.md     - Complete report"
echo "  docs/TROUBLESHOOTING.md                - Problem solving"
echo ""
echo "Thank you for trying the CoCo SGX demo!"
echo ""
