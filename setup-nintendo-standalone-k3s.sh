#!/bin/bash

# Nintendo Switch Standalone K3s Cluster Setup Script
# This script sets up the Nintendo Switch as a complete single-node Kubernetes cluster
# (master + worker combined) with monitoring and management UIs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SWITCH_IP="${SWITCH_IP:-}"
SWITCH_USER="${SWITCH_USER:-}"
SWITCH_PASS="${SWITCH_PASS:-}"
K3S_VERSION="${K3S_VERSION:-v1.30.0+k3s1}"
CLUSTER_TOKEN="nintendo-switch-cluster-token"
LOCAL_IP=""

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

success() {
    echo -e "${PURPLE}✅ $1${NC}"
}

collect_nintendo_switch_info() {
    heading "Nintendo Switch Configuration"
    
    # Get Nintendo Switch IP
    if [[ -z "$SWITCH_IP" ]]; then
        echo -n "Enter Nintendo Switch IP address: "
        read -r SWITCH_IP
        if [[ -z "$SWITCH_IP" ]]; then
            error "Nintendo Switch IP address is required"
        fi
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
    
    # Check for required tools
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v curl >/dev/null 2>&1 || error "curl is required but not installed"
    
    # Check if sshpass is available
    if ! command -v sshpass >/dev/null 2>&1; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log "Installing sshpass..."
            brew install sshpass || error "Failed to install sshpass"
        else
            error "sshpass is required. Please install it first."
        fi
    fi
    
    log "All dependencies satisfied"
}

