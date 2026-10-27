"""App-only UI checks. Never changes network settings or accesses other apps' data."""
import sys,time,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import evergreen_device_smoke as ui
ui.OUT=Path('artifacts/phase5_2_device');ui.OUT.mkdir(exist_ok=True)
def tab(name): return ui.tap(name+"\nTab")
def labels():return [ui.label(n).strip() for n in ui.nodes() if ui.label(n).strip()]
def find(fragment,limit=14):
 for _ in range(limit):
  if any(fragment.lower() in s.lower() for s in labels()): return ui.tap(fragment)
  ui.scroll()
 raise RuntimeError('Not found: '+fragment)
def top():
 for _ in range(18):ui.scroll(False)
def start():
 ui.adb('shell','am','force-stop','ai.agrivision.agrivision_ai')
 ui.adb('shell','am','start','-W','-f','0x10008000','-n','ai.agrivision.agrivision_ai/.MainActivity');time.sleep(1)
if __name__=='__main__':
 ui.screenshot('home');print('\n'.join(labels()))
