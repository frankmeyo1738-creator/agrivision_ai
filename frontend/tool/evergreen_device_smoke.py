"""Read/drive the real Evergreen release UI on the test phone. No network changes."""
import json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ADB='/Users/frankmeyo/Library/Android/sdk/platform-tools/adb'
SERIAL='38121FDJH00B41'
OUT=Path('artifacts/phase5_device')

def adb(*args):return subprocess.check_output([ADB,'-s',SERIAL,*args],timeout=40)
def nodes():
 adb('shell','uiautomator','dump','/sdcard/agrivision-evergreen-ui.xml')
 xml=adb('exec-out','cat','/sdcard/agrivision-evergreen-ui.xml').decode()
 (OUT/'ui_latest.xml').write_text(xml)
 return list(ET.fromstring(xml).iter('node'))
def label(n):return n.get('text','')+' '+n.get('content-desc','')
def tap(fragment,exact=False):
 for n in nodes():
  value=label(n).strip()
  if (value==fragment if exact else fragment.lower() in value.lower()) and n.get('enabled')!='false':
   b=list(map(int,re.findall(r'\d+',n.get('bounds',''))))
   if len(b)==4 and b[2]>b[0] and b[3]>b[1]:
    adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));time.sleep(.4);return value
 raise RuntimeError('No visible target: '+fragment)
def screenshot(name):
 OUT.mkdir(exist_ok=True);(OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def scroll(down=True):
 size=adb('shell','wm','size').decode();w,h=map(int,re.findall(r'(\d+)x(\d+)',size)[-1]);x=w//2
 adb('shell','input','swipe',str(x),str(h*3//4 if down else h//3),str(x),str(h//3 if down else h*3//4),'350');time.sleep(.3)
if __name__=='__main__':
 OUT.mkdir(exist_ok=True)
 adb('shell','am','start','-n','ai.agrivision.agrivision_ai/.MainActivity');time.sleep(1)
 screenshot('home');print('\n'.join(label(n) for n in nodes() if label(n).strip()))
