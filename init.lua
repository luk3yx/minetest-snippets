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
local enable_buttons = minetest.settings:get_bool('snippets.enable_buttons')
if enable_buttons or enable_buttons == nil then
    dofile(modpath .. '/nodes.lua')
end

minetest.register_on_mods_loaded(function()
    for name, def in pairs(snippets.registered_snippets) do
        if def.autorun then
            snippets.run(name)
        end
    end
end)
