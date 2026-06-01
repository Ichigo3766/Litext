//
//  LTXLabelMenuItem.swift
//  Litext
//
//  Created by OpenAI Codex.
//

#if canImport(UIKit) && !os(tvOS) && !os(watchOS)

    import UIKit

    enum LTXLabelMenuItem: CaseIterable {
        case copy
        case selectAll
        case share
        case ask
        case explain

        var action: Selector? {
            switch self {
            case .copy:
                #selector(LTXLabel.copyMenuItemTapped)
            case .selectAll:
                #selector(LTXLabel.selectAllTapped)
            case .share:
                #selector(LTXLabel.shareMenuItemTapped)
            case .ask:
                #selector(LTXLabel.askMenuItemTapped)
            case .explain:
                #selector(LTXLabel.explainMenuItemTapped)
            }
        }

        var title: String {
            switch self {
            case .copy:
                LocalizedText.copy
            case .selectAll:
                LocalizedText.selectAll
            case .share:
                LocalizedText.share
            case .ask:
                "Ask"
            case .explain:
                "Explain"
            }
        }

        var image: UIImage? {
            switch self {
            case .copy:
                UIImage(systemName: "doc.on.doc")
            case .selectAll:
                UIImage(systemName: "selection.pin.in.out")
            case .share:
                UIImage(systemName: "square.and.arrow.up")
            case .ask:
                UIImage(systemName: "bubble.left")
            case .explain:
                UIImage(systemName: "lightbulb")
            }
        }

        static func textSelectionMenu() -> [LTXLabelMenuItem] {
            allCases
        }
    }

#endif
