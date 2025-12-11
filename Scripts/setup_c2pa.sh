#!/bin/bash
set -e

echo "C2PAC Framework Builder"
echo "======================="

# Environments
# Environments
GITHUB_ORG="${GITHUB_ORG:-LuckyOkoedion}" # Default to user fork
C2PA_VERSION="${C2PA_VERSION:-v0.33.8-fix}"           # The Release TAG on GitHub
ARTIFACT_VERSION="${ARTIFACT_VERSION:-0.73.0}"        # The Rust Crate Version (filename)

# ...

    # Download function
    download_and_extract() {
        local suffix="$1"
        local output_dir="$2"
        
        # URL Logic:
        # Tag: ${C2PA_VERSION} (e.g. v0.33.8-fix)
        # Filename: c2pa-v${ARTIFACT_VERSION}-${suffix}.zip (e.g. c2pa-v0.73.0-aarch64-apple-ios.zip)
        
        local url="https://github.com/${GITHUB_ORG}/c2pa-rs/releases/download/${C2PA_VERSION}/c2pa-v${ARTIFACT_VERSION}-${suffix}.zip"
        
        echo "  • Downloading ${suffix} from ${url}..."
        curl -sL "${url}" -o "${DOWNLOAD_DIR}/${suffix}.zip"
        
        if [ ! -f "${DOWNLOAD_DIR}/${suffix}.zip" ] || [ ! -s "${DOWNLOAD_DIR}/${suffix}.zip" ]; then
             echo "❌ Error: Download failed or file empty."
             exit 1
        fi
        
        mkdir -p "${DOWNLOAD_DIR}/${suffix}"
        unzip -q -o "${DOWNLOAD_DIR}/${suffix}.zip" -d "${DOWNLOAD_DIR}/${suffix}"
        
        cp "${DOWNLOAD_DIR}/${suffix}/lib/libc2pa_c.a" "${output_dir}/libc2pa_c.a"
        
        # Copy and patch header
        if [ ! -f "${FRAMEWORK_DIR}/Headers/c2pa.h" ]; then
            mkdir -p "${FRAMEWORK_DIR}/Headers"
            # Patch the header to fix Swift compatibility
            sed 's/typedef struct C2paSigner C2paSigner;/typedef struct C2paSigner { } C2paSigner;/g' \
                "${DOWNLOAD_DIR}/${suffix}/include/c2pa.h" > "${FRAMEWORK_DIR}/Headers/c2pa.h"
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
