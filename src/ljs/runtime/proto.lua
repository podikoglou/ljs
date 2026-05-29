-- Forward declarations of the root prototype tables. These are populated later
-- by the runtime stdlib files (object.lua, function.lua, number.lua, etc.).
-- Declared first so that all helpers (which run between proto and stdlib in the
-- preamble) can reference them.
local Array

local _ljs_object_prototype = {}

local _ljs_function_prototype = {}

local _ljs_number_prototype = {}

local _ljs_string_prototype = {}
local _ljs_string_box_index

local _ljs_boolean_prototype = {}
