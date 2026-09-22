import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    extension ProcessInfo {
        static var isRunningOnMac: Bool {
            if #available(iOS 14.0, *) {
                return processInfo.isiOSAppOnMac
            }
            return false
        }
    }

    extension TextLabelView {
        /// Preserve pointer selection in the iPad app running on Apple Silicon.
        func lockSelectionScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    if scroll.isScrollEnabled {
                        scroll.isScrollEnabled = false
                        selectionLockedScrollView = scroll
                    }
                    return
                }
                ancestor = view.superview
            }
        }

        func unlockSelectionScrollView() {
            selectionLockedScrollView?.isScrollEnabled = true
            selectionLockedScrollView = nil
        }

        #if !os(tvOS)
            func installSelectionGestures() {
                if #available(iOS 13.4, *), ProcessInfo.isRunningOnMac {
                    let tap = UITapGestureRecognizer(target: self, action: #selector(handleSecondaryClick(_:)))
                    tap.buttonMaskRequired = .secondary
                    addGestureRecognizer(tap)
                } else {
                    let press = UILongPressGestureRecognizer(target: self, action: #selector(handleSelectionLongPress(_:)))
                    press.minimumPressDuration = 0.4
                    addGestureRecognizer(press)
                }
            }

            @objc private func handleSelectionLongPress(_ recognizer: UILongPressGestureRecognizer) {
                guard isSelectable, recognizer.state == .began,
                      let index = nearestTextIndexAtPoint(recognizer.location(in: self)) else { return }
                selectWordAtIndex(index)
                _ = becomeFirstResponder()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.async { [weak self] in self?.showSelectionMenuController() }
            }

            @objc private func handleSecondaryClick(_ recognizer: UITapGestureRecognizer) {
                guard isSelectable, recognizer.state == .ended else { return }
                if selectionRange == nil {
                    selectAll()
                }
                _ = becomeFirstResponder()
                showSelectionMenuController()
            }
        #endif
    }
#endif
