#!/bin/bash

# Script to add a new template version for testing
# Usage: ./add_template.sh <template-name> <version>
# Example: ./add_template.sh property-brochure 3

set -e  # Exit on any error

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <template-name> <version>"
    echo "Example: $0 property-brochure 3"
    echo ""
    echo "Available templates:"
    find src/templates -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "  (none found - check if you're in the right directory)"
    exit 1
fi

TEMPLATE_NAME=$1
VERSION_NUMBER=$2
VERSION="v${VERSION_NUMBER}"

echo "=== Adding Template Version ==="
echo "Template: $TEMPLATE_NAME"
echo "Version: $VERSION"
echo ""

# Check if we're in the right directory
if [ ! -d "src/templates" ]; then
    echo "Error: src/templates directory not found!"
    echo "Please run this script from the templates-test-repo directory"
    exit 1
fi

# Create template directory if it doesn't exist
TEMPLATE_DIR="src/templates/${TEMPLATE_NAME}"
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Creating new template directory: $TEMPLATE_DIR"
    mkdir -p "$TEMPLATE_DIR"
fi

# Create the new template file
TEMPLATE_FILE="${TEMPLATE_DIR}/${VERSION}.tsx"
FIXTURES_FILE="${TEMPLATE_DIR}/${VERSION}.fixtures.json"

echo "Creating template file: $TEMPLATE_FILE"
echo "${TEMPLATE_NAME^} Template $VERSION - $(date)" > "$TEMPLATE_FILE"

echo "Creating fixtures file: $FIXTURES_FILE"
cat > "$FIXTURES_FILE" << EOF
{
  "templateName": "$TEMPLATE_NAME",
  "version": "$VERSION",
  "testData": "Generated on $(date)",
  "sampleValue": "test-$VERSION_NUMBER"
}
EOF

# Show what was created
echo ""
echo "=== Files Created ==="
echo "Template: $(cat $TEMPLATE_FILE)"
echo "Fixtures: $(cat $FIXTURES_FILE)"

# Git operations
echo ""
echo "=== Git Operations ==="
echo "Adding files to git..."
git add .

echo "Committing changes..."
COMMIT_MSG="Add ${TEMPLATE_NAME} ${VERSION}"
git commit -m "$COMMIT_MSG"

echo "Pushing to origin main..."
git push origin main

echo ""
echo "✅ Success! Added $TEMPLATE_NAME:$VERSION"
echo ""
echo "Now you can:"
echo "1. Run the Jenkins job to test template detection"
echo "2. Check your document-service logs for the API call"
echo ""
echo "Git commit message: $COMMIT_MSG"
