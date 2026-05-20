.PHONY: test lint

test:
	@echo "Running test suites..."
	@echo
	@for f in test/parser/*.lua; do \
		[ -f "$$f" ] && lua "$$f" || exit 1; \
	done
	@for f in test/transpile/*.lua; do \
		[ -f "$$f" ] && lua "$$f" || exit 1; \
	done
	@[ -f test/codegen.lua ] && lua test/codegen.lua || exit 1
	@echo "All tests passed!"

lint:
	@echo "Linting with lua-language-server..."
	@lua-language-server --check . 2>&1
	@echo "Lint passed!"
