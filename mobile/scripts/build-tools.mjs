import { readFile, writeFile } from 'node:fs/promises'
import { basename, dirname, resolve } from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { parse, compileScript, compileStyle } from 'vue/compiler-sfc'

const require = createRequire(import.meta.url)
const nuxt = createRequire(require.resolve('nuxt/package.json'))
const builder = createRequire(nuxt.resolve('@nuxt/vite-builder/package.json'))
const esbuild = createRequire(builder.resolve('vite/package.json'))('esbuild')
const mobile = fileURLToPath(new URL('../', import.meta.url))
const assets = resolve(mobile, 'android/app/src/main/assets')
const styles = []
const vue = {
  name: 'standalone-vue',
  setup(build) {
    build.onLoad({ filter: /\.vue$/ }, async ({ path }) => {
      let source = await readFile(path, 'utf8')
      if (basename(path) === 'BedDimensions.vue') {
        source = source.replace('<script setup lang="ts">', '<script setup lang="ts">\nimport { ref, computed } from "vue"')
      }
      const { descriptor, errors } = parse(source, { filename: path })
      if (errors.length) throw errors[0]
      const id = basename(path, '.vue').toLowerCase()
      const script = compileScript(descriptor, { id, inlineTemplate: true, genDefaultAs: 'component' })
      for (const style of descriptor.styles) {
        const css = compileStyle({ source: style.content, filename: path, id: 'data-v-' + id, scoped: style.scoped })
        if (css.errors.length) throw css.errors[0]
        styles.push(css.code)
      }
      return { loader: 'ts', resolveDir: dirname(path), contents: script.content + '\ncomponent.__scopeId="data-v-' + id + '"; export default component' }
    })
  },
}
const bundle = await esbuild.build({
  entryPoints: [resolve(mobile, 'tools/index.mjs')], bundle: true, write: false, minify: true,
  target: 'chrome80', plugins: [vue], define: { 'process.env.NODE_ENV': '"production"', __VUE_OPTIONS_API__: 'true', __VUE_PROD_DEVTOOLS__: 'false', __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false' },
})
const js = bundle.outputFiles[0].text.replace(/<\/script/gi, '<\\/script')
await writeFile(resolve(assets, 'tools.html'), '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>' + styles.join('\n') + '</style><main id="app"></main><script>' + js + '</script></html>')
await esbuild.build({ entryPoints: [resolve(mobile, 'scripts/today.mjs')], bundle: true, target: 'chrome80', outfile: resolve(assets, 'today.js') })
