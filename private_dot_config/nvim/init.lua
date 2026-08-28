vim.opt.shortmess:append("I") 

require("config.options")
require("config.keybinds")
require("config.lazy")

-- Auto-display dashboard and shift working context when launching with folders
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local target_path = vim.fn.argv(0)
        -- Verify if the startup argument is a valid directory
        if target_path and vim.fn.isdirectory(target_path) == 1 then
            -- 1. Safely lock Neovim's focus to the requested folder
            vim.cmd("cd " .. vim.fn.fnameescape(target_path))
            -- 2. Terminate the raw, empty directory text buffer
            vim.cmd("bd!")
            -- 3. Draw the dashboard layout
            vim.cmd("Dashboard")
        end
    end,
})

-- Diagnostics

vim.diagnostic.config({
    signs = true,
    virtual_text = true,
    underline = true,
})
