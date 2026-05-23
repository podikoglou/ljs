.PHONY: test lint rock pack install uninstall

test:
	@LUA_PATH="src/?.lua;;" lua test/run.lua "$(VERBOSE)"

lint:
	@lua-language-server --check . 2>&1

rock:
	@luarocks make --local rockspec/ljs-0.1.0-1.rockspec

pack:
	@luarocks pack rockspec/ljs-0.1.0-1.rockspec

install: rock

uninstall:
	@luarocks remove ljs
