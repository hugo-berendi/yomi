const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const {once} = require('node:events');
const modulePath = process.argv[2] || path.join(__dirname, '../hosts/nixos/inari/services/n8n/alert-router.cjs');

(async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'router-http-'));
  const state = path.join(directory, 'state.json');
  const published = [];
  const ntfy = http.createServer(async (request, response) => {
    assert.equal(request.headers.authorization, 'Bearer fixture');
    let body = '';
    for await (const chunk of request) body += chunk;
    published.push(JSON.parse(body));
    response.writeHead(200).end('{}');
  }).listen(0, '127.0.0.1');
  await once(ntfy, 'listening');
  const reservation = http.createServer().listen(0, '127.0.0.1');
  await once(reservation, 'listening');
  const port = reservation.address().port;
  await new Promise(resolve => reservation.close(resolve));
  const child = spawn(process.execPath, [modulePath], {stdio: 'ignore', env: {...process.env,
    PORT: String(port), ALERT_ROUTER_STATE: state,
    NTFY_URL: `http://127.0.0.1:${ntfy.address().port}`, NTFY_TOPIC: 'test', NTFY_TOKEN: 'fixture',
  }});
  const url = `http://127.0.0.1:${port}/alert`;
  try {
    let connected = false;
    for (let tries = 0; tries < 100; tries++) {
      try { await fetch(url); connected = true; break; }
      catch { await new Promise(resolve => setTimeout(resolve, 25)); }
    }
    assert(connected, 'router HTTP server starts');
    const post = body => fetch(url, {method:'POST',body,headers:{'content-type':'application/json'}});
    const replies = await Promise.all(['a','b'].map(fingerprint => post(JSON.stringify({source:'test',title:fingerprint,fingerprint,severity:'critical'}))));
    assert(replies.every(reply => reply.status === 200));
    assert.equal(published.length, 2);
    assert.equal(Object.keys(JSON.parse(await fs.readFile(state)).alerts).length, 2, 'both requests persist before acknowledgement');
    assert.equal((await fs.stat(state)).mode & 0o777, 0o600);
    assert.equal((await post('[]')).status, 200);
    assert.equal(published.length, 2, 'tick does not duplicate receipts');
    assert.equal((await post('{')).status, 503);
    assert.equal((await post('x'.repeat(65537))).status, 413);
    assert.equal((await fetch(url)).status, 404);
    console.log('router HTTP: concurrent requests, persistence, permissions and failure responses passed');
  } finally {
    const stopped = once(child, 'exit'); child.kill(); await stopped;
    await new Promise(resolve => ntfy.close(resolve));
    await fs.rm(directory, {recursive:true,force:true});
  }
})().catch(error => {console.error(error);process.exitCode=1;});
