import Foundation

// Keep existing MarkdownView clients source-compatible with the upstream API rename.
public typealias LitextLabel = TextLabel
public typealias LTXAttachment = TextLabel.Attachment
public typealias LTXLineDrawingAction = TextLabel.LineDrawingAction
public let LTXAttachmentAttributeName = NSAttributedString.Key.litextAttachment
public let LTXLineDrawingCallbackName = NSAttributedString.Key.litextLineDrawingAction
public let LTXReplacementText = "\u{FFFC}"

public extension NSAttributedString.Key {
    static let ltxAttachment = litextAttachment
    static let ltxLineDrawingCallback = litextLineDrawingAction
}

public extension Notification.Name {
    static let ltxLabelAskSelection = Notification.Name("ltxLabelAskSelection")
    static let ltxLabelExplainSelection = Notification.Name("ltxLabelExplainSelection")
}

#if !os(watchOS)
    public typealias LTXLabel = TextLabelView
    public typealias LTXTextLayout = TextLabel.Layout
    public typealias LTXHighlightRegion = TextLabel.HighlightRegion
    public typealias LTXAttributeStringRepresentable = TextLabel.AttachmentRepresentable
    public typealias LTXPlatformView = PlatformView

    @MainActor
    public protocol LTXLabelDelegate: TextLabelViewDelegate {
        func ltxLabelSelectionDidChange(_ label: LTXLabel, selection: NSRange?)
        func ltxLabelDetectedUserEventMovingAtLocation(_ label: LTXLabel, location: CGPoint)
        func ltxLabelDidTapOnHighlightContent(_ label: LTXLabel, region: LTXHighlightRegion?, location: CGPoint)
    }

    public extension LTXLabelDelegate {
        func textLabelView(_ label: TextLabelView, didChangeSelection selection: NSRange?) {
            ltxLabelSelectionDidChange(label, selection: selection)
        }

        func textLabelView(_ label: TextLabelView, didDragSelectionAt location: CGPoint) {
            ltxLabelDetectedUserEventMovingAtLocation(label, location: location)
        }

        func textLabelView(_ label: TextLabelView, didTapHighlightRegion region: TextLabel.HighlightRegion, at location: CGPoint) {
            ltxLabelDidTapOnHighlightContent(label, region: region, location: location)
        }
    }
#endif
