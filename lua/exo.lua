local M = {}

--- @type number
M.W_THRESHOLD = 160

--- @type vim.SystemObj?
M.job = nil

--- @type number
M.bufnr = -1

--- @type string
M.time_format = "%a %b %e %H:%M:%S"

--- @type number
M.started_at = 0

--- @type number
M.finished_at = 0

local buf_set_lines = vim.schedule_wrap(vim.api.nvim_buf_set_lines)
local notify = vim.schedule_wrap(vim.notify)

--- @param name string
--- @return number
local function get_buf_by_name(name)
    local bufs = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(bufs) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local buf_name = vim.api.nvim_buf_get_name(bufnr)
            buf_name = vim.fn.fnamemodify(buf_name, ":t")
            if buf_name == name then
                return bufnr
            end
        end
    end

    return -1
end

--- @param bufnr number
--- @return number?
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
local function open_window(bufnr, w_threshold)
    local win_cfg = {}
    win_cfg.win = -1
    if vim.o.columns >= w_threshold and vim.fn.winlayout()[0] ~= 'row' then
        win_cfg.vertical = true
    else
        win_cfg.split = "below"
    end

    return vim.api.nvim_open_win(bufnr, false, win_cfg)
end

function M.kill()
    if M.job ~= nil then
        M.job:kill(15) -- SIGTERM
        M.job:wait(150) -- wait before SIGKILL
    end
end

--- @param err string
--- @param data string
function on_data(err, data)
    if err ~= nil then
        vim.notify("exo: " .. err, vim.log.levels.ERROR)
    elseif data ~= nil then
        buf_set_lines(M.bufnr, -2, -1, false, vim.split(data, "\n"))
    end
end

--- @param obj vim.SystemCompleted
function on_exit(obj)
    M.finished_at = os.time()
    local duration_seconds = os.difftime(M.finished_at, M.started_at)
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

    local msg = string.format("Process %s at %s, duration %s", status, os.date(M.time_format, M.finished_at), duration)
    buf_set_lines(M.bufnr, -2, -1, false, {"", msg})
    M.job = nil
end

---@param cmd string
function M.run(cmd)
    if M.bufnr == -1 then
        M.bufnr = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_set_option_value('modified', false, { buf = M.bufnr})
        vim.api.nvim_create_autocmd({ "BufDelete" }, {
            buffer = M.bufnr,
            callback = function(_)
                if M.job ~= nil then
                    vim.notify("exo: terminating job...")
                    M.job:wait(100)
                end
            end,
            desc = "exo: stop abandoned job",
            once = true,
        })
        vim.api.nvim_buf_set_name(M.bufnr, "[exo]")
        vim.api.nvim_set_option_value("filetype", "exo", { scope = "local", buf = M.bufnr })
        local ok, bufix = pcall(require, "bufix.api")
        if ok then
            bufix.set_buf(M.bufnr)
        end
    else
        if M.job ~= nil then
            vim.notify("exo: buffer already has a job. terminating it...")
            M.job:wait(100)
        end
        vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, true, {})
    end

    -- window logic
    local window = find_window_for_buf(M.bufnr)
    if window == nil then
        open_window(M.bufnr, M.W_THRESHOLD)
    end

    M.started_at = os.time()

    local modeline = "vim: filetype=exo:path+=" .. vim.fn.getcwd():gsub("^" .. vim.env.HOME, "~")
    local lines = {
        "vim: filetype=exo:path+=" .. vim.fn.getcwd():gsub("^" .. vim.env.HOME, "~"),
        "Process started at " .. os.date(M.time_format, M.start_time),
        "",
        cmd,
    }
    vim.api.nvim_buf_set_lines(M.bufnr, 0, -2, true, lines)

    local argv = { vim.o.shell, vim.o.shellcmdflag, vim.fn.escape(cmd, "\\") }
    M.job = vim.system(argv, {
        text = true,
        stdout = on_data,
        stderr = on_data,
    }, on_exit)
end

function M.prompt()
    local opts = { prompt = "$ ", completion = "shellcmdline" }
    vim.ui.input(opts, function(input)
        if input ~= nil and input ~= "" then
            M.run(input)
        end
    end)
end

function M.open()
    if M.bufnr == -1 then
        vim.notify("exo: No exo buffer to open", vim.log.levels.WARN)
        return
    end

    local window = find_window_for_buf(M.bufnr)
    if window == nil then
        window = open_window(M.bufnr, M.W_THRESHOLD)
    end

    vim.api.nvim_set_current_win(window)
end

do
    local bufnr = get_buf_by_name("[exo]")
    if bufnr ~= -1 then
        vim.api.nvim_buf_delete(bufnr, {force = true})
    end
end


return M
