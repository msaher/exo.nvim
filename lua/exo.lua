--- *exo* run commands in a throwaway buffer
---
--- Run external commands and show the output in a throwaway buffer
--- Inspired by https://github.com/habamax/vim-shout
--- By design, it does not do syntax highligting or parse error output. You can
--- use :cgetbuffer to send the buffer's content to the quickfix list. However,
--- it'll use https://github.com/msaher/bufix.nvim if its available
---
--- It internally uses vim.system(), which does NOT use a tty. If you want a
--- tty, use |:terminal|. There are advantages to not using :terminal.
--- 1. The buffer is modifable. You can delete or mark on comment on output.
--- Think running commands like `:g/re/d`
--- 2. Since there are no escape sequences, you can save the buffer as a file
--- 3. exo buffers have a filetype. Meaning you can use custom bindings, syntax rules, etc.

local exo = {}

--- The width threshold before
--- The number of columns to decide when to split vertically
---@type number
exo.w_threshold = 160

--- The underlying job in the exo buffer
---@type vim.SystemObj?
exo.job = nil

--- The exo buffer number. Its -1 when there's no buffer
---@type number
exo.bufnr = -1

--- Time format used in the exo buffer.
---@type string
exo.time_format = "%a %b %e %H:%M:%S"

--- When the job started in seconds
---@type number
exo.started_at = 0

--- When the job finished in seconds
---@type number
exo.finished_at = 0

--- Automatically focus window when the window opens
---@type bool
exo.focus_win = true

local buf_set_lines = vim.schedule_wrap(vim.api.nvim_buf_set_lines)

---@param bufnr number
---@return number?
---@private
local function find_window_for_buf(bufnr)
    local window = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(win)
        if b == bufnr then
            window = win
            vim.api.nvim_win_call(win, vim.cmd.clearjumps)
        end
    end

    return window
end

---@param bufnr number
---@param w_threshold number
---@return number
---@private
local function open_window(bufnr, w_threshold)
    local win_cfg = {}
    win_cfg.win = -1
    if vim.o.columns >= w_threshold and vim.fn.winlayout()[0] ~= 'row' then
        win_cfg.vertical = true
    else
        win_cfg.split = "below"
    end

    return vim.api.nvim_open_win(bufnr, exo.focus_win, win_cfg)
end

--- Sends SIGTERM to the job. If it does not terminate after a timeout. It
--- sends SIGKILL
function exo.kill()
    if exo.job ~= nil then
        exo.job:kill(15) -- SIGTERM
        exo.job:wait(150) -- wait before SIGKILL
    end
end

---@param err string
---@param data string
---@private
local function on_data(err, data)
    if err ~= nil then
        vim.notify("exo: " .. err, vim.log.levels.ERROR)
    elseif data ~= nil then
        buf_set_lines(exo.bufnr, -2, -1, false, vim.split(data, "\n"))
    end
end

---@param obj vim.SystemCompleted
---@private
local function on_exit(obj)
    exo.finished_at = os.time()
    local duration_seconds = os.difftime(exo.finished_at, exo.started_at)
    local duration = ""
    if duration_seconds <= 60 then
        duration = duration_seconds .. " s"
    else
        local hours = math.floor(duration_seconds / 3600)
        local minutes = math.floor((duration_seconds % 3600) / 60)
        local seconds = duration_seconds % 60
        duration = string.format("%.2d:%.2d:%.2d", hours, minutes, seconds)
    end

    local status = ""
    if obj.code == 0 then
        status = "finished"
    else
        status = "exited abnormally with code " .. obj.code
    end

    local msg = string.format("Process %s at %s, duration %s", status, os.date(exo.time_format, exo.finished_at), duration)
    buf_set_lines(exo.bufnr, -2, -1, false, {"", msg})
    exo.job = nil
end

--- Starts a new job in the exo buffer
---@param cmd string
function exo.run(cmd)
    if exo.bufnr == -1 then
        exo.bufnr = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_set_option_value('modified', false, { buf = exo.bufnr})
        vim.api.nvim_set_option_value('buftype', "nofile", { buf = exo.bufnr})
        vim.api.nvim_create_autocmd({ "BufDelete" }, {
            buffer = exo.bufnr,
            callback = function(_)
                if exo.job ~= nil then
                    vim.notify("exo: terminating job...")
                    exo.job:wait(100)
                end
            end,
            desc = "exo: stop abandoned job",
            once = true,
        })
        vim.api.nvim_buf_set_name(exo.bufnr, "[exo]")
        vim.api.nvim_set_option_value("filetype", "exo", { scope = "local", buf = exo.bufnr })
        local ok, bufix = pcall(require, "bufix.api")
        if ok then
            bufix.set_buf(exo.bufnr)
        end
    else
        if exo.job ~= nil then
            vim.notify("exo: buffer already has a job. terminating it...")
            exo.job:wait(100)
        end
        vim.api.nvim_buf_set_lines(exo.bufnr, 0, -1, true, {})
    end

    -- window logic
    local window = find_window_for_buf(exo.bufnr)
    if window == nil then
        open_window(exo.bufnr, exo.w_threshold)
    end

    exo.started_at = os.time()

    local lines = {
        "vim: filetype=exo:path+=" .. vim.fn.getcwd():gsub("^" .. vim.env.HOME, "~"),
        "Process started at " .. os.date(exo.time_format, exo.start_time),
        "",
        cmd,
    }
    vim.api.nvim_buf_set_lines(exo.bufnr, 0, -2, true, lines)

    local argv = { vim.o.shell, vim.o.shellcmdflag, vim.fn.escape(cmd, "\\") }
    exo.job = vim.system(argv, {
        text = true,
        stdout = on_data,
        stderr = on_data,
    }, on_exit)
end

--- Prompts for a command to run
function exo.prompt()
    local opts = { prompt = "$ ", completion = "shellcmdline" }
    vim.ui.input(opts, function(input)
        if input ~= nil and input ~= "" then
            exo.run(input)
        end
    end)
end

--- Opens the exo window
function exo.open()
    if exo.bufnr == -1 then
        vim.notify("exo: No exo buffer to open", vim.log.levels.WARN)
        return
    end

    local window = find_window_for_buf(exo.bufnr)
    if window == nil then
        window = open_window(exo.bufnr, exo.w_threshold)
    end

    vim.api.nvim_set_current_win(window)
end

return exo
