import Foundation

struct ActorPose: Codable, Equatable {
    var x = -0.6, z = 0.0, yaw = 15.0, lift = 0.0, lean = 0.0
    // Shoulder front/side, elbow, hip, knee for left and right sides.
    var joints = [0.0, -12, 8, 0, 0, 0, 12, 8, 0, 0]
    var visible = true
    static let names = ["自然体", "歩く", "座る", "指さす", "驚く", "手を振る"]
    mutating func preset(_ n: Int) {
        lift=0;lean=0
        switch n {
        case 1:joints=[-30,-8,25,28,12,30,8,15,-25,35]
        case 2:joints=[-25,-10,65,-85,90,-25,10,65,-85,90];lift = -0.38
        case 3:joints=[-85,-18,8,0,0,0,12,15,0,0]
        case 4:joints=[-45,-65,110,10,15,-45,65,110,-10,15];lean = -8
        case 5:joints=[0,-145,60,0,0,0,12,10,0,0]
        default:joints=[0,-12,8,0,0,0,12,8,0,0]
        }
    }
    var isValid: Bool { joints.count==10 && joints.allSatisfy{$0.isFinite && abs($0)<=180} && [x,z,yaw,lift,lean].allSatisfy{$0.isFinite} && abs(x)<=3 && abs(z)<=3 && abs(yaw)<=180 && abs(lift)<=1 && abs(lean)<=45 }
}
struct StageCamera: Codable, Equatable {
    var yaw=18.0, pitch=8.0, distance=4.8, targetY=0.95, targetX=0.0, fov=42.0, roll=0.0
    mutating func preset(_ i:Int) {
        switch i {
        case 1:yaw=35;pitch=35;distance=5;targetY=0.8;fov=42;roll=0
        case 2:yaw = -25;pitch = -12;distance=3.5;targetY=1.1;fov=48;roll=0
        case 3:yaw=0;pitch=0;distance=2.3;targetY=1.45;fov=35;roll=0
        case 4:yaw=145;pitch=5;distance=2.8;targetY=1.4;fov=45;roll=0
        default:self=StageCamera()
        }
    }
    var isValid:Bool { [yaw,pitch,distance,targetY,targetX,fov,roll].allSatisfy{$0.isFinite} && abs(yaw)<=180 && (-35...75).contains(pitch) && (1.5...9).contains(distance) && (0...2).contains(targetY) && abs(targetX)<=2 && (20...80).contains(fov) && abs(roll)<=30 }
}
struct StagePanel: Identifiable,Codable,Equatable {
    var id=UUID(), title="新しいコマ", caption=""
    var actors:[ActorPose] = [ActorPose(), {var a=ActorPose();a.x=0.65;a.z = -0.25;a.yaw = -25;return a}()]
    var camera=StageCamera()
    var setting=0, guides=true
    var isValid:Bool {title.count<=40 && caption.count<=120 && actors.count==2 && actors.allSatisfy{$0.isValid} && camera.isValid && (0...2).contains(setting)}
}
struct StageProject:Codable,Equatable {
    var version=1, title="放課後の待ち合わせ", layout=0, rightToLeft=true
    var panels:[StagePanel] = {
        var a=StagePanel();a.title="場所を見せる";a.caption="放課後、待ち合わせ場所で。";a.setting=1
        var b=a;b.id=UUID();b.title="気づく";b.camera.preset(3);b.actors[0].preset(5);b.caption="こっちだよ。"
        var c=a;c.id=UUID();c.title="二人の距離";c.camera.preset(4);c.caption="待った？"
        return [a,b,c]
    }()
    var isValid:Bool {version==1 && title.count<=60 && (0...2).contains(layout) && (1...24).contains(panels.count) && Set(panels.map{$0.id}).count==panels.count && panels.allSatisfy{$0.isValid}}
    var perPage:Int {[3,4,6][layout]}
    var pages:Int {(panels.count+perPage-1)/perPage}
}
struct PanelRect:Equatable {var x:Double,y:Double,w:Double,h:Double}
enum PageLayout {
    static func rects(_ layout:Int,rtl:Bool)->[PanelRect] {
        let margin=28.0,gap=12.0,w=540.0,h=740.0
        if layout==0 {return (0..<3).map{PanelRect(x:margin,y:50+Double($0)*(h/3+gap),w:w,h:h/3)}}
        let rows=layout==1 ? 2 : 3, cw=(w-gap)/2, ch=(h-Double(rows-1)*gap)/Double(rows)
        return (0..<(rows*2)).map{i in let column=rtl ? 1-i%2 : i%2;return PanelRect(x:margin+Double(column)*(cw+gap),y:50+Double(i/2)*(ch+gap),w:cw,h:ch)}
    }
}
