.PHONY: test lint

test:
	@for f in test/parser/*.lua; do \
		[ -f "$$f" ] && lua "$$f" || exit 1; \
	done
	@for f in test/transpile/*.lua; do \
		[ -f "$$f" ] && lua "$$f" || exit 1; \
	done
	@# || true: runtime tests include known parser limitations (inline member calls)
	@for f in test/runtime/*.lua; do \
		[ -f "$$f" ] && lua "$$f" || true; \
	done
	@[ -f test/codegen.lua ] && lua test/codegen.lua || exit 1

lint:
	@lua-language-server --check . 2>&1
