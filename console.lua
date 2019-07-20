--
-- Snippet console - Allows players to create and edit persistent snippets
--

local snippet_list = {}
local selected_snippet = {}
local console_code = {}
local console_text = {}

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if snippet_list[name] then
        snippet_list[name] = nil
        selected_snippet[name] = nil
        console_code[name] = nil
        console_text[name] = nil
    end
end)

function snippets.show_console(name)
    local formspec = 'size[14,10]' ..
        'label[0,0;My snippets]' ..
        'textlist[0,0.5;3.5,7.4;snippetlist;#aaaaaaNew snippet'

    snippet_list[name] = {}
    for k, v in pairs(snippets.registered_snippets) do
        if v.persistent then
            table.insert(snippet_list[name], k)
        end
    end
    table.sort(snippet_list[name])

    local selected = 0
    local unsaved = false
    for id, snippet in ipairs(snippet_list[name]) do
        formspec = formspec .. ',##' .. minetest.formspec_escape(snippet)
        if snippet == selected_snippet[name] then
            selected = id
            local def = snippets.registered_snippets[snippet]
            if (def and def.code or '') ~= console_code[name] then
                formspec = formspec .. ' (unsaved)'
            end
        end
    end

    formspec = formspec .. ';' .. tostring(selected + 1) .. ']' ..
        'button[0,8.1;3.7,0.75;save;Save]' ..
        'button[0,8.85;3.7,0.75;save_as;Save as]' ..
        'button_exit[0,9.6;3.7,0.75;quit;Quit]'

    formspec = formspec ..
        'textlist[3.9,6.01;10,4.04;ignore;'
    if console_text[name] then
        if #console_text[name] > 0 then
            for id, msg in ipairs(console_text[name]) do
                if id > 1 then formspec = formspec .. ',' end
                formspec = formspec .. minetest.formspec_escape(msg)
            end
            formspec = formspec .. ',;' .. (#console_text[name] + 1)
        else
            formspec = formspec .. ';1'
        end
        formspec = formspec ..
            ']button[3.9,5.14;10.21,0.81;reset;Reset]' ..
            'box[3.9,0.4;10,4.5;#ffffff]'
    else
        formspec = formspec .. ';1]' ..
            'button[3.9,5.14;10.21,0.81;run;Run]'
    end

    if not console_code[name] then console_code[name] = '' end
    local code = minetest.formspec_escape(console_code[name])
    if code == '' and console_text[name] then code = '(no code)' end

    local snippet, owner
    if selected_snippet[name] then
        snippet = minetest.colorize('#aaa', selected_snippet[name])
    else
        snippet = minetest.colorize('#888', 'New snippet')
    end

    local def = snippets.registered_snippets[selected_snippet[name]]
    if def and def.owner then
        owner = minetest.colorize('#aaa', def.owner)
    elseif selected_snippet[name] then
        owner = minetest.colorize('#888', 'none')
    else
        owner = minetest.colorize('#aaa', name)
    end

    formspec = formspec .. ']textarea[4.2,0.4;10.2,5.31;' ..
        (console_text[name] and '' or 'code') .. ';Snippet: ' ..
        minetest.formspec_escape(snippet .. ', owner: ' .. owner) .. ';' ..
        code .. ']'

    minetest.show_formspec(name, 'snippets:console', formspec)
end

function snippets.push_console_msg(name, msg, col)
    if not col or col:sub(1, 1) ~= '#' or #col ~= 7 then
        col = '##'
    end

    if console_text[name] then
        table.insert(console_text[name], col .. tostring(msg))
        snippets.show_console(name)
    end
end

snippets.register_on_log(function(snippet, level, msg)
    local owner = snippets.registered_snippets[snippet].owner
    if not owner or not console_text[owner] then return end
    if level ~= 'none' then
        msg = level:sub(1, 1):upper() .. level:sub(2) .. ': ' .. msg
    end

    local col
    if level == 'warning' then
        col = '#FFFF00'
    elseif level == 'error' then
        col = '#FF0000'
    elseif level == 'debug' then
        col = '#888888'
    end

    local p = snippet:sub(1, 16) == 'snippets:player_'
    if not p then msg = 'From snippet "' .. snippet .. '": ' .. msg end

    snippets.push_console_msg(owner, msg, col)

    if p then return true end
end)

minetest.register_chatcommand('snippets', {
    description = 'Opens the snippets console.',
    privs = {server=true},
    func = function(name, param)
        snippets.show_console(name)
        return true, 'Opened the snippets console.'
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= 'snippets:console' and
            formname ~= 'snippets:console_save_as' then
        return
    end
    local name = player:get_player_name()

    -- Sanity check
    if not minetest.check_player_privs(name, 'server') then
        if console_text[name] then
            console_text[name] = nil
            minetest.close_formspec(name, 'snippets:console')
        elseif not fields.quit then
            minetest.kick_player(name,
                'You appear to be using a "hacked" client.')
        end
        return
    elseif not console_code[name] then
        return
    end

    -- Handle "Save as"
    if formname == 'snippets:console_save_as' then
        if not fields.filename or fields.filename == '' then
            minetest.chat_send_player(name, 'Save operation cancelled.')
            snippets.show_console(name)
            return
        end

        -- Don't overwrite non-persistent snippets
        local filename = fields.filename:gsub(':', '/')
        while snippets.registered_snippets[filename] and
                not snippets.registered_snippets[filename].persistent do
            filename = filename .. '_'
        end

        -- Actually save it
        snippets.register_snippet(filename, {
            owner = name,
            code  = console_code[name],
            persistent = true,
        })

        selected_snippet[name] = filename
        snippets.show_console(name)
        return
    end

    if fields.code then console_code[name] = fields.code end

    if fields.ignore then
        return
    elseif fields.run then
        local code = fields.code
        console_text[name] = {}
        snippets.show_console(name)
        if not code or code == '' then return end
        local good, msg = loadstring('return ' .. code)
        if good then code = 'return ' .. code end
        local res = snippets.exec_as_player(name, code)
        if res ~= nil then
            snippets.push_console_msg(name, res)
        end
    elseif fields.reset then
        console_text[name] = nil
        snippets.show_console(name)
    elseif fields.snippetlist and snippet_list[name] then
        local event = minetest.explode_textlist_event(fields.snippetlist)
        local selected = snippet_list[name][event.index - 1]
        if selected_snippet[name] == selected then return end
        selected_snippet[name] = selected
        if console_text[name] then console_text[name] = nil end
        local def = snippets.registered_snippets[selected]
        console_code[name] = def and def.code or ''
        snippets.show_console(name)
    elseif fields.save and selected_snippet[name] then
        if console_code[name] == '' then
            snippets.unregister_snippet(selected_snippet[name])
            selected_snippet[name] = nil
        else
            snippets.register_snippet(selected_snippet[name], {
                owner = name,
                code  = console_code[name],
                persistent = true,
            })
        end
        snippets.show_console(name)
    elseif fields.save or fields.save_as and console_code[name] ~= '' then
        console_text[name] = nil
        minetest.show_formspec(name, 'snippets:console_save_as',
            'field[filename;Please enter a new snippet name.;]')
    elseif fields.quit then
        -- console_code[name] = nil
        console_text[name] = nil
    end
end)
