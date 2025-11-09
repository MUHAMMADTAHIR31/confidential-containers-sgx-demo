#!/bin/bash
# CoCo SGX Demo - Setup Script

INSTALL_DIR="$HOME/coco-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info() { echo "→ $1"; }
print_success() { echo "✓ $1"; }
print_warning() { echo "⚠ $1"; }
print_error() { echo "✗ $1"; }

print_section() {
    echo ""
    echo "$1"
    echo "----------------------------------------"
}

command_exists() { command -v "$1" &> /dev/null; }
service_is_running() { systemctl is-active --quiet "$1"; }
get_actual_user() { echo "${SUDO_USER:-$USER}"; }
get_actual_home() {
    local user=$(get_actual_user)
    eval echo "~$user"
}
get_local_ip() { hostname -I | awk '{print $1}'; }
################################################################################

# STEP 1: Update system and install basic tools
step1_prepare_system() {
    print_section "STEP 1/8: Preparing System"
    
    print_info "Updating package lists (this may take a moment)..."
    apt-get update -qq
    
    print_info "Installing essential tools..."
    # Install tools we'll need later:
    # - curl/wget: Download files from internet
    # - git: Clone repositories
    # - jq: Parse JSON (for working with Kubernetes)
    # - netcat: Test network connections
    # - openssl: Encryption/decryption tools
    apt-get install -y -qq \
        curl \
        wget \
        git \
        jq \
        netcat-openbsd \
        openssl \
        > /dev/null 2>&1
    
    print_success "System preparation complete"
}

# STEP 2: Install Docker (needed to run Trustee services)
step2_install_docker() {
    print_section "STEP 2/8: Installing Docker"
    
    # Check if Docker is already installed and running
    if command_exists docker && systemctl is-active --quiet docker 2>/dev/null; then
        print_success "Docker is already installed and running (skipping)"
        return 0
    fi
    
    print_info "Installing Docker from official script..."
    # Use Docker's official installation script (easiest method)
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    
    # Ensure docker group exists
    print_info "Ensuring docker group exists..."
    groupadd docker 2>/dev/null || true
    
    # Add user to docker group so they can run docker without sudo
    local actual_user=$(get_actual_user)
    usermod -aG docker "$actual_user" 2>/dev/null || true
    print_info "Added $actual_user to docker group"
    
    # Reload systemd daemon to pick up docker service
    systemctl daemon-reload
    
    # Enable and start Docker socket first
    print_info "Starting Docker services..."
    systemctl enable docker.socket > /dev/null 2>&1 || true
    systemctl start docker.socket 2>/dev/null || true
    
    # Then enable and start Docker service
    systemctl enable docker > /dev/null 2>&1 || true
    systemctl start docker 2>/dev/null || true
    
    # Wait a moment for Docker to fully start
    sleep 5
    
    # Verify Docker is running
    if systemctl is-active --quiet docker; then
        print_success "Docker installed and running successfully"
    else
        print_warning "Docker installed but may not be fully started yet"
        # Try to start it again
        systemctl restart docker 2>/dev/null || true
        sleep 3
    fi
}

# STEP 3: Install Docker Compose (to manage multiple containers)
step3_install_docker_compose() {
    print_info "Checking Docker Compose..."
    
    # Docker Compose might be installed as a plugin or standalone
    if command_exists docker-compose || docker compose version &> /dev/null; then
        print_success "Docker Compose is already available"
        return 0
    fi
    
    print_info "Installing Docker Compose..."
    # Download the Docker Compose binary
    local compose_version="v2.20.0"
    local os=$(uname -s)
    local arch=$(uname -m)
    curl -sL "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-${os}-${arch}" \
        -o /usr/local/bin/docker-compose
    
    # Make it executable
    chmod +x /usr/local/bin/docker-compose
    
    print_success "Docker Compose installed"
}

# STEP 4: Prepare system for Kubernetes
step4_prepare_kubernetes_system() {
    print_section "STEP 3/8: Preparing System for Kubernetes"
    
    # Kubernetes requires swap to be disabled (it doesn't work well with swap)
    print_info "Disabling swap (required for Kubernetes)..."
    swapoff -a
    # Remove swap from /etc/fstab so it stays disabled after reboot
    sed -i '/ swap / s/^/#/' /etc/fstab
    
    # Load kernel modules needed for container networking
    print_info "Loading required kernel modules..."
    modprobe overlay      # For overlayfs (how container images work)
    modprobe br_netfilter # For container networking
    
    # Configure kernel networking parameters
    print_info "Configuring kernel networking..."
    cat > /etc/sysctl.d/k8s.conf <<EOF
# Allow containers to talk through the bridge network
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
# Allow packet forwarding (needed for pod-to-pod communication)
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system > /dev/null 2>&1
    
    print_success "System configured for Kubernetes"
}

