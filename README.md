# 🎮⚓ K3s Nintendo Switch Cluster

**A complete setup for running Kubernetes on your Nintendo Switch with Tekton CI/CD pipelines!**

This repository provides everything you need to set up a K3s Kubernetes cluster with:
- **macOS Master Node**: Running K3s server in Docker
- **Nintendo Switch Worker Node**: ARM64 device running K3s agent
- **Tekton Pipelines**: CI/CD pipelines optimized for ARM64 builds

## 🚀 Quick Start

### One-Command Setup
```bash
./setup-k3s-nintendo-cluster.sh
```

The script will interactively prompt you for your Nintendo Switch credentials and then automatically:
1. ✅ Check dependencies and install missing tools
2. ✅ Set up K3s master on your macOS 
3. ✅ Install K3s agent on Nintendo Switch
4. ✅ Install Tekton Pipelines with Dashboard
5. ✅ Create sample pipelines for testing
6. ✅ Configure the Nintendo Switch as a dedicated worker node

### Custom Configuration
```bash
# Specify IP address, script will prompt for credentials
./setup-k3s-nintendo-cluster.sh --switch-ip 192.168.1.100

# Set credentials via environment variables (non-interactive)
SWITCH_USER=myuser SWITCH_PASS=mypassword ./setup-k3s-nintendo-cluster.sh

# Custom K3s version
./setup-k3s-nintendo-cluster.sh --k3s-version v1.29.0+k3s1

# Show all options
./setup-k3s-nintendo-cluster.sh --help
```

## 📋 Prerequisites

### macOS Master
- macOS (Intel or Apple Silicon)
- Docker Desktop installed and running
- kubectl installed
- Homebrew (for dependency installation)

### Nintendo Switch
- Nintendo Switch with Linux installed (Ubuntu 18.04+ recommended)
- SSH access enabled
- sudo privileges for the user
- Network connectivity to macOS

## 🎯 What You Get

### 📊 Cluster Architecture
```
┌─────────────────────┐    Network     ┌──────────────────────┐
│   macOS Master      │◄──────────────►│  Nintendo Switch     │
│   192.168.0.109     │    6443/tcp    │    Worker            │
│   (Control Plane)   │                │  192.168.0.112       │
│   + Tekton Dashboard │                │  + ARM64 Workloads  │
└─────────────────────┘                └──────────────────────┘
```

### 🔧 Installed Components
- **K3s v1.30.0+k3s1**: Lightweight Kubernetes distribution
- **Tekton Pipelines**: Modern CI/CD for Kubernetes
- **Tekton Dashboard**: Web UI for pipeline management
- **Sample Pipelines**: Ready-to-use ARM64 build examples

### 🏷️ Node Labels
```bash
# Master Node Labels
node-role.kubernetes.io/control-plane=true
node-role.kubernetes.io/master=true

# Nintendo Switch Labels
node-role.kubernetes.io/worker=true
hardware=nintendo-switch
arch=arm64
```

## 🎮 Running Pipelines

### Access Tekton Dashboard
```bash
# Start port forward
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097

# Open dashboard
open http://localhost:9097
```

### Run Sample Pipelines

#### 1. Nintendo Cluster Demo Pipeline
```bash
# Create and run the demo pipeline
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: nintendo-demo-$(date +%s)
spec:
  pipelineRef:
    name: nintendo-cluster-demo
EOF

# Monitor the pipeline
kubectl get pipelineruns -w
```

#### 2. ARM64 Build Pipeline
```bash
# Create workspace for the build
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-workspace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Run the ARM64 build pipeline
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: nintendo-build-$(date +%s)
spec:
  pipelineRef:
    name: nintendo-arm64-build
  workspaces:
    - name: shared-data
      persistentVolumeClaim:
        claimName: shared-workspace
EOF
```

### Monitor Pipeline Execution
```bash
# List all pipeline runs
kubectl get pipelineruns

# Watch pipeline progress
kubectl get pipelineruns -w

# Get detailed logs
kubectl logs -f $(kubectl get pods -l tekton.dev/pipelineRun=<pipeline-run-name> -o name)

# Check task status
kubectl get taskruns
```

