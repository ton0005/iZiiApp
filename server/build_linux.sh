#!/bin/bash
# ==============================================================================
# Build script: iZiiServer standalone executable for Ubuntu / Linux x64
# ==============================================================================
set -e

echo "🚀 [1/4] Checking Python environment..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please run:"
    echo "   sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
    exit 1
fi

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "ℹ️  Detected Python version: $PY_VER"

echo "📦 [2/4] Setting up Virtualenv & Dependencies..."
if [ ! -f "venv/bin/activate" ]; then
    rm -rf venv
    echo "Creating virtual environment in ./venv..."
    if ! python3 -m venv venv; then
        echo ""
        echo "❌ Failed to create virtual environment."
        echo "👉 On Ubuntu/Debian, please run this command to install the required venv package:"
        echo "   sudo apt update && sudo apt install -y python3-venv python3-pip python3-dev python${PY_VER}-venv"
        echo "   Then re-run: ./build_linux.sh"
        exit 1
    fi
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install pyinstaller

echo "🔨 [3/4] Running PyInstaller build (izii_server.spec)..."
pyinstaller --noconfirm izii_server.spec

echo "📂 [4/4] Finalizing build package..."
if [ -f ".env" ]; then
    cp .env dist/izii_server/.env
else
    cp .env.example dist/izii_server/.env
fi

mkdir -p dist/izii_server/data/logs dist/izii_server/data/attachments

echo "✅ Build completed successfully!"
echo "📍 Output location: $(pwd)/dist/izii_server/izii_server"
echo "👉 To run: cd dist/izii_server && ./izii_server"
