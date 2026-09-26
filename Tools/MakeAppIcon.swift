#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

/// Renders the app icon: a V-taper on the app's violet-to-teal gradient.
///
/// Run with `swift Tools/MakeAppIcon.swift`. Kept as a script rather than a
/// checked-in binary blob so the shape stays editable and reviewable — an icon
/// nobody can change is an icon that rots.
///
/// The V-taper represents the shoulder-to-waist ratio shown in the app.

let size = 1024.0

func makeIcon() -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Background: the same violet → teal field the app uses behind its glass.
    let violet = CGColor(red: 0.42, green: 0.29, blue: 0.78, alpha: 1)
    let teal = CGColor(red: 0.12, green: 0.72, blue: 0.72, alpha: 1)
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [violet, teal] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }

    // A bold V, not a filled torso.
    //
    // Two earlier attempts drew the body as a solid silhouette; at icon size
    // both read as a funnel, because a torso without head or arms is just a
    // trapezoid. The letter form is unambiguous, scales down cleanly, and still
    // names the V-taper ratio shown in the app.
    let centre = size / 2
    let top = size * 0.72
    let bottom = size * 0.235
    let outerHalf = size * 0.285
    let stroke = size * 0.135

    let v = CGMutablePath()
    // Outer edge, left arm down to the point and back up the right arm.
    v.move(to: CGPoint(x: centre - outerHalf, y: top))
    v.addLine(to: CGPoint(x: centre - outerHalf + stroke, y: top))
    v.addLine(to: CGPoint(x: centre, y: bottom + stroke * 0.85))
    v.addLine(to: CGPoint(x: centre + outerHalf - stroke, y: top))
    v.addLine(to: CGPoint(x: centre + outerHalf, y: top))
    v.addLine(to: CGPoint(x: centre, y: bottom))
    v.closeSubpath()

    let taper = v

    // A soft shadow lifts the shape off the gradient without an outline.
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.035,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28)
    )
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
    context.addPath(taper)
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)


    return context.makeImage()
}

guard let image = makeIcon() else {
    FileHandle.standardError.write(Data("Icon konnte nicht gerendert werden\n".utf8))
    exit(1)
}

let output = URL(fileURLWithPath: "Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG-Kodierung fehlgeschlagen\n".utf8))
    exit(1)
}
try data.write(to: output)
print("geschrieben: \(output.path) (\(data.count) Bytes)")
