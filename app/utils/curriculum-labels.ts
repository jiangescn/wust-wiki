// Keep archive metadata intact; presentation follows the confirmed, simplified labels.
export const curriculumLabel = (text: string) => text
  .replace(/（系统版本供参考，以最终纸质为准）/g, '')
  .replace(/（(?:文件标注|文件名|参考稿|专业目录待核)）/g, '')
  .replace(/-?(?:官网原件|官方历史原件|官方原件|版本待核)$/g, '')
  .replace(/\s*\(\d+\)$/, '')
  .trim()

export const curriculumTitle = (text: string) => curriculumLabel(text).replaceAll('-', ' · ')
