import { mkdir, copyFile } from 'node:fs/promises'
import { resolve } from 'node:path'

const destination = resolve('.cache/schedule-release-20260923-2')
await mkdir(destination, { recursive: true })
for (const name of ['Dockerfile', 'compose.yaml', 'package.json', 'package-lock.json', 'openresty.conf', 'renew-certificate.sh', 'wust-schedule-cert-renew.service', 'wust-schedule-cert-renew.timer']) await copyFile(`deploy/schedule/${name}`, `${destination}/${name}`)
await mkdir(`${destination}/server/utils`, { recursive: true })
await copyFile('server/schedule-service.mjs', `${destination}/server/schedule-service.mjs`)
for (const name of ['login-template-adapters.mjs', 'login-template-http.mjs', 'login-template-store.mjs', 'school-schedule.mjs']) await copyFile(`server/utils/${name}`, `${destination}/server/utils/${name}`)
console.log(destination)
