import Litext
import UIKit
import XCTest

#if UPSTREAM
    private typealias ComparedLabel = TextLabelView
#else
    private typealias ComparedLabel = LTXLabel
#endif

@MainActor
final class RendererTests: XCTestCase {
    private let paragraph = "A copper telescope stands beside a blue notebook. Seven paper stars mark an imaginary map. A quiet observatory records the colors of the sky, then stores its numbered sketch for another evening."

    private func text(_ count: Int) -> NSAttributedString {
        NSAttributedString(string: (1 ... count).map { "Observation \($0)\n" + paragraph }.joined(separator: "\n\n"), attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black])
    }

    private func window() throws -> (UIWindow, UIScrollView) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view.backgroundColor = .white
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 100, width: 300, height: 400))
        controller.view.addSubview(scroll)
        return (window, scroll)
    }

    private func label(_ text: NSAttributedString, y: CGFloat, in parent: UIView) -> ComparedLabel {
        let label = ComparedLabel()
        label.preferredMaxLayoutWidth = 300
        label.attributedText = text
        label.frame = CGRect(x: 0, y: y, width: 300, height: label.intrinsicContentSize.height)
        parent.addSubview(label)
        label.layoutIfNeeded()
        return label
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    private func measured(_ body: () -> Void) {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTCPUMetric(), XCTClockMetric(), XCTMemoryMetric()], options: options, block: body)
    }

    func testSingleLongLabelInitialRender() throws {
        let content = text(256)
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        measured {
            autoreleasepool {
                let label = label(content, y: 0, in: scroll)
                scroll.contentSize = label.bounds.size
                settle(window)
                label.removeFromSuperview()
                settle(window)
            }
        }
    }

    func testChunkedInitialRender() throws {
        let content = text(8)
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        measured {
            autoreleasepool {
                var labels: [ComparedLabel] = []
                var y: CGFloat = 0
                for _ in 0 ..< 32 {
                    let label = label(content, y: y, in: scroll)
                    y += label.bounds.height
                    labels.append(label)
                }
                scroll.contentSize = CGSize(width: 300, height: y)
                settle(window)
                labels.forEach { $0.removeFromSuperview() }
                settle(window)
            }
        }
    }

    func testAlternatingWidthMeasurement() {
        let label = ComparedLabel()
        label.attributedText = text(256)
        measured {
            for index in 0 ..< 50 {
                label.preferredMaxLayoutWidth = index.isMultiple(of: 2) ? 300 : 340
                XCTAssertGreaterThan(label.intrinsicContentSize.height, 400)
            }
        }
    }

    func testRepeatedEqualTextAssignment() throws {
        let content = text(256)
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        let label = label(content, y: 0, in: scroll)
        scroll.contentSize = label.bounds.size
        settle(window)
        measured {
            for _ in 0 ..< 20 {
                label.attributedText = NSAttributedString(attributedString: content)
                label.layoutIfNeeded()
            }
            settle(window)
        }
    }

    func testRepeatedScrolling() throws {
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        let label = label(text(256), y: 0, in: scroll)
        scroll.contentSize = label.bounds.size
        settle(window)
        measured {
            for index in 0 ..< 40 {
                scroll.contentOffset.y = CGFloat(index) * (label.bounds.height - 400) / 39
                window.layoutIfNeeded()
                CATransaction.flush()
                RunLoop.main.run(until: Date().addingTimeInterval(0.017))
            }
        }
    }

    func testAncestorMoveDrawsVisibleText() throws {
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        scroll.contentSize = CGSize(width: 300, height: 2000)
        let row = UIView(frame: CGRect(x: 0, y: 800, width: 300, height: 300))
        scroll.addSubview(row)
        _ = label(text(1), y: 0, in: row)
        settle(window)
        row.frame.origin.y = 50
        settle(window)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: 0, y: 150 * image.scale, width: 300 * image.scale, height: 200 * image.scale)))
        var pixels = [UInt8](repeating: 255, count: crop.width * crop.height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        let ink = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0] < 100 && pixels[$0 + 1] < 100 && pixels[$0 + 2] < 100 }.count
        XCTAssertGreaterThan(ink, 100)
    }

    func testLongTextDrawsAtStartMiddleAndEnd() throws {
        let (window, scroll) = try window()
        defer { window.isHidden = true }
        let label = label(text(256), y: 0, in: scroll)
        scroll.contentSize = label.bounds.size
        for fraction in [0.0, 0.5, 1.0] {
            scroll.contentOffset.y = fraction * (label.bounds.height - 400)
            settle(window)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let crop = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: 0, y: 100 * image.scale, width: 300 * image.scale, height: 400 * image.scale)))
            var pixels = [UInt8](repeating: 255, count: crop.width * crop.height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            let ink = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0] < 100 && pixels[$0 + 1] < 100 && pixels[$0 + 2] < 100 }.count
            XCTAssertGreaterThan(ink, 100, "Visible text at scroll fraction \(fraction)")
        }
    }
}
