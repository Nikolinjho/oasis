from pathlib import Path
import hashlib,json,struct
root=Path(__file__).resolve().parent
repo=root.parents[2]
audit=json.loads((root/'source-verification.json').read_text())
for row in audit['files']:
 p=repo/'app/Sources'/row['file']
 assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],f'Source changed: {p}'
current=json.loads((root/'current/index.json').read_text());after=json.loads((root/'refreshed/index.json').read_text())
assert current==after
assert len(current)==63
for row in current:
 sizes=[]
 for folder in ['current','refreshed']:
  data=(root/folder/(row['id']+'.png')).read_bytes()
  assert data[:8]==b'\x89PNG\r\n\x1a\n'
  w,h=struct.unpack('>II',data[16:24]);sizes.append((w,h))
  assert (w,h)==(2*int(row['width']),2*int(row['height'])),(row['id'],w,h)
 assert sizes[0]==sizes[1]
result={'nativePairs':len(current),'samePairDimensions':True,'sourceFilesUnchanged':len(audit['files']),'identicalRendererFiles':audit['identical'],'rendererExceptions':list(audit['exceptions'])}
(root/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps(result,ensure_ascii=False))
