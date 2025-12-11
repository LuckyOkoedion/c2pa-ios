#!/bin/bash
set -e

echo "C2PAC Framework Builder"
echo "======================="

# Environments
GITHUB_ORG="${GITHUB_ORG:-LuckyOkoedion}" # Default to user fork
C2PA_VERSION="${C2PA_VERSION:-v0.33.8-fix}"           # The Release TAG on GitHub
ARTIFACT_VERSION="${ARTIFACT_VERSION:-0.73.0}"        # The Rust Crate Version (filename)
PROJECT_ROOT="${SRCROOT}"
SUBMODULE_DIR="${PROJECT_ROOT}/../c2pa-rs"
FRAMEWORK_DIR="${TARGET_BUILD_DIR}/${PRODUCT_NAME}.framework"
DOWNLOAD_DIR="${TEMP_DIR}/C2PAC-Downloads"

mkdir -p "${DOWNLOAD_DIR}"
mkdir -p "${FRAMEWORK_DIR}"

# 1. Check if we should build from source (Release Workflow Preferred by User)
# Set BUILD_FROM_SOURCE=true to force local compilation
if [ "${BUILD_FROM_SOURCE}" = "true" ] && [ -d "${SUBMODULE_DIR}/c2pa_c_ffi" ]; then
    echo "• Found c2pa-rs submodule. Building from source..."
    
    cd "${SUBMODULE_DIR}/c2pa_c_ffi"
    
    # Define output lib name
    LIB_NAME="libc2pa_c.a"
    
    if [ "${PLATFORM_NAME}" = "iphoneos" ]; then
        echo "  Building for Device (arm64)..."
        make release-ios-arm64
        SRC_LIB="${SUBMODULE_DIR}/target/aarch64-apple-ios/release/${LIB_NAME}"
        cp "${SRC_LIB}" "${FRAMEWORK_DIR}/C2PAC"
        
    elif [ "${PLATFORM_NAME}" = "iphonesimulator" ]; then
        echo "  Building for Simulator (arm64 + x86_64)..."
        make release-ios-arm64-sim
        make release-ios-x86_64
        
        LIB_ARM="${SUBMODULE_DIR}/target/aarch64-apple-ios-sim/release/${LIB_NAME}"
        LIB_X86="${SUBMODULE_DIR}/target/x86_64-apple-ios/release/${LIB_NAME}"
        
        echo "  Lipo-ing simulator binaries..."
        lipo -create "${LIB_ARM}" "${LIB_X86}" -output "${FRAMEWORK_DIR}/C2PAC"
    fi
    
    # Copy Headers
    echo "  Copying headers..."
    mkdir -p "${FRAMEWORK_DIR}/Headers"
    if [ -f "c2pa.h" ]; then
        CP_HEADER="c2pa.h"
    else
        CP_HEADER="include/c2pa.h"
    fi
    sed 's/typedef struct C2paSigner C2paSigner;/typedef struct C2paSigner { } C2paSigner;/g' \
        "${CP_HEADER}" > "${FRAMEWORK_DIR}/Headers/c2pa.h"

    echo "✓ Built from source."