get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        LOCAL_IP=$(route get "$SWITCH_IP" 2>/dev/null | grep interface | awk '{print $2}' | xargs ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    else
        LOCAL_IP=$(ip route get "$SWITCH_IP" 2>/dev/null | grep src | awk '{print $7}' | head -1)
    fi
    
    if [[ -z "$LOCAL_IP" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
        else
            LOCAL_IP=$(hostname -I | awk '{print $1}')
        fi
    fi
    
    if [[ -z "$LOCAL_IP" ]]; then
        error "Could not determine local IP address"
    fi
    
    log "Local machine IP detected: $LOCAL_IP"
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
    
    success "Nintendo Switch connectivity verified"
}

setup_nintendo_k3s_master() {
    heading "Setting up Nintendo Switch as Standalone K3s Cluster"
    
    log "Installing K3s as single-node cluster on Nintendo Switch..."
    
    # Create the installation command
    local install_cmd="curl -sfL https://get.k3s.io | K3S_TOKEN=$CLUSTER_TOKEN INSTALL_K3S_VERSION=$K3S_VERSION sudo sh -s - --write-kubeconfig-mode 644 --bind-address $SWITCH_IP --advertise-address $SWITCH_IP --disable traefik"
    
    # Execute the installation
    if ! timeout 300 sshpass -p "$SWITCH_PASS" ssh -t -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" \
        "echo '$SWITCH_PASS' | sudo -S bash -c \"$install_cmd\""; then
        error "Failed to install K3s on Nintendo Switch"
    fi
    
    log "Waiting for K3s cluster to be ready..."
    for i in {1..30}; do
        if timeout 10 sshpass -p "$SWITCH_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" \
            "sudo kubectl get nodes >/dev/null 2>&1"; then
            break
        fi
        sleep 2
        if [[ $i -eq 30 ]]; then
            error "K3s cluster failed to start within 1 minute"
        fi
    done
    
    success "K3s cluster successfully installed on Nintendo Switch"
}

setup_local_kubectl_access() {
    heading "Setting up Local kubectl Access"
    
    log "Retrieving kubeconfig from Nintendo Switch..."
    
    # Get the kubeconfig
    local kubeconfig
    kubeconfig=$(timeout 30 sshpass -p "$SWITCH_PASS" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SWITCH_USER@$SWITCH_IP" \
        "sudo cat /etc/rancher/k3s/k3s.yaml") || error "Failed to retrieve kubeconfig"
    
    # Create local .kube directory
    mkdir -p "$HOME/.kube"
    
    # Update server IP and save kubeconfig
    echo "$kubeconfig" | sed "s/127\.0\.0\.1/$SWITCH_IP/g" > "$HOME/.kube/nintendo-switch-config"
    
    # Backup existing config if it exists
    if [[ -f "$HOME/.kube/config" ]]; then
        cp "$HOME/.kube/config" "$HOME/.kube/config.backup.$(date +%s)"
        log "Backed up existing kubeconfig"
    fi
    
    # Set the new config as default
    cp "$HOME/.kube/nintendo-switch-config" "$HOME/.kube/config"
    
    # Test kubectl connectivity
    if kubectl get nodes >/dev/null 2>&1; then
        success "kubectl configured successfully"
    else
        error "kubectl configuration failed"
    fi
}

deploy_kubernetes_dashboard() {
    heading "Deploying Kubernetes Dashboard"
    
    log "Installing Kubernetes Dashboard..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml >/dev/null 2>&1
    
    log "Creating admin service account..."
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
    
    success "Kubernetes Dashboard deployed"
}







create_sample_workloads() {
    heading "Creating Sample Nintendo Switch Workloads"
    
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nintendo-info-app
  labels:
    app: nintendo-info
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nintendo-info
  template:
    metadata:
      labels:
        app: nintendo-info
    spec:
      containers:
      - name: nintendo-info
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args:
          - -c
          - |
            cat > /usr/share/nginx/html/index.html << 'HTMLEOF'
            <!DOCTYPE html>
            <html>
            <head>
                <title>Nintendo Switch K3s Cluster</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0f0; }
                    .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                    h1 { color: #e60012; text-align: center; }
                    .info { margin: 20px 0; padding: 15px; background: #f9f9f9; border-left: 4px solid #0066cc; }
                    .links { display: flex; flex-wrap: wrap; gap: 15px; margin-top: 30px; }
                    .link { background: #0066cc; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; }
                    .link:hover { background: #0052a3; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🎮 Nintendo Switch K3s Cluster 🎮</h1>
                    <div class="info">
                        <h3>Cluster Information</h3>
                        <p><strong>Node:</strong> Nintendo Switch (ARM64)</p>
                        <p><strong>Kubernetes:</strong> K3s Single-Node Cluster</p>
                        <p><strong>Status:</strong> ✅ Running Independently</p>
                        <p><strong>IP Address:</strong> $SWITCH_IP</p>
                    </div>
                    <div class="info">
                        <h3>Available Services</h3>
                        <div class="links">
                            <a href="http://$SWITCH_IP:30000" class="link" target="_blank">🎛️ Kubernetes Dashboard</a>
                        </div>
                    </div>
                    <div class="info">
                        <h3>Quick Access Commands</h3>
                        <pre>
# Connect to cluster
export KUBECONFIG=~/.kube/nintendo-switch-config
kubectl get nodes

# Access Kubernetes Dashboard Token
kubectl -n kubernetes-dashboard create token admin-user

# Monitor cluster
kubectl top nodes
kubectl get pods --all-namespaces
                        </pre>
                    </div>
                </div>
            </body>
            </html>
HTMLEOF
            nginx -g 'daemon off;'
---
apiVersion: v1
kind: Service
metadata:
  name: nintendo-info-service
spec:
  selector:
    app: nintendo-info
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
EOF
    
    success "Sample Nintendo Switch web app deployed"
}

configure_dashboard_access() {
    heading "Configuring Dashboard Access"
    
    # Expose Kubernetes Dashboard
    kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30000}]' >/dev/null 2>&1
    
    success "Kubernetes Dashboard configured for external access"
}

display_cluster_info() {
    heading "Nintendo Switch Kubernetes Cluster Ready! 🎮⚓"
    
    echo
    log "Cluster Information:"
    kubectl get nodes -o wide 2>/dev/null || warn "Could not retrieve node information"
    
    echo
    log "🌐 Web Dashboards (Access from any device on your network):"
    echo "  🏠 Nintendo Switch Info:     http://$SWITCH_IP:30080"
    echo "  🎛️ Kubernetes Dashboard:     http://$SWITCH_IP:30000"
    
    echo
    log "🔑 Kubernetes Dashboard Access Token:"
    echo "  kubectl -n kubernetes-dashboard create token admin-user"
    
    echo
    log "💻 Local kubectl Configuration:"
    echo "  export KUBECONFIG=$HOME/.kube/nintendo-switch-config"
    echo "  kubectl get nodes"
    
    echo
    log "📋 Useful Commands:"
    echo "  kubectl top nodes                    # Resource usage"
    echo "  kubectl get pods --all-namespaces   # All running pods"
    echo "  kubectl cluster-info                # Cluster info"
    
    echo
    success "Your Nintendo Switch is now running a complete, independent Kubernetes cluster! 🎮🚀"
    echo -e "${PURPLE}Access the web dashboard at: ${BLUE}http://$SWITCH_IP:30080${NC}"
}

# Main execution
main() {
    heading "Nintendo Switch Standalone K3s Cluster Setup"
    
    check_dependencies
    collect_nintendo_switch_info
    get_local_ip
    test_switch_connectivity
    setup_nintendo_k3s_master
    setup_local_kubectl_access
    deploy_kubernetes_dashboard
    create_sample_workloads
    configure_dashboard_access
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
            echo "Setup Nintendo Switch as a standalone single-node Kubernetes cluster"
            echo
            echo "Options:"
            echo "  --switch-ip IP       Nintendo Switch IP address (will prompt if not provided)"
            echo "  --switch-user USER   Nintendo Switch SSH user (will prompt if not provided)"
            echo "  --switch-pass PASS   Nintendo Switch SSH password (will prompt if not provided)"
            echo "  --k3s-version VER    K3s version to install (default: v1.30.0+k3s1)"
            echo "  --help              Show this help message"
            echo
            echo "This will set up a complete Kubernetes cluster on your Nintendo Switch with:"
            echo "  - K3s single-node cluster (master + worker)"
            echo "  - Kubernetes Dashboard"
            echo "  - Web-based cluster management"
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Run main function
main "$@"
