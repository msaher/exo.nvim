if vim.b.did_ftplugin == 1 then
    return
end
vim.b.did_ftplugin = 1

local exo = require("exo")
vim.keymap.set("n", "<C-c>", exo.kill, { buffer = true })
