#!/bin/bash

# K3s Nintendo Switch Cluster Setup Script
# This script sets up a K3s cluster with macOS as master and Nintendo Switch as worker
# Includes Tekton Pipelines installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SWITCH_IP="${SWITCH_IP:-}"
SWITCH_USER="${SWITCH_USER:-}"
SWITCH_PASS="${SWITCH_PASS:-}"
K3S_VERSION="${K3S_VERSION:-v1.30.0+k3s1}"
CLUSTER_TOKEN="k3s-nintendo-switch-token"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

heading() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

collect_nintendo_switch_info() {
    heading "Nintendo Switch Configuration"
    
    # Get Nintendo Switch IP
    if [[ -z "$SWITCH_IP" ]]; then
        echo -n "Enter Nintendo Switch IP address [192.168.0.112]: "
        read -r user_ip
        SWITCH_IP="${user_ip:-192.168.0.112}"
    fi
    
    # Get Nintendo Switch username
    if [[ -z "$SWITCH_USER" ]]; then
        echo -n "Enter Nintendo Switch SSH username: "
        read -r SWITCH_USER
        if [[ -z "$SWITCH_USER" ]]; then
            error "Username is required"
        fi
    fi
    
    # Get Nintendo Switch password
    if [[ -z "$SWITCH_PASS" ]]; then
        echo -n "Enter Nintendo Switch SSH password: "
        read -s SWITCH_PASS
        echo  # New line after hidden input
        if [[ -z "$SWITCH_PASS" ]]; then
            error "Password is required"
        fi
    fi
    
    log "Configuration collected:"
    log "  Nintendo Switch IP: $SWITCH_IP"
    log "  Nintendo Switch User: $SWITCH_USER"
    log "  Password: [HIDDEN]"
    echo
}

check_dependencies() {
    heading "Checking Dependencies"
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This script is designed for macOS master nodes only"
    fi
    
    # Check for required tools
    command -v docker >/dev/null 2>&1 || error "Docker is required but not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v curl >/dev/null 2>&1 || error "curl is required but not installed"
    
    # Check if sshpass is available
    if ! command -v sshpass >/dev/null 2>&1; then
        log "Installing sshpass..."
        brew install sshpass || error "Failed to install sshpass"
    fi
    
    log "All dependencies satisfied"
}

