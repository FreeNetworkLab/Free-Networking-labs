import https from 'node:https'
import fs from 'node:fs'
import { spawn } from 'node:child_process'
import { execFileSync } from 'node:child_process'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { WebSocketServer, WebSocket } from 'ws'
// capture-proxy のチケット＋Cookie 認証のテスト（node --test で動く。擬似の上流サーバーを立てて、実際に中継する）。
// 自己署名の証明書は、openssl で、一時フォルダに作る
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'
const HERE = path.dirname(fileURLToPath(import.meta.url))
const D = fs.mkdtempSync(path.join(os.tmpdir(), 'captest-'))
execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-keyout', `${D}/key.pem`, '-out', `${D}/cert.pem`, '-days', '1', '-nodes', '-subj', '/CN=localhost'], { stdio: 'ignore' })
const tls = { key: fs.readFileSync(`${D}/key.pem`), cert: fs.readFileSync(`${D}/cert.pem`) }
const GOOD = 'good.jwt.token'
const seen = []
// 擬似の上流（clab-api-server）：/api/v1/labs は有効なトークンなら200、VNCのパスは Authorization を返す
const up = https.createServer(tls, (req, res) => {
  const ok = req.headers.authorization === `Bearer ${GOOD}`
  seen.push(`${req.method} ${req.url} auth=${req.headers.authorization}`)
  if (req.url === '/api/v1/labs') { res.writeHead(ok ? 200 : 401); return res.end('{}') }
  res.writeHead(ok ? 200 : 401, { 'content-type': 'text/html' }); res.end(`<html><title>x</title><body>auth=${req.headers.authorization}</body></html>`)
})
const wss = new WebSocketServer({ noServer: true })
up.on('upgrade', (req, sock, head) => { seen.push(`WS ${req.url} auth=${req.headers.authorization}`); wss.handleUpgrade(req, sock, head, (c) => c.send('hello-from-upstream')) })
await new Promise((r) => up.listen(18090, '127.0.0.1', r))
const px = spawn('node', ['server.js'], { cwd: HERE, env: { ...process.env, CAPTURE_PROXY_PORT: '18084', CLAB_API_BASE_URL: 'https://127.0.0.1:18090', CAPTURE_PROXY_TLS_CERT: `${D}/cert.pem`, CAPTURE_PROXY_TLS_KEY: `${D}/key.pem` }, stdio: ['ignore', 'pipe', 'pipe'] })
let plog = ''; px.stdout.on('data', (d) => (plog += d)); px.stderr.on('data', (d) => (plog += d))
await new Promise((r) => setTimeout(r, 800))
const req = (method, path, { headers = {}, body } = {}) => new Promise((resolve, reject) => {
  const r = https.request({ host: '127.0.0.1', port: 18084, path, method, headers }, (res) => { let b = ''; res.on('data', (c) => (b += c)); res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: b })) })
  r.on('error', reject); if (body) r.write(body); r.end()
})
let fails = 0
const check = (name, cond, extra = '') => { console.log(`${cond ? 'OK  ' : 'FAIL'} ${name} ${extra}`); if (!cond) fails++ }
const VNC = '/api/v1/capture/wireshark-vnc-sessions/abc123/vnc/vnc.html'

let r = await req('POST', '/capture/_ticket'); check('チケット：認証なし → 401', r.status === 401, r.status)
r = await req('POST', '/capture/_ticket', { headers: { authorization: 'Bearer bad' } }); check('チケット：無効なトークン → 401', r.status === 401, r.status)
r = await req('POST', '/capture/_ticket', { headers: { authorization: `Bearer ${GOOD}` } }); check('チケット：有効 → 200＋ticket', r.status === 200 && JSON.parse(r.body).ticket?.length > 20, r.status)
const ticket = JSON.parse(r.body).ticket
check('チケットに JWT が含まれない', !r.body.includes(GOOD))

r = await req('GET', `/capture/_enter/${ticket}/api/v1/other/path`); check('入口：VNC 以外のパス → 404（チケットは残る）', r.status === 404, r.status)
r = await req('GET', `/capture/_enter/${ticket}${VNC}?label=R1`)
check('入口：302 でリダイレクト', r.status === 302 && r.headers.location === `/capture/s${VNC}?label=R1`, `${r.status} ${r.headers.location}`)
const sc = String(r.headers['set-cookie'] ?? '')
check('Cookie：HttpOnly・Secure・SameSite=Strict・Path=/capture/', /HttpOnly/.test(sc) && /Secure/.test(sc) && /SameSite=Strict/.test(sc) && /Path=\/capture\//.test(sc), sc.slice(0, 60))
check('Cookie の値に JWT が含まれない', !sc.includes(GOOD) && !sc.includes('good'))
check('リダイレクト先に JWT が含まれない', !String(r.headers.location).includes('good'))
const cookie = sc.split(';')[0]
r = await req('GET', `/capture/_enter/${ticket}${VNC}`); check('入口：同じチケットの再利用 → 410（使い切り）', r.status === 410, r.status)

r = await req('GET', `/capture/s${VNC}?label=R1`, { headers: { cookie } })
check('Cookie で中継：200、上流には Bearer が付く', r.status === 200 && r.body.includes(`auth=Bearer ${GOOD}`), r.status)
check('label でタイトルが書き換わる', r.body.includes('<title>R1</title>'))
check('上流のパスに label が出ない', !seen.some((s) => s.includes('label=')))
r = await req('GET', `/capture/s${VNC}`); check('Cookie なし → 401', r.status === 401, r.status)
r = await req('GET', `/capture/s${VNC}`, { headers: { cookie: 'fnl_capture=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' } }); check('でたらめな Cookie → 401', r.status === 401, r.status)
r = await req('GET', `/capture/${GOOD}${VNC}`); check('旧形式（JWT をパスに）→ 404', r.status === 404, r.status)
r = await req('GET', `/capture/s/api/v1/labs`, { headers: { cookie } }); check('Cookie があっても VNC 以外のパス → 404', r.status === 404, r.status)

const wsOpen = (headers) => new Promise((resolve) => {
  const w = new WebSocket(`wss://127.0.0.1:18084/capture/s${VNC.replace('vnc.html', 'websockify')}`, ['binary'], { headers })
  const t = setTimeout(() => resolve('timeout'), 3000)
  w.on('message', (m) => { clearTimeout(t); w.close(); resolve(String(m)) })
  w.on('error', () => { clearTimeout(t); resolve('error') }); w.on('unexpected-response', () => { clearTimeout(t); resolve('rejected') })
})
check('WebSocket：Cookie あり → 上流に中継', (await wsOpen({ cookie })) === 'hello-from-upstream')
check('WebSocket：Cookie なし → 拒否', ['error', 'rejected'].includes(await wsOpen({})))
check('WebSocket：上流に Bearer が付いた', seen.some((s) => s.startsWith('WS ') && s.includes(`Bearer ${GOOD}`)))
check('proxy のログに JWT が出ない', !plog.includes('good.jwt'))
px.kill(); up.close(); wss.close()
fs.rmSync(D, { recursive: true, force: true })
console.log(fails === 0 ? '\nすべて OK' : `\n失敗 ${fails} 件`); process.exit(fails ? 1 : 0)
