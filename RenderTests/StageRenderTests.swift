import XCTest
import PDFKit
@testable import MangaDirectionStudio
final class StageRenderTests:XCTestCase {
    @MainActor func testRenderAndExport()throws{
        let out=URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("stage-artifacts",isDirectory:true)
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        var p=StageProject()
        for layout in 0...2{p.layout=layout;let pdf=PageExporter.pdf(p);let doc=try XCTUnwrap(PDFDocument(data:pdf));XCTAssertEqual(doc.pageCount,p.pages);try pdf.write(to:out.appendingPathComponent("layout-\(layout).pdf"));try XCTUnwrap(PageExporter.png(p,page:0)).write(to:out.appendingPathComponent("layout-\(layout).png"))}
        for i in 0..<5{var panel=StagePanel();panel.camera.preset(i);let image=StageScene.image(panel,size:CGSize(width:900,height:600));XCTAssertEqual(image.size.width,900);try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent("camera-\(i).png"))}
        let store=StageStore();let original=store.project;defer{store.project=original;store.selected=0;store.persist()}
        let before=store.project.panels.count;store.duplicate();XCTAssertEqual(store.project.panels.count,before+1);XCTAssertTrue(store.project.isValid);store.undo();XCTAssertEqual(store.project,original)
        XCTAssertThrowsError(try store.load(Data("{}".utf8)));XCTAssertEqual(store.project,original)
        print("PASS: render/export, duplicate/undo, corrupt import preservation")
    }
}
