const minimist = require('minimist');
const { startWebSocketServer, disconnectAllClients } = require('./websocketServer');
const { startByondServer } = require('./ByondServer.js');
const { monitorParentProcess } = require('./processUtils.js');
const { sendJSON } = require('./byondCommunication');

const argv = minimist(process.argv.slice(2));
const byondPort = argv['byond-port']
const nodePort = argv['node-port']
const shutdown_function = () => {
    disconnectAllClients(io);
    io.close(() => {
        wsServer.close(() => {
            ByondServer.close(() => {
                console.log('shutdown_function called');
                setTimeout(() => {
                    process.exit(0);
                }, 2000);
            });
        });
    });
};

// Monitor parent process
monitorParentProcess(shutdown_function);

// Start servers
const { io, server: wsServer } = startWebSocketServer(byondPort, nodePort);
const ByondServer = startByondServer(byondPort, io, shutdown_function);
sendJSON({ server_ready: 1 }, byondPort);

process.on('SIGTERM', () => shutdown_function())
process.on('SIGINT', () => shutdown_function())