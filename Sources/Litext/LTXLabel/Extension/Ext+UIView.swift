//
//  Ext+UIView.swift
//  MarkdownView
//
//  Created by 秋星桥 on 7/8/25.
//

#if canImport(UIKit) && !os(watchOS)

    import UIKit

    extension UIView {
        var parentViewController: UIViewController? {
            weak var parentResponder: UIResponder? = self
            while parentResponder != nil {
                parentResponder = parentResponder!.next
                if let viewController = parentResponder as? UIViewController {
                    return viewController
                }
            }
            return nil
        }

        /// Walk up the superview tree and return the first UIScrollView ancestor.
        var nearestScrollView: UIScrollView? {
            var view: UIView? = superview
            while let current = view {
                if let scrollView = current as? UIScrollView {
                    return scrollView
                }
                view = current.superview
            }
            return nil
        }
    }

#endif