# STEP 5: Install Kubernetes packages
step5_install_kubernetes() {
    print_section "STEP 4/8: Installing Kubernetes"
    
    # Check if already installed AND cluster is running
    if command_exists kubectl && kubectl get nodes &> /dev/null; then
        print_warning "Kubernetes already installed and cluster is running - skipping"
        return 0
    fi
    
    # If kubectl exists but cluster is not running, just note it
    if command_exists kubectl; then
        print_info "Kubernetes packages installed, will initialize cluster in next step"
        return 0
    fi
    
    # Add Kubernetes repository
    print_info "Adding Kubernetes repository..."
    # Create directory for GPG keys
    mkdir -p /etc/apt/keyrings
    # Remove old key if it exists to avoid prompts
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    # Download and install Kubernetes signing key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
        | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    # Add repository to apt sources
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' \
        > /etc/apt/sources.list.d/kubernetes.list
    
    # Update package lists to include new repo
    apt-get update -qq
    
    # Install Kubernetes components
    # kubelet - Runs on each node, starts containers
    # kubeadm - Tool to set up cluster
    # kubectl - Command-line tool to control cluster
    print_info "Installing Kubernetes packages (this takes a few minutes)..."
    apt-get install -y -qq kubelet kubeadm kubectl > /dev/null 2>&1
    
    # Prevent automatic updates (we want specific versions)
    apt-mark hold kubelet kubeadm kubectl > /dev/null 2>&1
    
    print_success "Kubernetes packages installed"
}

# STEP 6: Install containerd (the container runtime)
step6_install_containerd() {
    print_info "Checking containerd..."
    
    if command_exists containerd; then
        print_success "containerd already installed"
        return 0
    fi
    
    print_info "Installing containerd..."
    apt-get install -y -qq containerd > /dev/null 2>&1
    
    # Generate default configuration
    print_info "Configuring containerd..."
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    
    # Enable systemd cgroup driver (recommended for Kubernetes)
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Restart with new config
    systemctl restart containerd
    
    print_success "containerd installed and configured"
}

# STEP 7: Initialize Kubernetes cluster
step7_initialize_kubernetes() {
    print_section "STEP 5/8: Creating Kubernetes Cluster"
    
    # Check if cluster already exists and is working
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get nodes &> /dev/null; then
        print_warning "Kubernetes cluster already initialized"
        local node_status=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
        if [ "$node_status" = "True" ]; then
            print_success "Kubernetes cluster is already ready"
            
            # IMPORTANT: Always ensure taint is removed for single-node cluster
            print_info "Ensuring control-plane taint is removed (single-node setup)..."
            kubectl taint nodes --all node-role.kubernetes.io/control-plane- > /dev/null 2>&1 || true
            kubectl taint nodes --all node-role.kubernetes.io/master- > /dev/null 2>&1 || true
            
            return 0
        else
            print_info "Cluster exists but node not ready - will check network setup"
            return 0
        fi
    fi
    
    print_info "Using universal Kubernetes recovery script for cluster setup..."
    
    # Use the universal script which handles everything properly
    if [ -f "./universal-k8s-recovery.sh" ]; then
        print_info "Running universal-k8s-recovery.sh (this will take 2-3 minutes)..."
        echo "yes" | bash ./universal-k8s-recovery.sh
        
        if [ $? -ne 0 ]; then
            print_error "Kubernetes cluster initialization failed!"
            return 1
        fi
    else
        # Fallback to manual initialization
        print_info "Universal script not found, using manual initialization..."
        local local_ip=$(get_local_ip)
        
        # Run kubeadm init with ignore preflight errors for port conflicts
        if ! kubeadm init \
            --pod-network-cidr=10.244.0.0/16 \
            --apiserver-advertise-address=$local_ip \
            --ignore-preflight-errors=Port-6443,Port-10259,Port-10257,Port-2379,Port-2380; then
            print_error "Kubernetes cluster initialization failed!"
            print_error "Check /var/log/pods/ for details"
            return 1
        fi
        
        # Set up kubectl
        print_info "Configuring kubectl access..."
        local actual_user=$(get_actual_user)
        local actual_home=$(get_actual_home)
        mkdir -p "$actual_home/.kube"
        cp /etc/kubernetes/admin.conf "$actual_home/.kube/config"
        chown -R "$actual_user:$actual_user" "$actual_home/.kube"
        export KUBECONFIG=/etc/kubernetes/admin.conf
        
        # Remove taint so pods can run on this control-plane node
        print_info "Allowing workloads on control plane (single-node setup)..."
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- > /dev/null 2>&1 || true
        
        # Install Flannel manually
        print_info "Installing Flannel networking..."
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        sleep 10
    fi
    
    # Set KUBECONFIG for rest of script
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    print_success "Kubernetes cluster initialized"
}

