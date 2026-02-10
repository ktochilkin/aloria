#!/bin/bash

# Скрипт для локальной сборки с оптимизациями для iOS Safari

echo "🚀 Building optimized web version for iOS Safari..."

# Проверка Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "📦 Getting packages..."
flutter pub get

echo "🔨 Building web (Flutter auto-selects optimal renderer)..."
flutter build web --release

echo "✅ Build complete!"
echo "📂 Output: build/web/"
echo ""
echo "💡 Tips:"
echo "  - Test on actual iOS device for best results"
echo "  - Use Safari Web Inspector for debugging"
echo "  - Check WEB_OPTIMIZATION.md for more details"