## 🔍 Cluster Management

### Check Cluster Status
```bash
# View all nodes
kubectl get nodes -o wide

# Check Nintendo Switch specific workloads
kubectl get pods -o wide --field-selector spec.nodeName=waveywaves-switch

# View cluster resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Deploy Test Workloads
```bash
# Deploy to Nintendo Switch specifically
kubectl run nintendo-nginx \
  --image=nginx:alpine \
  --overrides='{"spec":{"nodeSelector":{"hardware":"nintendo-switch"}}}'

# Deploy ARM64 optimized workload
kubectl run arm64-test \
  --image=arm64v8/alpine:latest \
  --overrides='{"spec":{"nodeSelector":{"arch":"arm64"}}}'
```

### Tekton Pipeline Development
```bash
# List available tasks and pipelines
kubectl get tasks
kubectl get pipelines

# Create custom tasks for your ARM64 builds
kubectl apply -f your-custom-pipeline.yaml

# Debug pipeline runs
kubectl describe pipelinerun <pipeline-run-name>
```

## 📁 Repository Structure

```
k8s-nintendo-switch/
├── setup-k3s-nintendo-cluster.sh    # 🎯 Main setup script (ONE COMMAND!)
├── tekton-nintendo-pipeline.yaml    # 🏗️ Sample Tekton pipelines for ARM64
└── README.md                        # 📚 Complete documentation
```

**That's it! Just 3 files for a complete Nintendo Switch Kubernetes cluster with CI/CD pipelines!**

## 🛠️ Troubleshooting

### Nintendo Switch Issues
```bash
# Check K3s agent status
ssh waveywaves@192.168.0.112 "sudo systemctl status k3s-agent"

# View agent logs
ssh waveywaves@192.168.0.112 "sudo journalctl -u k3s-agent -f"

# Restart agent service
ssh waveywaves@192.168.0.112 "sudo systemctl restart k3s-agent"

# Test master connectivity
ssh waveywaves@192.168.0.112 "curl -k https://192.168.0.109:6443/ping"
```

### macOS Master Issues
```bash
# Check K3s master container
docker ps | grep k3s-master
docker logs k3s-master

# Restart master
docker restart k3s-master

# Check kubectl connectivity
kubectl cluster-info
```

### Tekton Issues
```bash
# Check Tekton components
kubectl get pods -n tekton-pipelines

# View Tekton logs
kubectl logs -n tekton-pipelines deployment/tekton-pipelines-controller

# Restart Tekton dashboard
kubectl rollout restart deployment/tekton-dashboard -n tekton-pipelines
```

## 🚀 Advanced Usage

### Custom Pipeline Development
Create your own ARM64-optimized build pipelines:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: my-arm64-app
spec:
  workspaces:
    - name: source-code
  tasks:
    - name: build-arm64
      taskSpec:
        steps:
          - name: build
            image: arm64v8/golang:alpine
            script: |
              # Your ARM64 build logic here
              go build -o app-arm64 .
```

### Nintendo Switch Specific Deployments
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nintendo-specific-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nintendo-app
  template:
    metadata:
      labels:
        app: nintendo-app
    spec:
      nodeSelector:
        hardware: nintendo-switch
      containers:
      - name: app
        image: your-arm64-image:latest
```

## 🎯 Next Steps

1. **Explore Tekton**: Create custom pipelines for your projects
2. **ARM64 Optimization**: Build native ARM64 applications
3. **Monitoring**: Add Prometheus/Grafana for cluster monitoring
4. **Networking**: Configure ingress for external access
5. **Storage**: Set up persistent volumes for stateful workloads
6. **Security**: Implement RBAC and network policies

## 🔐 Security Considerations

- Default setup uses simple token authentication (demo purposes)
- In production: use proper certificates, RBAC, and network policies
- Consider network segmentation between master and workers
- Regular security updates for K3s and container images
- Nintendo Switch should be on isolated network segment

## 🤝 Contributing

Found an issue or want to improve the setup? PRs welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

---

**🎮⚓ Happy Kubernetes Gaming with your Nintendo Switch! 🎮⚓**

*Turn your gaming console into a powerful ARM64 worker node for your development workflows!*