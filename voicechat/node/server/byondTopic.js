const net = require('net');

/**
 * Ensures the topic data starts with '?'.
 * @param {string} data - The topic data to format.
 * @returns {string} - The formatted data.
 */
function formatData(data) {
    return data.startsWith('?') ? data : `?${data}`;
}

/**
 * Constructs a BYOND topic packet buffer.
 * @param {string} data - The topic data to encode.
 * @returns {Buffer} - The packet buffer.
 * @throws {Error} If the data exceeds maximum size.
 */
function buildPacket(data) {
    const formattedData = formatData(data);
    const dataLength = formattedData.length;
    const remainingSize = dataLength + 6; // Length field value: type (1) + padding (4) + data + null (1)

    if (remainingSize > 65535) {
        throw new Error(`Data exceeds maximum size: ${remainingSize}`);
    }

    const header = Buffer.alloc(9);
    header[1] = 0x83;
    header.writeUInt16BE(remainingSize, 2);

    const queryBuffer = Buffer.from(formattedData, 'utf8');
    const nullBuffer = Buffer.alloc(1); // 0x00

    return Buffer.concat([header, queryBuffer, nullBuffer]);
}

/**
 * Sends a topic packet to a BYOND server.
 * @param {string} host - The server hostname or IP.
 * @param {number} port - The server port.
 * @param {string} data - The topic data to send.
 * @param {number} [timeout=5000] - Socket timeout in milliseconds.
 * @returns {Promise<void>} - Resolves when sent, rejects on error.
 */
function sendByondTopic(host, port, data, timeout = 5000) {
    return new Promise((resolve, reject) => {
        if (typeof data !== 'string') {
            reject(new Error('Data must be a string'));
            return;
        }

        let packet;
        try {
            packet = buildPacket(data);
        } catch (err) {
            reject(err);
            return;
        }

        const client = new net.Socket();
        client.setTimeout(timeout, () => {
            client.destroy();
            reject(new Error('Connection timeout'));
        });

        client.on('error', (err) => {
            client.destroy();
            reject(err);
        });

        client.connect(port, host, () => {
            client.write(packet, () => {
                client.end(); // Close the connection after sending
                resolve();
            });
        });
    });
}

module.exports = { sendByondTopic };