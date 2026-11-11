import Foundation
func check(_ value:Bool,_ label:String){if !value{fatalError(label)}}
var p=StageProject();check(p.isValid,"default")
let roundtrip=try JSONDecoder().decode(StageProject.self,from:JSONEncoder().encode(p));check(roundtrip==p,"JSON")
var a=ActorPose();for i in 0..<6{a.preset(i);check(a.isValid,"pose")}
var c=StageCamera();for i in 0..<5{c.preset(i);check(c.isValid,"camera")}
for layout in 0...2{for rtl in [true,false]{let rs=PageLayout.rects(layout,rtl:rtl);check(rs.count==[3,4,6][layout],"count");for r in rs{check(r.x>=0 && r.y>=0 && r.x+r.w<=596 && r.y+r.h<825,"bounds")};if layout>0{check((rs[0].x>rs[1].x)==rtl,"reading order")}}}
p.panels.append(p.panels[0]);check(!p.isValid,"duplicate id")
p=StageProject();p.panels[0].actors[0].joints=[];check(!p.isValid,"invalid pose")
p=StageProject();p.panels[0].camera.fov=0;check(!p.isValid,"invalid camera")
for count in 1...24{for layout in 0...2{var project=StageProject();project.panels=(0..<count).map{_ in StagePanel()};project.layout=layout;check(project.isValid,"valid project");check(project.pages*project.perPage>=count,"page capacity")}}
print("PASS: scene persistence, 6 poses, 5 cameras, reading order, page bounds and 72 pagination cases")
