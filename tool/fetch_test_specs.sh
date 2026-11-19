#!/usr/bin/env bash
# Downloads the large real-world spec(s) used by the tests into test/specs/.
# They are pinned to fixed commits and kept out of git and the package.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p test/specs
curl -sSfL -o test/specs/stripe.json \
  https://raw.githubusercontent.com/stripe/openapi/33a4d4d78b0844356a332c30645ec6807d0c2e3d/openapi/spec3.json
