import { addIcon } from '@iconify/vue'
import icons from '~/xupt/icons.json'

export default defineNuxtPlugin(() => {
  for (const [name, data] of Object.entries(icons)) addIcon(name, data)
})
