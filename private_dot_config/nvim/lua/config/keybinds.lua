vim.g.mapleader = " "
-- vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)

vim.keymap.set("n", "<Esc>", ":nohlsearch<Enter>")
vim.keymap.set("n", "<leader>fd", function()
    local conform = require("conform")

    local formatters = conform.list_formatters_for_buffer()

    if vim.tbl_contains(formatters, "prettier") then
        conform.format({ async = true })
    else
        vim.cmd("normal! gg=G")
    end
end, { desc = "Format file" })

vim.keymap.set('i', 'jj', '<Esc>')
