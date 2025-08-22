const { execSync } = require('child_process');

const originalParentPid = process.ppid;

function isParentRunning() {
    if (process.platform === 'win32') {
        try {
            const output = execSync(`tasklist /FI "PID eq ${originalParentPid}"`).toString();
            return output.includes(originalParentPid.toString());
        } catch (e) {
            return false;
        }
    } else {
        try {
            process.kill(originalParentPid, 0);
            return true;
        } catch (e) {
            return false;
        }
    }
}

function monitorParentProcess(shutdown_function) {
    setInterval(() => {
        if (!isParentRunning()) {
            console.log('Parent process terminated, shutting down Node.js server');
            shutdown_function();
            
        }
    }, 10000); // 10 seconds
}

module.exports = { monitorParentProcess };