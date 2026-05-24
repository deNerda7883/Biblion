#!/usr/bin/env python3
"""Genera un'icona PNG 1024x1024 in stile macOS per l'app Libreria.
Usa solo le framework Quartz/AppKit incluse in macOS (PyObjC).
"""
import sys
from pathlib import Path

try:
    from AppKit import (
        NSImage, NSBitmapImageRep, NSPNGFileType, NSColor, NSBezierPath,
        NSGraphicsContext, NSAffineTransform, NSFont, NSFontAttributeName,
        NSForegroundColorAttributeName, NSAttributedString, NSMakeRect,
        NSCompositingOperationSourceOver, NSShadow, NSMakeSize,
    )
    from Cocoa import NSSize
except ImportError:
    print("Errore: PyObjC non disponibile. Su macOS è incluso di default in /usr/bin/python3.")
    sys.exit(1)


def crea_icona(size: int, output: Path):
    image = NSImage.alloc().initWithSize_(NSSize(size, size))
    image.lockFocus()

    ctx = NSGraphicsContext.currentContext()
    ctx.setShouldAntialias_(True)
    ctx.setImageInterpolation_(3)  # high

    # ----- Sfondo arrotondato (squircle-ish) -----
    radius = size * 0.225
    rect = NSMakeRect(0, 0, size, size)
    path = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(rect, radius, radius)

    # gradient simulato a 3 layer
    NSColor.colorWithSRGBRed_green_blue_alpha_(0.345, 0.118, 0.090, 1.0).setFill()
    path.fill()

    inset = size * 0.02
    inner = NSMakeRect(inset, inset, size - 2*inset, size - 2*inset)
    NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(inner, radius*0.95, radius*0.95).addClip()
    NSColor.colorWithSRGBRed_green_blue_alpha_(0.545, 0.227, 0.180, 1.0).setFill()
    path.fill()

    # ----- Libri in pila -----
    centro_x = size * 0.50
    centro_y = size * 0.42
    larghezza_libro = size * 0.13
    altezza_libro = size * 0.36
    gap = size * 0.018

    libri = [
        # (offset_x, color_r, color_g, color_b, altezza_extra)
        (-2.2 * (larghezza_libro + gap), 0.96, 0.92, 0.85, 0.0),   # crema
        (-1.1 * (larghezza_libro + gap), 0.79, 0.27, 0.22, 0.04),  # rosso
        ( 0.0,                            0.96, 0.92, 0.85, 0.08),  # crema (alto)
        ( 1.1 * (larghezza_libro + gap), 0.20, 0.40, 0.55, 0.02),   # blu
        ( 2.2 * (larghezza_libro + gap), 0.85, 0.70, 0.40, 0.0),    # ocra
    ]
    base_y = centro_y - altezza_libro / 2
    for offset_x, r, g, b, extra in libri:
        x = centro_x - larghezza_libro / 2 + offset_x
        h = altezza_libro * (1.0 + extra)
        libro_rect = NSMakeRect(x, base_y, larghezza_libro, h)
        radius_libro = size * 0.012
        bp = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(libro_rect, radius_libro, radius_libro)
        NSColor.colorWithSRGBRed_green_blue_alpha_(r, g, b, 1.0).setFill()
        bp.fill()

        # banda decorativa nella parte alta
        banda_alta = NSMakeRect(x, base_y + h * 0.78, larghezza_libro, h * 0.04)
        bp_banda = NSBezierPath.bezierPathWithRect_(banda_alta)
        NSColor.colorWithSRGBRed_green_blue_alpha_(0, 0, 0, 0.15).setFill()
        bp_banda.fill()

        # banda in basso
        banda_bassa = NSMakeRect(x, base_y + h * 0.10, larghezza_libro, h * 0.025)
        bp_banda2 = NSBezierPath.bezierPathWithRect_(banda_bassa)
        NSColor.colorWithSRGBRed_green_blue_alpha_(0, 0, 0, 0.12).setFill()
        bp_banda2.fill()

    image.unlockFocus()

    # Estrai PNG
    tiff = image.TIFFRepresentation()
    rep = NSBitmapImageRep.imageRepWithData_(tiff)
    png_data = rep.representationUsingType_properties_(NSPNGFileType, {})
    png_data.writeToFile_atomically_(str(output), True)
    print(f"  → {output} ({size}×{size})")


if __name__ == "__main__":
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    out_dir.mkdir(parents=True, exist_ok=True)

    print("Genero icone:")
    sizes = [
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
    for name, sz in sizes:
        crea_icona(sz, out_dir / name)
    print("Fatto.")
