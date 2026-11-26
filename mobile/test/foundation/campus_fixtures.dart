const campusNoticeListFixture = '''
<ul class="news_list_date">
<li><a href="/info/1001/123.htm" title="合成通知">2026年计划</a><time datetime="2026-11-09">11月9日</time></li>
<li><a href="/info/1001/123.htm">重复</a><span>2026-11-09</span></li>
<li><a href="/info/1001/124.htm">排除日期</a><span>1980-01-01</span></li>
<li><a href="/info/1001/125.htm">无日期</a></li>
<li><a href="/info/1001/126.htm">未来通知</a><span>2099年1月1日</span></li>
</ul><div class="p_pages"><b class="p_no_d">1</b><b class="p_no">3</b><a href="tzgg/2.htm">下一页</a></div>
''';
const campusNoticeDetailFixture = '''
<meta name="pageTitle" content="合成详情"><meta name="PubDate" content="2026-11-09">
<section><div id="vsb_content"><p>正文一<br>正文二</p><table><tr><td>列一</td><td>列二</td></tr></table>
<img data-src="/images/test.png" alt="合成图"><img src="/images/test.png">
<a href="/files/test.pdf">附件</a><a href="https://example.test/">外链</a>
<iframe src="/files/test.pdf"></iframe><script>showVsbpdfIframe('/files/body.pdf');</script>
<script>hidden-script-text</script></div><a href="/files/test.docx">文档</a></section>
''';
const campusShuttleFixture = '''
<p>合成备注</p><table><tr><td colspan="5">测试校车</td></tr>
<tr><th>日期</th><th>起点</th><th>终点</th><th>发车时间</th><th>行车线路</th></tr>
<tr><td rowspan="2">工作日</td><td rowspan="2">校区甲</td><td rowspan="2">校区乙</td><td>07：30</td><td>路线甲</td></tr>
<tr><td>17:00</td><td>路线乙</td></tr><tr><td colspan="5">请提前候车</td></tr></table>
''';
const campusSecondClassFixture = {
  'code': '0',
  'data': {
    'cj': [
      {
        'MKDM': 'arts',
        'NR': '文化艺术',
        'XF': '2',
        'YXXF': 1.5,
        'BXXF': 0,
        'bxyxxf': 0,
        'XXXF': '2',
        'xxyxxf': 9,
        'xxyxxfR': '1.5',
      },
      {
        'MKDM': 'optional',
        'NR': '无学分要求',
        'XF': 0,
        'YXXF': 0,
        'BXXF': '0.0',
        'bxyxxf': 0,
        'XXXF': 0,
        'xxyxxfR': 0,
      },
      {
        'MKDM': 'service',
        'NR': '社会实践',
        'XF': 3,
        'YXXF': '0',
        'BXXF': 1,
        'bxyxxf': '0',
        'XXXF': 2,
        'xxyxxfR': 0,
      },
    ],
  },
};
