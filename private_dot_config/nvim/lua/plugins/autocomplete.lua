return {
    {
        'saghen/blink.cmp',
        dependencies = {
            'saghen/blink.lib',
            -- optional: provides snippets for the snippet source
            'rafamadriz/friendly-snippets',
        },
        build = function() require('blink.cmp').build():pwait() end,
        ---@module 'blink.cmp'
        ---@type blink.cmp.Config
        opts = {
            -- Keymaps config
            keymap = { 
                preset = 'default',
                ['<TAB>'] = { 'select_and_accept' },
                ['<CR>'] = { 'accept', 'fallback' }
            }, -- Properly ends the keymap table, NOT the opts table

            -- Only show the documentation popup when manually triggered
            completion = { 
                documentation = { auto_show = false },
                accept = { auto_brackets = { enabled = true } }
            },

            -- Explicitly provide sources inside opts
            sources = { 
                default = { 'lsp', 'path', 'snippets', 'buffer' } 
            },

            -- Fuzzy matcher configuration
            fuzzy = { 
                implementation = "rust" 
            },
        },
    },
}

