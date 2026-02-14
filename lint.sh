#!/bin/bash
set -euo pipefail

if ! command -v swiftlint &> /dev/null; then
    echo "Error: swiftlint is not installed"
    echo "Install with: brew install swiftlint"
    exit 1
fi

case "${1:-lint}" in
    fix)
        echo "Auto-fixing lint violations..."
        swiftlint lint --fix --config .swiftlint.yml
        echo "Running lint to show remaining issues..."
        swiftlint lint --config .swiftlint.yml
        ;;
    lint|*)
        swiftlint lint --config .swiftlint.yml
        ;;
esac
