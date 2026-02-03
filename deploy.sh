#!/bin/bash

# Set the build directory
BUILD_DIR="./build"

echo "Building GoogleDriveSync..."

# Build using xcodebuild
# -scheme: The scheme to build (GoogleDriveSync)
# -configuration: Release (for optimized build)
# -derivedDataPath: Custom build location so we know where the app ends up
xcodebuild -scheme GoogleDriveSync -configuration Release -derivedDataPath "$BUILD_DIR" build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build successful."
    
    # Define the app path
    APP_PATH="$BUILD_DIR/Build/Products/Release/GoogleDriveSync.app"
    
    if [ -d "$APP_PATH" ]; then
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
