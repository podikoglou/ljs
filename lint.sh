#!/bin/bash
set -e

echo "Linting with lua-language-server..."
lua-language-server --check . 2>&1
echo "Lint passed!"
