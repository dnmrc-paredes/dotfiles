return {
    {
        "leath-dub/snipe.nvim",
        keys = {
            {"<leader>ta", function () require("snipe").open_buffer_menu() end, desc = "Open Snipe buffer menu"}
        },
        opts = {
            ui = {
                position = 'topleft',
                open_win_override = {
                    title = 'Tabs',
                    border = 'single'
                }
            },
        }
    }
}
