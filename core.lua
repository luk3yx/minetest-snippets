--
-- Minetest snippets mod: Attempt to prevent snippets from crashing the server
--

-- Make loadstring a local variable
local loadstring
if minetest.global_exists('loadstring') then
    loadstring = _G.loadstring
else
    loadstring = assert(load)
end

local copy = table.copy
local safe_funcs = {}
local orig_funcs, running_snippet

function snippets.get_current_snippet()
    return running_snippet
end

-- Apply "safe functions": These wrap normal registration functions so that
--  snippets can't crash them as easily.
local function apply_safe_funcs()
    if orig_funcs then return end
    orig_funcs = {}
    for k, v in pairs(safe_funcs) do
        if k ~= 'print' then
            orig_funcs[k] = minetest[k]
            minetest[k] = v
        end
    end
    orig_funcs.print, print = print, safe_funcs.print
end

local function remove_safe_funcs()
    if not orig_funcs then return end
    for k, v in pairs(orig_funcs) do
        minetest[k] = orig_funcs[k]
    end
    print = orig_funcs.print
    orig_funcs = nil
end

-- "Break out" of wrapped functions.
local function wrap_unsafe(func)
    return function(...)
        if orig_funcs then
            remove_safe_funcs()
            local res = {func(...)}
            apply_safe_funcs()
            return (table.unpack or unpack)(res)
        else
            return func(...)
        end
    end
end

-- Logging
snippets.registered_on_log = {}
snippets.log_levels = {}
function snippets.log_levels.error(n)
    return minetest.colorize('red', n)
end
function snippets.log_levels.warning(n)
    return minetest.colorize('yellow', n)
end
function snippets.log_levels.info(n)
    return n
end
snippets.log_levels.none = snippets.log_levels.info
function snippets.log_levels.debug(n)
    return minetest.colorize('grey', n)
end

function snippets.log(level, msg)
    local snippet = running_snippet or 'snippets:anonymous'
    if msg == nil then level, msg = 'none', level end
    level, msg = tostring(level), tostring(msg)

    if level == 'warn' then
        level = 'warning'
    elseif not snippets.log_levels[level] then
        level = 'none'
    end

    for _, func in ipairs(snippets.registered_on_log) do
        if func(snippet, level, msg) then return end
    end
end
snippets.log = wrap_unsafe(snippets.log)

function snippets.register_on_log(func)
    assert(type(func) == 'function')
    table.insert(snippets.registered_on_log, 1, func)
end

-- Create the default log action
-- Only notify the player of errors or warnings
snippets.register_on_log(function(snippet, level, msg)
    local rawmsg
    if level == 'warning' then
        rawmsg = 'Warning'
    elseif level == 'error' then
        rawmsg = 'Error'
    else
        return
    end

    rawmsg = snippets.log_levels[level](rawmsg .. ' in snippet "' .. snippet ..
        '": ' .. msg)

    local def = snippets.registered_snippets[snippet]
    if def and def.owner then
        minetest.chat_send_player(def.owner, rawmsg)
    else
        minetest.chat_send_all(rawmsg)
    end
end)

-- Create a safe print()
function safe_funcs.print(...)
    local msg = ''
    for i = 1, select('#', ...) do
        if i > 1 then msg = msg .. '\t' end
        msg = msg .. tostring(select(i, ...))
    end
    snippets.log('none', msg)
end

-- Mostly copied from https://stackoverflow.com/a/26367080
local function wrap_raw(snippet, func, ...)
    local old_running = running_snippet
    running_snippet = snippet
    local use_safe_funcs = not orig_funcs
    if use_safe_funcs then apply_safe_funcs() end
    local good, msg = pcall(func, ...)
    if use_safe_funcs then remove_safe_funcs() end
    if good then
        running_snippet = old_running
        return msg
    else
        snippets.log('error', msg)
        running_snippet = old_running
    end
end

