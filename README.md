# Minetest snippets mod

A way for admins to run and save lua snippets.

More documentation coming soon.

## API

 - `snippets.register_snippet(name, <code or def>)`: Registers a snippet.
    `def` can be a table containing `code` (or `func`), and optionally `owner`.
    If `persistent` is specified, this snippet will remain registered across
    reboots.
 - `snippets.unregister_snippet(name)`: The opposite of
    `snippets.register_snippet`.
 - `snippets.registered_snippets`: A table containing the above snippets.
 - `snippets.log(level, msg)`: For use inside snippets: Logs a message. `level`
    can be `none`, `debug`, `info`, `warning`, or `error`.
 - `snippets.register_on_log(function(snippet, level, msg))`: Run when
    snippets.log is called. `snippet` is the name of the snippet. Newest
    functions are called first. If a callback returns `true`, any remaining
    functions are not called (including the built-in log function). Callbacks
    can check what player (if any) owns a snippet with
    `snippets.registered_snippets[snippet].owner`.
 - `snippets.log_levels`: A table containing functions that run
    `minetest.colorize` on log levels (if applicable).
    Example: `snippets.log_levels.error('Hello')` →
    `minetest.colorize('red', 'Hello')`
 - `snippets.exec_as_player(player_or_name, code)`: Executes `code` (a string)
    inside an "anonymous snippet" owned by the player.
 - `snippets.exec(code)`: Executes `code` inside a generic snippet.
 - `snippets.run(name, ...)`: Executes a snippet.

## Example snippets

`get_connected_names`:
```lua
local res = {}
for _, player in ipairs(minetest.get_connected_players()) do
    table.insert(res, player:get_player_name())
end
return res
```

`greeting_test`:
```lua
for _, name in ipairs(snippets.run 'get_connected_names') do
    minetest.chat_send_player(name, 'Hello ' .. name .. '!')
end
```
