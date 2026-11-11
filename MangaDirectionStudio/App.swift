import SwiftUI
import UniformTypeIdentifiers

@MainActor final class StageStore:ObservableObject {
    @Published var project=StageProject()
    @Published var selected=0
    @Published var error:String?
    @Published var history:[StageProject]=[]
    private var readFailed=false
    private let url:URL
    init(){
        let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("MangaDirectionStudio",isDirectory:true)
        url=root.appendingPathComponent("project.json")
        do{try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);if FileManager.default.fileExists(atPath:url.path){let p=try JSONDecoder().decode(StageProject.self,from:Data(contentsOf:url));guard p.isValid else{throw CocoaError(.fileReadCorruptFile)};project=p}}
        catch{readFailed=true;error="保存データを読み込めません。元のファイルは保持しています。"}
    }
    var panel:StagePanel {project.panels[min(selected,project.panels.count-1)]}
    func change(_ edit:(inout StageProject)->Void){
        var next=project;edit(&next);guard next.isValid,next != project else{return}
        history.append(project);if history.count>40{history.removeFirst()};project=next;persist()
    }
    func panelChange(_ edit:(inout StagePanel)->Void){let i=selected;change{edit(&$0.panels[i])}}
    func undo(){guard let p=history.popLast()else{return};project=p;selected=min(selected,p.panels.count-1);persist()}
    func duplicate(){guard project.panels.count<24 else{return};var p=panel;p.id=UUID();p.title=String((p.title+" の続き").prefix(40));change{$0.panels.insert(p,at:selected+1)};selected+=1}
    func remove(){guard project.panels.count>1 else{return};let i=selected;change{$0.panels.remove(at:i)};selected=min(i,project.panels.count-1)}
    func move(_ delta:Int){let next=selected+delta;guard project.panels.indices.contains(next)else{return};let i=selected;change{$0.panels.swapAt(i,next)};selected=next}
    func load(_ data:Data)throws{guard data.count<=2_000_000 else{throw CocoaError(.fileReadTooLarge)};let p=try JSONDecoder().decode(StageProject.self,from:data);guard p.isValid else{throw CocoaError(.fileReadCorruptFile)};change{$0=p};selected=0}
    func persist(){guard !readFailed else{return};do{try JSONEncoder().encode(project).write(to:url,options:.atomic)}catch{self.error="保存できませんでした。作品をJSONで書き出して退避してください。"}}
}
@main struct MangaDirectionStudioApp:App {var body:some Scene{WindowGroup{WorkshopView()}}}
struct ExportFile:Identifiable {let id=UUID();let url:URL}
struct WorkshopView:View {
    @StateObject private var store=StageStore()
    @State private var actor=0
    @State private var tab=0
    @State private var share:ExportFile?
    @State private var importing=false
    @State private var removing=false
    @State private var showPage=false
    @State private var orbitStart:StageCamera?
    @Environment(\.horizontalSizeClass) private var sizeClass
    private let ink=Color(red:0.18,green:0.25,blue:0.36)
    var body:some View {
        NavigationStack {
            VStack(spacing:0){
                panelStrip
                if sizeClass == .regular {
                    HStack(spacing:0){stage.padding(16);ScrollView{controls}.frame(width:340)}
                }else{ScrollView{VStack(spacing:0){stage.frame(height:310).padding(12);controls}}}
            }.background(Color(white:0.96))
                .navigationTitle("漫画の演出工房").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.topBarLeading){Button{store.undo()}label:{Image(systemName:"arrow.uturn.backward")}.disabled(store.history.isEmpty).accessibilityLabel("元に戻す")}
                    ToolbarItem(placement:.topBarTrailing){Menu{
                        Button("ページを確認"){showPage=true}
                        Button("全ページをPDFで共有"){export("pdf")}
                        Button("選択コマのページをPNGで共有"){export("png")}
                        Button("作品をJSONで保存"){export("json")}
                        Button("JSONから作品を読み込む"){importing=true}
                    }label:{Image(systemName:"square.and.arrow.up")}.accessibilityLabel("ページと書き出し")}
                }
                .sheet(item:$share){ShareSheet(url:$0.url)}
                .sheet(isPresented:$showPage){PagePreview(project:store.project)}
                .alert("コマを削除しますか？",isPresented:$removing){Button("削除",role:.destructive){store.remove()};Button("キャンセル",role:.cancel){}}
                .alert("保存・読み込み",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("閉じる"){store.error=nil}}message:{Text(store.error ?? "")}
                .fileImporter(isPresented:$importing,allowedContentTypes:[.json]){result in
                    do{let u=try result.get();let access=u.startAccessingSecurityScopedResource();defer{if access{u.stopAccessingSecurityScopedResource()}};try store.load(Data(contentsOf:u))}catch{store.error="この作品ファイルを読み込めませんでした。現在の作品は保持しています。"}
                }
        }.tint(ink)
    }
    private var panelStrip:some View {
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){
            ForEach(Array(store.project.panels.enumerated()),id:\.element.id){i,p in
                Button{store.selected=i}label:{VStack(alignment:.leading,spacing:5){Text("\(i+1)").font(.system(.title2,design:.monospaced).bold());Text(p.title).font(.caption).lineLimit(1)}.frame(width:105,alignment:.leading).padding(10).foregroundStyle(store.selected==i ? .white : ink).background(store.selected==i ? ink : Color.white,in:RoundedRectangle(cornerRadius:7))}
            }
            Button{store.duplicate()}label:{Image(systemName:"plus").frame(width:40,height:60)}.disabled(store.project.panels.count>=24).accessibilityLabel("コマを複製して追加")
        }.padding(12)}.background(Color(white:0.89))
    }
    private var panelAspect:Double {let r=PageLayout.rects(store.project.layout,rtl:store.project.rightToLeft)[store.selected % store.project.perPage];return r.w/(r.h-72)}
    private var stage:some View {
        VStack(alignment:.leading,spacing:8){
            HStack{Text("\(store.selected+1) / \(store.project.panels.count)   \(store.panel.title)").font(.headline);Spacer();Image(systemName:"viewfinder")}
            ZStack{
                StageViewport(panel:store.panel)
                    .gesture(DragGesture().onChanged{v in
                        if orbitStart==nil{orbitStart=store.panel.camera}
                        guard let c=orbitStart else{return}
                        store.panelChange{$0.camera.yaw=min(180,max(-180,c.yaw-Double(v.translation.width)*0.25));$0.camera.pitch=min(75,max(-35,c.pitch+Double(v.translation.height)*0.20))}
                    }.onEnded{_ in orbitStart=nil})
                if store.panel.guides {GeometryReader{g in Path{p in for f in [1.0/3,2.0/3]{p.move(to:CGPoint(x:g.size.width*f,y:0));p.addLine(to:CGPoint(x:g.size.width*f,y:g.size.height));p.move(to:CGPoint(x:0,y:g.size.height*f));p.addLine(to:CGPoint(x:g.size.width,y:g.size.height*f))}}.stroke(.white.opacity(0.65),style:StrokeStyle(lineWidth:1,dash:[5,5]))}.allowsHitTesting(false)}
            }.aspectRatio(panelAspect,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(ink.opacity(0.2)))
            Text("ドラッグで視点を回転。各コマに構図とポーズを保存します。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var controls:some View {
        VStack(spacing:12){
            Picker("編集",selection:$tab){Text("カメラ").tag(0);Text("人物").tag(1);Text("コマ").tag(2)}.pickerStyle(.segmented)
            if tab==0{cameraControls}else if tab==1{actorControls}else{panelControls}
        }.padding(16).background(.white)
    }
    private var cameraControls:some View {
        VStack(alignment:.leading,spacing:12){
            Text("同じ場面を、違う目線で。").font(.headline)
            ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(Array(["全景","俯瞰","あおり","寄り","肩越し"].enumerated()),id:\.offset){i,s in Button(s){store.panelChange{$0.camera.preset(i)}}.buttonStyle(.bordered)}}}
            cameraSlider("左右の角度",\.yaw,-180...180)
            cameraSlider("見下ろす角度",\.pitch,-35...75)
            cameraSlider("カメラの距離",\.distance,1.5...9)
            cameraSlider("注目する高さ",\.targetY,0...2)
            cameraSlider("注目する左右位置",\.targetX,-2...2)
            cameraSlider("画角",\.fov,20...80)
            cameraSlider("画面の傾き",\.roll,-30...30)
            Toggle("構図ガイドと床グリッド",isOn:Binding(get:{store.panel.guides},set:{v in store.panelChange{$0.guides=v}}))
        }
    }
    private var actorControls:some View {
        VStack(alignment:.leading,spacing:10){
            Picker("人物",selection:$actor){Text("青の人物").tag(0);Text("赤の人物").tag(1)}.pickerStyle(.segmented)
            Toggle("人物を表示",isOn:Binding(get:{store.panel.actors[actor].visible},set:{v in store.panelChange{$0.actors[actor].visible=v}}))
            ScrollView(.horizontal,showsIndicators:false){HStack{ForEach(0..<ActorPose.names.count,id:\.self){i in Button(ActorPose.names[i]){store.panelChange{$0.actors[actor].preset(i)}}.buttonStyle(.bordered)}}}
            actorSlider("左右の位置",\.x,-3...3);actorSlider("奥行き",\.z,-3...3);actorSlider("向き",\.yaw,-180...180)
            actorSlider("上下の位置",\.lift,-1...1);actorSlider("体の傾き",\.lean,-45...45)
            ForEach(0..<10,id:\.self){i in
                let names=["左腕 前後","左腕 開き","左ひじ","左もも","左ひざ","右腕 前後","右腕 開き","右ひじ","右もも","右ひざ"]
                valueSlider(names[i],value:Binding(get:{store.panel.actors[actor].joints[i]},set:{v in store.panelChange{$0.actors[actor].joints[i]=v}}),range:(i%5==2 || i%5==4) ? 0...150 : -150...150)
            }
            Text("ポーズ用の簡易人形です。関節の干渉や接地は自動補正しません。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var panelControls:some View {
        VStack(alignment:.leading,spacing:14){
            TextField("作品名",text:Binding(get:{store.project.title},set:{v in store.change{$0.title=String(v.prefix(60))}})).textFieldStyle(.roundedBorder)
            TextField("コマの見出し",text:Binding(get:{store.panel.title},set:{v in store.panelChange{$0.title=String(v.prefix(40))}})).textFieldStyle(.roundedBorder)
            TextField("セリフ・演出メモ",text:Binding(get:{store.panel.caption},set:{v in store.panelChange{$0.caption=String(v.prefix(120))}}),axis:.vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Picker("舞台",selection:Binding(get:{store.panel.setting},set:{v in store.panelChange{$0.setting=v}})){Text("スタジオ").tag(0);Text("机と椅子").tag(1);Text("廊下").tag(2)}
            Picker("ページの割り方",selection:Binding(get:{store.project.layout},set:{v in store.change{$0.layout=v}})){Text("横長3コマ").tag(0);Text("4コマ").tag(1);Text("6コマ").tag(2)}
            Toggle("右から左へ読む",isOn:Binding(get:{store.project.rightToLeft},set:{v in store.change{$0.rightToLeft=v}}))
            HStack{Button("前へ移動"){store.move(-1)}.disabled(store.selected==0);Spacer();Button("後へ移動"){store.move(1)}.disabled(store.selected==store.project.panels.count-1)}
            Button("このコマを複製"){store.duplicate()}.disabled(store.project.panels.count>=24)
            Button("このコマを削除",role:.destructive){removing=true}.disabled(store.project.panels.count==1)
            Text("自動保存。最大24コマ。読み込み前の作品は「元に戻す」で復元できます。JSONを書き出すと別の作品として保管できます。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func cameraSlider(_ name:String,_ key:WritableKeyPath<StageCamera,Double>,_ range:ClosedRange<Double>)->some View{valueSlider(name,value:Binding(get:{store.panel.camera[keyPath:key]},set:{v in store.panelChange{$0.camera[keyPath:key]=v}}),range:range)}
    private func actorSlider(_ name:String,_ key:WritableKeyPath<ActorPose,Double>,_ range:ClosedRange<Double>)->some View{valueSlider(name,value:Binding(get:{store.panel.actors[actor][keyPath:key]},set:{v in store.panelChange{$0.actors[actor][keyPath:key]=v}}),range:range)}
    private func valueSlider(_ name:String,value:Binding<Double>,range:ClosedRange<Double>)->some View{VStack(spacing:2){HStack{Text(name);Spacer();Text(value.wrappedValue.formatted(.number.precision(.fractionLength(1)))).monospacedDigit().foregroundStyle(.secondary)}.font(.caption);Slider(value:value,in:range).accessibilityLabel(name)}}
    private func export(_ ext:String){do{let data:Data;if ext=="pdf"{data=PageExporter.pdf(store.project)}else if ext=="png"{guard let d=PageExporter.png(store.project,page:store.selected/store.project.perPage)else{throw CocoaError(.fileWriteUnknown)};data=d}else{data=try JSONEncoder().encode(store.project)};let u=FileManager.default.temporaryDirectory.appendingPathComponent("manga-stage-\(UUID()).\(ext)");try data.write(to:u,options:.atomic);share=ExportFile(url:u)}catch{store.error="書き出せませんでした。空き容量を確認してください。"}}
}
struct PagePreview:View {
    let project:StageProject
    @Environment(\.dismiss) var dismiss
    var body:some View{NavigationStack{ScrollView{ForEach(0..<project.pages,id:\.self){i in if let data=PageExporter.png(project,page:i),let image=UIImage(data:data){Image(uiImage:image).resizable().scaledToFit().padding()}}}.navigationTitle("ページの流れ").toolbar{Button("閉じる"){dismiss()}}}}
}
struct ShareSheet:UIViewControllerRepresentable {
    let url:URL
    func makeUIViewController(context:Context)->UIActivityViewController{UIActivityViewController(activityItems:[url],applicationActivities:nil)}
    func updateUIViewController(_ view:UIActivityViewController,context:Context){}
}