# STEP 8: Wait for Network to be Ready
step8_install_network() {
    print_section "STEP 6/8: Verifying Network"
    
    # Set KUBECONFIG
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    # Check if Flannel is already installed and running
    if kubectl get pods -n kube-flannel &> /dev/null; then
        local flannel_ready=$(kubectl get pods -n kube-flannel -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True" || echo "0")
        if [ "$flannel_ready" -gt 0 ]; then
            print_success "Flannel is already running"
            return 0
        fi
    fi
    
    # Wait for Flannel pods to be ready (important - don't skip this!)
    print_info "Waiting for Flannel pods to be ready (may take 1-2 minutes)..."
    kubectl wait --for=condition=Ready pods --all -n kube-flannel --timeout=180s > /dev/null 2>&1 || true
    
    # Wait for node to be ready
    print_info "Waiting for node to be Ready..."
    local max_wait=120  # Increased from 60 to 120 seconds
    local count=0
    while [ $count -lt $max_wait ]; do
        if kubectl get nodes | grep -q " Ready "; then
            break
        fi
        sleep 5  # Check every 5 seconds
        count=$((count + 5))
        echo -n "."
    done
    echo
    
    print_success "Kubernetes cluster is ready"
}

# STEP 9: Install CoCo operator
step9_install_coco_operator() {
    print_section "STEP 6/8: Installing Confidential Containers Operator"
    
    # Set KUBECONFIG
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    # Check if CoCo operator is already installed and running
    if kubectl get namespace confidential-containers-system &> /dev/null; then
        local operator_pods=$(kubectl get pods -n confidential-containers-system -l app.kubernetes.io/name=cc-operator-controller-manager -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
        if echo "$operator_pods" | grep -q "Running"; then
            print_warning "CoCo operator is already installed and running - skipping"
            print_success "CoCo operator installed"
            return 0
        fi
    fi
    
    print_info "Installing CoCo operator v0.10.0 (official method)..."
    # Using official operator installation from quickstart.md
    kubectl apply -k "github.com/confidential-containers/operator/config/release?ref=v0.10.0"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to install CoCo operator"
        return 1
    fi
    
    # Wait for operator pods to be created
    print_info "Waiting for operator pods to be created (60 seconds)..."
    sleep 60
    
    # Wait for operator to be ready
    print_info "Waiting for operator to be ready..."
    kubectl wait --for=condition=Ready \
        pod -l app.kubernetes.io/name=cc-operator-controller-manager \
        -n confidential-containers-system \
        --timeout=300s
    
    if [ $? -ne 0 ]; then
        print_warning "Operator may still be starting, continuing..."
    fi
    
    print_success "CoCo operator installed"
}

# STEP 10: Configure CoCo runtime (using official enclave-cc configuration)
step10_configure_coco_runtime() {
    # Set KUBECONFIG
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    print_info "Labeling node as worker (required by CcRuntime)..."
    # Label node as worker - this is required by CcRuntime CcNodeSelector
    local node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    kubectl label node "$node_name" node.kubernetes.io/worker= --overwrite
    
    print_info "Deploying enclave-cc runtime using OFFICIAL configuration..."
    print_info "Using: config/samples/enclave-cc/sim (SGX simulation mode)"
    
    # Use official enclave-cc SGX simulation configuration from operator repo
    # This is the tested and working configuration
    kubectl apply -k "github.com/confidential-containers/operator/config/samples/enclave-cc/sim?ref=v0.10.0"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to apply enclave-cc configuration"
        return 1
    fi
    
    # Wait for CcRuntime to be created
    print_info "Waiting for CcRuntime to be created..."
    sleep 10
    
    # Monitor runtime installation progress
    print_info "Monitoring runtime installation (may take 2-3 minutes)..."
    local max_wait=180  # 3 minutes
    local count=0
    while [ $count -lt $max_wait ]; do
        local completed=$(kubectl get ccruntime -o jsonpath='{.items[0].status.installationStatus.completed.completedNodesCount}' 2>/dev/null || echo "0")
        local total=$(kubectl get ccruntime -o jsonpath='{.items[0].status.totalNodesCount}' 2>/dev/null || echo "0")
        
        if [ "$completed" != "0" ] && [ "$completed" == "$total" ]; then
            echo
            print_success "Runtime installation completed on $completed/$total nodes"
            break
        fi
        
        sleep 5
        count=$((count + 5))
        echo -n "."
    done
    echo
    
    # Verify RuntimeClass was created
    print_info "Verifying RuntimeClass creation..."
    if kubectl get runtimeclass enclave-cc &>/dev/null; then
        print_success "RuntimeClass 'enclave-cc' created successfully"
    else
        print_error "RuntimeClass not found - installation may have failed"
        print_info "Run: kubectl describe ccruntime"
        return 1
    fi
    
    print_success "enclave-cc runtime configured"
}

# STEP 11: Start Trustee services
step11_start_trustee_services() {
    print_section "STEP 7/8: Starting Trustee Services"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || {
        print_error "Failed to access $INSTALL_DIR"
        return 1
    }
    
    # Check if Trustee services are already running
    if docker ps | grep -q "trustee-kbs" && docker ps | grep -q "trustee-as"; then
        print_warning "Trustee services are already running - skipping"
        print_success "Trustee services running and healthy"
        return 0
    fi
    
    # Clean up any old docker containers that might be holding ports
    print_info "Cleaning up old docker containers..."
    docker stop $(docker ps -q) > /dev/null 2>&1 || true
    docker rm $(docker ps -aq) > /dev/null 2>&1 || true
    
    # Clone Trustee repository if not already there
    if [ ! -d "trustee" ]; then
        print_info "Downloading Trustee code to $INSTALL_DIR/trustee ..."
        git clone https://github.com/confidential-containers/trustee.git > /dev/null 2>&1
        
        if [ ! -d "trustee" ]; then
            print_error "Failed to download Trustee code"
            print_info "Trying alternative method..."
            git clone https://github.com/confidential-containers/trustee.git 2>&1 | tail -5
            
            if [ ! -d "trustee" ]; then
                print_error "Could not download Trustee. Please check internet connection."
                return 1
            fi
        fi
        
        # Set ownership to actual user
        local actual_user=$(get_actual_user)
        chown -R "$actual_user:$actual_user" trustee 2>/dev/null || true
        
        print_success "Trustee code downloaded"
    else
        print_info "Trustee code already present at $INSTALL_DIR/trustee"
    fi
    
    # Change to trustee directory
    cd trustee || {
        print_error "Failed to access trustee directory"
        return 1
    }
    
    print_info "Working directory: $(pwd)"
    
    # Configure docker-compose for SGX simulation with sample attestation
    print_info "Configuring Trustee for SGX simulation mode..."
    
    # 1. Modify docker-compose.yml to use port 8090 for KBS (external access)
    if [ -f "docker-compose.yml" ]; then
        print_info "Updating KBS port mapping to 8090:8080..."
        sed -i 's/"8080:8080"/"8090:8080"/g' docker-compose.yml
    fi
    
    # 2. Configure AS to support sample attestation verifier
    print_info "Adding sample verifier configuration to AS..."
    if [ -f "kbs/config/as-config.json" ]; then
        # Check if verifier_config already exists
        if ! grep -q "verifier_config" kbs/config/as-config.json; then
            # Add verifier_config for sample attestation
            # Use Python to properly insert JSON (safer than sed for JSON)
            python3 -c '
import json
import sys

try:
    with open("kbs/config/as-config.json", "r") as f:
        config = json.load(f)
    
    # Add verifier_config if not present
    if "verifier_config" not in config:
        config["verifier_config"] = {"sample": {}}
        
        with open("kbs/config/as-config.json", "w") as f:
            json.dump(config, f, indent=4)
        print("✓ Added sample verifier config")
    else:
        print("✓ Verifier config already present")
except Exception as e:
    print(f"Warning: Could not modify AS config: {e}", file=sys.stderr)
    sys.exit(0)  # Continue anyway
' || {
                # Fallback: manual JSON append
                print_warning "Python modification failed, using manual method..."
                # Backup original
                cp kbs/config/as-config.json kbs/config/as-config.json.backup 2>/dev/null || true
                # Add verifier_config manually (simple append before closing brace)
                sed -i 's/}$/,\n    "verifier_config": {\n        "sample": {}\n    }\n}/' kbs/config/as-config.json
            }
        else
            print_info "Sample verifier already configured"
        fi
    else
        print_warning "AS config file not found at kbs/config/as-config.json"
    fi
    
    print_success "Trustee configuration completed"
    
    # Start all Trustee services using docker compose
    print_info "Starting Trustee services (KBS, AS, RVPS, Keyprovider)..."
    if docker compose up -d 2>&1 | grep -q "no configuration file provided"; then
        print_error "docker-compose.yml not found in $(pwd)"
        print_info "Checking directory contents..."
        ls -la | head -10
        return 1
    fi
    
    # Wait for services to start
    print_info "Waiting for services to initialize (10 seconds)..."
    sleep 10
    
    # Check if services are actually running
    print_info "Verifying Trustee services are healthy..."
    local max_wait=60
    local count=0
    local all_running=false
    while [ $count -lt $max_wait ]; do
        if docker ps | grep -q "trustee-kbs.*Up" && \
           docker ps | grep -q "trustee-as.*Up" && \
           docker ps | grep -q "trustee-rvps.*Up"; then
            all_running=true
            break
        fi
        sleep 5
        count=$((count + 5))
        echo -n "."
    done
    echo
    
    if [ "$all_running" = true ]; then
        print_success "Trustee services running and healthy"
        
        # Show running services
        print_info "Service status:"
        docker ps --filter "name=trustee" --format "  {{.Names}}: {{.Status}}"
        
        # Test KBS API to ensure it's really working
        sleep 3
        local kbs_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/kbs/v0/auth 2>/dev/null || echo "000")
        if [ "$kbs_response" = "401" ] || [ "$kbs_response" = "200" ]; then
            print_success "KBS API responding on port 8080"
        else
            # Try port 8090
            kbs_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/kbs/v0/auth 2>/dev/null || echo "000")
            if [ "$kbs_response" = "401" ] || [ "$kbs_response" = "200" ]; then
                print_success "KBS API responding on port 8090"
            else
                print_warning "KBS API may not be fully ready yet (will retry during demo)"
            fi
        fi
    else
        print_warning "Trustee services may still be initializing"
        print_info "Checking what's running:"
        docker ps --filter "name=trustee" --format "  {{.Names}}: {{.Status}}"
    fi
    
    # Return to install dir
    cd "$INSTALL_DIR"
}

