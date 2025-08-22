const net = require('net');
const { sendJSON } = require('./byondCommunication');
const { handleRequest } = require('./ByondHandlers');
const PIPE_NAME = '/tmp/byond_node.sock';
function startByondServer(byondPort, io, shutdown_function) {
    const ByondServer = net.createServer((stream) => {
        stream.on('data', (data) => {
            const jsonStr = data.toString('utf-8');
            try {
                const json = JSON.parse(jsonStr);
                // console.log('Received JSON:', json);
                handleRequest(json, byondPort, io, shutdown_function);
            } catch (err) {
                console.log(jsonStr);
                console.error('Invalid JSON:', err);
                sendJSON({ error: 'invalid JSON', data: err }, byondPort)
            }
        });
        stream.on('end', () => {
        });
    });

    ByondServer.listen(PIPE_NAME, () => {
        console.log(`socket server listening on ${PIPE_NAME}`);
    });

    ByondServer.on('error', (err) => {
        console.error('Pipe server error:', err);
    });
    return ByondServer;
}


module.exports = { startByondServer };