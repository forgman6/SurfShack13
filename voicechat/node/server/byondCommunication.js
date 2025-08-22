const { sendByondTopic } = require('./byondTopic.js');

async function sendJSON(data, byondPort) {
    const out = JSON.stringify(data);
    try {
        await sendByondTopic('127.0.0.1', byondPort, out);
    } catch (err) {
        console.error('Failed to send command:', err.message);
    }
}

module.exports = { sendJSON };