return {
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        },
        keys = {
            {
                '<leader>st',
                '<cmd>TodoTelescope keywords=FIX,BUG,ISSUE,TODO,NOTE,TEST<cr>',
                { desc = 'Search for TODO comments' }
            }
        }
    }
}
