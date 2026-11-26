"""Drive debug-only synthetic file fixtures on an already running Android emulator."""
from pathlib import Path
import json
import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET

adb = str(Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe')
serial = 'emulator-5562'
root = Path(__file__).resolve().parents[1]

def run(*args):
    return subprocess.check_output([adb, '-s', serial, *args], stderr=subprocess.DEVNULL)

def nodes():
    run('shell', 'uiautomator', 'dump', '/sdcard/synthetic-window.xml')
    return list(ET.fromstring(run('shell', 'cat', '/sdcard/synthetic-window.xml')).iter('node'))

def find(text, timeout=12):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        matches = [node for node in nodes() if text in (node.attrib.get('text','') + node.attrib.get('content-desc',''))]
        if matches:
            return matches[0]
        time.sleep(.5)
    raise AssertionError('Expected synthetic UI label missing')

def tap(node):
    x1,y1,x2,y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
    run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

try:
    old = run('exec-out','cat','/sdcard/Download/synthetic-acceptance.txt')
except subprocess.CalledProcessError:
    old = None
if old is not None:
    assert old == b'Synthetic file acceptance\n', 'Existing file is not our fixture'
    run('shell','rm','/sdcard/Download/synthetic-acceptance.txt')
run('shell','am','force-stop','com.wustacm.wiki')
time.sleep(.7)
run('shell','am','start','-W','-n','com.wustacm.wiki/.MainActivity','--ez','foundationAuthProbe','true','--es','probeMode','files')
find('MD5 + GB18030 PASS')
tap(find('导出文件'))
time.sleep(1)
run('shell','input','keyevent','4')
find('操作已取消')
tap(find('导出文件'))
time.sleep(1)
save = None
for node in nodes():
    if node.attrib.get('text','').lower() in {'save','保存'} and node.attrib.get('enabled') == 'true':
        save = node
assert save is not None, 'SAF save button not available'
tap(save)
find('文件已导出')
data = run('exec-out','cat','/sdcard/Download/synthetic-acceptance.txt')
assert data == b'Synthetic file acceptance\n'
tap(find('打开 PDF'))
time.sleep(1)
assert b'com.wustacm.wiki/.PdfActivity' in run('shell','dumpsys','activity','activities')
(root/'verification/synthetic-pdf.png').write_bytes(run('exec-out','screencap','-p'))
run('shell','input','keyevent','4')
find('MD5 + GB18030 PASS')
(root/'verification/synthetic-files.png').write_bytes(run('exec-out','screencap','-p'))
result = {'digestAndCharset':True,'safCancel':True,'safExactBytes':True,'pdfOpenedAndReturned':True}
(root/'verification/android-system.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
