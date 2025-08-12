const express = require('express');
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8080;

// Serve static files
app.use(express.static(path.join(__dirname)));

// API endpoint for stats
app.get('/api/stats', async (req, res) => {
    try {
        const stats = await getSystemStats();
        res.json(stats);
    } catch (error) {
        console.error('Error getting stats:', error);
        res.json({
            cpu: '--',
            memory: '--',
            pods: '--',
            uptime: '--',
            error: true
        });
    }
});

async function getSystemStats() {
    return new Promise((resolve, reject) => {
        const commands = [
            'kubectl top nodes --no-headers 2>/dev/null || echo "-- --"',
            'kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep Running | wc -l || echo "0"',
            'uptime | grep -o "up.*" | cut -d"," -f1 | sed "s/up //" || echo "--"'
        ];
        
        Promise.allSettled(commands.map(cmd => 
            new Promise((resolve, reject) => {
                exec(cmd, (error, stdout) => {
                    if (error) resolve('--');
                    else resolve(stdout.trim());
                });
            })
        )).then(results => {
            const nodeStats = results[0].value.split(/\s+/);
            const cpu = nodeStats[1] || '--';
            const memory = nodeStats[2] || '--';
            const pods = results[1].value || '--';
            const uptime = results[2].value || '--';
            
            resolve({
                cpu: cpu.replace('%', '') + '%',
                memory: memory.replace('%', '') + '%',
                pods: parseInt(pods) || 0,
                uptime: uptime,
                timestamp: new Date().toISOString()
            });
        }).catch(reject);
    });
}

app.listen(PORT, '0.0.0.0', () => {
    console.log(`📊 Dashboard API running on port ${PORT}`);
});
