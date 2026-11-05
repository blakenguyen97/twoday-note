import AppKit
import Observation
import SwiftUI

/// The zoom level of a ZoomableImage, for the viewer's buttons and ⌘= ⌘- ⌘0.
@Observable
final class ZoomControl {
    /// Magnification in percent of the image's own size.
    private(set) var percent = 100
    /// True while the whole image fits, nothing to drag.
    private(set) var isFitted = true
    private(set) var canZoomIn = true
    @ObservationIgnored fileprivate weak var view: ZoomScrollView?

    func zoomIn() { view?.zoom(by: ZoomScrollView.step) }
    func zoomOut() { view?.zoom(by: 1 / ZoomScrollView.step) }
    func fit() { view?.fit() }

    fileprivate func update(magnification: CGFloat, fitted: Bool, canZoomIn: Bool) {
        let percent = Int((magnification * 100).rounded())
        if percent != self.percent { self.percent = percent }
        if fitted != isFitted { isFitted = fitted }
        if canZoomIn != self.canZoomIn { self.canZoomIn = canZoomIn }
    }
}

/// An image that opens fitted to the space and zooms with a pinch, a double
/// click, or the ZoomControl. Zoomed in, drag it or scroll to move around.
/// Give it `.id(name)` so another image starts fitted again.
struct ZoomableImage: NSViewRepresentable {
    let image: NSImage
    let control: ZoomControl

    func makeNSView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView(image: image)
        view.onChange = { [weak control] magnification, fitted, canZoomIn in
            control?.update(magnification: magnification, fitted: fitted, canZoomIn: canZoomIn)
        }
        control.view = view
        return view
    }

    func updateNSView(_ view: ZoomScrollView, context: Context) {
        control.view = view
    }
}

final class ZoomScrollView: NSScrollView {
    /// The image viewer's scroll view inside `view`, for the self-test and snapshots.
    static func find(in view: NSView?) -> ZoomScrollView? {
        guard let view else { return nil }
        if let found = view as? ZoomScrollView { return found }
        return view.subviews.lazy.compactMap { find(in: $0) }.first
    }

    var isFitted: Bool { fitted }

    /// One press of + or −.
    static let step: CGFloat = 1.5
    /// How far past the image's own size people can zoom.
    private static let maxMagnification: CGFloat = 8

    var onChange: ((CGFloat, Bool, Bool) -> Void)?
    /// Follows the view's size while true; a zoom or pinch ends it.
    private var fitted = true
    private var fitMagnification: CGFloat = 1

    init(image: NSImage) {
        super.init(frame: .zero)
        let clip = CenteringClipView()
        clip.drawsBackground = false
        contentView = clip
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        allowsMagnification = true

        let imageView = DragImageView(frame: NSRect(origin: .zero, size: image.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isEditable = false
        imageView.setAccessibilityLabel("Ảnh")
        documentView = imageView

        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged),
                                               name: NSView.boundsDidChangeNotification, object: clip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        updateFitMagnification()
        if fitted, abs(magnification - fitMagnification) > 0.001 { magnification = fitMagnification }
        report()
    }

    /// The magnification that shows the whole image, never above its own size.
    private func updateFitMagnification() {
        guard let size = documentView?.frame.size, size.width > 0, size.height > 0,
              contentView.frame.width > 0, contentView.frame.height > 0 else { return }
        fitMagnification = min(1, contentView.frame.width / size.width, contentView.frame.height / size.height)
        minMagnification = fitMagnification
        maxMagnification = max(Self.maxMagnification, fitMagnification)
    }

    // MARK: Zooming

    func fit() {
        fitted = true
        animateMagnification(to: fitMagnification, at: nil)
    }

    func zoom(by factor: CGFloat) {
        animateMagnification(to: magnification * factor, at: nil)
    }

    /// Double click: zoom in on the point, or back to fit.
    func toggleZoom(at point: NSPoint) {
        if fitted || magnification <= fitMagnification + 0.001 {
            animateMagnification(to: max(1, fitMagnification * 2.5), at: point)
        } else {
            fit()
        }
    }

    private func animateMagnification(to target: CGFloat, at point: NSPoint?) {
        let clamped = min(max(target, minMagnification), maxMagnification)
        let center = point ?? NSPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        fitted = abs(clamped - fitMagnification) < 0.001
        NSAnimationContext.runAnimationGroup { _ in
            animator().setMagnification(clamped, centeredAt: center)
        }
    }

    override func endGesture(with event: NSEvent) {
        super.endGesture(with: event)
        fitted = abs(magnification - fitMagnification) < 0.001
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        fitted = abs(magnification - fitMagnification) < 0.001
        report()
    }

    // MARK: Dragging

    /// Moves the image with the pointer, by `delta` window points.
    func pan(by delta: CGSize) {
        var bounds = contentView.bounds
        bounds.origin.x -= delta.width / magnification
        bounds.origin.y -= delta.height / magnification
        contentView.scroll(to: contentView.constrainBoundsRect(bounds).origin)
        reflectScrolledClipView(contentView)
    }

    var canPan: Bool {
        guard let size = documentView?.frame.size else { return false }
        return contentView.bounds.width < size.width - 0.5 || contentView.bounds.height < size.height - 0.5
    }

    @objc private func boundsChanged() {
        report()
        window?.invalidateCursorRects(for: documentView ?? self)
    }

    private func report() {
        onChange?(magnification, fitted, magnification < maxMagnification - 0.001)
    }
}

/// Keeps an image smaller than the view in the middle instead of the corner.
private final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposed: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposed)
        guard let document = documentView?.frame else { return rect }
        if rect.width > document.width { rect.origin.x = (document.width - rect.width) / 2 }
        if rect.height > document.height { rect.origin.y = (document.height - rect.height) / 2 }
        return rect
    }
}

/// The image inside ZoomScrollView: drag to move, double click to zoom.
private final class DragImageView: NSImageView {
    private var zoomView: ZoomScrollView? { enclosingScrollView as? ZoomScrollView }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let zoomView else { return }
        if event.clickCount == 2 {
            zoomView.toggleZoom(at: convert(event.locationInWindow, from: nil))
            return
        }
        guard zoomView.canPan else { return }
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        var last = event.locationInWindow
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type == .leftMouseDragged {
            let point = next.locationInWindow
            zoomView.pan(by: CGSize(width: point.x - last.x, height: point.y - last.y))
            last = point
        }
    }

    override func resetCursorRects() {
        if zoomView?.canPan == true { addCursorRect(visibleRect, cursor: .openHand) }
    }
}
