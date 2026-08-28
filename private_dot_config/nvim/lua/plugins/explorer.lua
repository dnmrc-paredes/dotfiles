return {
    {
        "nvim-telescope/telescope-file-browser.nvim",
        dependencies = {
            "nvim-telescope/telescope.nvim",
        },
        opts = {
            extensions = {
                file_browser = {
                    theme = "ivy",
                    hijack_netrw = true,
                    grouped = true,
                    hidden = true,
                    layout_strategy = "horizontal"
                },
            },
        },
        config = function(_, opts)
            local telescope = require("telescope")
            telescope.setup(opts)
            telescope.load_extension("file_browser")
        end,
        keys = {
            {
                "<leader>fe",
                function()
                    require("telescope").extensions.file_browser.file_browser({
                        path = "%:p:h",
                        cwd = vim.fn.expand("%:p:h"),
                    })
                end,
                desc = "File Browser",
            },
        },
    },
}   
