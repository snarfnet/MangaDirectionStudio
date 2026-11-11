import SwiftUI
import SceneKit

enum StageScene {
    static func material(_ color:UIColor)->SCNMaterial {let m=SCNMaterial();m.diffuse.contents=color;m.roughness.contents=0.85;return m}
    static func build(_ panel:StagePanel)->(SCNScene,SCNNode) {
        let scene=SCNScene();scene.background.contents=UIColor(white:0.94,alpha:1)
        func box(_ width:CGFloat,_ height:CGFloat,_ length:CGFloat,_ x:Float,_ y:Float,_ z:Float) {
            let g=SCNBox(width:width,height:height,length:length,chamferRadius:0.015);g.materials=[material(.init(white:0.73,alpha:1))]
            let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);scene.rootNode.addChildNode(n)
        }
        let floor=SCNFloor();floor.reflectivity=0;floor.materials=[material(.init(white:0.9,alpha:1))];scene.rootNode.addChildNode(SCNNode(geometry:floor))
        if panel.guides {
            for i in -5...5 {box(0.009,0.003,10,Float(i),0.004,0);box(10,0.003,0.009,0,0.004,Float(i))}
        }
        if panel.setting==1 {
            box(1.35,0.08,0.65,0,0.74,-1.1)
            for x in [-0.57,0.57] as [Float] {for z in [-1.35,-0.85] as [Float] {box(0.07,0.7,0.07,x,0.35,z)}}
            box(0.55,0.08,0.55,0.65,0.43,0)
            box(0.55,0.6,0.06,0.65,0.76,-0.25)
            for x in [0.43,0.87] as [Float] {for z in [-0.22,0.22] as [Float] {box(0.05,0.42,0.05,x,0.21,z)}}
        }
        if panel.setting==2 {
            box(7,2.8,0.1,0,1.4,-3)
            for x in [-2,0,2] as [Float] {box(0.14,2.8,0.2,x,1.4,-2.8)}
        }
        for (index,actor) in panel.actors.enumerated() where actor.visible {
            let n=figure(actor,color:index==0 ? UIColor(red:0.26,green:0.40,blue:0.59,alpha:1) : UIColor(red:0.62,green:0.36,blue:0.34,alpha:1))
            scene.rootNode.addChildNode(n)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=650;scene.rootNode.addChildNode(ambient)
        let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.intensity=900;light.position=SCNVector3(-3,6,4);scene.rootNode.addChildNode(light)
        let c=panel.camera, camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=c.fov;camera.camera?.zNear=0.05;camera.camera?.zFar=100
        let yaw=c.yaw * .pi/180,pitch=c.pitch * .pi/180
        camera.position=SCNVector3(Float(c.targetX+sin(yaw)*cos(pitch)*c.distance),Float(c.targetY+sin(pitch)*c.distance),Float(cos(yaw)*cos(pitch)*c.distance))
        camera.look(at:SCNVector3(Float(c.targetX),Float(c.targetY),0));camera.eulerAngles.z += Float(c.roll * .pi/180)
        scene.rootNode.addChildNode(camera);return (scene,camera)
    }
    static func figure(_ pose:ActorPose,color:UIColor)->SCNNode {
        let root=SCNNode();root.position=SCNVector3(Float(pose.x),Float(pose.lift),Float(pose.z));root.eulerAngles.y=Float(pose.yaw * .pi/180)
        let body=SCNNode();body.position=SCNVector3(0,0.86,0);body.eulerAngles.z=Float(pose.lean * .pi/180);root.addChildNode(body)
        let m=material(color),jointMaterial=material(color.withAlphaComponent(0.85))
        func part(_ geometry:SCNGeometry,_ parent:SCNNode,_ position:SCNVector3)->SCNNode {
            geometry.materials=[m];let n=SCNNode(geometry:geometry);n.position=position;parent.addChildNode(n);return n
        }
        _=part(SCNCapsule(capRadius:0.19,height:0.54),body,SCNVector3(0,0.25,0))
        _=part(SCNSphere(radius:0.105),body,SCNVector3(0,0.57,0))
        let head=part(SCNSphere(radius:0.175),body,SCNVector3(0,0.77,0));head.scale=SCNVector3(0.85,1.15,0.9)
        let face=part(SCNSphere(radius:0.045),head,SCNVector3(0,0,0.16));face.geometry?.materials=[material(.init(white:0.23,alpha:1))]
        func pivot(_ parent:SCNNode,_ p:SCNVector3,_ rx:Double,_ rz:Double)->SCNNode {
            let n=SCNNode();n.position=p;n.eulerAngles=SCNVector3(Float(rx * .pi/180),0,Float(rz * .pi/180));parent.addChildNode(n)
            let j=SCNSphere(radius:0.072);j.materials=[jointMaterial];n.addChildNode(SCNNode(geometry:j));return n
        }
        for side in 0..<2 {
            let k=side*5,s:Float=side==0 ? -1 : 1
            let shoulder=pivot(body,SCNVector3(s*0.24,0.45,0),pose.joints[k],pose.joints[k+1])
            _=part(SCNCapsule(capRadius:0.065,height:0.32),shoulder,SCNVector3(0,-0.16,0))
            let elbow=pivot(shoulder,SCNVector3(0,-0.32,0),-pose.joints[k+2],0)
            _=part(SCNCapsule(capRadius:0.052,height:0.29),elbow,SCNVector3(0,-0.145,0))
            let hand=part(SCNSphere(radius:0.07),elbow,SCNVector3(0,-0.32,0));hand.scale=SCNVector3(0.7,1.25,0.6)
            let hip=pivot(root,SCNVector3(s*0.12,0.85,0),pose.joints[k+3],0)
            _=part(SCNCapsule(capRadius:0.085,height:0.40),hip,SCNVector3(0,-0.2,0))
            let knee=pivot(hip,SCNVector3(0,-0.40,0),pose.joints[k+4],0)
            _=part(SCNCapsule(capRadius:0.065,height:0.39),knee,SCNVector3(0,-0.195,0))
            _=part(SCNBox(width:0.14,height:0.09,length:0.25,chamferRadius:0.03),knee,SCNVector3(0,-0.4,0.055))
        }
        return root
    }
    static func image(_ panel:StagePanel,size:CGSize)->UIImage {
        let (scene,camera)=build(panel);let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=camera
        return renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
    }
}
struct StageViewport:UIViewRepresentable {
    let panel:StagePanel
    func makeUIView(context:Context)->SCNView {let v=SCNView();v.antialiasingMode = .multisampling4X;v.isPlaying=false;return v}
    func updateUIView(_ view:SCNView,context:Context) {let (scene,camera)=StageScene.build(panel);view.scene=scene;view.pointOfView=camera}
}

