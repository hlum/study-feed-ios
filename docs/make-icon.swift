import AppKit
import ImageIO
import UniformTypeIdentifiers

// 1024x1024 icons written without an alpha channel (the App Store rejects icons that have one).
func render(background: NSColor, letter: NSColor, name: String) {
    let size = 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    background.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    var font = NSFont.systemFont(ofSize: 760, weight: .heavy)
    if let rounded = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: rounded, size: 760) { font = f }
    let text = NSAttributedString(string: "S", attributes: [.font: font, .foregroundColor: letter, .kern: -8])
    let bounds = text.boundingRect(with: NSSize(width: size, height: size), options: [.usesLineFragmentOrigin])
    text.draw(at: NSPoint(x: (CGFloat(size) - bounds.width) / 2, y: (CGFloat(size) - bounds.height) / 2 - 10))
    NSGraphicsContext.restoreGraphicsState()
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

let dark = NSColor(srgbRed: 0x0C / 255, green: 0x0C / 255, blue: 0x0E / 255, alpha: 1)
let peach = NSColor(srgbRed: 0xF5 / 255, green: 0xC9 / 255, blue: 0x9B / 255, alpha: 1)
render(background: dark, letter: peach, name: "AppIcon.png")
render(background: dark, letter: peach, name: "AppIcon-Dark.png")
render(background: .black, letter: .white, name: "AppIcon-Tinted.png")
