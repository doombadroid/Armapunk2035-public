#!/usr/bin/env python3
"""Owner 2026-09-07: the delivered sqm wins for La Trinite floor tiles. For every floor-class tile in the
delivery (box x7000-7500 y7700-8200) that matches a live row by class + XY < 5 cm but differs in height
(> 5 cm) or orientation (> 0.5 deg) -- the 9/1 zfix rows -- overwrite z + vdir/vup with the delivery's.
Old values -> undo JSON. Run tilecheck.py afterwards: everything must read 'ok'."""
import sys, math, json, collections, datetime; sys.path.insert(0,'/home/timb/Armapunk2035/tools')
import sqm_read, sqm_frame, apdb_dsn
DEL="/home/timb/Downloads/mission(1).sqm"; X0,X1,Y0,Y1=7000,7500,7700,8200
FLOOR=('Land_Sidewalk','Land_CobblestoneSquare','Land_GardenPavement','Land_ConcretePanels','Land_TreeGrate','Land_ConcreteTile','Land_Pavement','Land_Tarmac','Land_ConcreteSlab')
def angdiff(a,b): return math.degrees(math.acos(max(-1,min(1,sum(x*y for x,y in zip(a,b))))))
c=apdb_dsn.connect(); cur=c.cursor(); upd=[]
for n in sqm_read.walk(sqm_read.parse(DEL)):
    p=n['props']
    if p.get('dataType')!='Object' or not p.get('type','').startswith(FLOOR): continue
    pi=n['subs'].get('PositionInfo')
    if not pi: continue
    w=sqm_frame.SQM_POS_TO_WORLD([float(v) for v in pi['props']['position']])
    if not (X0<=w[0]<=X1 and Y0<=w[1]<=Y1): continue
    d,u=sqm_frame.angles_to_vectors([float(v) for v in pi['props'].get('angles',[0,0,0])])
    cur.execute("select id,z,vdir_x,vdir_y,vdir_z,vup_x,vup_y,vup_z,author_uid from map_objects where not deleted and classname=%s and abs(x-%s)<0.05 and abs(y-%s)<0.05",(p['type'],w[0],w[1]))
    rows=cur.fetchall()
    if len(rows)!=1: continue
    r=[rows[0][0]]+[float(v) for v in rows[0][1:8]]; rid=rows[0][0]
    if abs(w[2]-r[1])<0.05 and angdiff(d,r[2:5])<0.5 and angdiff(u,r[5:8])<0.5: continue
    cur.execute("update map_objects set z=%s,vdir_x=%s,vdir_y=%s,vdir_z=%s,vup_x=%s,vup_y=%s,vup_z=%s,author_uid='designer-20260907' where id=%s",(w[2],d[0],d[1],d[2],u[0],u[1],u[2],rid))
    upd.append({"id":rid,"cls":p['type'],"old":r[1:8],"old_author":rows[0][8],"new_z":w[2]})
c.commit()
print("updated",len(upd),collections.Counter(x["old_author"] for x in upd))
json.dump({"tiles_overwritten_with_designer_transform":upd},open('/home/timb/Armapunk2035/scratchpad/map_delivery/undo_tiles_%s.json'%datetime.datetime.now().strftime('%Y%m%d-%H%M%S'),'w'),indent=1,default=str)
