return {
    {
        'nvim-telescope/telescope.nvim', version = '*',
        dependencies = {
            'nvim-lua/plenary.nvim',
            "nvim-tree/nvim-web-devicons",
            -- optional but recommended
            { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
            -- Media files preview
            "nvim-telescope/telescope-media-files.nvim",
        },
        config = function()
            local builtin = require('telescope.builtin')
            local telescope = require('telescope')

            telescope.setup({
                extensions = {
                    media_files = {
                        filetypes = { "png", "webp", "jpg", "jpeg" },
                        find_cmd = "rg",
                    },
                },
            })

            telescope.load_extension("media_files")

            vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
            vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
            vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
            vim.keymap.set('n', '<leader>dg', builtin.diagnostics, { desc = 'Telescope diagnostics' })

            -- For media files
            vim.keymap.set("n", "<leader>fm", function()
                require("telescope").extensions.media_files.media_files()
            end, {
            desc = "Telescope media files",
        })

    end
}
}
