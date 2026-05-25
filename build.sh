#!/bin/bash
# Compila Biblion.app — app SwiftUI nativa macOS.
# Usa solo Command Line Tools (non serve Xcode IDE).

set -e
cd "$(dirname "$0")"

APP_NAME="Biblion"
BUNDLE_ID="com.biblion.app"
APP_DIR="build/${APP_NAME}.app"
TARGET="arm64-apple-macos14"

echo "===================================================="
echo "  Compilo ${APP_NAME}.app"
echo "===================================================="

# 1. Pulizia
rm -rf "${APP_DIR}"

# 2. Struttura bundle
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# 3. Genera icona se manca
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "→ Genero icona…"
    swift Resources/gen_icon.swift Resources/AppIcon.iconset
    iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
fi

# 4. Compila Swift
echo "→ Compilo sorgenti Swift…"
SOURCES=$(find Sources -name "*.swift")
swiftc \
    -target "${TARGET}" \
    -parse-as-library \
    -O \
    -framework SwiftUI \
    -framework SwiftData \
    -framework AppKit \
    -framework AVFoundation \
    -o "${APP_DIR}/Contents/MacOS/${APP_NAME}" \
    ${SOURCES}

# 5. Copia risorse
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"

# 6. PkgInfo (alcuni tool macOS lo cercano)
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# 7. Firma ad-hoc (necessaria per accesso fotocamera su macOS 15+)
echo "→ Firma ad-hoc…"
codesign --force --deep --sign - \
    --entitlements Resources/Biblion.entitlements \
    --options runtime \
    "${APP_DIR}" 2>&1 | grep -v "replacing existing signature" || true

# 8. Verifica
echo ""
echo "→ Verifica firma:"
codesign -dvv "${APP_DIR}" 2>&1 | head -10

echo ""
echo "✅ Compilazione completata."
echo ""

# 9. Copia nella cartella del progetto e in /Applications
DEST="$(dirname "$0")/${APP_NAME}.app"
rm -rf "${DEST}"
cp -r "${APP_DIR}" "${DEST}"

rm -rf "/Applications/${APP_NAME}.app"
cp -r "${APP_DIR}" "/Applications/${APP_NAME}.app"

echo "   Bundle aggiornato: ${DEST}"
echo "   Installato in:     /Applications/${APP_NAME}.app"
echo "   Dimensione: $(du -sh "${DEST}" | cut -f1)"
echo ""
echo "   Per lanciare:    open /Applications/${APP_NAME}.app"
