import AppKit

protocol CertificateStore {
    func exists() -> Bool
    func generate() throws
    func revealInFinder()
}

enum CertificateError: Error {
    case renderingFailed
}

/// Writes the E-Kitten certificate as a PNG in Application Support. The file
/// is a keepsake; the rank itself lives in stored state.
struct FileCertificateStore: CertificateStore {
    let fileURL: URL

    static func defaultFileURL() -> URL {
        AppDirectories.applicationSupport()
            .appendingPathComponent("Certificates", isDirectory: true)
            .appendingPathComponent(CeremonyCopy.certificateFileName)
    }

    func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func generate() throws {
        let data = try CertificateRenderer.pngData()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}

enum CertificateRenderer {
    static let pixelSize = (width: 1200, height: 850)

    static func pngData() throws -> Data {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelSize.width,
                pixelsHigh: pixelSize.height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw CertificateError.renderingFailed
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw(in: NSRect(x: 0, y: 0, width: pixelSize.width, height: pixelSize.height))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CertificateError.renderingFailed
        }
        return data
    }

    private static func draw(in bounds: NSRect) {
        let paper = NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.92, alpha: 1)
        let ink = NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.20, alpha: 1)

        paper.setFill()
        bounds.fill()

        ink.setStroke()
        let outerBorder = NSBezierPath(rect: bounds.insetBy(dx: 40, dy: 40))
        outerBorder.lineWidth = 6
        outerBorder.stroke()
        let innerBorder = NSBezierPath(rect: bounds.insetBy(dx: 56, dy: 56))
        innerBorder.lineWidth = 2
        innerBorder.stroke()

        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        centered.lineSpacing = 14

        let body = NSAttributedString(
            string: CeremonyCopy.certificateBody,
            attributes: [.font: serifFont(size: 44), .foregroundColor: ink, .paragraphStyle: centered]
        )
        let signature = NSAttributedString(
            string: CeremonyCopy.certificateSignature,
            attributes: [.font: serifFont(size: 36, italic: true), .foregroundColor: ink, .paragraphStyle: centered]
        )

        let textWidth = bounds.width - 240
        let bodyHeight = body.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin]
        ).height
        body.draw(
            with: NSRect(x: 120, y: bounds.midY - bodyHeight / 2 + 60, width: textWidth, height: bodyHeight),
            options: [.usesLineFragmentOrigin]
        )
        signature.draw(
            with: NSRect(x: 120, y: 130, width: textWidth, height: 60),
            options: [.usesLineFragmentOrigin]
        )
    }

    private static func serifFont(size: CGFloat, italic: Bool = false) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        if italic { descriptor = descriptor.withSymbolicTraits(.italic) }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}
