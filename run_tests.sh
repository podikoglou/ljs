#!/bin/bash
# Run all test files in sequence, fail fast if any test suite fails
set -e

echo "Running test suites..."
echo

# Run parser tests
for f in test/parser/*.lua; do
  if [ -f "$f" ]; then
    lua "$f" || exit 1
  fi
done

# Run transpile tests
for f in test/transpile/*.lua; do
  if [ -f "$f" ]; then
    lua "$f" || exit 1
  fi
done

# Run codegen tests
if [ -f test/codegen.lua ]; then
  lua test/codegen.lua || exit 1
fi

echo "All tests passed!"
