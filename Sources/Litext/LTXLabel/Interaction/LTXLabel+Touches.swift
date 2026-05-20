//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import CoreText
    import Foundation
    import UIKit

    public extension LTXLabel {
        fileprivate static var menuOwnerIdentifier: UUID = .init()

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard isSelectable else {
                super.pressesBegan(presses, with: event)
                return
            }
            var didHandleEvent = false
            for press in presses {
                guard let key = press.key else { continue }
                // Use keyCode instead of charactersIgnoringModifiers for keyboard layout independence
                if key.keyCode == .keyboardC, key.modifierFlags.contains(.command) {
                    let copiedText = copySelectedText()
                    didHandleEvent = copiedText.length > 0
                }
                if key.keyCode == .keyboardA, key.modifierFlags.contains(.command) {
                    selectAllText()
                    didHandleEvent = true
                }
            }
            if !didHandleEvent { super.pressesBegan(presses, with: event) }
        }

        override var canBecomeFocused: Bool {
            isSelectable
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            #if !targetEnvironment(macCatalyst) && !os(tvOS) && !os(watchOS)
                for handler in [selectionHandleStart, selectionHandleEnd] {
                    let rect = handler.frame
                        .insetBy(
                            dx: -LTXSelectionHandle.knobExtraResponsiveArea,
                            dy: -LTXSelectionHandle.knobExtraResponsiveArea
                        )
                    if rect.contains(point) { return true }
                }
            #endif

            if !bounds.contains(point) { return false }

            for view in attachmentViews {
                if view.frame.contains(point) {
                    return super.point(inside: point, with: event)
                }
            }

            if isSelectable || highlightRegionAtPoint(point) != nil {
                return true
            }

            return false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard touches.count == 1,
                  let firstTouch = touches.first
            else {
                super.touchesBegan(touches, with: event)
                return
            }

            if isSelectable, !isFirstResponder {
                // to received keyboard event from there
                _ = becomeFirstResponder()
            }

            let location = firstTouch.location(in: self)
            setInteractionStateToBegin(initialLocation: location)

            if isLocationAboveAttachmentView(location: location) {
                super.touchesBegan(touches, with: event)
                return
            }
            interactionState.isFirstMove = true

            if activateHighlightRegionAtPoint(location) {
                return
            }

            bumpClickCountIfWithinTimeGap()
            if !isSelectable { return }

            if interactionState.clickCount <= 1 {
                if isPointerDevice(touch: firstTouch) {
                    // On macOS: Shift+click extends existing selection to the clicked point.
                    // This is the standard macOS text selection affordance and allows users
                    // to extend/shrink a selection without drag handles.
                    if ProcessInfo.isRunningOnMac,
                       let existingRange = selectionRange, existingRange.length > 0,
                       event?.modifierFlags.contains(.shift) == true,
                       let index = nearestTextIndexAtPoint(location)
                    {
                        let existingStart = existingRange.location
                        let existingEnd = existingRange.location + existingRange.length
                        let newStart = min(index, existingStart)
                        let newEnd = max(index, existingEnd)
                        selectionRange = NSRange(location: newStart, length: newEnd - newStart)
                        // Also update the drag anchor so subsequent shift+clicks keep working
                        // from the far end of the selection
                        return
                    }
                    if let index = textIndexAtPoint(location) {
                        selectionRange = NSRange(location: index, length: 0)
                    }
                }
            } else if interactionState.clickCount == 2 {
                if let index = textIndexAtPoint(location) {
                    selectWordAtIndex(index)
                    // prevent touches did end discard the changes
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self.selectWordAtIndex(index)
                    }
                }
            } else {
                if let index = textIndexAtPoint(location) {
                    selectLineAtIndex(index)
                    // prevent touches did end discard the changes
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self.selectLineAtIndex(index)
                    }
                }
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard touches.count == 1,
                  let firstTouch = touches.first
            else {
                super.touchesMoved(touches, with: event)
                return
            }

            let location = firstTouch.location(in: self)
            guard isTouchReallyMoved(location) else { return }

            deactivateHighlightRegion()
            performContinuousStateReset()

            if interactionState.isFirstMove {
                interactionState.isFirstMove = false
            }

            guard isSelectable else { return }

            if isPointerDevice(touch: firstTouch) {
                updateSelectionRange(withLocation: location)
                if selectionRange != nil {
                    delegate?.ltxLabelDetectedUserEventMovingAtLocation(self, location: location)
                }
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            isInteractionInProgress = false
            guard touches.count == 1,
                  let firstTouch = touches.first
            else {
                super.touchesEnded(touches, with: event)
                return
            }
            let location = firstTouch.location(in: self)
            defer { deactivateHighlightRegion() }

            if !isTouchReallyMoved(location),
               interactionState.clickCount <= 1
            {
                if isLocationInSelection(location: location) {
                    // On macOS (iPad app on Apple Silicon), don't show the tap-up copy menu —
                    // right-click via UIContextMenuInteraction is the correct macOS affordance.
                    #if !targetEnvironment(macCatalyst) && !os(tvOS) && !os(watchOS)
                        if !ProcessInfo.isRunningOnMac {
                            showSelectionMenuController()
                        }
                    #endif
                } else {
                    clearSelection()
                }
            }

            guard selectionRange == nil, !isTouchReallyMoved(location) else { return }
            outer: for region in highlightRegions {
                let rects = region.rects.map {
                    convertRectFromTextLayout($0.cgRectValue, insetForInteraction: true)
                }
                for rect in rects where rect.contains(location) {
                    self.delegate?.ltxLabelDidTapOnHighlightContent(self, region: region, location: location)
                    break outer
                }
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            isInteractionInProgress = false
            guard touches.count == 1,
                  let firstTouch = touches.first
            else {
                super.touchesCancelled(touches, with: event)
                return
            }
            _ = firstTouch
            deactivateHighlightRegion()
        }

        #if !os(tvOS) && !os(watchOS)
            /// Install UIContextMenuInteraction for right-click menus.
            /// On macOS (iPad app on Apple Silicon) we skip this entirely because
            /// UIContextMenuInteraction's internal long-press gesture recognizer
            /// fires almost immediately and cancels ongoing touch sequences —
            /// preventing click-drag text selection entirely.
            func installContextMenuInteraction() {
                guard !ProcessInfo.isRunningOnMac else { return }
                let interaction = UIContextMenuInteraction(delegate: self)
                addInteraction(interaction)
            }

            func installTextPointerInteraction() {
                if #available(iOS 13.4, macCatalyst 13.4, *) {
                    let pointerInteraction = UIPointerInteraction(delegate: self)
                    addInteraction(pointerInteraction)
                }
            }

            func installLongPressGestureRecognizer() {
                // Skip long-press on macOS (iPad app on Apple Silicon): holding the mouse
                // button triggers unwanted word-selection and a UIMenuController that can't
                // be dismissed with the mouse. Standard click-drag selection is sufficient.
                guard !ProcessInfo.isRunningOnMac else { return }
                let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                recognizer.minimumPressDuration = 0.4
                addGestureRecognizer(recognizer)
            }

            /// Install a secondary-click (right-click / two-finger tap) gesture for macOS.
            /// This replaces UIContextMenuInteraction on macOS to show the copy/select menu
            /// without interfering with primary-click drag selection.
            func installSecondaryClickGestureRecognizer() {
                guard ProcessInfo.isRunningOnMac else { return }
                if #available(iOS 13.4, *) {
                    let tap = UITapGestureRecognizer(target: self, action: #selector(handleSecondaryClick(_:)))
                    tap.buttonMaskRequired = .secondary
                    addGestureRecognizer(tap)
                }
            }

            @available(iOS 13.4, *)
            @objc func handleSecondaryClick(_ recognizer: UITapGestureRecognizer) {
                guard isSelectable, recognizer.state == .ended else { return }
                let location = recognizer.location(in: self)
                // Auto-select all text so Copy is immediately available if nothing is selected
                if selectionRange == nil || selectionRange!.length == 0 {
                    selectAllText()
                }
                _ = becomeFirstResponder()
                // Build and show an edit menu at the right-click location
                if #available(iOS 16.0, *) {
                    let interaction = UIEditMenuInteraction(delegate: nil)
                    addInteraction(interaction)
                    let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
                    interaction.presentEditMenu(with: config)
                    // Clean up the interaction after the menu is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.removeInteraction(interaction)
                    }
                } else {
                    showSelectionMenuController()
                }
            }

            @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
                guard isSelectable, recognizer.state == .began else { return }
                let location = recognizer.location(in: self)
                guard let index = textIndexAtPoint(location) else { return }
                selectWordAtIndex(index)
                _ = becomeFirstResponder()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.async { self.showSelectionMenuController() }
            }

        #endif
    }

    #if !os(tvOS) && !os(watchOS)
        extension LTXLabel {
            func showSelectionMenuController() {
                guard let range = selectionRange, range.length > 0 else { return }

                // Don't show the menu if another view controller is presented above ours
                // (e.g. UIActivityViewController from shareMenuItemTapped)
                if parentViewController?.presentedViewController != nil { return }

                let rects: [CGRect] = textLayout.rects(for: range).map {
                    convertRectFromTextLayout($0, insetForInteraction: true)
                }
                guard !rects.isEmpty, var unionRect = rects.first else { return }

                for rect in rects.dropFirst() {
                    unionRect = unionRect.union(rect)
                }

                let menuController = UIMenuController.shared

                let items = LTXLabelMenuItem
                    .textSelectionMenu()
                    .compactMap { item -> UIMenuItem? in
                        guard let selector = item.action else { return nil }
                        guard canPerformAction(selector, withSender: nil) else { return nil }
                        return UIMenuItem(title: item.title, action: selector)
                    }
                menuController.menuItems = items

                Self.menuOwnerIdentifier = id
                menuController.showMenu(
                    from: self,
                    rect: unionRect.insetBy(dx: -8, dy: -8)
                )
            }

            func hideSelectionMenuController() {
                guard Self.menuOwnerIdentifier == id else { return }
                UIMenuController.shared.hideMenu()
            }

            @objc func copyMenuItemTapped() {
                let copiedText = copySelectedText()
                if copiedText.length <= 0 {
                    _ = copyFromSubviewsRecursively()
                }
                clearSelection()
            }

            @objc func selectAllTapped() {
                selectAllText()
                DispatchQueue.main.async {
                    self.showSelectionMenuController()
                }
            }

            @objc func shareMenuItemTapped() {
                guard let text = selectedPlainText(), !text.isEmpty else { return }
                let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = self
                parentViewController?.present(activityController, animated: true)
            }

            @objc private func copyKeyCommand() {
                let copiedText = copySelectedText()
                if copiedText.length <= 0 {
                    _ = copyFromSubviewsRecursively()
                }
            }

            override public var canBecomeFirstResponder: Bool {
                isSelectable
            }

            override public func canPerformAction(
                _ action: Selector,
                withSender _: Any?
            ) -> Bool {
                if action == #selector(copyMenuItemTapped) {
                    return selectionRange != nil
                        && selectionRange!.length > 0
                }
                if action == #selector(selectAllTapped) {
                    return selectionRange != selectAllRange()
                }
                if action == #selector(shareMenuItemTapped) {
                    return (selectedPlainText() ?? "").isEmpty == false
                }
                return false
            }

            private func copyFromSubviewsRecursively() -> Bool {
                copyFromSubviewsRecursively(in: self)
            }

            private func copyFromSubviewsRecursively(in view: UIView) -> Bool {
                for subview in view.subviews {
                    if let ltxLabel = subview as? LTXLabel {
                        let copiedText = ltxLabel.copySelectedText()
                        if copiedText.length > 0 {
                            return true
                        }
                    } else {
                        if copyFromSubviewsRecursively(in: subview) {
                            return true
                        }
                    }
                }
                return false
            }
        }
    #endif

    extension LTXLabel {
        func isPointerDevice(touch: UITouch) -> Bool {
            #if targetEnvironment(macCatalyst)
                return true // Mac Catalyst is always a pointer device
            #else
                // On macOS running as an "Designed for iPad" app, all mouse events
                // arrive as .direct touch type — not .indirectPointer. Treat the Mac
                // as a pointer device so click-to-place-cursor and drag-to-select work.
                if ProcessInfo.isRunningOnMac { return true }
                switch touch.type {
                case .indirectPointer, .pencil:
                    return true
                default:
                    return false
                }
            #endif
        }
    }

#endif
