#!/usr/bin/env bash
# Downloads the large real-world specs used by the tests into test/specs/.
# They are pinned to fixed commits and kept out of git and the package.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p test/specs
curl -sSfL -o test/specs/kubernetes.json \
  https://raw.githubusercontent.com/kubernetes/kubernetes/f091073b0fb4d3a550e7f182eb5465338c8b7cbf/api/openapi-spec/swagger.json
curl -sSfL -o test/specs/stripe.json \
  https://raw.githubusercontent.com/stripe/openapi/33a4d4d78b0844356a332c30645ec6807d0c2e3d/openapi/spec3.json
