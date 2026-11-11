import CoreGraphics
import Foundation
import ImageIO

/// One animation frame at the art's native resolution: one bitmap pixel per
/// drawn pixel.
struct SpriteFrame {
    let width: Int
    let height: Int
    let image: CGImage
    let duration: TimeInterval
    /// Row-major from the top-left, one entry per art pixel.
    private let opaque: [Bool]

    init(width: Int, height: Int, image: CGImage, duration: TimeInterval, opaque: [Bool]) {
        self.width = width
        self.height = height
        self.image = image
        self.duration = duration
        self.opaque = opaque
    }

    /// `y` counts down from the top row. Out-of-range pixels are transparent.
    func isOpaque(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return opaque[y * width + x]
    }
}

struct SpriteSet {
    let idle: [SpriteFrame]
    /// Played while the speech bubble is open, if supplied.
    let talk: [SpriteFrame]?
}

enum SpriteLoader {
    /// GIFs with no usable frame delay play at this pace.
    static let fallbackFrameDuration: TimeInterval = 0.1

    /// Loads the frames of an animated GIF and reduces each to the art's
    /// native grid.
    ///
    /// The supplied art is exported enlarged: every drawn pixel is a square
    /// block of `sourcePixelsPerArtPixel` identical source pixels. Sampling
    /// one pixel per block recovers the original exactly, with no
    /// resampling, so it can then be scaled up crisply by any whole number.
    static func loadGIF(at url: URL, sourcePixelsPerArtPixel: Int) -> [SpriteFrame]? {
        guard sourcePixelsPerArtPixel > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let count = CGImageSourceGetCount(source)
        var frames: [SpriteFrame] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil),
                  let frame = reduce(
                      image,
                      by: sourcePixelsPerArtPixel,
                      duration: frameDuration(of: source, at: index)
                  ) else { return nil }
            frames.append(frame)
        }
        return frames.isEmpty ? nil : frames
    }

    static func reduce(_ image: CGImage, by blockSize: Int, duration: TimeInterval) -> SpriteFrame? {
        guard blockSize > 0,
              image.width % blockSize == 0, image.height % blockSize == 0,
              let source = rgbaBytes(of: image) else { return nil }

        let width = image.width / blockSize
        let height = image.height / blockSize
        guard width > 0, height > 0 else { return nil }

        var reduced = [UInt8](repeating: 0, count: width * height * 4)
        var opaque = [Bool](repeating: false, count: width * height)
        let centerOffset = blockSize / 2
        for y in 0..<height {
            for x in 0..<width {
                let sourceIndex = ((y * blockSize + centerOffset) * image.width + x * blockSize + centerOffset) * 4
                let index = y * width + x
                for channel in 0..<4 {
                    reduced[index * 4 + channel] = source[sourceIndex + channel]
                }
                opaque[index] = source[sourceIndex + 3] > 127
            }
        }

        guard let reducedImage = makeImage(rgba: reduced, width: width, height: height) else { return nil }
        return SpriteFrame(width: width, height: height, image: reducedImage, duration: duration, opaque: opaque)
    }

    private static func frameDuration(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0
        return delay > 0 ? delay : fallbackFrameDuration
    }

    private static var colorSpace: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    private static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    /// Premultiplied RGBA, row-major from the top-left.
    private static func rgbaBytes(of image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }

    private static func makeImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
