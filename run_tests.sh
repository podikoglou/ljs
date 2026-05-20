#!/bin/bash
# Run all test files in sequence, fail fast if any test suite fails
set -e

echo "Running test suites..."
echo

for f in test_ljs_parser_*.lua test_ljs_transpile_*.lua test_ljs_codegen.lua; do
  if [ -f "$f" ]; then
    lua "$f" || exit 1
  fi
done

echo "All tests passed!"
