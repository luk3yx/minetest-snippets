--
-- Buttons that run snippets
--

-- Use steel block texture in minetest_game
local bg = minetest.global_exists('xcompat') and xcompat.textures and
    xcompat.textures.metal.steel.block or
    '[combine:1x1^[noalpha^[colorize:#aaa'

minetest.register_node('snippets:button', {
    description = 'Snippets button',
    tiles = {bg, bg, bg .. '^snippets_button.png'},
    groups = {cracky = 2, not_in_creative_inventory = 1},

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string('infotext', 'Unconfigured snippets button')
        meta:set_string('formspec', 'field[snippet;Snippet to run:;]')
    end,

    on_receive_fields = function(pos, formname, fields, sender)
        if not fields.snippet or fields.snippet == '' then return end

        local name = sender:get_player_name()
        if not minetest.check_player_privs(name, {server=true}) then
            minetest.chat_send_player(name, 'Insufficient privileges!')
            return
        end

        local snippet = fields.snippet
        if not snippets.registered_snippets[snippet] or
                snippet:sub(1, 9) == 'snippets:' then
            minetest.chat_send_player(name, 'Unknown snippet!')
        else
            local meta = minetest.get_meta(pos)
            meta:set_string('snippet', snippet)
            meta:set_string('infotext', 'Snippet: ' .. fields.snippet)
            meta:set_string('formspec', '')
        end
    end,

    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local meta, name = minetest.get_meta(pos), clicker:get_player_name()
        local snippet = meta:get_string('snippet')
        if not snippet or snippet == '' then return end
        if snippets.registered_snippets[snippet] then
            snippets.run(snippet, name)
        else
            minetest.chat_send_player(name, 'Invalid snippet: "' .. snippet ..
                '"')
        end
    end,
})
