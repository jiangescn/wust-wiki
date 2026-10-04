export interface NearbyPlace {
  id: string
  name: string
  category: string
  area: string
  coordinates: [number, number]
  zoom: number
  source: string
}

export interface NearbyCampus extends NearbyPlace {
  label: string
}

export const nearbyCampuses: NearbyCampus[] = [
  { id: 'wust-huangjiahu', name: '武汉科技大学（黄家湖校区）', label: '黄家湖校区', category: '武科大', area: '黄家湖', coordinates: [114.263847, 30.4416718], zoom: 14.5, source: 'https://www.openstreetmap.org/way/491613595' },
  { id: 'wust-qingshan', name: '武汉科技大学（青山校区）', label: '青山校区', category: '武科大', area: '青山', coordinates: [114.3636069, 30.6253445], zoom: 15, source: 'https://www.openstreetmap.org/way/1073158160' },
  { id: 'wust-hongshan', name: '武汉科技大学（洪山校区）', label: '洪山校区', category: '武科大', area: '洪山', coordinates: [114.3347276, 30.5179177], zoom: 15.5, source: 'https://www.openstreetmap.org/way/1416272579' },
]

// 页面默认展示范围；保留其他已核对校区的数据及来源。
export const nearbyDefaultCampuses = nearbyCampuses.filter(campus => campus.id !== 'wust-hongshan')

// WGS84 参考位置，非入口坐标。来源与增补方法见 docs/nearby-map.md。
export const nearbyPlaces: NearbyPlace[] = [
  { id: 'baisha-paradise-walk', name: '白沙天街', category: '商场', area: '白沙洲', coordinates: [114.2865347, 30.4790718], zoom: 15, source: 'https://www.openstreetmap.org/way/1390462403' },
  { id: 'jianghan-road', name: '江汉路', category: '街区', area: '汉口', coordinates: [114.2891825, 30.580974], zoom: 15.5, source: 'https://www.openstreetmap.org/way/128398503' },
  { id: 'east-lake-greenway', name: '东湖绿道', category: '公园', area: '东湖', coordinates: [114.3857299, 30.584778], zoom: 14, source: 'https://www.openstreetmap.org/way/1054176899' },
  { id: 'yellow-crane-tower', name: '黄鹤楼', category: '历史建筑', area: '武昌', coordinates: [114.296944, 30.546944], zoom: 15, source: 'https://www.wikidata.org/wiki/Q462372' },
  { id: 'tanhualin', name: '昙华林', category: '街区', area: '武昌', coordinates: [114.3019253, 30.55518], zoom: 15.5, source: 'https://www.openstreetmap.org/way/1411750190' },
  { id: 'hubei-museum', name: '湖北省博物馆', category: '博物馆', area: '东湖', coordinates: [114.358889, 30.563889], zoom: 15, source: 'https://www.wikidata.org/wiki/Q4391403' },
  { id: 'wuhan-university', name: '武汉大学', category: '校园', area: '珞珈山', coordinates: [114.361111, 30.540833], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q1108197' },
  { id: 'gude-temple', name: '古德寺', category: '历史建筑', area: '汉口', coordinates: [114.302583, 30.620972], zoom: 15.5, source: 'https://www.wikidata.org/wiki/Q10913316' },
  { id: 'botanical-garden', name: '武汉植物园', category: '公园', area: '东湖', coordinates: [114.414444, 30.545833], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q10874031' },
  { id: 'huangjiahu-metro', name: '黄家湖（武科大）站', category: '交通', area: '黄家湖 · 地铁', coordinates: [114.2574358, 30.4459077], zoom: 16, source: 'https://www.openstreetmap.org/node/11389760009' },
  { id: 'wuhan-station', name: '武汉站', category: '交通', area: '武汉 · 火车站', coordinates: [114.41898, 30.60967], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q584376' },
  { id: 'wuchang-station', name: '武昌站', category: '交通', area: '武昌 · 火车站', coordinates: [114.311773, 30.531313], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q5959771' },
  { id: 'hankou-station', name: '汉口站', category: '交通', area: '汉口 · 火车站', coordinates: [114.24984, 30.62043], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q1010546' },
  { id: 'wuhan-east-station', name: '武汉东站', category: '交通', area: '光谷 · 火车站', coordinates: [114.425, 30.4861], zoom: 14.5, source: 'https://www.wikidata.org/wiki/Q15916087' },
  { id: 'tianhe-airport', name: '天河机场', category: '交通', area: '天河 · 机场', coordinates: [114.2181778, 30.775834], zoom: 12.5, source: 'https://www.openstreetmap.org/way/233511368' },
]
