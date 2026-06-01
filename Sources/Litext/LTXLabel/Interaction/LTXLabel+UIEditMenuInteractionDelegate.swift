//
//  LTXLabel+UIEditMenuInteractionDelegate.swift
//  Litext
//
//  Provides UIEditMenuInteractionDelegate conformance for iOS 16+.
//  This wires up Copy, Select All, Share, Ask and Explain actions in the
//  modern system edit menu shown after text selection.
//
//  NOTE: LTXLabel does NOT conform to UITextInput, so the system cannot
//  auto-populate `suggestedActions` with Copy/Select All/Share. We build
//  all actions manually here so the full set is always available.
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
                var actions: [UIMenuElement] = []

                // --- Standard actions (system doesn't auto-add these because LTXLabel
                //     doesn't conform to UITextInput, so we build them manually) ---

                // Copy
                if canPerformAction(#selector(copyMenuItemTapped), withSender: nil) {
                    let copyAction = UIAction(
                        title: "Copy",
                        image: UIImage(systemName: "doc.on.doc")
                    ) { [weak self] _ in
                        self?.copyMenuItemTapped()
                    }
                    actions.append(copyAction)
                }

                // Select All
                if canPerformAction(#selector(selectAllTapped), withSender: nil) {
                    let selectAllAction = UIAction(
                        title: "Select All",
                        image: UIImage(systemName: "text.cursor")
                    ) { [weak self] _ in
                        self?.selectAllTapped()
                    }
                    actions.append(selectAllAction)
                }

                // Share
                if canPerformAction(#selector(shareMenuItemTapped), withSender: nil) {
                    let shareAction = UIAction(
                        title: "Share",
                        image: UIImage(systemName: "square.and.arrow.up")
                    ) { [weak self] _ in
                        self?.shareMenuItemTapped()
                    }
                    actions.append(shareAction)
                }

                // --- Custom Ask / Explain actions ---

                // Ask — places selected text quoted in the input box
                if canPerformAction(#selector(askMenuItemTapped), withSender: nil) {
                    let askAction = UIAction(
                        title: "Ask",
                        image: UIImage(systemName: "bubble.left")
                    ) { [weak self] _ in
                        self?.askMenuItemTapped()
                    }
                    actions.append(askAction)
                }

                // Explain — places "Explain: [selected text]" in the input box
                if canPerformAction(#selector(explainMenuItemTapped), withSender: nil) {
                    let explainAction = UIAction(
                        title: "Explain",
                        image: UIImage(systemName: "lightbulb")
                    ) { [weak self] _ in
                        self?.explainMenuItemTapped()
                    }
                    actions.append(explainAction)
                }

                guard !actions.isEmpty else { return nil }
                return UIMenu(children: actions)
            }
        }

        /// Return the bounding rect of the current text selection so UIKit knows which
        /// region to avoid. This causes the menu to appear above or below the selected
        /// text rather than overlapping it.
        public nonisolated func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            targetRectFor configuration: UIEditMenuConfiguration
        ) -> CGRect {
            MainActor.assumeIsolated {
                currentEditMenuTargetRect
            }
        }
    }

#endif
