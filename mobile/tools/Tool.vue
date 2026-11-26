<script setup>
import { computed, ref } from 'vue'
import BedDimensions from '../../app/components/content/BedDimensions.vue'
import { campusTimes } from '../../app/utils/schedule'
import { calculateGpa, gradeNumber } from '../../app/utils/gpa'
import catalog2024 from '../../app/data/competitions-2024.json'
import catalog2025 from '../../app/data/competitions-2025.json'

const tool = location.pathname.split('/').pop()
const campus = ref('huangjiahu')
const year = ref('2025')
const keyword = ref('')
const level = ref('')
const catalog = computed(() => year.value === '2025' ? catalog2025 : catalog2024)
const levels = computed(() => [...new Set(catalog.value.map(c => c.level))].sort())
const matches = computed(() => {
  const term = keyword.value.trim().toLowerCase()
  return catalog.value.filter(c => (!level.value || c.level === level.value) &&
    [c.name, c.host, ...c.organizers, c.audience].join(' ').toLowerCase().includes(term))
})
const rows = ref([])
let nextId = 0
function add() { rows.value.push({ id: ++nextId, credit: '', point: '' }) }
add()
const active = computed(() => rows.value.filter(row => row.credit.trim() || row.point.trim()))
const invalid = computed(() => active.value.some(row => !(gradeNumber(row.credit) > 0) || gradeNumber(row.point) === null))
const gpa = computed(() => calculateGpa(active.value))
</script>

<template>
  <template v-if="tool === 'beds'">
    <BedDimensions />
    <p class="note">数据取自 Wiki《入学办理》。床型按资料所列展示，请以实际寝室为准。</p>
  </template>
  <template v-else-if="tool === 'times'">
    <label>校区<select v-model="campus"><option value="huangjiahu">黄家湖校区</option><option value="qingshan">青山校区</option></select></label>
    <table><thead><tr><th>节次</th><th>上课</th><th>下课</th></tr></thead><tbody>
      <tr v-for="([start,end], i) in campusTimes[campus]" :key="i"><td>第 {{ i + 1 }} 节</td><td>{{ start }}</td><td>{{ end }}</td></tr>
    </tbody></table>
  </template>
  <template v-else-if="tool === 'gpa'">
    <p>按教务系统显示的学分和课程绩点录入。重修课程只录入本次要计入的记录。</p>
    <div v-for="(row, i) in rows" :key="row.id" class="course">
      <strong>课程 {{ i + 1 }}</strong><button @click="rows.splice(i,1)">移除</button>
      <label>学分<input v-model="row.credit" inputmode="decimal" placeholder="如 2.5"></label>
      <label>课程绩点<input v-model="row.point" inputmode="decimal" placeholder="如 3.0"></label>
    </div>
    <button @click="add">＋ 添加课程</button>
    <p v-if="invalid" role="status">请补全学分和绩点。学分须大于 0，绩点可为 0。</p>
    <p v-else-if="gpa.count" role="status">加权平均绩点 <strong>{{ gpa.gpa.toFixed(2) }}</strong> · 共 {{ gpa.credits }} 学分</p>
    <p class="note">按学分加权计算，仅供参考。</p>
  </template>
  <template v-else-if="tool === 'contests'">
    <label>搜索竞赛<input type="search" v-model="keyword" placeholder="竞赛名称、组织单位或主办单位"></label>
    <div class="filters"><label>目录版本<select v-model="year" @change="level=''"><option>2025</option><option>2024</option></select></label>
    <label>竞赛类别<select v-model="level"><option value="">全部类别</option><option v-for="item in levels" :key="item">{{ item }}</option></select></label></div>
    <p role="status">找到 {{ matches.length }} 项</p>
    <article v-for="c in matches" :key="c.id"><small>{{ c.level }} 类</small><h2>{{ c.name }}</h2>
      <p>{{ c.organizers.join('、') }} · {{ c.audience || '面向对象未注明' }}</p><p v-if="c.host">主办单位：{{ c.host }}</p>
    </article>
  </template>
</template>

<style>
:root{color-scheme:light dark;--ui-primary:#2563eb;--ui-bg:#fff;--ui-text:#18181b;--ui-text-muted:#52525b;--ui-border:#e4e4e7;font:16px/1.6 system-ui,sans-serif;color:var(--ui-text);background:var(--ui-bg)}
@media(prefers-color-scheme:dark){:root{--ui-primary:#93b8ff;--ui-bg:#18181b;--ui-text:#fafafa;--ui-text-muted:#a1a1aa;--ui-border:#3f3f46}}
*{box-sizing:border-box}body{margin:0}main{max-width:640px;margin:auto;padding:18px}p{margin:8px 0 16px}label{display:grid;gap:5px;font-size:14px;color:var(--ui-text-muted)}input,select,button{font:inherit;color:var(--ui-text);background:var(--ui-bg);border:1px solid var(--ui-border);border-radius:7px;padding:9px;min-width:0;max-width:100%}button,small{color:var(--ui-primary)}table{margin-top:16px;border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{text-align:left;border-bottom:1px solid var(--ui-border);padding:9px}article,.course{padding:12px 0;border-bottom:1px solid var(--ui-border)}article p,.note{font-size:14px;color:var(--ui-text-muted)}article p{margin:4px 0}h2{font-size:17px;margin:2px 0}.course,.filters{display:grid;grid-template-columns:1fr 1fr;gap:10px}.course{margin-bottom:12px}.course button{justify-self:end}.filters{margin:12px 0}input,select{width:100%}
</style>
