#!/bin/bash

echo "Downloading Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter Doctor..."
flutter doctor

echo "Enabling Web..."
flutter config --enable-web

echo "Getting packages..."
flutter pub get

echo "Building Web..."
# Используем --release для оптимизации и --no-tree-shake-icons во избежание проблем с иконками в некоторых случаях
flutter build web --release --no-tree-shake-icons
