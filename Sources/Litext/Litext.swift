//
//  Litext.swift
//  Litext
//
//  Created by 秋星桥 on 3/27/25.
//

import Foundation

public let LTXReplacementText = "\u{FFFC}"
public let LTXAttachmentAttributeName = NSAttributedString.Key("LTXAttachment")
public let LTXLineDrawingCallbackName = NSAttributedString.Key("LTXLineDrawingCallback")

public extension NSAttributedString.Key {
    @inline(__always) static let ltxAttachment = LTXAttachmentAttributeName
    @inline(__always) static let ltxLineDrawingCallback = LTXLineDrawingCallbackName
}

// MARK: - LTXLabel Notification Names

public extension Notification.Name {
    /// Posted by LTXLabel when the user taps "Ask" in the text selection menu.
    /// userInfo["selectedText"] contains the selected plain text string.
    static let ltxLabelAskSelection = Notification.Name("ltxLabelAskSelection")

    /// Posted by LTXLabel when the user taps "Explain" in the text selection menu.
    /// userInfo["selectedText"] contains the selected plain text string.
    static let ltxLabelExplainSelection = Notification.Name("ltxLabelExplainSelection")
}
