{ config, pkgs, lib, ... }:
 
let
  pkgsUnstable = import <nixpkgs-unstable> {};
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = pkgsUnstable.neovim-unwrapped;
    plugins = with pkgs.vimPlugins; [
      guess-indent-nvim
      dhall-vim
      telescope-nvim
      which-key-nvim
      tokyonight-nvim
      # coc-nvim
      haskell-vim
      onedark-nvim
      cyberdream-nvim
      telescope-file-browser-nvim
      conflict-marker-vim
      diffview-nvim
      context-vim
      #telescope-coc-nvim
      #copilot-vim
      {
        plugin = pkgsUnstable.vimPlugins.lz-n;
        type = "lua";
        config = ''
          require("lz.n").load {
            "copilot.lua",
            cmd = "Copilot",
            event = "InsertEnter",
            after = function()
              require("copilot").setup({
                suggestion = { enabled = false },
                panel = { enabled = false },
              })
              require("copilot_cmp").setup()
            end
          }
        '';
      }
      pkgsUnstable.vimPlugins.copilot-lua
      pkgsUnstable.vimPlugins.copilot-cmp
      neoscroll-nvim
      ghcid
      citruszest-nvim
      vim-monokai-tasty
      vim-commentary
      nvim-treesitter
      nvim-treesitter-parsers.luadoc
      nvim-treesitter-parsers.vimdoc
      nvim-surround
      vim-bookmarks
      vim-easymotion
      auto-session
      purescript-vim
      vim-LanguageTool
      todo-comments-nvim
      vim-fugitive
      pkgsUnstable.vimPlugins.haskell-tools-nvim
      telescope_hoogle
      nvim-ufo
      nvim-lint
      trouble-nvim
      nvim-web-devicons
      hover-nvim
      nvim-cmp
      nvim-ufo
      cmp-nvim-lsp
      text-case-nvim
      plenary-nvim
      pkgsUnstable.vimPlugins.yazi-nvim
      golden-ratio
      yanky-nvim
      kanagawa-nvim
      lualine-nvim
      lualine-lsp-progress
      pkgsUnstable.vimPlugins.telescope-live-grep-args-nvim
      vim-dasht
      dash-vim
      # lsp_lines-nvim
      # coc-ltex
    ];
    extraLuaConfig = ''
      if not vim.uv then
        vim.uv = vim.loop
      end
 
 
      require'lualine'.setup{
        sections = {},
        tabline = {
          lualine_a = {'mode'},
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {'lsp_progress', {'filename', path = 1, shorting_target=40}},
          lualine_x = {'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location'}
        },
      }
 
      require('guess-indent').setup {}
      require("todo-comments").setup()
 
      local ht = require('haskell-tools')
      local wk = require("which-key")
      wk.register({
        f = {
          name = "telescope", -- optional group name
          f = { "<cmd>Telescope find_files shorten_path=true<cr>", "Find File" }, 
          g = { ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>", "Grep" }, 
          w = { "<cmd>Telescope grep_string<cr>", "Grep word" }, 
          o = { "<cmd>Telescope oldfiles shorten_path=true<cr>", "Recent files" }, 
          r = { "<cmd>Telescope file_browser<cr>", "File explorer root" }, 
          e = { "<cmd>Telescope file_browser path=%:p:h select_buffer=true<cr>", "File explorer here" }, 
          b = { "<cmd>Telescope buffers shorten_path=true<cr>", "Buffers" }, 
          h = { "<cmd>Telescope hoogle<cr>", "Hoogle" }, 
          c = { "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", "Symbols" }, 
          j = { "<cmd>Telescope jumplist<cr>", "Jump list" }, 
          m = { "<cmd>Telescope marks<cr>", "Marks" }, 
          t = { ":TodoTelescope keywords=FIX<CR>", "List TODOs (FIX)" }, 
          y = { function() require("telescope").extensions.yank_history.yank_history({ }) end, "Yanky" },
        },
        c = {
          h = { "<cmd>Telescope ht hoogle_signature<CR>", "Hoogle this!" },
          f = { "<cmd> Telescope ht package_files<CR>", "Find package files" },
          g = { "<cmd> Telescope ht package_grep<CR>", "Package grep" },
          d = { "<cmd>lua vim.diagnostic.open_float(0, { scope = 'line' })<CR>", "Diagnostic" },
          l = { "<cmd>lua require('haskell-tools').log.nvim_open_logfile()<CR>", "Logs"},
          k = { "<cmd>lua require('haskell-tools').log.nvim_open_hls_logfile()<CR>", "HLS Logs"},
          j = { "<cmd>lua require('haskell-tools').log.set_level(vim.log.levels.DEBUG)<CR>", "HLS debug"},
          g = { "<cmd>Hls stop<CR><cmd>Ghcid -c 'cabal repl --enable-multi-repl all'<CR>", "Use GHCID" },
          s = { "<cmd>GhcidKill<CR><cmd>Hls start<CR>", "Use HLS"},
          q = { "<cmd>TroubleToggle quickfix<CR>", "Trobule"},
          t = { "<cmd>Ghcid<CR>", "Ghcid toggle"}
        },
        b = {
          name = "Bookmarks",
          m = { "<Plug>BookmarkToggle", "Toggle bookmark" }, 
          a = { "<Plug>BookmarkAnnotate", "Annotate" }, 
          n = { "<Plug>BookmarkNext", "Next bookmark" }, 
          p = { "<Plug>BookmarkPrev", "Previous bookmark" }, 
          l = { "<Plug>BookmarkShowAll", "List bookmarks" }, 
        },
        t = {
          name = "Trouble",
          t = { "<cmd>TroubleToggle<CR>", "Trouble" },
          q = { "<cmd>Trouble quickfix<CR>", "Quickfix" },
          g = { "<cmd>Ghcid<CR>", "Ghcid toggle" },
        },
        g = {
          name = "GHCI",
          t = { function() ht.repl.toggle() end, "Toggle repl" },
          q = { function() ht.repl.quit() end, "Quit repl" },
          c = { function() ht.repl.cword_type() end, "Type of word under cursor" },
          i = { function() ht.repl.cword_info() end, "Info on word under cursor" },
          r = { function() ht.repl.reload() end, "Reload repl" },
        },
        d = {
          name = "Diffview",
          o = { "<cmd>DiffviewOpen<CR>", "Open", mode="n" },
          q = { "<cmd>DiffviewClose<CR>", "Quit", mode="n" },
          r = { "<cmd>DiffviewFileHistory<cr>", "Repo history" },
          m = { "<cmd>DiffviewOpen master<CR>", "Diffview master", mode="n" },
          f = { "<cmd>DiffviewFileHistory --follow %<cr>", "File history" },
          l = { "<Cmd>.DiffviewFileHistory --follow<CR>", "Line history" },
          v = { "<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>", "Range history", mode = "v" },
          b = { "<cmd>DiffviewToggleFiles<CR>", "Toggle files" },
        },
        h = {
          name = "Help (dash)",
          w = { "<cmd>call Dasht(dasht#cursor_search_terms())<CR>", "Search word" },
          v = { "y:<C-U>call Dasht(getreg(0))", mode="v", "Search selection" },
          f = { "<cmd>Dasht<CR>", "Free search" },
          e = { "<cmd>Dash<CR>", "Word GUI"},
        },
        j = {
          name = "Other",
          s = { "<Plug>(golden_ratio_resize)<CR>", "Godlen ratio resize" },
          t = { "<Plug>(golden_ratio_toggle)<CR>", "Godlen ratio toggle" },
        },
      }, { prefix = "<leader>" })
      wk.setup {}
 
      require('onedark').setup {
         style = 'darker'
      }
      require('onedark').load()
 
      local telescope = require('telescope')
 
      telescope.setup{
        defaults = {
          path_display={"truncate"} 
        },
        extensions = {
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            mappings = { -- extend mappings
              i = {
                ["<C-k>"] = require("telescope-live-grep-args.actions").quote_prompt(),
                ["<C-i>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " }),
                ["<C-t>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = ' --iglob **/test/**' }),
                ["<C-s>"] = require("telescope-live-grep-args.actions").quote_prompt({ postfix = ' --iglob **/src/**' }),
                -- freeze the current list and start a fuzzy search in the frozen list
                ["<C-space>"] = require("telescope-live-grep-args.actions").to_fuzzy_refine,
              },
            },
            -- ... also accepts theme settings, for example:
            -- theme = "dropdown", -- use dropdown theme
            -- theme = { }, -- use own theme spec
            -- layout_config = { mirror=true }, -- mirror preview pane
          }
        }
      }
 
      telescope.load_extension "file_browser"
      telescope.load_extension('hoogle')
      telescope.load_extension("live_grep_args")
 
      require('neoscroll').setup({})
      vim.g["languagetool_jar"] = '/Users/mateusz.urban/LanguageTool-5.9/languagetool-commandline.jar'
 
      local bufnr = vim.api.nvim_get_current_buf()
      local opts = { noremap = true, silent = true, buffer = bufnr, }
      -- haskell-language-server relies heavily on codeLenses,
      -- so auto-refresh (see advanced configuration) is enabled by default
      vim.keymap.set('n', '<space>cl', vim.lsp.codelens.run, opts)
      -- Hoogle search for the type signature of the definition under the cursor
      vim.keymap.set('n', '<space>hs', ht.hoogle.hoogle_signature, opts)
      -- Evaluate all code snippets
      vim.keymap.set('n', '<space>ea', ht.lsp.buf_eval_all, opts)
      -- Toggle a GHCi repl for the current package
      vim.keymap.set('n', '<leader>rr', ht.repl.toggle, opts)
      -- Toggle a GHCi repl for the current buffer
      vim.keymap.set('n', '<leader>rf', function()
        ht.repl.toggle(vim.api.nvim_buf_get_name(0))
      end, opts)
      vim.keymap.set('n', '<leader>rq', ht.repl.quit, opts)
 
      local hl_groups = { 'DiagnosticUnderlineError' }
      for _, hl in ipairs(hl_groups) do
        vim.cmd.highlight(hl .. ' gui=undercurl')
      end
 
      require('textcase').setup {
        prefix = '<leader>t'
      }
      require('telescope').load_extension('textcase')
 
 
      vim.o.foldcolumn = '1' -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
 
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
 
      require('ufo').setup({
          provider_selector = function(bufnr, filetype, buftype)
              return {'treesitter', 'indent'}
          end
      })
 
      require("yazi").setup({
        keys = {
          {
            "<leader>-",
            "<cmd>Yazi<cr>",
            desc = "Open yazi at the current file",
          },
          {
            -- Open in the current working directory
            "<leader>cw",
            "<cmd>Yazi cwd<cr>",
            desc = "Open the file manager in nvim's working directory" ,
          },
          {
            -- NOTE: this requires a version of yazi that includes
            -- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
            '<c-up>',
            "<cmd>Yazi toggle<cr>",
            desc = "Resume the last yazi session",
          }
        }})
 
      vim.keymap.set("n", "<leader>-", function()
        require("yazi").yazi()
      end)
 
      -- Yanky
      require("yanky").setup()
      vim.keymap.set({"n","x"}, "p", "<Plug>(YankyPutAfter)")
      vim.keymap.set({"n","x"}, "P", "<Plug>(YankyPutBefore)")
      vim.keymap.set({"n","x"}, "gp", "<Plug>(YankyGPutAfter)")
      vim.keymap.set({"n","x"}, "gP", "<Plug>(YankyGPutBefore)")
 
      vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)")
      vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)")
 
      -- Surround
      require("nvim-surround").setup()
 
      local cmp = require('cmp')
 
      -- nvim-cmp
      cmp.setup {
        sources = {
          { name = "copilot", group_index = 2 },
          { name = 'nvim_lsp' }
        },
        mapping = {
          ['<CR>'] = cmp.mapping.confirm({select = false}),
          ['<S-Tab>'] = cmp.mapping.select_prev_item(select_opts),
          ['<Tab>'] = cmp.mapping.select_next_item(select_opts),
          ['<C-Space>'] = cmp.mapping.complete(),
        }
      }
 
      -- The nvim-cmp almost supports LSP's capabilities so You should advertise it to LSP servers..
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
 
      require('kanagawa').setup()
      require("kanagawa").load("wave")
 
 
    '';
    extraConfig = ''
      map <Space> <Leader>
      set number
      set nu rnu
      set mouse=nicr
      set diffopt+=vertical
 
      " colorscheme citruszest
      " colorscheme onedark
      filetype plugin indent on
 
      command -nargs=+ LspHover lua vim.lsp.buf.hover()
      set keywordprg=:LspHover
      noremap <silent> <C-S-Left> :vertical resize -3<CR>
      noremap <silent> <C-S-Right> :vertical resize +3<CR>
 
      let g:ghcid_background = 1
 
      :tnoremap <A-Left> <m-b>
      :tnoremap <A-Right> <m-f>
      :tnoremap <Esc> <C-\><C-n>
 
      let g:golden_ratio_exclude_nonmodifiable = 1
      let g:golden_ratio_autocommand = 0
 
    '';
  };
}
