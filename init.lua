--
-- Minetest snippets mod: Allows admins to run a bunch of predefined snippets
--

assert(minetest.get_current_modname() == 'snippets')
snippets = {}

local modpath = minetest.get_modpath('snippets')

-- Load the core sandbox
dofile(modpath .. '/core.lua')

-- Load persistence
loadfile(modpath .. '/persistence.lua')(minetest.get_mod_storage())

-- Load the Form object
dofile(modpath .. '/forms.lua')

-- Load the "console"
dofile(modpath .. '/console.lua')

-- Load "snippet buttons"
dofile(modpath .. '/nodes.lua')
