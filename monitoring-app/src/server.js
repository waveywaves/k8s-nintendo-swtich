const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Get system metrics
app.get('/api/metrics', async (req, res) => {
    try {
        const metrics = await getSystemMetrics();
        res.json(metrics);
    } catch (error) {
        console.error('Error getting metrics:', error);
        res.status(500).json({ error: 'Failed to get metrics' });
    }
});

// Get Kubernetes info
app.get('/api/k8s', async (req, res) => {
    try {
        const k8sInfo = await getK8sInfo();
        res.json(k8sInfo);
    } catch (error) {
        console.error('Error getting K8s info:', error);
        res.status(500).json({ error: 'Failed to get K8s info' });
    }
});

async function getSystemMetrics() {
    return new Promise((resolve, reject) => {
        exec('cat /proc/meminfo && cat /proc/loadavg && uptime', (error, stdout, stderr) => {
            if (error) {
                reject(error);
                return;
            }
            
            const lines = stdout.split('\n');
            const memTotal = lines.find(l => l.startsWith('MemTotal:'))?.split(/\s+/)[1] || '0';
            const memAvailable = lines.find(l => l.startsWith('MemAvailable:'))?.split(/\s+/)[1] || '0';
            const loadAvg = lines.find(l => l.includes('load average'))?.split('load average:')[1]?.trim() || '0, 0, 0';
            
            const memUsedPercent = Math.round(((parseInt(memTotal) - parseInt(memAvailable)) / parseInt(memTotal)) * 100);
            
            resolve({
                memory: {
                    total: Math.round(parseInt(memTotal) / 1024 / 1024 * 100) / 100, // GB
                    used: memUsedPercent,
                    available: Math.round(parseInt(memAvailable) / 1024 / 1024 * 100) / 100 // GB
                },
                loadAverage: loadAvg.split(',').map(l => parseFloat(l.trim())),
                uptime: lines.find(l => l.includes('up'))?.trim() || 'unknown',
                timestamp: new Date().toISOString()
            });
        });
    });
}

async function getK8sInfo() {
    return new Promise((resolve, reject) => {
        exec('kubectl get nodes -o json 2>/dev/null', (error, stdout, stderr) => {
            if (error) {
                resolve({ nodes: [], pods: [], error: 'kubectl not configured' });
                return;
            }
            
            try {
                const nodesData = JSON.parse(stdout);
                const nodes = nodesData.items.map(node => ({
                    name: node.metadata.name,
                    status: node.status.conditions.find(c => c.type === 'Ready')?.status === 'True' ? 'Ready' : 'NotReady',
                    version: node.status.nodeInfo.kubeletVersion,
                    os: node.status.nodeInfo.osImage,
                    arch: node.status.nodeInfo.architecture
                }));
                
                // Get pods info
                exec('kubectl get pods --all-namespaces -o json 2>/dev/null', (error2, stdout2) => {
                    let pods = [];
                    if (!error2) {
                        try {
                            const podsData = JSON.parse(stdout2);
                            pods = podsData.items.map(pod => ({
                                name: pod.metadata.name,
                                namespace: pod.metadata.namespace,
                                status: pod.status.phase,
                                ready: pod.status.conditions?.find(c => c.type === 'Ready')?.status === 'True'
                            }));
                        } catch (e) {
                            console.error('Error parsing pods:', e);
                        }
                    }
                    
                    resolve({ nodes, pods, timestamp: new Date().toISOString() });
                });
                
            } catch (e) {
                reject(e);
            }
        });
    });
}

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🎮 Nintendo Switch Monitor running on port ${PORT}`);
    console.log(`📊 Access dashboard at http://localhost:${PORT}`);
});
