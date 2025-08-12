# 🎮⚓ Nintendo Switch Kubernetes Cluster

**Turn your Nintendo Switch into a complete, standalone Kubernetes cluster!**

This setup creates a **single-node K3s cluster** running entirely on your Nintendo Switch with:
- **Complete Independence**: No dependency on other machines
- **Web Dashboard**: Kubernetes Dashboard for cluster management
- **ARM64 Optimized**: All components built for Nintendo Switch hardware
- **Mobile Kubernetes**: Battery-powered cluster you can take anywhere!
- **Clean & Simple**: Minimal setup focused on core Kubernetes functionality

## 🚀 Quick Start

### One-Command Setup
```bash
./setup-nintendo-standalone-k3s.sh
```

This will create a complete, independent Kubernetes cluster on your Nintendo Switch with:
1. ✅ Single-node K3s cluster (master + worker combined)
2. ✅ Kubernetes Dashboard with web UI
3. ✅ Web-based cluster management interface
4. ✅ Sample workloads and demo applications
5. ✅ Clean, minimal setup focused on core functionality

**Access your cluster**: `http://[nintendo-switch-ip]:30080`

### Custom Configuration
```bash
# Specify IP address, script will prompt for credentials
./setup-nintendo-standalone-k3s.sh --switch-ip 192.168.1.100

# Set credentials via environment variables (non-interactive)
SWITCH_USER=myuser SWITCH_PASS=mypassword ./setup-nintendo-standalone-k3s.sh

# Custom K3s version
./setup-nintendo-standalone-k3s.sh --k3s-version v1.29.0+k3s1

# Show all options
./setup-nintendo-standalone-k3s.sh --help
```

## 📊 Nintendo Switch Cluster Features

### 🎯 Web Dashboard Access
- **Cluster Overview**: `http://[switch-ip]:30080` - Main information dashboard
- **Kubernetes Dashboard**: `http://[switch-ip]:30000` - Full cluster management

### 🚀 Core Capabilities
- **Single-node Cluster**: Complete Kubernetes functionality in one device
- **Web Management**: Browser-based cluster administration
- **ARM64 Native**: Optimized for Nintendo Switch ARM64 architecture
- **Portable**: Take your Kubernetes cluster anywhere

### 🔧 Independent Operation
- **No External Dependencies**: Complete cluster runs on Nintendo Switch only
- **Battery Powered**: Can run on Nintendo Switch battery for mobile Kubernetes!
- **Clean & Simple**: Focused on core Kubernetes functionality without extras
- **Easy Management**: Simple web interface for all cluster operations

## 📋 Prerequisites

- Nintendo Switch with Linux installed (Ubuntu 18.04+ recommended)
- SSH access enabled
- sudo privileges for the user
- Network connectivity (for downloading components)
- At least 4GB storage free
- Computer with kubectl installed (for initial setup)

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
├── setup-nintendo-standalone-k3s.sh    # 🎯 Nintendo Switch standalone cluster setup
└── README.md                           # 📚 Complete documentation
```

**Just 2 files for a complete Nintendo Switch Kubernetes cluster!**

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