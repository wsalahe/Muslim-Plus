#!/usr/bin/env python3
# Rebuild catalog.json from the release assets (source of truth), push if changed.
import json,re,subprocess,time,os,sys
R='wsalahe/Muslim-Plus'
names={'abdulbasit':'الشيخ عبد الباسط عبد الصمد','husary':'الشيخ محمود خليل الحصري','minshawi':'الشيخ محمد صديق المنشاوي','alafasy':'الشيخ مشاري بن راشد العفاسي','sudais':'الشيخ عبد الرحمن بن عبد العزيز السديس'}
old=json.load(open('catalog.json')) if os.path.exists('catalog.json') else {'catalog_version':0,'app_build':1}
sheikhs=[]
for k,nm in names.items():
    o=subprocess.run(['gh','release','view',k,'-R',R,'--json','assets'],capture_output=True,text=True)
    items=[]
    if o.returncode==0:
        for a in json.loads(o.stdout)['assets']:
            m=re.match(r'(\d{3})(?:_p(\d+))?\.mp4$',a['name'])
            if m: items.append({'n':int(m.group(1)),'p':int(m.group(2) or 0),'size':a['size'],'url':f'https://github.com/{R}/releases/download/{k}/{a["name"]}'})
    items.sort(key=lambda x:(x['n'],x['p']))
    sheikhs.append({'id':k,'name':nm,'surahs':items})
if sheikhs==old.get('sheikhs'):
    print('no change'); sys.exit(0)
new={'catalog_version':int(time.time()),'app_build':old.get('app_build',1),'min_build':old.get('min_build',0),'repo':R,'sheikhs':sheikhs}
json.dump(new,open('catalog.json','w'),ensure_ascii=False,indent=0)
print('changed',{s['id']:len(s['surahs']) for s in sheikhs})
