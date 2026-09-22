//
//  TextLabelView+Draw.swift
//  Litext
//
//  Created by 秋星桥 on 3/27/25.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    final class TextLabelDrawingView: UIView {
        weak var label: TextLabelView?

        override func draw(_: CGRect) {
            guard let label, label.canDrawTextLayout,
                  let context = UIGraphicsGetCurrentContext() else { return }
            context.translateBy(x: -frame.minX, y: -frame.minY)
            label.textLayout.draw(in: context, visibleRect: frame)
        }
    }

    extension TextLabelView {
        func observeDrawingViewport() {
            drawingObservers.removeAll()
            guard window != nil else {
                updateDrawingViewport()
                return
            }
            var ancestor: UIView? = self
            while let view = ancestor {
                drawingObservers.append(view.layer.observe(\.bounds) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.updateDrawingViewport() }
                })
                drawingObservers.append(view.layer.observe(\.position) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.updateDrawingViewport() }
                })
                drawingObservers.append(view.layer.observe(\.transform) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.updateDrawingViewport() }
                })
                ancestor = view.superview
            }
            updateDrawingViewport()
        }

        func updateDrawingViewport() {
            var visible = window.map { convert($0.bounds, from: $0).intersection(bounds) } ?? .zero
            var ancestor = superview
            while let view = ancestor {
                if view.clipsToBounds {
                    visible = visible.intersection(convert(view.bounds, from: view))
                }
                ancestor = view.superview
            }
            guard window != nil, !visible.isNull, !visible.isEmpty else {
                drawingView.frame = .zero
                drawingView.layer.contents = nil
                return
            }
            let frame = visible.integral.intersection(bounds)
            if drawingView.frame != frame {
                UIView.performWithoutAnimation { drawingView.frame = frame }
                drawingView.setNeedsDisplay()
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public extension TextLabelView {
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard canDrawTextLayout else { return }
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            textLayout.draw(in: context, visibleRect: dirtyRect)
        }

        override var isFlipped: Bool {
            true
        }
    }
#endif

#if !os(watchOS)
    extension TextLabelView {
        /// Whether the text layout describes the geometry being painted.
        ///
        /// Lines are positioned against `TextLabel.Layout.containerSize`, so painting while
        /// it disagrees with `bounds` offsets every line by the difference — and a shorter
        /// container may not even hold the same lines. A layout pass is always pending when
        /// they disagree, and it marks the view for display once it has caught up, so
        /// skipping here costs at most one frame and never paints the wrong thing.
        ///
        /// Repairing the layout from `draw(_:)` is not an option: the host is inside its
        /// display phase, and laying out there would reenter the phase it just left.
        var canDrawTextLayout: Bool {
            textLayout.containerSize == bounds.size
        }
    }
#endif
