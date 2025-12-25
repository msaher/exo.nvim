vim.api.nvim_create_user_command("Exo", function(data)
    require("exo").run(data.args)
end, {
    nargs = '+',
    complete = 'shellcmdline'
})

vim.api.nvim_create_user_command("ExoPrompt", function(data)
    require("exo").prompt()
end, {})

vim.api.nvim_create_user_command("ExoOpen", function(data)
    require("exo").open()
end, {})




