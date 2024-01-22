# Minetest snippets mod

A way for admins to run and save lua snippets.

## Chatcommands

 - `/snippets`: Open the snippets console. This allows you to edit and run Lua
   snippets.

## Nodes

This mod registers a snippets button node that runs a snippet when pressed. The
snippet will be called with the player name as its first argument. For example,
you can do `local name = ...` inside a snippet to get the name of the player
that pressed the button.

Buttons don't appear in the creative inventory, if you want them to you will
need to run `/giveme snippets:button`.

If you don't want the buttons at all, you can add
`snippets.enable_buttons = false` to your minetest.conf.

## API

 - `snippets.register_snippet(name, <code or def>)`: Registers a snippet.
    `def` can be a table containing `code` (or `func`), and optionally `owner`.
    If `persistent` is specified, this snippet will remain registered across
    reboots.
    If `autorun` is specified, this snippet will auto run on server start. (Snippet must be persistent to support autorun)
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
 - `snippets.Form(player_or_name)`: Creates a form.
 - `snippets.close_form(player_or_name)`: Closes `player_or_name`'s currently
    open form.

### Forms

`snippets.Form`s can display and handle formspecs, and are recommended inside
snippets over `minetest.show_formspec`, as they do not create semi-permanent
global handlers. There is currently no way to set the `formname`, it is
automatically chosen/generated and is used internally.

Consider using [flow](https://content.minetest.net/packages/luk3yx/flow/)
instead for new forms.

Form methods:

 - `form:show()` / `form:open()`: Displays the form.
 - `form:hide()` / `form:close()`: Closes the form.
 - `form:is_open()`: Returns `true` if the form is currently open.
 - `form:set_prepend(formspec)`: Sets text to prepend to the formspec. This has
    nothing to do with global formspec prepends.
 - `form:set_formspec(formspec)`: Sets the formspec text. This does not modify
    prepended text or appended text. Any change to this (or the prepend/append
    values) is displayed immediately to the client.
 - `form:set_append(formspec)`: Sets text to append to the formspec before
    displaying it.
 - `form:get_prepend`, `form:get_formspec`, `form:get_append`
 - `form:add_callback(function(form, fields))`: This creates a callback which
    is called whenever form data is received from the client.
 - `form:add_callback(name, function(form, fields))`: Similar to the above,
    however is only called if `fields` contains `name` (a string).
 - `form.context`: Private data stored with this `form` object. Not sent to
    clients.
 - `form.pname`: The player name associated with this form. *Changing this will
    not change the player the form is associated with.*

*When a form is deleted (`form=nil`) and it is not open by the client, garbage
collection will allow the internal `formname` to be reused.*

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
