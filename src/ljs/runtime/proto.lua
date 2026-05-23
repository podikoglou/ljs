-- Forward declarations of the root prototype tables. These are populated later
-- by the runtime stdlib files (object.lua, function.lua). Declared first so that
-- all helpers (which run between proto and stdlib in the preamble) can reference them.
local _ljs_object_prototype = {}

local _ljs_function_prototype = {}
