const express = require('express');
const https = require('https');
const fs = require('fs');
const { Server } = require('socket.io');
const { createConnectionHandler } = require('./websocketHandlers');

function startWebSocketServer(byondPort, nodePort) {
    const options = {
        key: fs.readFileSync(__dirname + '/certs/key.pem'),
        cert: fs.readFileSync(__dirname + '/certs/cert.pem')
    };
    const app = express();
    const server = https.createServer(options, app);
    const io = new Server(server);

    app.use(express.static(__dirname + '/public'));
    app.get('/', (req, res) => {
        res.sendFile(__dirname + '/public/voicechat.html');
    });

    const handleConnection = createConnectionHandler(byondPort, io);
    io.on('connection', handleConnection);

    const PORT = nodePort;
    server.listen(PORT, () => {
        console.log(`HTTPS server running on port ${PORT}`);
    });

    return { io, server };
}

function disconnectAllClients(io) {
    io.emit('server-shutdown');
    setTimeout(() => {
        io.sockets.sockets.forEach((socket) => {
            socket.emit('update', { type: 'update', data: 'Disconnected: Disconnecting all clients' });
            socket.disconnect(true);
        });
    }, 2000);
}

module.exports = { startWebSocketServer, disconnectAllClients };