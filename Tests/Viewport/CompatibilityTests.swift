@testable import Litext
import UIKit
import XCTest

@MainActor
final class CompatibilityTests: XCTestCase {
    func testReassigningMutatedTextRebuildsLayout() {
        let label = LTXLabel()
        let text = NSMutableAttributedString(string: "")
        label.attributedText = text
        text.append(NSAttributedString(string: "Seven paper stars."))
        label.attributedText = text
        XCTAssertEqual(label.textLayout.attributedString.string, text.string)
        let previous = label.textLayout
        text.addAttribute(.ltxLineDrawingCallback, value: LTXLineDrawingAction { _, _, _ in }, range: NSRange(location: 0, length: text.length))
        label.attributedText = text
        XCTAssertFalse(label.textLayout === previous, "A reused mutable input must not bypass invalidation.")
    }

    private final class LegacyDelegate: LTXLabelDelegate {
        var range: NSRange?
        var location: CGPoint?
        var highlight: LTXHighlightRegion?
        func ltxLabelSelectionDidChange(_: LTXLabel, selection: NSRange?) {
            range = selection
        }

        func ltxLabelDetectedUserEventMovingAtLocation(_: LTXLabel, location: CGPoint) {
            self.location = location
        }

        func ltxLabelDidTapOnHighlightContent(_: LTXLabel, region: LTXHighlightRegion?, location _: CGPoint) {
            highlight = region
        }
    }

    func testLegacyAttributeNamesAndDelegate() {
        XCTAssertEqual(NSAttributedString.Key.ltxAttachment, .litextAttachment)
        XCTAssertEqual(NSAttributedString.Key.ltxLineDrawingCallback, .litextLineDrawingAction)
        let label = LTXLabel(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        label.attributedText = NSAttributedString(string: "Seven paper stars.")
        let delegate = LegacyDelegate()
        label.delegate = delegate
        label.selectionRange = NSRange(location: 0, length: 5)
        XCTAssertEqual(delegate.range, label.selectionRange)
        label.delegate?.textLabelView(label, didDragSelectionAt: CGPoint(x: 20, y: 30))
        XCTAssertEqual(delegate.location, CGPoint(x: 20, y: 30))
    }

    func testAskAndExplainPreserveNotificationContract() {
        let label = LTXLabel(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        label.attributedText = NSAttributedString(string: "Seven paper stars.")
        for (name, action) in [(Notification.Name.ltxLabelAskSelection, #selector(TextLabelView.askMenuItemTapped)), (.ltxLabelExplainSelection, #selector(TextLabelView.explainMenuItemTapped))] {
            label.selectionRange = NSRange(location: 6, length: 5)
            XCTAssertTrue(label.canPerformAction(action, withSender: nil))
            let notification = expectation(forNotification: name, object: nil) { notification in
                notification.userInfo?["selectedText"] as? String == "paper"
            }
            label.perform(action)
            XCTAssertNil(label.selectionRange, "Clear selection before notifying the host app.")
            XCTAssertFalse(label.canPerformAction(action, withSender: nil))
            wait(for: [notification], timeout: 1)
        }
    }

    func testModernMenuIncludesForkActions() throws {
        let label = LTXLabel(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        label.attributedText = NSAttributedString(string: "Seven paper stars.")
        label.selectionRange = NSRange(location: 0, length: 5)
        let menu = try XCTUnwrap(label.editMenuInteraction(UIEditMenuInteraction(delegate: label), menuFor: UIEditMenuConfiguration(identifier: nil, sourcePoint: .zero), suggestedActions: []))
        XCTAssertTrue(menu.children.contains { $0.title == "Ask" })
        XCTAssertTrue(menu.children.contains { $0.title == "Explain" })
    }

    func testSelectionScrollLockRestoresOnlyEnabledScrollViews() {
        let scroll = UIScrollView()
        let label = LTXLabel()
        scroll.addSubview(label)
        label.lockSelectionScrollView()
        XCTAssertFalse(scroll.isScrollEnabled)
        label.unlockSelectionScrollView()
        XCTAssertTrue(scroll.isScrollEnabled)
        scroll.isScrollEnabled = false
        label.lockSelectionScrollView()
        label.unlockSelectionScrollView()
        XCTAssertFalse(scroll.isScrollEnabled)
    }
}
