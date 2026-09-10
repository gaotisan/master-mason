#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/_builds/web"
EXPORT_NAME="Web"

echo "🚀 Deploy Web Godot"
echo "📁 Proyecto: $PROJECT_DIR"
echo

# Comprobaciones básicas
command -v godot4 >/dev/null 2>&1 || { echo "❌ godot4 no está disponible"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud no está disponible"; exit 1; }

[ -f "$PROJECT_DIR/project.godot" ] || { echo "❌ No es un proyecto Godot válido"; exit 1; }
[ -f "$PROJECT_DIR/export_presets.cfg" ] || { echo "❌ Falta export_presets.cfg"; exit 1; }

echo "🧹 Limpiando build anterior..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🎮 Exportando proyecto (Web)..."
godot4 --headless \
  --path "$PROJECT_DIR" \
  --export-release "$EXPORT_NAME" \
  "$BUILD_DIR/index.html"

echo "☁️ Lanzando Cloud Build (solo _builds/web)..."
gcloud builds submit "$BUILD_DIR" \
  --config="$PROJECT_DIR/cloudbuild.yaml"

echo
echo "✅ Deploy lanzado correctamente"
echo "🌍 https://storage.googleapis.com/godot-builds/hello_test/index.html"
echo
