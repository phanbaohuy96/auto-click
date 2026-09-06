import AppKit

/// Lớp phủ toàn màn hình để kéo chọn một vùng chữ nhật (RG-4).
///
/// Khoanh được ở **bất cứ đâu**, không ràng buộc vào Ứng dụng khoá: mục tiêu cần nhắm thường
/// chưa hiện trên màn hình lúc soạn Kịch bản, nên người dùng hay mở một ảnh chụp màn hình cũ
/// rồi cắt Ảnh mẫu từ chính ảnh đó — xem [ADR-0006].
@MainActor
final class ScreenRegionSelector {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var completion: ((CGRect?) -> Void)?

    func start(prompt: String, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        NSApp.activate(ignoringOtherApps: true)

        for screen in NSScreen.screens {
            let window = RegionSelectionWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = RegionSelectionView(
                prompt: prompt,
                onSelect: { [weak self] rect in self?.finish(with: rect) },
                onCancel: { [weak self] in self?.finish(with: nil) }
            )
            window.orderFrontRegardless()
            windows.append(window)
        }

        windows.first?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.finish(with: nil)
                return nil
            }
            return event
        }
    }

    private func finish(with rect: CGRect?) {
        guard let completion else { return }
        self.completion = nil

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()

        completion(rect)
    }
}

private final class RegionSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class RegionSelectionView: NSView {
    private let prompt: String
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void

    /// Toạ độ trong không gian của `CGEvent` (gốc trên-trái toàn cục).
    private var anchor: CGPoint?
    private var current: CGPoint?

    init(prompt: String, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.prompt = prompt
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private func globalPoint(of event: NSEvent) -> CGPoint {
        event.cgEvent?.location ?? CGEvent(source: nil)?.location ?? .zero
    }

    override func mouseDown(with event: NSEvent) {
        anchor = globalPoint(of: event)
        current = anchor
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = globalPoint(of: event)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let anchor else { return }
        let end = globalPoint(of: event)
        let rect = CGRect(
            x: min(anchor.x, end.x),
            y: min(anchor.y, end.y),
            width: abs(end.x - anchor.x),
            height: abs(end.y - anchor.y)
        )
        self.anchor = nil
        current = nil

        // Vùng bé tí thường là lỡ tay click chứ không phải chủ ý khoanh.
        guard rect.width >= 4, rect.height >= 4 else {
            needsDisplay = true
            return
        }
        onSelect(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel() } else { super.keyDown(with: event) }
    }

    /// Khung đang kéo, quy về toạ độ nội bộ của view (gốc dưới-trái).
    private var selectionRectInView: NSRect? {
        guard let anchor, let current, let window else { return nil }
        let screenTop = window.screen?.frame.maxY ?? 0
        let screenLeft = window.screen?.frame.minX ?? 0
        func convert(_ point: CGPoint) -> NSPoint {
            NSPoint(x: point.x - screenLeft, y: screenTop - point.y - (window.screen?.frame.minY ?? 0))
        }
        let a = convert(anchor)
        let b = convert(current)
        return NSRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        dirtyRect.fill()

        if let selection = selectionRectInView, selection.width > 0, selection.height > 0 {
            // Khoét vùng đang chọn ra để người dùng thấy đúng thứ sắp được chụp.
            NSColor.clear.setFill()
            selection.fill(using: .copy)
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(rect: selection)
            path.lineWidth = 2
            path.stroke()

            let size = "\(Int(selection.width)) × \(Int(selection.height))"
            draw(text: size, at: NSPoint(x: selection.minX, y: selection.maxY + 6), font: 13)
            return
        }

        let text = prompt
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let panel = NSRect(
            x: bounds.midX - textSize.width / 2 - 22,
            y: bounds.midY - textSize.height / 2 - 14,
            width: textSize.width + 44,
            height: textSize.height + 28
        )
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12).fill()
        attributed.draw(
            at: NSPoint(x: panel.midX - textSize.width / 2, y: panel.midY - textSize.height / 2)
        )
    }

    private func draw(text: String, at point: NSPoint, font size: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        NSAttributedString(string: " \(text) ", attributes: attributes).draw(at: point)
    }
}
