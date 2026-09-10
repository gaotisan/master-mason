#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/_builds/pc"
EXPORT_NAME="Windows Desktop"
EXE_NAME="hello_test.exe"

echo "🪟 Deploy PC (Windows) Godot"
echo "📁 Proyecto: $PROJECT_DIR"
echo

# Comprobaciones básicas
command -v godot4 >/dev/null 2>&1 || { echo "❌ godot4 no está disponible"; exit 1; }

[ -f "$PROJECT_DIR/project.godot" ] || { echo "❌ No es un proyecto Godot válido"; exit 1; }
[ -f "$PROJECT_DIR/export_presets.cfg" ] || { echo "❌ Falta export_presets.cfg"; exit 1; }

echo "🧹 Limpiando build anterior..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🎮 Exportando proyecto (Windows Desktop)..."
godot4 --headless \
  --path "$PROJECT_DIR" \
  --export-release "$EXPORT_NAME" \
  "$BUILD_DIR/$EXE_NAME"

echo
echo "✅ Export PC completado correctamente"
echo "📦 Artefactos generados:"
ls -lh "$BUILD_DIR"

echo
echo "⬇️  Para probar en tu PC Windows:"
echo "   1. Descarga los archivos de $BUILD_DIR"
echo "   2. Mantén .exe y .pck en la misma carpeta"
echo "   3. Ejecuta $EXE_NAME"
echo
