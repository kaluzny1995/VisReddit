const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');
const os = require('os');

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

function httpPut(url) {
    return new Promise((resolve, reject) => {
        const req = http.request(url, { method: 'PUT' }, res => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => resolve(d));
        });
        req.end();
        req.on('error', reject);
    });
}

function recvMsg(ws, timeoutMs = 30000) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => { cleanup(); reject(new Error('timeout')); }, timeoutMs);
        const onMsg = (event) => { cleanup(); resolve(JSON.parse(event.data.toString())); };
        const onErr = () => { cleanup(); reject(new Error('ws error')); };
        const onClose = () => { cleanup(); reject(new Error('ws closed')); };
        function cleanup() { clearTimeout(timer); ws.removeEventListener('message', onMsg); ws.removeEventListener('error', onErr); ws.removeEventListener('close', onClose); }
        ws.addEventListener('message', onMsg);
        ws.addEventListener('error', onErr);
        ws.addEventListener('close', onClose);
    });
}

function sendMsg(ws, msg) { ws.send(JSON.stringify(msg)); }

function fileUrl(p) {
    return 'file:///' + p.replace(/\\/g, '/').replace(/^([a-zA-Z]):/, (_, d) => d.toLowerCase() + ':');
}

async function extractPage(pdfPath, pageNum, outputPngPath) {
    const port = 9222 + Math.floor(Math.random() * 1000);
    const userDir = path.join(os.tmpdir(), '_edge_' + Math.random().toString(36).slice(2));
    fs.mkdirSync(userDir, { recursive: true });

    const proc = spawn(EDGE, [
        '--headless', '--disable-gpu',
        `--remote-debugging-port=${port}`, `--user-data-dir=${userDir}`,
        '--window-size=1020,668', '--force-device-scale-factor=2',
        '--no-first-run', '--no-default-browser-check'
    ], { stdio: 'ignore' });

    await new Promise(r => setTimeout(r, 3000));

    let ws = null;
    try {
        const tabJson = await httpPut(`http://localhost:${port}/json/new?url=about:blank`);
        const tab = JSON.parse(tabJson);

        ws = new WebSocket(tab.webSocketDebuggerUrl);
        await new Promise((resolve, reject) => {
            const onOpen = () => { cleanup(); resolve(); };
            const onErr = () => { cleanup(); reject(new Error('WS connection failed')); };
            const onClose = () => { cleanup(); reject(new Error('WS closed')); };
            function cleanup() { ws.removeEventListener('open', onOpen); ws.removeEventListener('error', onErr); ws.removeEventListener('close', onClose); }
            ws.addEventListener('open', onOpen);
            ws.addEventListener('error', onErr);
            ws.addEventListener('close', onClose);
        });

        sendMsg(ws, { id: 1, method: 'Page.enable' });
        await recvMsg(ws);

        const targetUrl = fileUrl(pdfPath) + '#page=' + pageNum;
        sendMsg(ws, { id: 2, method: 'Page.navigate', params: { url: targetUrl } });

        await new Promise(r => setTimeout(r, 10000));

        sendMsg(ws, { id: 3, method: 'Page.captureScreenshot', params: {
            format: 'png', fromSurface: true
        }});

        let screenshotData = null;
        for (let i = 0; i < 20; i++) {
            const resp = await recvMsg(ws, 5000).catch(() => null);
            if (!resp) break;
            if (resp.id === 3 && resp.result && resp.result.data) {
                screenshotData = resp.result.data;
                break;
            }
        }

        if (screenshotData) {
            const buffer = Buffer.from(screenshotData, 'base64');
            fs.writeFileSync(outputPngPath, buffer);
            console.log(`OK ${path.basename(outputPngPath)}|${buffer.length}`);
            return buffer.length;
        }

        console.error('FAIL: No screenshot data');
        return 0;
    } catch (err) {
        console.error('Error:', err.message);
        return 0;
    } finally {
        try { ws && ws.close(); } catch {}
        try { proc.kill(); } catch {}
        try { fs.rmSync(userDir, { recursive: true, force: true }); } catch {}
    }
}

const args = process.argv.slice(2);
if (args.length < 3) {
    console.error('Usage: node script.js <pdfPath> <pageNum> <outputPngPath>');
    process.exit(1);
}
extractPage(args[0], parseInt(args[1]), args[2]).then(s => process.exit(s > 0 ? 0 : 1));
