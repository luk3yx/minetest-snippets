--
-- Snippet console - Allows players to create and edit persistent snippets
--

local forms = {}

minetest.register_on_leaveplayer(function(player)
    forms[player:get_player_name()] = nil
end)

local callback
function snippets.update_console(name)
    if not minetest.check_player_privs(name, 'server') then return end

    if not forms[name] then
        forms[name] = snippets.Form(name)
        forms[name]:add_callback(callback)
        forms[name].context.code = ''
    end
    local form = forms[name]
    if not form:is_open() then form.context.text = nil end

    local formspec = 'size[14,10]' ..
        'label[0,0;My snippets]' ..
        'textlist[0,0.5;3.5,7.4;snippetlist;#aaaaaaNew snippet'

    local snippet_list = {}
    form.context.snippet_list = snippet_list
    for k, v in pairs(snippets.registered_snippets) do
        if v.persistent then
            table.insert(snippet_list, k)
        end
    end
    table.sort(snippet_list)

    local selected, unaved = 0, false
    local selected_snippet = form.context.selected_snippet
    for id, snippet in ipairs(snippet_list) do
        local def = snippets.registered_snippets[snippet]
        formspec = formspec .. ',' .. (def.autorun and "#ff7777\\[A\\] " or "##") .. minetest.formspec_escape(snippet)
        if snippet == selected_snippet then
            selected = id
            if (def and def.code or '') ~= form.context.code then
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
    if form.context.text then
        local console_text = form.context.text
        if #console_text > 0 then
            for id, msg in ipairs(console_text) do
                if id > 1 then formspec = formspec .. ',' end
                formspec = formspec .. minetest.formspec_escape(msg)
            end
            formspec = formspec .. ',;' .. (#console_text + 1)
        else
            formspec = formspec .. ';1'
        end
        formspec = formspec ..
            ']button[3.9,5.14;'..(selected_snippet and '8.8' or '10.21')..',0.81;reset;Reset]' ..
            'box[3.9,0.4;10,4.5;#ffffff]'
    else
        formspec = formspec .. ';1]' ..
            'button[3.9,5.14;'..(selected_snippet and '8.8' or '10.21')..',0.81;run;Run]'
    end

    if not form.context.code then form.context.code = '' end
    local code = minetest.formspec_escape(form.context.code)
    if code == '' and form.context.text then code = '(no code)' end

    local snippet, owner
    if selected_snippet then
        snippet = minetest.colorize('#aaa', selected_snippet)
    else
        snippet = minetest.colorize('#888', 'New snippet')
    end

    local def = snippets.registered_snippets[selected_snippet]
    if def and def.owner then
        owner = minetest.colorize('#aaa', def.owner)
    elseif selected_snippet then
        owner = minetest.colorize('#888', 'none')
    else
        owner = minetest.colorize('#aaa', name)
    end

    formspec = formspec .. ']textarea[4.2,0.4;10.2,5.31;' ..
        (form.context.text and '' or 'code') .. ';Snippet: ' ..
        minetest.formspec_escape(snippet .. ', owner: ' .. owner) .. ';' ..
        code .. ']'
    if selected_snippet then
        local autorun
        if form.context.autorun == nil then
            autorun = def and def.autorun or false
        else
            autorun = form.context.autorun
        end
        formspec = formspec .. 'checkbox[12.7,5.05;autorun;Autorun;' .. tostring(autorun) .. ']'
    end

    form:set_formspec(formspec)
end

function snippets.show_console(name)
    snippets.update_console(name)
    local form = forms[name]
    if form then form:show() end
end

function snippets.push_console_msg(name, msg, col)
    if not col or col:sub(1, 1) ~= '#' or #col ~= 7 then
        col = '##'
    end

    local text = forms[name] and forms[name].context.text
    if not text then return end

    msg = tostring(msg)
    for _, line in ipairs(msg:split('\n', true)) do
        text[#text + 1] = col .. line
        if #text > 501 then
            text[1] = '#aaaaaaSnippets only stores 500 lines of scrollback.'
            table.remove(text, 2)
        end
    end
    snippets.update_console(name)
end

snippets.register_on_log(function(snippet, level, msg)
    local owner = snippets.registered_snippets[snippet].owner
    local form = forms[owner]
    if not owner or not form or not form.context.text or
            not form:is_open() then
        return
    end
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

local function saveform_callback(saveform, fields)
    local name = saveform.pname
    local form = forms[name]
    saveform:close()

    -- Sanity check
    if not minetest.check_player_privs(name, 'server') or not form then
        forms[name] = nil
        return
    end

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
        code  = form.context.code,
        persistent = true,
        autorun = form.context.autorun
    })

    form.context.selected_snippet = filename
    snippets.show_console(name)
end

function callback(form, fields)
    local name = form.pname
    if not minetest.check_player_privs(name, 'server') then
        forms[name] = nil
        form:close()
    end

    if fields.code then
        form.context.code = fields.code
    end

    if fields.ignore then
        return
    elseif fields.run then
        local code = fields.code
        form.context.text = {}
        snippets.show_console(name)
        if not code or code == '' then return end
        local res = snippets.exec_as_player(name, code)
        if res ~= nil then
            snippets.push_console_msg(name, res)
        end
    elseif fields.reset then
        form.context.text = nil
        snippets.update_console(name)
    elseif fields.snippetlist and form.context.snippet_list then
        local event = minetest.explode_textlist_event(fields.snippetlist)
        local selected = form.context.snippet_list[event.index - 1]
        if form.context.selected_snippet == selected then return end
        form.context.selected_snippet = selected
        form.context.text = nil
        form.context.autorun = nil
        local def = snippets.registered_snippets[selected]
        form.context.code = def and def.code or ''
        snippets.update_console(name)
    elseif fields.save and form.context.selected_snippet then
        if form.context.code == '' then
            snippets.unregister_snippet(form.context.selected_snippet)
            form.context.selected_snippet = nil
        else
            snippets.register_snippet(form.context.selected_snippet, {
                owner = name,
                code  = form.context.code,
                persistent = true,
                autorun = form.context.autorun
            })
        end
        snippets.show_console(name)
    elseif fields.save or fields.save_as and form.context.code ~= '' then
        form.context.text = nil

        local saveform = snippets.Form(name)
        saveform:set_formspec(
            'field[filename;Please enter a new snippet name.;]')
        saveform:add_callback(saveform_callback)
        saveform:show()
    elseif fields.autorun and form.context.selected_snippet then
        form.context.autorun = minetest.is_yes(fields.autorun)
    elseif fields.quit then
        form.text = nil
    end
end
