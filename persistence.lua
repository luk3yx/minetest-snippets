--
-- Persistent snippets
--

-- Get storage
local storage = ...
assert(storage)

-- Load persistent snippets
local register_snippet_raw = snippets.register_snippet
do
    for name, def in pairs(storage:to_table().fields) do
        if name:sub(1, 1) == '>' then
            def = minetest.deserialize(def)
            if def then
                def.persistent = true
                register_snippet_raw(name:sub(2), def)
            end
        end
    end
end

-- Override snippets.register_snippet so it accepts the "persistent" field.
function snippets.register_snippet(name, def)
    if def == nil and type(name) == 'table' then
        name, def = name.name, name
    end

    -- Fix tracebacks
    local good, msg = pcall(register_snippet_raw, name, def)
    if not good then error(msg, 2) end
    if not msg then return msg end

    -- Check for def.persistent
    def = snippets.registered_snippets[name]
    if type(def) == 'table' and def.persistent and def.code then
        print('Saving snippet', name)
        storage:set_string('>' .. name, minetest.serialize({
            code = def.code,
            owner = def.owner,
            autorun = def.autorun
        }))
    end

    -- Return the same value as register_snippet_raw.
    return msg
end

-- Override snippets.unregister_snippet
local unregister_snippet_raw = snippets.unregister_snippet
function snippets.unregister_snippet(name)
    local def = snippets.registered_snippets[name]
    if def and def.persistent then
        storage:set_string('>' .. name, '')
    end
    return unregister_snippet_raw(name)
end
