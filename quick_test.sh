#!/bin/bash

# Quick script to add property-brochure versions for testing
# Usage: ./quick_test.sh <version_number>
# Example: ./quick_test.sh 2

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <version_number>"
    echo "Example: $0 2  (creates property-brochure v2)"
    exit 1
fi

VERSION_NUMBER=$1

echo "=== Quick Test: Adding property-brochure v${VERSION_NUMBER} ==="

# Use the main script
./add_template.sh property-brochure $VERSION_NUMBER
