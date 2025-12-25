--- Runs the command in an exo buffer. It can act as drop-in replacement for *:!*
---@tag :Exo
vim.api.nvim_create_user_command("Exo", function(data)
    require("exo").run(data.args)
end, {
    nargs = '+',
    complete = 'shellcmdline'
})

--- Like |:Exo|, but interactive. Prompts for a shell command to
--- run. This is nice because you can use the <Up> and <Down>
--- keys to move through history if you're using the default
--- implementation of vim.ui.input
---@tag :ExoPrompt
vim.api.nvim_create_user_command("ExoPrompt", function(_)
    require("exo").prompt()
end, {})

--- Opens the exo window if it exists
---@tag :ExoOpen
vim.api.nvim_create_user_command("ExoOpen", function(_)
    require("exo").open()
end, {})




