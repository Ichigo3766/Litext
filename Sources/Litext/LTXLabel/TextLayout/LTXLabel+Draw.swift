//
//  LTXLabel+Draw.swift
//  Litext
//
//  Created by 秋星桥 on 3/27/25.
//

import Foundation

#if canImport(UIKit) && !os(watchOS)
    import UIKit

    final class LTXLabelDrawingView: UIView {
        weak var label: LTXLabel?

        override func draw(_: CGRect) {
            guard let label, let context = UIGraphicsGetCurrentContext() else { return }
            context.translateBy(x: -frame.minX, y: -frame.minY)
            label.textLayout.draw(in: context)
        }
    }

    extension LTXLabel {
        func observeDrawingViewport() {
            drawingObservers.removeAll()
            guard window != nil else {
                updateDrawingViewport()
                return
            }
            var ancestor: UIView? = self
            while let view = ancestor {
                // Scrolling changes bounds; pagination can instead move an ancestor
                // without laying out this label or changing the scroll offset.
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
                // Wrap in performWithoutAnimation to prevent UIKit's implicit animation
                // transaction (e.g. keyboard slide-up) from interpolating the drawing
                // surface frame, which would visibly shrink the text during keyboard open.
                UIView.performWithoutAnimation {
                    drawingView.frame = frame
                }
                drawingView.setNeedsDisplay()
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    public extension LTXLabel {
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            textLayout.draw(in: context)
        }

        override var isFlipped: Bool {
            true
        }
    }
#endif
