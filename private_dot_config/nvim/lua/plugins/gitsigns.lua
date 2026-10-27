return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        -- 1. This turns on the automatic inline blame text under your cursor
        current_line_blame = true, 

        -- 2. Fine-tune how the automatic blame behaves
        current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = 'eol', -- Places blame text at the End Of the Line
            delay = 100,           -- How fast it appears after moving your cursor (100ms)
            ignore_whitespace = false,
            virt_text_priority = 100,
        },

        -- 3. Customize what the text looks like (Author, Date - Message)
        current_line_blame_formatter = '   • <author>, <author_time:%b %d, %Y> - <summary>',
        
        -- 4. Clean visual gutter indicators (Adds context markers on the left)
        signs = {
            add          = { text = '┃' },
            change       = { text = '┃' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
            untracked    = { text = '┆' },
        },
    }
}

