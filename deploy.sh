#!/bin/bash

# Set the build directory
BUILD_DIR="./build"

echo "Building GoogleDriveSync..."

# Build using xcodebuild
# -scheme: The scheme to build (GoogleDriveSync)
# -configuration: Release (for optimized build)
# -derivedDataPath: Custom build location so we know where the app ends up

# --- Rclone Setup ---
ARCH=$(uname -m)
if [ "$ARCH" == "arm64" ]; then
    RCLONE_ARCH="osx-arm64"
else
    RCLONE_ARCH="osx-amd64"
fi

if [ ! -f "rclone-bin" ]; then
    echo "Downloading rclone for $RCLONE_ARCH..."
    curl -L -o rclone.zip "https://downloads.rclone.org/rclone-current-$RCLONE_ARCH.zip"
    unzip -q -o rclone.zip
    # Find the binary in the extracted folder (folder name contains version)
    find rclone-v*-${RCLONE_ARCH} -name "rclone" -type f -exec mv {} ./rclone-bin \;
    # Cleanup
    rm -rf rclone.zip rclone-v*-${RCLONE_ARCH}
    chmod +x rclone-bin
    echo "rclone binary prepared."
fi

# --- Build ---

xcodebuild -scheme GoogleDriveSync -configuration Release -derivedDataPath "$BUILD_DIR" build

# --- Bundle ---
APP_PATH="$BUILD_DIR/Build/Products/Release/GoogleDriveSync.app"
if [ -d "$APP_PATH" ]; then
    echo "Bundling rclone..."
    mkdir -p "$APP_PATH/Contents/Resources"
    cp rclone-bin "$APP_PATH/Contents/Resources/rclone"
fi


# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build successful."
    
    # Define the app path
    APP_PATH="$BUILD_DIR/Build/Products/Release/GoogleDriveSync.app"
    
    if [ -d "$APP_PATH" ]; then
        echo "Quitting existing instance..."
        # Kill the app if it's running. '|| true' suppresses error if not running.
        pkill -x "GoogleDriveSync" || true
        # Wait a moment for it to close fully
        sleep 1
        
        echo "Launching $APP_PATH..."
        open "$APP_PATH"
    else
        echo "Error: App not found at $APP_PATH"
        exit 1
    fi
else
    echo "Build failed."
    exit 1
fi