local function wrap(snippet, func)
    if not snippet then return func end
    return function(...) return wrap_raw(snippet, func, ...) end
end

-- Expose the above function to the API.
-- This will only wrap functions if called from inside a snippet.
function snippets.wrap_callback(func)
    return wrap(running_snippet, func)
end

do
    local after_ = minetest.after
    function safe_funcs.after(after, func, ...)
        after = tonumber(after)
        assert(after and after == after, 'Invalid core.ater invocation')
        after_(after, wrap_raw, running_snippet, func, ...)
    end

    function snippets.wrap_register_on(orig)
        return function(func, ...)
            return orig(wrap(running_snippet, func), ...)
        end
    end

    for k, v in pairs(minetest) do
        if type(k) == 'string' and k:sub(1, 12) == 'register_on_' then
            safe_funcs[k] = snippets.wrap_register_on(v)
        end
    end
end

-- Register a snippet
snippets.registered_snippets = {}
function snippets.register_snippet(name, def)
    if def == nil and type(name) == 'table' then
        name, def = name.name, name
    elseif type(name) ~= 'string' then
        error('Invalid name passed to snippets.register_snippet!', 2)
    elseif type(def) == 'string' then
        def = {code=def}
    elseif type(def) ~= 'table' then
        error('Invalid definition passed to snippets.register_snippet!', 2)
    elseif def.owner and type(def.owner) ~= 'string' then
        error('Invalid owner passed to snippets.register_snippet!', 2)
    end
    def = table.copy(def)
    def.name = name

    if def.code then
        -- Automatically add "return"
        local msg
        def.func = loadstring('return ' .. def.code, name)
        if not def.func then
            def.func, msg = loadstring(def.code, name)
        end

        if def.func then
            if name ~= 'snippets:anonymous' then
                local old_def = snippets.registered_snippets[name]
                def.env = old_def and old_def.env
            end
            if not def.env then
                local g = {}
                def.env = setmetatable({}, {__index = function(self, key)
                    local res = rawget(_G, key)
                    if res == nil and not g[key] then
                        snippets.log('warning', 'Undeclared global variable "'
                            .. key .. '" accessed.')
                        g[key] = true
                    end
                    return res
                end})
            end
            setfenv(def.func, def.env)
        else
            local r, s = running_snippet, snippets.registered_snippets[name]
            function def.func() end
            running_snippet, snippets.registered_snippets[name] = name, def
            snippets.log('error', 'Load error: ' .. tostring(msg))
            running_snippet, snippets.registered_snippets[name] = r, s
        end
    else
        def.persistent = nil
    end
    if not def.persistent then def.code = nil end
    if type(def.func) ~= 'function' then return false end

    snippets.registered_snippets[name] = def
    return true
end
snippets.register_snippet('snippets:anonymous', '')

-- Run a snippet
function snippets.run(snippet, ...)
    local def = snippets.registered_snippets[snippet]
    if not def then error('Invalid snippet specified!', 2) end
    return wrap_raw(snippet, def.func, ...)
end

-- Run code as player
function snippets.exec_as_player(name, code)
    if minetest.is_player(name) then name = name:get_player_name() end
    local owner
    if name and name ~= '' then
        owner = name
        name = 'snippets:player_' .. tostring(name)
    else
        name = 'snippets:anonymous'
    end

    local def = {
        code  = tostring(code),
        owner = owner,
    }
    if not snippets.register_snippet(name, def) then return end

    return snippets.run(name)
end

function snippets.exec(code) return snippets.exec_as_player(nil, code) end

minetest.register_on_leaveplayer(function(player)
    snippets.registered_snippets['snippets:player_' ..
        player:get_player_name()] = nil
end)

-- In case console.lua isn't loaded
function snippets.unregister_snippet(name)
    if snippets.registered_snippets[name] ~= nil then
        snippets.registered_snippets[name] = nil
    end
end
