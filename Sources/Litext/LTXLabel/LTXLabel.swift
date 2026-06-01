//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreFoundation
import CoreText
import Foundation
import QuartzCore

#if !os(watchOS)

    @MainActor
    public class LTXLabel: LTXPlatformView, Identifiable {
        public let id: UUID = .init()

        // MARK: - Public Properties

        public var attributedText: NSAttributedString = .init() {
            didSet { textLayout = LTXTextLayout(attributedString: attributedText) }
        }

        public var preferredMaxLayoutWidth: CGFloat = 0 {
            didSet {
                if preferredMaxLayoutWidth != oldValue {
                    invalidateTextLayout()
                }
            }
        }

        override public var frame: CGRect {
            get { super.frame }
            set {
                guard newValue != super.frame else { return }
                super.frame = newValue
                invalidateTextLayout()
            }
        }

        public var isSelectable: Bool = false {
            didSet { if !isSelectable { clearSelection() } }
        }

        public var selectionBackgroundColor: PlatformColor? {
            didSet { updateSelectionLayer() }
        }

        public internal(set) var isInteractionInProgress = false

        public weak var delegate: LTXLabelDelegate?

        // MARK: - Internal Properties

        var textLayout: LTXTextLayout = .init(attributedString: .init()) {
            didSet { invalidateTextLayout() }
        }

        var attachmentViews: Set<LTXPlatformView> = []
        var highlightRegions: [LTXHighlightRegion] {
            textLayout.highlightRegions
        }

        var activeHighlightRegion: LTXHighlightRegion?
        var lastContainerSize: CGSize = .zero

        public internal(set) var selectionRange: NSRange? {
            didSet {
                updateSelectionLayer()
                if selectionRange != oldValue {
                    delegate?.ltxLabelSelectionDidChange(self, selection: selectionRange)
                }
            }
        }

        var selectedLinkForMenuAction: URL?
        nonisolated(unsafe) var selectionLayer: CAShapeLayer?

        /// The bounding rect of the current text selection, in the label's own coordinate space.
        /// Stored just before the edit menu is presented so the delegate can return it via
        /// `editMenuInteraction(_:targetRectFor:)` and prevent the menu from overlapping the selection.
        #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
            var currentEditMenuTargetRect: CGRect = .zero
        #endif

        #if canImport(UIKit) && !targetEnvironment(macCatalyst) && !os(tvOS) && !os(watchOS)
            var selectionHandleStart: LTXSelectionHandle = .init(type: .start)
            var selectionHandleEnd: LTXSelectionHandle = .init(type: .end)
        #endif

        var interactionState = InteractionState()
        var flags = Flags()

        // On macOS (iPad app on Apple Silicon), we temporarily disable the nearest
        // ancestor UIScrollView while a click-drag selection is in progress so the
        // vertical drag is consumed for text selection instead of scrolling.
        #if canImport(UIKit) && !os(tvOS) && !os(watchOS)
            weak var selectionLockedScrollView: UIScrollView?
        #endif

        // MARK: - Initialization

        #if canImport(UIKit)
            override public init(frame: CGRect) {
                super.init(frame: frame)
                registerNotificationCenterForSelectionDeduplicate()

                backgroundColor = .clear
                #if !os(tvOS) && !os(watchOS)
                    installContextMenuInteraction()
                    installTextPointerInteraction()
                    installLongPressGestureRecognizer()
                    installSecondaryClickGestureRecognizer()
                #endif

                #if !os(tvOS)
                    isMultipleTouchEnabled = false
                    isExclusiveTouch = true
                #endif

                #if !targetEnvironment(macCatalyst) && !os(tvOS) && !os(watchOS)
                    // On macOS (iPad app running on Apple Silicon via "Designed for iPad"),
                    // the touch-lever handles cannot be dragged with mouse/trackpad — the
                    // UIPanGestureRecognizer on each handle intercepts and cancels mouse
                    // drag events before touchesMoved gets them, making selection impossible.
                    // Skip adding the handles entirely on macOS; the existing pointer-device
                    // path in touchesMoved handles click-drag selection correctly without them.
                    if !ProcessInfo.isRunningOnMac {
                        clipsToBounds = false // for selection handle
                        selectionHandleStart.isHidden = true
                        selectionHandleStart.delegate = self
                        addSubview(selectionHandleStart)
                        selectionHandleEnd.isHidden = true
                        selectionHandleEnd.delegate = self
                        addSubview(selectionHandleEnd)
                    }
                #endif
            }

        #elseif canImport(AppKit)
            override public init(frame: CGRect) {
                super.init(frame: frame)
                registerNotificationCenterForSelectionDeduplicate()
                wantsLayer = true
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        #endif

        public convenience init(frame: CGRect = .zero, attributedText: NSAttributedString) {
            self.init(frame: frame)
            self.attributedText = attributedText
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError()
        }

        deinit {
            selectionLayer?.removeFromSuperlayer()
            if let activeHighlightRegion,
               let highlightLayer = activeHighlightRegion.associatedObject as? CALayer
            {
                highlightLayer.removeFromSuperlayer()
            }
            NotificationCenter.default.removeObserver(self)
        }

        #if canImport(UIKit)
            override public func didMoveToWindow() {
                super.didMoveToWindow()
                clearSelection()
                invalidateTextLayout()
            }

        #elseif canImport(AppKit)
            override public func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                clearSelection()
                invalidateTextLayout()
            }

            public var backgroundColor: NSColor? {
                get {
                    guard let cgColor = layer?.backgroundColor else { return nil }
                    return NSColor(cgColor: cgColor)
                }
                set {
                    wantsLayer = true
                    layer?.backgroundColor = newValue?.cgColor
                }
            }
        #endif
    }

    extension LTXLabel {
        struct InteractionState {
            var initialTouchLocation: CGPoint = .zero
            var clickCount: Int = 1
            var lastClickTime: TimeInterval = 0
            var isFirstMove: Bool = false
        }

        struct Flags {
            var layoutIsDirty: Bool = false
            var needsUpdateHighlightRegions: Bool = false
        }
    }

#endif // !os(watchOS)
