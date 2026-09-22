import { fetchFoodResponse } from '../../utils/food-proxy.mjs'

export default defineEventHandler(event => fetchFoodResponse(getRequestURL(event).href, getMethod(event)))