enum PageExporter {
    static func draw(_ project:StageProject,page:Int) {
        UIColor.white.setFill();UIRectFill(CGRect(x:0,y:0,width:596,height:842))
        (project.title as NSString).draw(at:CGPoint(x:28,y:18),withAttributes:[.font:UIFont.boldSystemFont(ofSize:15),.foregroundColor:UIColor.black])
        let rects=PageLayout.rects(project.layout,rtl:project.rightToLeft)
        for (slot,r) in rects.enumerated() {
            let index=page*project.perPage+slot;guard index<project.panels.count else{continue}
            let p=project.panels[index],rect=CGRect(x:r.x,y:r.y,width:r.w,height:r.h)
            let imageRect=CGRect(x:r.x,y:r.y,width:r.w,height:r.h-72)
            StageScene.image(p,size:CGSize(width:imageRect.width*2,height:imageRect.height*2)).draw(in:imageRect)
            UIColor.black.setStroke();UIBezierPath(rect:rect).stroke()
            let caption="\(index+1)  \(p.title)\n\(p.caption)"
            (caption as NSString).draw(with:CGRect(x:r.x+6,y:imageRect.maxY+4,width:r.w-12,height:66),options:.usesLineFragmentOrigin,attributes:[.font:UIFont.systemFont(ofSize:8),.foregroundColor:UIColor.black],context:nil)
        }
        ("漫画の演出工房 / 下描き資料 / \(page+1)" as NSString).draw(at:CGPoint(x:28,y:826),withAttributes:[.font:UIFont.systemFont(ofSize:7),.foregroundColor:UIColor.gray])
    }
    static func pdf(_ project:StageProject)->Data {
        UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:596,height:842)).pdfData{c in for page in 0..<project.pages{c.beginPage();draw(project,page:page)}}
    }
    static func png(_ project:StageProject,page:Int)->Data? {
        let f=UIGraphicsImageRendererFormat();f.scale=2;f.opaque=true
        return UIGraphicsImageRenderer(size:CGSize(width:596,height:842),format:f).image{_ in draw(project,page:page)}.pngData()
    }
}
