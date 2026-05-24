// Genera l'iconset per l'app Libreria, usando solo AppKit.
// Uso: swift gen_icon.swift <cartella_output>

import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let outputURL = URL(fileURLWithPath: outputDir)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func crea(size: Int, to file: URL) {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // -- sfondo squircle --
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.225
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(srgbRed: 0.545, green: 0.227, blue: 0.180, alpha: 1.0).setFill()
    bg.fill()

    // bordo interno leggermente più chiaro (effetto profondità)
    let inset = s * 0.015
    let innerRect = rect.insetBy(dx: inset, dy: inset)
    let inner = NSBezierPath(roundedRect: innerRect, xRadius: radius * 0.95, yRadius: radius * 0.95)
    NSColor(srgbRed: 0.62, green: 0.27, blue: 0.21, alpha: 1.0).setFill()
    inner.fill()

    // ombra molto leggera sotto i libri
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.015,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)

    // -- libri in pila --
    let centroX = s * 0.50
    let centroY = s * 0.42
    let larghezzaLibro = s * 0.13
    let altezzaLibro = s * 0.36
    let gap = s * 0.018

    struct Libro { var off: CGFloat; var r: CGFloat; var g: CGFloat; var b: CGFloat; var extra: CGFloat }
    let libri: [Libro] = [
        Libro(off: -2.2 * (larghezzaLibro + gap), r: 0.96, g: 0.92, b: 0.85, extra: 0.0),
        Libro(off: -1.1 * (larghezzaLibro + gap), r: 0.79, g: 0.27, b: 0.22, extra: 0.04),
        Libro(off:  0.0,                          r: 0.96, g: 0.92, b: 0.85, extra: 0.10),
        Libro(off:  1.1 * (larghezzaLibro + gap), r: 0.20, g: 0.40, b: 0.55, extra: 0.02),
        Libro(off:  2.2 * (larghezzaLibro + gap), r: 0.85, g: 0.70, b: 0.40, extra: 0.0),
    ]

    let baseY = centroY - altezzaLibro / 2
    let rLibro = s * 0.012

    for lib in libri {
        let x = centroX - larghezzaLibro / 2 + lib.off
        let h = altezzaLibro * (1.0 + lib.extra)
        let r = NSRect(x: x, y: baseY, width: larghezzaLibro, height: h)
        let bp = NSBezierPath(roundedRect: r, xRadius: rLibro, yRadius: rLibro)
        NSColor(srgbRed: lib.r, green: lib.g, blue: lib.b, alpha: 1.0).setFill()
        bp.fill()

        // bande decorative
        let bandaAlta = NSRect(x: x, y: baseY + h * 0.80, width: larghezzaLibro, height: h * 0.04)
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(rect: bandaAlta).fill()

        let bandaBassa = NSRect(x: x, y: baseY + h * 0.10, width: larghezzaLibro, height: h * 0.025)
        NSColor.black.withAlphaComponent(0.12).setFill()
        NSBezierPath(rect: bandaBassa).fill()
    }

    ctx.restoreGState()

    image.unlockFocus()

    // estrai PNG
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: file)
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

print("Genero icone:")
for (name, sz) in sizes {
    let file = outputURL.appendingPathComponent(name)
    crea(size: sz, to: file)
    print("  → \(name) (\(sz)×\(sz))")
}
print("Fatto.")