get_master_ip() {
    # Get the local IP address that can reach the Nintendo Switch
    MASTER_IP=$(route get "$SWITCH_IP" 2>/dev/null | grep interface | awk '{print $2}' | xargs ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    
    if [[ -z "$MASTER_IP" ]]; then
        MASTER_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    fi
    
    if [[ -z "$MASTER_IP" ]]; then
        error "Could not determine master IP address"
    fi
    
    log "Master IP detected: $MASTER_IP"
}

test_switch_connectivity() {
    heading "Testing Nintendo Switch Connectivity"
    
    log "Testing ping to $SWITCH_IP..."
    if ! ping -c 3 "$SWITCH_IP" >/dev/null 2>&1; then
        error "Cannot ping Nintendo Switch at $SWITCH_IP"
    fi
    
    log "Testing SSH connectivity..."
    if ! timeout 10 sshpass -p "$SWITCH_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
        error "Cannot SSH to Nintendo Switch. Check credentials and connectivity."
    fi
    
    log "Nintendo Switch connectivity verified"
}

setup_k3s_master() {
    heading "Setting up K3s Master on macOS"
    
    # Stop existing container if running
    if docker ps --format "table {{.Names}}" | grep -q k3s-master; then
        log "Stopping existing K3s master container..."
        docker stop k3s-master >/dev/null 2>&1 || true
        docker rm k3s-master >/dev/null 2>&1 || true
    fi
    
    log "Starting K3s master container..."
    docker run -d \
        --name k3s-master \
        --restart unless-stopped \
        --privileged \
        -p 6443:6443 \
        -p 8080:80 \
        -p 8443:443 \
        -e K3S_TOKEN="$CLUSTER_TOKEN" \
        -e K3S_KUBECONFIG_OUTPUT=/output/kubeconfig.yaml \
        -e K3S_KUBECONFIG_MODE=666 \
        -v k3s-master:/var/lib/rancher/k3s \
        -v "$HOME/.kube:/output" \
        "rancher/k3s:$K3S_VERSION" \
        server --bind-address=0.0.0.0 --advertise-address="$MASTER_IP" >/dev/null
    
    log "Waiting for K3s master to be ready..."
    for i in {1..60}; do
        if curl -k "https://$MASTER_IP:6443/ping" >/dev/null 2>&1; then
            break
        fi
        sleep 2
        if [[ $i -eq 60 ]]; then
            error "K3s master failed to start within 2 minutes"
        fi
    done
    
    # Setup kubeconfig
    mkdir -p "$HOME/.kube"
    
    log "Waiting for kubeconfig generation..."
    for i in {1..30}; do
        if [[ -f "$HOME/.kube/kubeconfig.yaml" ]]; then
            break
        fi
        sleep 2
        if [[ $i -eq 30 ]]; then
            error "Kubeconfig not generated within 1 minute"
        fi
    done
    
    cp "$HOME/.kube/kubeconfig.yaml" "$HOME/.kube/config"
    
    # Update server IP in kubeconfig
    sed -i '' "s/127\.0\.0\.1/$MASTER_IP/g" "$HOME/.kube/config"
    
    # Test kubectl
    kubectl get nodes >/dev/null 2>&1 || error "kubectl connection failed"
    
    log "K3s master setup complete"
}

setup_k3s_agent() {
    heading "Setting up K3s Agent on Nintendo Switch"
    
    log "Testing master connectivity from Nintendo Switch..."
    if ! timeout 30 sshpass -p "$SWITCH_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" "curl -k https://$MASTER_IP:6443/ping --connect-timeout 10" >/dev/null 2>&1; then
        error "Nintendo Switch cannot reach K3s master"
    fi
    
    log "Installing K3s agent on Nintendo Switch..."
    timeout 300 sshpass -p "$SWITCH_PASS" ssh -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" \
        "echo '$SWITCH_PASS' | sudo -S bash -c \"curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$CLUSTER_TOKEN INSTALL_K3S_VERSION=$K3S_VERSION sh -\"" \
        || error "Failed to install K3s agent"
    
    log "Waiting for agent to join cluster..."
    for i in {1..30}; do
        if kubectl get nodes | grep -q waveywaves-switch; then
            break
        fi
        sleep 2
        if [[ $i -eq 30 ]]; then
            error "Nintendo Switch failed to join cluster within 1 minute"
        fi
    done
    
    # Label the Nintendo Switch node
    log "Configuring Nintendo Switch as worker node..."
    kubectl label node waveywaves-switch hardware=nintendo-switch --overwrite >/dev/null 2>&1 || true
    kubectl label node waveywaves-switch arch=arm64 --overwrite >/dev/null 2>&1 || true
    
    log "K3s agent setup complete"
}

install_tekton() {
    heading "Installing Tekton Pipelines"
    
    log "Installing Tekton Pipelines..."
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml >/dev/null 2>&1
    
    log "Waiting for Tekton Pipelines to be ready..."
    kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s >/dev/null 2>&1 || {
        warn "Tekton Pipelines deployment timed out, but may still be starting"
    }
    
    log "Installing Tekton Dashboard..."
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml >/dev/null 2>&1
    
    log "Waiting for Tekton Dashboard to be ready..."
    kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s >/dev/null 2>&1 || {
        warn "Tekton Dashboard deployment timed out, but may still be starting"
    }
    
    log "Tekton Pipelines installation complete"
}

create_sample_pipeline() {
    heading "Creating Sample Tekton Pipeline"
    
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: nintendo-hello-task
  namespace: default
spec:
  steps:
    - name: hello
      image: ubuntu
      command:
        - echo
      args:
        - "Hello from Nintendo Switch K3s Cluster! 🎮⚓"
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: nintendo-hello-pipeline
  namespace: default
spec:
  tasks:
    - name: say-hello
      taskRef:
        name: nintendo-hello-task
---
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: nintendo-hello-pipeline-run
  namespace: default
spec:
  pipelineRef:
    name: nintendo-hello-pipeline
EOF
    
    log "Sample pipeline created: nintendo-hello-pipeline"
}

display_cluster_info() {
    heading "Cluster Information"
    
    echo
    log "Cluster Nodes:"
    kubectl get nodes -o wide
    
    echo
    log "Cluster Info:"
    kubectl cluster-info
    
    echo
    log "Tekton Pipelines Status:"
    kubectl get pods -n tekton-pipelines
    
    echo
    log "Sample Pipeline Status:"
    kubectl get pipelinerun nintendo-hello-pipeline-run -o wide 2>/dev/null || echo "Sample pipeline not yet created"
    
    echo
    log "Access Tekton Dashboard:"
    echo "  kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097"
    echo "  Then open: http://localhost:9097"
    
    echo
    log "Monitor Sample Pipeline:"
    echo "  kubectl logs -f \$(kubectl get pods -l tekton.dev/pipelineRun=nintendo-hello-pipeline-run -o name)"
    
    echo
    log "Nintendo Switch K3s Cluster is ready! 🎮⚓"
}

# Main execution
main() {
    heading "K3s Nintendo Switch Cluster Setup"
    
    check_dependencies
    collect_nintendo_switch_info
    get_master_ip
    test_switch_connectivity
    setup_k3s_master
    setup_k3s_agent
    install_tekton
    create_sample_pipeline
    display_cluster_info
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --switch-ip)
            SWITCH_IP="$2"
            shift 2
            ;;
        --switch-user)
            SWITCH_USER="$2"
            shift 2
            ;;
        --switch-pass)
            SWITCH_PASS="$2"
            shift 2
            ;;
        --k3s-version)
            K3S_VERSION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "This script will interactively prompt for Nintendo Switch credentials"
            echo "if they are not provided via command line options or environment variables."
            echo
            echo "Options:"
            echo "  --switch-ip IP       Nintendo Switch IP address (will prompt if not provided)"
            echo "  --switch-user USER   Nintendo Switch SSH user (will prompt if not provided)"
            echo "  --switch-pass PASS   Nintendo Switch SSH password (will prompt if not provided)"
            echo "  --k3s-version VER    K3s version to install (default: v1.30.0+k3s1)"
            echo "  --help              Show this help message"
            echo
            echo "Environment variables:"
            echo "  SWITCH_IP, SWITCH_USER, SWITCH_PASS, K3S_VERSION"
            echo
            echo "Examples:"
            echo "  $0                                    # Interactive mode (recommended)"
            echo "  $0 --switch-ip 192.168.1.100        # Specify IP, prompt for credentials"
            echo "  SWITCH_USER=myuser $0                # Set user via environment variable"
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Run main function
main "$@"
