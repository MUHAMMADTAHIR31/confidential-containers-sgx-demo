#!/bin/bash
# Deployment validation script

echo "CoCo SGX Demo - Deployment Validation"
echo ""

CHECKS=0
PASSED=0
FAILED=0

if [ "$EUID" -eq 0 ]; then
    ACTUAL_USER=${SUDO_USER:-$USER}
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
    
    if [ -f "$ACTUAL_HOME/.kube/config" ]; then
        export KUBECONFIG="$ACTUAL_HOME/.kube/config"
    elif [ -f "/etc/kubernetes/admin.conf" ]; then
        export KUBECONFIG="/etc/kubernetes/admin.conf"
    fi
else
    ACTUAL_USER=$USER
    ACTUAL_HOME=$HOME
    if [ -f "$HOME/.kube/config" ]; then
        export KUBECONFIG="$HOME/.kube/config"
    fi
fi

validate_step() {
    local description="$1"
    local command="$2"
    
    CHECKS=$((CHECKS + 1))
    echo -n "[$CHECKS] $description ... "
    
    if eval "$command" &>/dev/null; then
        echo "PASS"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "FAIL"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "Kubernetes Cluster:"
validate_step "kubectl configured" "kubectl version --client"
validate_step "Cluster reachable" "kubectl cluster-info"
validate_step "Node ready" "kubectl get nodes | grep -w Ready"
echo ""

echo "CoCo Operator:"
validate_step "CoCo namespace exists" "kubectl get ns confidential-containers-system"
validate_step "Operator pods running" "kubectl get pods -n confidential-containers-system | grep -v NAME | grep Running"
validate_step "RuntimeClass enclave-cc exists" "kubectl get runtimeclass enclave-cc"
echo ""

echo "Trustee Services:"

TRUSTEE_DIR=""
if [ -d "/root/coco-demo/trustee" ]; then
    TRUSTEE_DIR="/root/coco-demo/trustee"
elif [ -d "$HOME/coco-demo/trustee" ]; then
    TRUSTEE_DIR="$HOME/coco-demo/trustee"
elif [ -d "/root/trustee" ]; then
    TRUSTEE_DIR="/root/trustee"
elif [ -d "$HOME/trustee" ]; then
    TRUSTEE_DIR="$HOME/trustee"
fi

if docker ps --filter "name=trustee" --format "{{.Names}}" | grep -q trustee; then
    validate_step "Trustee containers running" "docker ps --filter 'name=trustee' | grep -q trustee"
    validate_step "KBS service running" "docker ps --filter 'name=trustee-kbs' | grep -q Up"
    validate_step "AS service running" "docker ps --filter 'name=trustee-as' | grep -q Up"
    validate_step "RVPS service running" "docker ps --filter 'name=trustee-rvps' | grep -q Up"
    validate_step "Keyprovider service running" "docker ps --filter 'name=trustee-keyprovider' | grep -q Up"
elif [ -n "$TRUSTEE_DIR" ] && [ -d "$TRUSTEE_DIR" ]; then
    cd "$TRUSTEE_DIR"
    validate_step "Trustee directory exists" "test -d $TRUSTEE_DIR"
    validate_step "Docker compose file present" "test -f docker-compose.yml"
    validate_step "KBS service running" "docker compose ps 2>/dev/null | grep kbs | grep -q Up || docker-compose ps 2>/dev/null | grep kbs | grep -q Up"
    validate_step "AS service running" "docker compose ps 2>/dev/null | grep as | grep -q Up || docker-compose ps 2>/dev/null | grep as | grep -q Up"
    validate_step "RVPS service running" "docker compose ps 2>/dev/null | grep rvps | grep -q Up || docker-compose ps 2>/dev/null | grep rvps | grep -q Up"
    validate_step "Keyprovider service running" "docker compose ps 2>/dev/null | grep keyprovider | grep -q Up || docker-compose ps 2>/dev/null | grep keyprovider | grep -q Up"
    cd - >/dev/null
else
    echo "FAIL - Trustee services not found"
    FAILED=$((FAILED + 1))
fi
echo ""

echo "Summary:"
echo "  Total checks: $CHECKS"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All validation checks passed"
    echo ""
    echo "Next: sudo ./complete-flow.sh"
    exit 0
else
    echo "✗ Some validation checks failed"
    exit 1
fi
