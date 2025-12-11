#!/bin/bash
set -e

# Config
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/output"
FRAMEWORK_ZIP="${OUTPUT_DIR}/C2PAC.xcframework.zip"

# 1. Check Pre-requisites
if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' CLI is not installed."
    exit 1
fi
if ! gh auth status &> /dev/null; then
    echo "❌ Error: You are not logged in to GitHub CLI."
    exit 1
fi

# Parse args
TAG_NAME="${1:-v0.33.8-fix}"
SKIP_BUILD=false
if [ "$2" == "--skip-build" ]; then
    SKIP_BUILD=true
fi
if echo "$*" | grep -q -- "--skip-build"; then SKIP_BUILD=true; fi 

# 2. Build Artifacts
if [ "$SKIP_BUILD" = "true" ]; then
    echo "⏩ --skip-build flag detected. Skipping XCFramework build..."
    if [ ! -f "${FRAMEWORK_ZIP}" ]; then
        echo "❌ Error: Framework zip not found at ${FRAMEWORK_ZIP}. Cannot skip build."
        exit 1
    fi
else
    echo "📦 Building iOS XCFramework..."
    # Clean old artifacts
    rm -rf Base/C2PAC.framework
    rm -rf "${OUTPUT_DIR}"

    # Run build (relies on setup_c2pa.sh)
    make ios-framework

    # Check result
    if [ ! -f "${FRAMEWORK_ZIP}" ]; then
        echo "❌ Error: Build failed, ${FRAMEWORK_ZIP} not found."
        exit 1
    fi
fi

# 3. Compute Checksum
echo "✅ Build Complete."
CHECKSUM=$(swift package compute-checksum "${FRAMEWORK_ZIP}")
echo "🔑 Checksum: ${CHECKSUM}"

# 4. Create Release & Upload
TAG_NAME="${1:-v0.33.8-fix}" # Default tag
REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
echo "🚀 Creating GitHub Release '${TAG_NAME}' on ${REPO_URL}..."

if gh release view "${TAG_NAME}" --repo "LuckyOkoedion/c2pa-ios" &> /dev/null; then
    echo "⚠️  Release '${TAG_NAME}' already exists. Uploading missing assets..."
else
    gh release create "${TAG_NAME}" \
        --repo "LuckyOkoedion/c2pa-ios" \
        --title "${TAG_NAME}" \
        --notes "Automated release of C2PAC.xcframework.\n\nchecksum: ${CHECKSUM}"
fi

echo "⬆️  Uploading artifacts..."
gh release upload "${TAG_NAME}" "${FRAMEWORK_ZIP}" \
    --repo "LuckyOkoedion/c2pa-ios" \
    --clobber

echo ""
echo "✅ Success! Release available at:"
echo "   ${REPO_URL}/releases/tag/${TAG_NAME}"
echo ""
echo "👉 ACTION REQUIRED: Update Package.swift with the new checksum:"
echo "   checksum: \"${CHECKSUM}\""