else
    # 2. Fallback to Download
    echo "• Downloading from GitHub (${GITHUB_ORG})..."
    
    # Determine which library to download based on platform
    if [ "${PLATFORM_NAME}" = "iphoneos" ]; then
        ARCH_SUFFIX="aarch64-apple-ios"
    elif [ "${PLATFORM_NAME}" = "iphonesimulator" ]; then
        NEEDS_LIPO=true
    else
        echo "Unsupported platform: ${PLATFORM_NAME}"
        exit 1
    fi

    # Download function
    download_and_extract() {
        local suffix="$1"
        local output_dir="$2"
        
        # URL Logic:
        # Tag: ${C2PA_VERSION} (e.g. v0.33.8-fix)
        # Filename: c2pa-v${ARTIFACT_VERSION}-${suffix}.zip (e.g. c2pa-v0.73.0-aarch64-apple-ios.zip)
        
        local url="https://github.com/${GITHUB_ORG}/c2pa-rs/releases/download/${C2PA_VERSION}/c2pa-v${ARTIFACT_VERSION}-${suffix}.zip"
        
        echo "  • Downloading from ${url}..."
        # Use -f to fail on HTTP errors (404), -L to follow redirects
        if ! curl -f -sL "${url}" -o "${DOWNLOAD_DIR}/${suffix}.zip"; then
             echo "❌ Error: Download failed (404 Not Found or Network Error)."
             exit 1
        fi
        
        mkdir -p "${DOWNLOAD_DIR}/${suffix}"
        if ! unzip -q -o "${DOWNLOAD_DIR}/${suffix}.zip" -d "${DOWNLOAD_DIR}/${suffix}"; then
             echo "❌ Error: Unzip failed. File might be corrupt."
             exit 1
        fi
        
        # Robustly find the library
        local lib_path
        lib_path=$(find "${DOWNLOAD_DIR}/${suffix}" -name "libc2pa_c.a" | head -n 1)
        
        if [ -z "${lib_path}" ]; then
            echo "❌ Error: libc2pa_c.a not found in downloaded zip."
            echo "   Contents of download:"
            ls -R "${DOWNLOAD_DIR}/${suffix}"
            exit 1
        fi
        
        echo "  • Found lib at: ${lib_path}"
        cp "${lib_path}" "${output_dir}/libc2pa_c.a"
        
        # Copy headers (find c2pa.h robustly)
        if [ ! -f "${FRAMEWORK_DIR}/Headers/c2pa.h" ]; then
            mkdir -p "${FRAMEWORK_DIR}/Headers"
            local header_path
            header_path=$(find "${DOWNLOAD_DIR}/${suffix}" -name "c2pa.h" | head -n 1)
            
            if [ -n "${header_path}" ]; then
                # Patch the header to fix Swift compatibility
                sed 's/typedef struct C2paSigner C2paSigner;/typedef struct C2paSigner { } C2paSigner;/g' \
                    "${header_path}" > "${FRAMEWORK_DIR}/Headers/c2pa.h"
            else
                echo "⚠️ Warning: c2pa.h not found in download."
            fi
        fi
    }

    if [ "${NEEDS_LIPO}" = "true" ]; then
        echo "Building universal simulator library..."
        mkdir -p "${DOWNLOAD_DIR}/x86_64"
        mkdir -p "${DOWNLOAD_DIR}/arm64-sim"
        
        download_and_extract "x86_64-apple-ios" "${DOWNLOAD_DIR}/x86_64"
        download_and_extract "aarch64-apple-ios-sim" "${DOWNLOAD_DIR}/arm64-sim"
        
        lipo -create \
            "${DOWNLOAD_DIR}/x86_64/libc2pa_c.a" \
            "${DOWNLOAD_DIR}/arm64-sim/libc2pa_c.a" \
            -output "${FRAMEWORK_DIR}/C2PAC"
    else
        mkdir -p "${DOWNLOAD_DIR}/device"
        download_and_extract "${ARCH_SUFFIX}" "${DOWNLOAD_DIR}/device"
        cp "${DOWNLOAD_DIR}/device/libc2pa_c.a" "${FRAMEWORK_DIR}/C2PAC"
    fi
fi

# Create module map
mkdir -p "${FRAMEWORK_DIR}/Modules"
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << EOF
framework module C2PAC {
    header "c2pa.h"
    export *
}
EOF

# Create Info.plist
cat > "${FRAMEWORK_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>org.contentauth.C2PAC</string>
    <key>CFBundleName</key>
    <string>C2PAC</string>
    <key>CFBundleExecutable</key>
    <string>C2PAC</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>MinimumOSVersion</key>
    <string>16.0</string>
</dict>
</plist>
EOF

# Create stamp file
touch "${FRAMEWORK_DIR}/.stamp"

echo "✓ C2PAC framework built successfully at ${FRAMEWORK_DIR}"
