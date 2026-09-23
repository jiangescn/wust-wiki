import { SCHEDULE_CACHE_KEY, makeSnapshot, readSnapshot, type ScheduleSnapshot } from '~/utils/schedule'

export function useSchoolScheduleCache() {
  const snapshot = shallowRef<ScheduleSnapshot | null>(null)
  const notice = ref('')
  let timer: ReturnType<typeof setInterval> | undefined
  function removeDisk() { try { localStorage.removeItem(SCHEDULE_CACHE_KEY) } catch { notice.value = '无法操作浏览器存储，请在浏览器设置中清除本站数据。' } }
  function expire() {
    if (snapshot.value && Date.now() >= snapshot.value.expiresAt) {
      snapshot.value = null; removeDisk(); notice.value = '课表已超过七天，请重新扫码更新。'
    }
  }
  function load() {
    try {
      const raw = localStorage.getItem(SCHEDULE_CACHE_KEY)
      snapshot.value = readSnapshot(raw)
      if (raw && !snapshot.value) { removeDisk(); notice.value = '本机课表已到期或无法读取，请重新扫码。' }
    } catch { notice.value = '当前浏览器不允许保存课表，本次仅在页面内显示。' }
  }
  function save(result: unknown) {
    const value = makeSnapshot(result)
    if (!value) return false
    snapshot.value = value; notice.value = ''
    try { localStorage.setItem(SCHEDULE_CACHE_KEY, JSON.stringify(value)) }
    catch { removeDisk(); notice.value = '课表已读取，但浏览器未能保存；关闭页面后需重新扫码。' }
    return true
  }
  function clear() { snapshot.value = null; notice.value = ''; removeDisk() }
  function storage(event: StorageEvent) { if (event.key === SCHEDULE_CACHE_KEY || event.key === null) load() }
  onMounted(() => { load(); timer = setInterval(expire, 10_000); window.addEventListener('storage', storage); document.addEventListener('visibilitychange', expire); window.addEventListener('pageshow', expire) })
  onBeforeUnmount(() => { if (timer) clearInterval(timer); window.removeEventListener('storage', storage); document.removeEventListener('visibilitychange', expire); window.removeEventListener('pageshow', expire) })
  return { snapshot, notice, save, clear, expire }
}
