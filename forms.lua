--
-- Minetest snippets mod: A formspec API
--
-- This should probably be put in formspeclib.
--

local open_formspecs = {}

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    open_formspecs[name] = nil
end)

local get_player_by_name = minetest.global_exists('cloaking') and
    cloaking.get_player_by_name or minetest.get_player_by_name

-- Formspec objects
-- You can create one of these per player and handle input
local Form = {}
local forms = {}
setmetatable(forms, {__mode = 'k'})
local function get(form)
    if not forms[form] then
        error('snippets.Form method called on a non-Form!', 3)
    end
    return forms[form]
end

-- Get unique formnames
local used_ids = {}
setmetatable(used_ids, {__mode = 'v'})

local function get_next_formname(form)
    -- Iterate over it because of inconsistencies when getting the length of a
    --  list containing nil.
    local id = 1
    for _ in ipairs(used_ids) do id = id + 1 end

    -- ID should be equal to #used_ids + 1.
    used_ids[id] = form
    return 'snippets:form_' .. id
end

-- Override minetest.show_formspec
local show_formspec = minetest.show_formspec
function minetest.show_formspec(pname, ...)
    if pname then open_formspecs[pname] = nil end
    return show_formspec(pname, ...)
end

-- Show formspecs
local print = print
function Form:show()
    local data = get(self)
    if not get_player_by_name(data.victim) then return false end
    open_formspecs[data.victim] = self
    print('show_formspec', data.victim, data.formname,
        data.prepend .. data.formspec .. data.append)
    show_formspec(data.victim, data.formname,
        data.prepend .. data.formspec .. data.append)
    return true
end
Form.open = Form.show

-- Close formspecs
function Form:close()
    local data = get(self)
    if open_formspecs[data.victim] == self then
        minetest.close_formspec(data.victim, data.name)
        open_formspecs[data.victim] = nil
    end
end
Form.hide = Form.close

-- Prepends etc
function Form:get_prepend()  return get(self).prepend  end
function Form:get_formspec() return get(self).formspec end
function Form:get_append()   return get(self).append   end

function Form:set_prepend(text)
    local data = get(self)
    data.prepend = tostring(text or '')
    if open_formspecs[data.victim] == self then self:show() end
end

function Form:set_formspec(text)
    local data = get(self)
    data.formspec = tostring(text or '')
    if open_formspecs[data.victim] == self then self:show() end
end

function Form:set_append(text)
    local data = get(self)
    data.append = tostring(text or '')
    if open_formspecs[data.victim] == self then self:show() end
end

-- Callbacks
function Form:add_callback(...)
    local data, argc = get(self), select('#', ...)
    local event, func
    if argc == 1 then
        event, func = '', ...
    elseif argc == 2 then
        event, func = ...
        if type(event) ~= 'string' then
            error('Invalid usage for snippets.Form:add_callback().', 2)
        end
    else
        error('snippets.Form:add_callback() takes one or two arguments.', 2)
    end

    if not data.callbacks[event] then data.callbacks[event] = {} end
    table.insert(data.callbacks[event], snippets.wrap_callback(func))
end

-- Create a Formspec object
function snippets.Form(player)
    if minetest.is_player(player) then player = player:get_player_name() end
    if type(player) ~= 'string' or not get_player_by_name(player) then
        error('Attempted to create a Form for a non-existent player!', 2)
    end
    local form = {context = {}}
    setmetatable(form, {__index = Form})
    forms[form] = {
        victim = player, prepend = '', formspec = '', append = '',
        callbacks = {}, formname = get_next_formname(form), pname = player,
    }
    return form
end

-- Callbacks
local function run_callbacks(callbacks, ...)
    if not callbacks then return end
    for _, func in ipairs(callbacks) do func(...) end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname:sub(1, 14) ~= 'snippets:form_' then return end
    local pname = player:get_player_name()
    local form = open_formspecs[pname]
    local data = forms[form]
    if not data or data.formname ~= formname then return end

    -- Nuke the formspec if required
    if fields.quit then open_formspecs[pname] = nil end

    -- Run generic callbacks
    run_callbacks(data.callbacks[''], form, fields)

    -- Run field-specific callbacks
    for k, v in pairs(fields) do
        run_callbacks(data.callbacks[k], form, fields)
    end
end)
