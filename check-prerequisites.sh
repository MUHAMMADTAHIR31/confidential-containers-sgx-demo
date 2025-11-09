#!/bin/bash
# Prerequisites Checker

set -e

echo "CoCo SGX Demo - Prerequisites Checker"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

check_pass() {
    echo "✓ $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo "✗ $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

check_warn() {
    echo "⚠ $1"
    WARNINGS=$((WARNINGS + 1))
}

echo "Checking system requirements..."
echo ""

echo "Operating System:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  Distribution: $NAME $VERSION"
    if [[ "$ID" == "ubuntu" ]] && [[ "$VERSION_ID" == "22.04" || "$VERSION_ID" == "24.04" ]]; then
        check_pass "Ubuntu 22.04 or 24.04 detected"
    else
        check_warn "OS is $NAME $VERSION (tested on Ubuntu 22.04/24.04)"
    fi
else
    check_warn "Cannot detect OS version"
fi
echo ""

echo "Memory:"
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
echo "  Total RAM: ${TOTAL_MEM}GB"
if [ "$TOTAL_MEM" -ge 8 ]; then
    check_pass "Sufficient RAM (${TOTAL_MEM}GB)"
elif [ "$TOTAL_MEM" -ge 4 ]; then
    check_warn "Limited RAM (${TOTAL_MEM}GB, 8GB+ recommended)"
else
    check_fail "Insufficient RAM (${TOTAL_MEM}GB < 4GB minimum)"
fi
echo ""

echo "CPU:"
CPU_CORES=$(nproc)
echo "  Cores: $CPU_CORES"
if [ "$CPU_CORES" -ge 4 ]; then
    check_pass "Sufficient CPU cores ($CPU_CORES)"
elif [ "$CPU_CORES" -ge 2 ]; then
    check_warn "Limited CPU cores ($CPU_CORES, 4+ recommended)"
else
    check_fail "Insufficient CPU cores ($CPU_CORES < 2 minimum)"
fi
echo ""

echo "Disk Space:"
AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo "  Available: ${AVAILABLE_GB}GB"
if [ "$AVAILABLE_GB" -ge 20 ]; then
    check_pass "Sufficient disk space (${AVAILABLE_GB}GB)"
elif [ "$AVAILABLE_GB" -ge 10 ]; then
    check_warn "Limited disk space (${AVAILABLE_GB}GB, 20GB+ recommended)"
else
    check_fail "Insufficient disk space (${AVAILABLE_GB}GB < 10GB minimum)"
fi
echo ""

echo "Network:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    check_pass "Internet connectivity available"
else
    check_fail "No internet connectivity"
fi
echo ""

echo "Existing Services:"
if command -v kubectl &> /dev/null; then
    if kubectl cluster-info &> /dev/null; then
        check_warn "Kubernetes already running"
    else
        check_pass "kubectl installed"
    fi
else
    check_pass "kubectl not found (will install)"
fi

if systemctl is-active --quiet docker 2>/dev/null; then
    check_warn "Docker already running"
elif command -v docker &> /dev/null; then
    check_warn "Docker installed (not running)"
else
    check_pass "Docker not found (will install)"
fi
echo ""

echo "Permissions:"
if sudo -n true 2>/dev/null; then
    check_pass "Passwordless sudo available"
elif sudo true 2>/dev/null; then
    check_pass "Sudo access available"
else
    check_fail "No sudo access"
fi
echo ""

echo "System Configuration:"
if [ "$(swapon --show | wc -l)" -eq 0 ]; then
    check_pass "Swap disabled"
else
    check_warn "Swap enabled (disable with: sudo swapoff -a)"
fi
echo ""

echo "Summary:"
echo "  Passed: $CHECKS_PASSED"
if [ $WARNINGS -gt 0 ]; then
    echo "  Warnings: $WARNINGS"
fi
if [ $CHECKS_FAILED -gt 0 ]; then
    echo "  Failed: $CHECKS_FAILED"
fi
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo "✓ System ready for installation"
    echo ""
    echo "Next: sudo ./setup-coco-demo.sh"
    exit 0
else
    echo "✗ System does not meet minimum requirements"
    exit 1
fi
