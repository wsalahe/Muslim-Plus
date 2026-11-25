import os,re,json,sys
repo='wsalahe/Muslim-Plus'
names={'husary':'الشيخ محمود خليل الحصري','abdulbasit':'الشيخ عبد الباسط عبد الصمد','minshawi':'الشيخ محمد صديق المنشاوي','alafasy':'الشيخ مشاري بن راشد العفاسي','sudais':'الشيخ عبد الرحمن بن عبد العزيز السديس'}
order=['abdulbasit','husary','minshawi','alafasy','sudais']
ver=int(sys.argv[2]) if len(sys.argv)>2 else 1
out={'catalog_version':ver,'app_build':1,'repo':repo,'sheikhs':[]}
for k in order:
    d=os.path.join(sys.argv[1],k); items=[]
    for f in sorted(os.listdir(d)):
        m=re.match(r'(\d{3})(?:_p(\d+))?\.mp4$',f)
        if m: items.append({'n':int(m.group(1)),'p':int(m.group(2) or 0),'size':os.path.getsize(os.path.join(d,f)),'url':f'https://github.com/{repo}/releases/download/{k}/{f}'})
    out['sheikhs'].append({'id':k,'name':names[k],'surahs':items})
json.dump(out,open('catalog.json','w'),ensure_ascii=False,indent=0)
print({s['id']:len(s['surahs']) for s in out['sheikhs']})
