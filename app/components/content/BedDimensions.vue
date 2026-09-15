<script setup lang="ts">
// Experimental illustration; measurements copied from the enrollment document.
const beds = [
  { name: '男生五人寝 · 上铺', length: 193, width: 82.5, height: 188 },
  { name: '男生五人寝 · 下铺', length: 193, width: 90, height: 125 },
  { name: '男生四人寝 · 上铺', length: 193, width: 82.5, height: 188 },
  { name: '女生四人寝 · 上铺', length: 195, width: 85, height: 135 },
]
const selected = ref(0)
const bed = computed(() => beds[selected.value]!)
const lower = computed(() => selected.value === 1)
const deckY = computed(() => lower.value ? 365 : 165)
</script>

<template>
  <section class="bed-demo not-prose" aria-label="床铺尺寸示意">
    <div class="bed-toolbar">
      <label>床型 <select v-model.number="selected"><option v-for="(item, index) in beds" :key="item.name" :value="index">{{ item.name }}</option></select></label>
      <span>单位：cm</span>
    </div>
    <svg viewBox="0 0 760 540" role="img" :aria-label="bed.name + '，长' + bed.length + '厘米，宽' + bed.width + '厘米，高' + bed.height + '厘米'">
      <!-- Illustration geometry is visual reference, not measured furniture dimensions. -->
      <polygon points="125,460 570,460 690,365 235,365" class="floor" />
      <!-- Rear posts and wooden head / foot panels -->
      <g class="metal"><path d="M235 365 V60 M665 365 V60 M235 90 H665 M235 280 H665" /></g>
      <g class="wood"><path d="M145 165 L235 100 V285 L145 350 Z"/><path d="M575 165 L665 100 V285 L575 350 Z"/></g>
      <!-- Small side storage unit visible beside the photographed bunk -->
      <g class="cabinet">
        <path d="M55 70 L122 35 L153 44 V428 L130 466 H55 Z"/>
        <path d="M55 70 H130 V466 H55 Z"/>
        <path d="M60 76 H125 V269 H60 Z" fill="#efeee6"/>
        <path d="M92 76 V269 M60 335 H125 M60 397 H125"/>
        <path d="M84 175 V191 M101 175 V191" stroke="#777b72" stroke-width="3"/>
      </g>
      <!-- Pegboard behind the lower berth -->
      <path d="M240 215 H660 V258 H240 Z" fill="#eeeae0" stroke="#c5c3b9"/>
      <g fill="#aaa89e"><circle v-for="n in 40" :key="n" :cx="248 + ((n - 1) % 20) * 21" :cy="228 + Math.floor((n - 1) / 20) * 17" r="1.5"/></g>
      <!-- Both bed boards; blue outline identifies the selected berth -->
      <g v-for="(level, index) in [165, 365]" :key="level">
        <polygon :points="'145,' + level + ' 575,' + level + ' 665,' + (level - 65) + ' 235,' + (level - 65)" class="wood" :class="{ chosen: lower === (index === 1) }" />
        <g class="grain"><path v-for="n in 7" :key="n" :d="'M' + (145 + n * 11) + ' ' + (level - n * 8) + ' h430'"/></g>
        <path :d="'M145 ' + level + ' H575 L665 ' + (level - 65)" class="beam" />
      </g>
      <!-- Uprights, rounded guard rails and reinforcing bars -->
      <g class="metal"><path d="M145 442 V105 Q145 88 162 88 H485 Q498 88 498 103 V161 M575 442 V90 M665 365 V60 M145 350 L235 285 M145 165 L235 100 M145 440 L235 375"/><path d="M172 91 V160 M480 93 V160 M145 142 H498"/></g>
      <path d="M179 116 H465 V151 H179 Z" class="wood" />
      <path d="M270 93 H465 V116 H270 Z" class="wood" />
      <path d="M179 116 H465 M270 91 V116" fill="none" stroke="#d3d8d0" stroke-width="5" />
      <!-- Slanted ladder and blue anti-slip treads -->
      <g class="ladder"><path d="M531 473 L574 105 Q576 88 589 86 M615 473 L653 107 Q655 91 645 91"/><path v-for="n in 5" :key="n" :d="'M' + (536 + n * 7) + ' ' + (452 - n * 62) + ' h80'"/></g>
      <g stroke="#65add1" stroke-width="6"><path v-for="n in 5" :key="n" :d="'M' + (540 + n * 7) + ' ' + (450 - n * 62) + ' h71'"/></g>
      <g class="dimension">
        <path :d="'M145 ' + (deckY + 28) + ' H510 M145 ' + (deckY + 22) + ' v12 M510 ' + (deckY + 22) + ' v12'"/>
        <text x="330" :y="deckY + 53" text-anchor="middle">长 {{ bed.length }} cm</text>
        <path :d="'M682 ' + (deckY - 65) + ' l-72 53'"/>
        <text x="673" :y="deckY + 12" text-anchor="middle">宽 {{ bed.width }}</text>
      </g>
      <text x="380" y="515" text-anchor="middle" class="height-note">原文标高 {{ bed.height }} cm · 测量起止点待确认</text>
    </svg>
    <p class="bed-values">长 {{ bed.length }} × 宽 {{ bed.width }} × 高 {{ bed.height }} cm</p>
    <p class="bed-note">参照你提供的正面、侧面照片绘制；蓝色轮廓表示所选床位。长宽高沿用原文，护栏、爬梯和高柜仅为结构示意。“高”的测量起止点待确认，暂不画高度尺寸线。四人寝暂共用此外形参考。</p>
  </section>
</template>

<style scoped>
.bed-demo { border: 1px solid var(--ui-border); border-radius: 1rem; padding: 1rem; background: var(--ui-bg-muted); margin-block: 1.5rem; }
.bed-toolbar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .75rem; font-size: .85rem; }
select { background: var(--ui-bg); color: var(--ui-text); border: 1px solid var(--ui-border); border-radius: .5rem; padding: .5rem; max-width: 100%; }
svg { display: block; width: 100%; max-height: 540px; overflow: visible; }
.floor { fill: var(--ui-border); opacity: .4; }
.leg { stroke: var(--ui-text-muted); stroke-width: 7; stroke-linecap: round; }
.surface { fill: color-mix(in srgb, var(--ui-primary) 24%, var(--ui-bg)); stroke: var(--ui-primary); stroke-width: 3; stroke-linejoin: round; }
.dimension path { fill: none; stroke: var(--ui-primary); stroke-width: 1.5; }
.dimension text { fill: var(--ui-text); font-size: 18px; }
.bed-values { text-align: center; font-weight: 600; }
.bed-note { color: var(--ui-text-muted); font-size: .8rem; line-height: 1.6; }
</style>

<style scoped>
.wood { fill: #dfbd89; stroke: #b89562; stroke-width: 1.5; }
.cabinet { fill: #d9bd93; stroke: #ad916b; stroke-width: 3; }
.metal path { fill: none; stroke: #b8bdb8; stroke-width: 9; stroke-linejoin: round; stroke-linecap: round; }
.beam { fill: none; stroke: #d3d8d0; stroke-width: 12; stroke-linejoin: round; }
.grain { stroke: #b58b53; stroke-width: 1; opacity: .6; }
.chosen { stroke: var(--ui-primary); stroke-width: 5; }
.ladder { fill: none; stroke: #b8bdb8; stroke-width: 10; stroke-linecap: round; }
.height-note { fill: var(--ui-text-muted); font-size: 16px; }
</style>
