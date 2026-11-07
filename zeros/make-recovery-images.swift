// ZeroS recovery images (bug B16): the logo animation shown while recovery
// installs an update (loop00000-loop00029.png) and the recovery menu logo
// (logo_image.png, logo_image_switch.png), for res-mdpi .. res-xxxhdpi.
// Same mark and palette as the boot animation (vendor/zeros/bootanimation):
// white ring, red dot orbiting once over the 30 frames, on black.
//
//   swift zeros/make-recovery-images.swift <Roboto TTF> <recovery checkout>
//
// SPDX-License-Identifier: Apache-2.0

import AppKit
import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-recovery-images.swift <Roboto TTF> <recovery checkout>\n".data(using: .utf8)!)
    exit(2)
}
let fontURL = URL(fileURLWithPath: args[1]) as CFURL
let root = args[2]
CTFontManagerRegisterFontsForURL(fontURL, .process, nil)

let white = CGColor(red: 0xF2 / 255.0, green: 0xF2 / 255.0, blue: 0xF0 / 255.0, alpha: 1)
let red = CGColor(red: 0xE5 / 255.0, green: 0x32 / 255.0, blue: 0x2D / 255.0, alpha: 1)
let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

// Square loop frame side and logo width per density (LineageOS's sizes)
let densities: [(String, Int, Int)] = [
    ("res-mdpi", 200, 256), ("res-hdpi", 300, 384), ("res-xhdpi", 400, 512),
    ("res-xxhdpi", 600, 768), ("res-xxxhdpi", 800, 1024),
]
let frames = 30

func context(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(black)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx
}

// Ring with the dot at angle (radians, 0 = left, clockwise on screen)
func drawMark(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, radius: CGFloat, angle: CGFloat) {
    ctx.setStrokeColor(white)
    ctx.setLineWidth(radius * 0.11)
    ctx.strokeEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
    let dot = radius * 0.16
    // Core Graphics' y axis points up: clockwise on screen is a decreasing angle
    let x = cx - radius * cos(angle)
    let y = cy + radius * sin(angle)
    ctx.setFillColor(red)
    ctx.fillEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
}

func save(_ ctx: CGContext, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for (folder, side, logoW) in densities {
    let dir = "\(root)/\(folder)/images"
    let s = CGFloat(side)
    for i in 0..<frames {
        let ctx = context(side, side)
        let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(frames)
        drawMark(ctx, cx: s / 2, cy: s / 2, radius: s * 0.30, angle: angle)
        save(ctx, String(format: "%@/loop%05d.png", dir, i))
    }

    // Menu logo: mark above "RECOVERY" in red, letter-spaced like LineageOS's
    let w = CGFloat(logoW), h = CGFloat(logoW) * 0.625
    let ctx = context(logoW, Int(h))
    drawMark(ctx, cx: w / 2, cy: h * 0.60, radius: h * 0.17, angle: 0)
    let font = CTFontCreateWithName("Roboto" as CFString, h * 0.085, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): red,
        NSAttributedString.Key(kCTKernAttributeName as String): h * 0.03,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "RECOVERY", attributes: attrs))
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: (w - bounds.width) / 2 - bounds.minX, y: h * 0.16)
    CTLineDraw(line, ctx)
    save(ctx, "\(dir)/logo_image.png")
    save(ctx, "\(dir)/logo_image_switch.png")
}
print("wrote \(densities.count * (frames + 2)) images")
