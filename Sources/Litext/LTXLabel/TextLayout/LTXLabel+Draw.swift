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
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    drawingObservers.append(scroll.observe(\.contentOffset) { [weak self] _, _ in
                        self?.updateDrawingViewport()
                    })
                }
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
                drawingView.frame = frame
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
