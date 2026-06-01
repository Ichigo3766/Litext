//
//  LTXLabel+UIEditMenuInteractionDelegate.swift
//  Litext
//
//  Provides UIEditMenuInteractionDelegate conformance for iOS 16+.
//  This wires up the Ask and Explain custom menu items in the modern
//  system edit menu shown after text selection.
//

#if canImport(UIKit) && !os(tvOS) && !os(watchOS)

    import UIKit

    @available(iOS 16.0, *)
    extension LTXLabel: UIEditMenuInteractionDelegate {
        // `nonisolated` satisfies the non-isolated protocol requirement; UIKit always
        // invokes this delegate callback on the main thread, so we re-enter the main
        // actor via `MainActor.assumeIsolated` to safely touch `LTXLabel` members.
        public nonisolated func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            MainActor.assumeIsolated {
                // Build the standard actions (Copy, Select All, Share) from suggestedActions
                // plus our custom Ask and Explain actions.
                var customActions: [UIAction] = []

                // Ask action — places selected text quoted in the input box
                if canPerformAction(#selector(askMenuItemTapped), withSender: nil) {
                    let askAction = UIAction(
                        title: "Ask",
                        image: UIImage(systemName: "bubble.left")
                    ) { [weak self] _ in
                        self?.askMenuItemTapped()
                    }
                    customActions.append(askAction)
                }

                // Explain action — places "Explain: [selected text]" in the input box
                if canPerformAction(#selector(explainMenuItemTapped), withSender: nil) {
                    let explainAction = UIAction(
                        title: "Explain",
                        image: UIImage(systemName: "lightbulb")
                    ) { [weak self] _ in
                        self?.explainMenuItemTapped()
                    }
                    customActions.append(explainAction)
                }

                if customActions.isEmpty {
                    // No custom actions available — return nil to show default menu only
                    return nil
                }

                // Merge: standard system actions first, then Ask/Explain
                let allActions: [UIMenuElement] = suggestedActions + customActions
                return UIMenu(children: allActions)
            }
        }
    }

#endif