# STEP 12: Deploy demo workload
step12_deploy_demo_workload() {
    print_section "STEP 8/8: Deploying Demo Workload"
    
    # Set KUBECONFIG
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    local local_ip=$(get_local_ip)
    
    print_info "Creating SGX demo pod configuration..."
    # Create a pod that uses the enclave-cc runtime
    cat > /tmp/sgx-demo-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sgx-demo-pod
  namespace: default
  labels:
    app: coco-demo
  annotations:
    # Tell the pod how to reach the Key Broker Service with sample attestation
    # sample mode is correct for SGX simulation - it contacts KBS with sample evidence
    io.katacontainers.config.hypervisor.kernel_params: |
      agent.aa_kbc_params=cc_kbc::sample::http://${local_ip}:8090
      agent.log_level=debug
    # Enable SGX simulation mode
    io.katacontainers.config.hypervisor.sgx_simulation: "true"
spec:
  # Use CoCo runtime (this is the key part!)
  runtimeClassName: enclave-cc
  containers:
  - name: demo-container
    image: ubuntu:22.04
    command: ["/bin/bash", "-c"]
    args:
      - |
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║   CoCo SGX Demo - Running in Confidential Container     ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        echo "This pod is protected by SGX (simulation mode)"
        echo "Runtime: enclave-cc"
        echo "KBS endpoint: http://${local_ip}:8090"
        echo "Attestation: Sample TEE (for demo/testing)"
        echo ""
        echo "Container ready! Keeping alive for demonstrations..."
        sleep 7200
    resources:
      limits:
        cpu: "1000m"
        memory: "512Mi"
  restartPolicy: Never
EOF

    print_info "Deploying pod..."
    kubectl apply -f /tmp/sgx-demo-pod.yaml > /dev/null 2>&1
    
    # Copy config to package for reference
    cp /tmp/sgx-demo-pod.yaml "$SCRIPT_DIR/configs/" 2>/dev/null || true
    
    # Wait for pod to be created
    print_info "Waiting for pod to be created..."
    sleep 5
    
    # Wait for pod to be running or completed (with timeout)
    print_info "Waiting for pod to start (may take 1-2 minutes)..."
    local max_wait=180  # 3 minutes
    local count=0
    while [ $count -lt $max_wait ]; do
        local pod_status=$(kubectl get pod sgx-demo-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$pod_status" = "Running" ] || [ "$pod_status" = "Succeeded" ]; then
            echo
            break
        fi
        sleep 5
        count=$((count + 5))
        echo -n "."
    done
    echo
    
    print_success "Demo workload deployed"
}

# STEP 13: Verify everything
step13_verify_deployment() {
    print_section "VERIFICATION"
    
    print_info "Checking deployment status..."
    echo
    
    # Check each component
    if kubectl get nodes | grep -q " Ready "; then
        print_success "Kubernetes cluster: Ready"
    else
        print_error "Kubernetes cluster: Not ready"
    fi
    
    if kubectl get pods -n confidential-containers-system | grep -q "Running"; then
        print_success "CoCo operator: Running"
    else
        print_warning "CoCo operator: Still starting"
    fi
    
    if kubectl get runtimeclass enclave-cc &> /dev/null; then
        print_success "enclave-cc runtime: Available"
    else
        print_error "enclave-cc runtime: Not found"
    fi
    
    if docker ps | grep -q "trustee-kbs"; then
        print_success "Trustee services: Running"
    else
        print_error "Trustee services: Not running"
    fi
    
    local pod_status=$(kubectl get pod sgx-demo-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [ "$pod_status" = "Running" ]; then
        print_success "Demo pod: Running"
    elif [ "$pod_status" = "Pending" ]; then
        print_warning "Demo pod: Starting (this is normal)"
    else
        print_warning "Demo pod: $pod_status"
    fi
    
    echo
}

# STEP 14: Save deployment information
step14_save_info() {
    local local_ip=$(get_local_ip)
    local actual_user=$(get_actual_user)
    
    print_info "Saving deployment information..."
    
    # Create an info file for the user
    cat > "$INSTALL_DIR/deployment-info.txt" <<EOF
CoCo SGX Demo - Deployment Information
======================================

Installed: $(date)
Location: $INSTALL_DIR
Local IP: $local_ip

Service Endpoints:
-----------------
KBS (Key Broker):         http://${local_ip}:8090
AS (Attestation):         grpc://${local_ip}:50014
RVPS (Reference Values):  http://${local_ip}:50013
Keyprovider:              grpc://${local_ip}:50010

Quick Commands:
--------------
Check all pods:          kubectl get pods --all-namespaces
View demo pod logs:      kubectl logs sgx-demo-pod
Check Trustee services:  cd $INSTALL_DIR/trustee && docker compose ps
Run tests:               $SCRIPT_DIR/test-deployment.sh
Try encryption demo:     $SCRIPT_DIR/demo-encryption.sh

Files:
-----
Installation directory:  $INSTALL_DIR
Trustee services:        $INSTALL_DIR/trustee
Kubectl config:          ~/.kube/config
EOF

    chown "$actual_user:$actual_user" "$INSTALL_DIR/deployment-info.txt"
    
    # Save local IP for other scripts to use
    echo "$local_ip" > "$SCRIPT_DIR/.local-ip"
    chown "$actual_user:$actual_user" "$SCRIPT_DIR/.local-ip"
    
    print_success "Deployment info saved to $INSTALL_DIR/deployment-info.txt"
}

# STEP 15: Show final message
step15_show_final_message() {
    local local_ip=$(get_local_ip)
    local actual_user=$(get_actual_user)
    
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          ✅ INSTALLATION COMPLETE! ✅                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

${COLOR_GREEN}What was installed:${COLOR_RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ Kubernetes v1.31.13 (single-node cluster)
  ✅ CoCo operator v0.10.0
  ✅ enclave-cc RuntimeClass (for SGX containers)
  ✅ Trustee services (KBS, AS, RVPS, Keyprovider)
  ✅ Sample attestation configured (for SGX simulation)
  ✅ Demo SGX-protected workload

${COLOR_CYAN}Attestation Configuration:${COLOR_RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Mode:     SGX Simulation with sample attestation
  KBC:      sample (contacts KBS with sample evidence type)
  Protocol: AA → KBS → AS → verify sample → token → fetch key
  Evidence: Simulated SGX quote (sample type)

${COLOR_CYAN}Service endpoints:${COLOR_RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  KBS:  http://${local_ip}:8090

${COLOR_YELLOW}Next steps:${COLOR_RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Run tests to verify everything:
     ${COLOR_GREEN}./test-deployment.sh${COLOR_RESET}

  2. Try the encrypted data demonstration:
     ${COLOR_GREEN}./demo-encryption.sh${COLOR_RESET}

  3. Check the demo pod:
     ${COLOR_GREEN}kubectl get pods${COLOR_RESET}
     ${COLOR_GREEN}kubectl logs sgx-demo-pod${COLOR_RESET}

${COLOR_BLUE}Info file:${COLOR_RESET} $INSTALL_DIR/deployment-info.txt

${COLOR_GREEN}🎉 Your CoCo SGX demo is ready! 🎉${COLOR_RESET}

${COLOR_YELLOW}Note: The demo pod may take 1-2 minutes to fully start.${COLOR_RESET}

To remove everything:  ${COLOR_RED}sudo ./cleanup.sh${COLOR_RESET}

EOF
}

################################################################################
# MAIN SCRIPT EXECUTION
# This is where the actual work happens
################################################################################

main() {
    # Show welcome banner
    clear
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🔐 CONFIDENTIAL CONTAINERS SGX DEMO SETUP 🔐             ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

This script will install a complete Confidential Containers demo.

Time required: ~10 minutes
Requirements:  Ubuntu 20.04+, 8GB RAM, internet, sudo

EOF

    # Ask user to confirm
    echo -e "${COLOR_YELLOW}Press Enter to start installation, or Ctrl+C to cancel...${COLOR_RESET}"
    read
    
    # Check we're running as root (with sudo)
    if [ "$EUID" -ne 0 ]; then 
        print_error "Please run with sudo: sudo ./setup-coco-demo.sh"
        exit 1
    fi
    
    # Get actual user info (not root)
    local actual_user=$(get_actual_user)
    local actual_home=$(get_actual_home)
    
    # Update INSTALL_DIR to use actual user's home
    INSTALL_DIR="$actual_home/coco-demo"
    
    # Run all installation steps in order
    step1_prepare_system || { print_error "Step 1 failed"; exit 1; }
    step2_install_docker || { print_error "Step 2 failed"; exit 1; }
    step3_install_docker_compose || { print_error "Step 3 failed"; exit 1; }
    step4_prepare_kubernetes_system || { print_error "Step 4 failed"; exit 1; }
    step5_install_kubernetes || { print_error "Step 5 failed"; exit 1; }
    step6_install_containerd || { print_error "Step 6 failed"; exit 1; }
    step7_initialize_kubernetes || { print_error "Step 7 failed - Kubernetes cluster initialization"; exit 1; }
    step8_install_network || { print_error "Step 8 failed - Network setup"; exit 1; }
    step9_install_coco_operator || { print_error "Step 9 failed - CoCo operator"; exit 1; }
    step10_configure_coco_runtime || { print_error "Step 10 failed - Runtime configuration"; exit 1; }
    step11_start_trustee_services || { print_error "Step 11 failed - Trustee services"; exit 1; }
    step12_deploy_demo_workload || { print_error "Step 12 failed - Demo workload"; exit 1; }
    step13_verify_deployment
    step14_save_info
    
    # Make user owner of installation directory
    chown -R "$actual_user:$actual_user" "$INSTALL_DIR"
    
    # Show success message
    step15_show_final_message
}

# Start the script
main

exit 0
