import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { networkInterfaces } from 'node:os'

const lan = process.argv.includes('--lan')
const port = process.env.PORT || '3017'
const privateIPv4 = ip => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip)
const lanHosts = lan ? Object.values(networkInterfaces()).flat().filter(n => n.family === 'IPv4' && !n.internal && privateIPv4(n.address)).map(n => `${n.address}:${port}`) : []
if (lan && !lanHosts.length) throw new Error('No private IPv4 interface found')
for (const host of lanHosts) console.log(`LAN preview: http://${host}/previews/schedule-login`)

// Use the existing Nuxt installation, never download a runtime or open a shell.
const cli = fileURLToPath(new URL('./bin/nuxt.mjs', import.meta.resolve('nuxt/package.json')))
const child = spawn(process.execPath, [cli, 'dev', '--host', lan ? '0.0.0.0' : '127.0.0.1', '--port', port], {
  stdio: 'inherit', env: { ...process.env, WIKI_LOGIN_TEMPLATES: '1', WIKI_LOGIN_LAN_HOSTS: lanHosts.join(',') },
})
child.on('exit', code => { process.exitCode = code ?? 1 })
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal))
