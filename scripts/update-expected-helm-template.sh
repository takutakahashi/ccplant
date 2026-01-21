#!/bin/bash
set -euo pipefail

# Script to update the expected Helm template output for testing
# Usage: ./scripts/update-expected-helm-template.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${REPO_ROOT}/charts/ccplant"
EXPECTED_FILE="${REPO_ROOT}/testdata/expected.yaml"

echo "📦 Updating Helm dependencies..."
cd "${CHART_DIR}"
helm dependency update

echo "🔨 Generating Helm template output..."
helm template ccplant . --namespace default > "${EXPECTED_FILE}"

echo "✅ Successfully updated ${EXPECTED_FILE}"
echo ""
echo "Generated output:"
wc -l "${EXPECTED_FILE}"
echo ""
echo "To commit this change:"
echo "  git add testdata/expected.yaml"
echo "  git commit -m 'Update expected Helm template output'"
