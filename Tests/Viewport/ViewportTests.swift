@testable import Litext
import UIKit
import XCTest

@MainActor
final class ViewportTests: XCTestCase {
    @MainActor private final class Fixture {
        let window: UIWindow
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 100, width: 300, height: 400))
        let row = UIView(frame: CGRect(x: 0, y: 800, width: 300, height: 200))
        let label = LTXLabel(frame: CGRect(x: 0, y: 0, width: 300, height: 200))

        init() throws {
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            window = UIWindow(windowScene: scene)
            let controller = UIViewController()
            controller.view.backgroundColor = .white
            window.rootViewController = controller
            window.makeKeyAndVisible()
            scroll.contentSize = CGSize(width: 300, height: 20000)
            controller.view.addSubview(scroll)
            scroll.addSubview(row)
            label.attributedText = NSAttributedString(
                string: "A copper telescope stands beside a blue notebook.\nSeven paper stars mark an imaginary map.",
                attributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.black]
            )
            row.addSubview(label)
            window.layoutIfNeeded()
        }
    }

    func testAncestorMoveRefreshesPreviouslyOffscreenText() async throws {
        let f = try Fixture()
        defer { f.window.isHidden = true }
        XCTAssertEqual(f.label.drawingView.frame, .zero)

        // A prepended/removed row changes an ancestor's origin without changing
        // this label's bounds or the scroll view's content offset.
        f.row.frame.origin.y = 50
        f.window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(f.label.drawingView.frame, f.label.bounds)

        let image = UIGraphicsImageRenderer(bounds: f.window.bounds).image { _ in
            f.window.drawHierarchy(in: f.window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Synthetic text after ancestor move"
        attachment.lifetime = .keepAlways
        add(attachment)
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: 0, y: 150 * image.scale, width: 300 * image.scale, height: 200 * image.scale)))
        var pixels = [UInt8](repeating: 255, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        let ink = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0] < 100 && pixels[$0 + 1] < 100 && pixels[$0 + 2] < 100 }.count
        XCTAssertGreaterThan(ink, 100, "The onscreen text must actually draw, not merely remain accessible.")
    }

    func testRepeatedPrependingAndScrollingKeepSurfaceBounded() async throws {
        let f = try Fixture()
        defer { f.window.isHidden = true }
        f.label.frame.size.height = 12000
        f.row.frame.size.height = 12000
        f.window.layoutIfNeeded()
        for index in 0 ..< 100 {
            f.scroll.contentOffset.y = CGFloat(index * 70 + 900)
            f.row.frame.origin.y = CGFloat(index * 70 + 800)
            XCTAssertEqual(f.label.drawingView.frame, CGRect(x: 0, y: 100, width: 300, height: 400))
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(f.label.drawingView.frame.height, 400)
    }

    func testAncestorResizeTransformAndDetach() async throws {
        let f = try Fixture()
        defer { f.window.isHidden = true }
        f.row.frame.origin.y = 50
        XCTAssertEqual(f.label.drawingView.frame, f.label.bounds)
        f.scroll.bounds.size.height = 120
        XCTAssertEqual(f.label.drawingView.frame.height, 70)
        f.row.transform = CGAffineTransform(translationX: 0, y: 30)
        XCTAssertEqual(f.label.drawingView.frame.height, 40)
        f.row.removeFromSuperview()
        XCTAssertTrue(f.label.drawingObservers.isEmpty)
        XCTAssertEqual(f.label.drawingView.frame, .zero)
        f.scroll.addSubview(f.row)
        XCTAssertEqual(f.label.drawingView.frame.height, 40)
        try await Task.sleep(for: .milliseconds(100))
    }

    func testObserversDoNotRetainLabel() async throws {
        weak var released: LTXLabel?
        try autoreleasepool {
            let f = try Fixture()
            f.window.isHidden = true
            released = f.label
            f.row.removeFromSuperview()
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(released)
    }
}
