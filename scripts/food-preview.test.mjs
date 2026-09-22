import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { setTimeout as delay } from 'node:timers/promises'

test('a failed upstream image stream does not terminate the static preview', { timeout: 15000 }, async () => {
  // Uses the generated site but never contacts the live API.
  const script = `
    globalThis.fetch = async (url) => {
      if (url.pathname.endsWith('/medium')) await new Promise(resolve => setTimeout(resolve, 60));
      return new Response(new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array([1, 2, 3]));
        setTimeout(() => controller.error(new Error('Simulated media timeout')), 20);
      }
    }), { headers: { 'Content-Type': 'image/webp' } });
    };
    await import('./scripts/serve-static.mjs');
  `
  const child = spawn(process.execPath, ['--input-type=module', '-e', script], { env: { ...process.env, PORT: '0' }, stdio: ['ignore', 'pipe', 'pipe'] })
  let stderr = ''
  child.stderr.on('data', data => { stderr += data })
  try {
    const address = await new Promise((resolve, reject) => {
      child.stdout.on('data', data => {
        const match = String(data).match(/http:\/\/127\.0\.0\.1:\d+/)
        if (match) resolve(match[0])
      })
      child.once('error', reject)
      child.once('exit', code => reject(new Error(`Preview exited ${code}: ${stderr}`)))
    })
    await assert.rejects(async () => {
      const response = await fetch(address + '/api/food/media/6499a73f-44bc-442a-aff8-90bdeadbe62e')
      await response.arrayBuffer()
    })
    const homepage = await fetch(address + '/')
    assert.equal(homepage.status, 200)
    assert.match(await homepage.text(), /WUST Wiki/)
    assert.equal(child.exitCode, null)
    // A browser may leave the page before an upstream image finishes.
    const controller = new AbortController()
    const pending = await fetch(address + '/api/food/media/6499a73f-44bc-442a-aff8-90bdeadbe62e', { signal: controller.signal })
    controller.abort()
    await pending.body.cancel().catch(() => {})
    await delay(100)
    assert.equal(child.exitCode, null, stderr)
    assert.equal((await fetch(address + '/')).status, 200)
    // Also cancel before upstream headers arrive, so pipeline sees a closed client.
    const earlyAbort = new AbortController()
    const abandoned = fetch(address + '/api/food/media/6499a73f-44bc-442a-aff8-90bdeadbe62e/medium', { signal: earlyAbort.signal }).catch(() => {})
    await delay(10)
    earlyAbort.abort()
    await abandoned
    await delay(150)
    assert.equal(child.exitCode, null, stderr)
    assert.equal((await fetch(address + '/')).status, 200)
  } finally {
    child.kill()
    await once(child, 'exit')
  }
})
