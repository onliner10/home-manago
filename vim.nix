{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim-unwrapped;
    plugins = with pkgs.vimPlugins; [
      # Core
      plenary-nvim
      nvim-web-devicons

      # UI
      kanagawa-nvim
      lualine-nvim
      lualine-lsp-progress
      neoscroll-nvim
      golden-ratio
      citruszest-nvim
      vim-monokai-tasty
      hover-nvim
      dash-vim

      # Telescope
      telescope-nvim
      telescope-file-browser-nvim
      telescope_hoogle
      pkgs.vimPlugins.telescope-live-grep-args-nvim

      # Navigation
      pkgs.vimPlugins.flash-nvim
      nvim-ufo
      vim-bookmarks
      vim-easymotion

      # Git
      vim-fugitive
      vim-signify
      diffview-nvim
      conflict-marker-vim

      # LSP & Completion
      nvim-cmp
      cmp-nvim-lsp
      trouble-nvim

      # Copilot
      {
        plugin = pkgs.vimPlugins.lz-n;
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
      pkgs.vimPlugins.copilot-lua
      pkgs.vimPlugins.copilot-cmp

      # Editing
      which-key-nvim
      nvim-surround
      vim-commentary
      guess-indent-nvim
      yanky-nvim
      text-case-nvim
      todo-comments-nvim
      vim-LanguageTool

      # Treesitter
      nvim-treesitter
      nvim-treesitter-context
      nvim-treesitter-parsers.haskell
      nvim-treesitter-parsers.nix
      nvim-treesitter-parsers.lua
      nvim-treesitter-parsers.luadoc
      nvim-treesitter-parsers.vimdoc

      # Haskell
      haskell-vim
      pkgs.vimPlugins.haskell-tools-nvim
      ghcid

      # Other languages
      dhall-vim
      purescript-vim

      # Session & misc
      auto-session
      pkgs.vimPlugins.yazi-nvim
      vim-dasht

      # Claude Code integration
      pkgs.vimPlugins.snacks-nvim
      pkgs.vimPlugins.claudecode-nvim
    ];
    initLua = ''
      if not vim.uv then
        vim.uv = vim.loop
      end

      -- Start RPC server so external tools can open files in this Neovim
      local nvim_sock = '/tmp/nvim-zellij.sock'
      pcall(vim.fn.delete, nvim_sock)
      vim.fn.serverstart(nvim_sock)

      require'lualine'.setup{
        sections = {},
        tabline = {
          lualine_a = {
            'mode',
            {
              function() return "REVIEW" end,
              color = { bg = "#c34043", fg = "#1f1f28", gui = "bold" },
              cond = function()
                local ok, lib = pcall(require, "diffview.lib")
                return ok and lib.get_current_view() ~= nil
              end,
            },
          },
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {'lsp_progress', {'filename', path = 1, shorting_target=40}},
          lualine_x = {'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location'}
        },
      }
  
      -- Start treesitter (needed for treesitter-context) then re-enable traditional syntax
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].syntax = 'ON'
          end
        end,
      })

      require('guess-indent').setup {}
      require("todo-comments").setup()

      local ht = require('haskell-tools')
      local wk = require("which-key")

      wk.setup {
        delay = 200,  -- Show popup quickly for discoverability
        icons = { mappings = false },
      }

      -- ══════════════════════════════════════════
      -- Code review: base branch detection + toggle
      -- ══════════════════════════════════════════
      local function get_base_branch()
        local ref = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null")
        if vim.v.shell_error == 0 then
          local branch = vim.trim(ref):match("refs/remotes/origin/(.*)")
          if branch then return "origin/" .. branch end
        end
        for _, name in ipairs({"main", "master", "develop"}) do
          vim.fn.system("git rev-parse --verify origin/" .. name .. " 2>/dev/null")
          if vim.v.shell_error == 0 then return "origin/" .. name end
        end
        return "origin/main"
      end

      local function diffview_smart_toggle()
        local lib = require("diffview.lib")

        if #lib.views == 0 then
          local base = get_base_branch()
          vim.cmd("DiffviewOpen " .. base .. "...HEAD")
          vim.notify("REVIEW vs " .. base .. ": ]c/[c=hunks  gf=file  <leader>gm=back  <leader>gq=end")
          return
        end

        if lib.get_current_view() then
          local prev = lib.get_prev_non_view_tabpage()
          if prev then
            vim.api.nvim_set_current_tabpage(prev)
            vim.notify("EXPLORING: <leader>gm=diff  <leader>gq=end review")
          end
        else
          local view = lib.views[1]
          if view and vim.api.nvim_tabpage_is_valid(view.tabpage) then
            vim.api.nvim_set_current_tabpage(view.tabpage)
            vim.notify("REVIEW: ]c/[c=hunks  gf=file  <leader>gm=back  <leader>gq=end")
          end
        end
      end

      -- ══════════════════════════════════════════
      -- Floating cheat sheet (organized by workflow)
      -- ══════════════════════════════════════════
      local function show_cheat_sheet()
        local lines = {
          " REVIEW CODE",
          "   <leader>gm   Toggle diff vs base branch",
          "   <leader>gq   End review",
          "   ]c / [c      Next / prev hunk",
          "   gf           Go to file (from diff)",
          "   <leader>gb   Blame  <leader>gs  Status",
          "",
          " FIND THINGS",
          "   <leader>ff   Files     <leader>fg  Grep",
          "   <leader>fw   Word      <leader>fc  Symbols",
          "   <leader>fo   Recent    <leader>fb  Buffers",
          "",
          " NAVIGATE",
          "   s / S        Flash jump / treesitter",
          "   gd  definition   gr  references   K  hover",
          "   <leader>[  back  <leader>]  forward",
          "",
          " EDIT & FILES",
          "   <leader>w  save   <leader>q  quit",
          "   <leader>-  Yazi   <leader>t  text case",
          "",
          " AI (CLAUDE)",
          "   <leader>ac  toggle   <leader>as  send (v)",
          "",
          "                        [q] or [Esc] to close",
        }

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = "wipe"

        local width = 55
        local height = #lines
        local ui = vim.api.nvim_list_uis()[1]

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = math.floor((ui.height - height) / 2),
          col = math.floor((ui.width - width) / 2),
          style = "minimal",
          border = "rounded",
          title = " Cheat Sheet ",
          title_pos = "center",
        })

        local close = function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end
        vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
        vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
      end

      wk.add({
        -- ══════════════════════════════════════════
        -- Find (Telescope)
        -- ══════════════════════════════════════════
        { "<leader>f", group = "Find" },
        { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Files" },
        { "<leader>fg", ":lua require('telescope').extensions.live_grep_args.live_grep_args()\n<CR>", desc = "Grep" },
        { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Word (grep)" },
        { "<leader>fo", "<cmd>Telescope oldfiles<cr>", desc = "Old/recent files" },
        { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
        { "<leader>fj", "<cmd>Telescope jumplist<cr>", desc = "Jumplist" },
        { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Marks" },
        { "<leader>ft", ":TodoTelescope keywords=FIX<CR>", desc = "TODOs" },
        { "<leader>fy", function() require("telescope").extensions.yank_history.yank_history({}) end, desc = "Yank history" },
        { "<leader>fc", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Code symbols" },
        { "<leader>fn", function() require('telescope.builtin').find_files({find_command={'fd', vim.fn.expand("<cword>")}}) end, desc = "Word as filename" },

        -- Fallback searches (when LSP is stuck)
        { "<leader>fd", function()
            local word = vim.fn.expand("<cword>")
            require('telescope.builtin').grep_string({search = "^" .. word .. " ::", regex = true})
          end, desc = "Definition (Haskell ::)" },
        { "<leader>f=", function()
            local word = vim.fn.expand("<cword>")
            require('telescope.builtin').grep_string({search = "^" .. word .. " =", regex = true})
          end, desc = "Definition (= binding)" },
        { "<leader>fW", function()
            local word = vim.fn.expand("<cword>")
            require('telescope.builtin').grep_string({search = "\\b" .. word .. "\\b", regex = true})
          end, desc = "Word (exact match)" },
        { "<leader>fr", "<cmd>Telescope resume<cr>", desc = "Resume last search" },

        -- File explorer
        { "<leader>e", group = "Explorer" },
        { "<leader>ee", "<cmd>Telescope file_browser path=%:p:h select_buffer=true<cr>", desc = "Here" },
        { "<leader>er", "<cmd>Telescope file_browser<cr>", desc = "Root" },
        { "<leader>ey", "<cmd>Yazi<cr>", desc = "Yazi" },

        -- ══════════════════════════════════════════
        -- LSP (code intelligence)
        -- ══════════════════════════════════════════
        { "<leader>l", group = "LSP" },
        { "<leader>ld", vim.lsp.buf.definition, desc = "Definition" },
        { "<leader>lD", vim.lsp.buf.declaration, desc = "Declaration" },
        { "<leader>lt", vim.lsp.buf.type_definition, desc = "Type definition" },
        { "<leader>lr", "<cmd>Telescope lsp_references<cr>", desc = "References" },
        { "<leader>li", vim.lsp.buf.implementation, desc = "Implementation" },
        { "<leader>ln", vim.lsp.buf.rename, desc = "Rename" },
        { "<leader>la", vim.lsp.buf.code_action, desc = "Action" },
        { "<leader>lk", vim.lsp.buf.hover, desc = "Hover docs" },
        { "<leader>ls", vim.lsp.buf.signature_help, desc = "Signature" },
        { "<leader>lf", vim.lsp.buf.format, desc = "Format" },
        { "<leader>ll", vim.diagnostic.open_float, desc = "Line diagnostic" },
        { "<leader>lc", vim.lsp.codelens.run, desc = "Codelens" },
        { "<leader>lC", function() require('treesitter-context').toggle() end, desc = "Context (toggle)" },

        -- ══════════════════════════════════════════
        -- Git
        -- ══════════════════════════════════════════
        { "<leader>g", group = "Git" },
        { "<leader>go", "<cmd>DiffviewOpen<CR>", desc = "Open diff" },
        { "<leader>gq", function()
            local lib = require("diffview.lib")
            if #lib.views > 0 then
              local view = lib.views[1]
              if view and vim.api.nvim_tabpage_is_valid(view.tabpage) then
                vim.api.nvim_set_current_tabpage(view.tabpage)
              end
              vim.cmd("DiffviewClose")
              vim.notify("Review ended.")
            end
          end, desc = "End review" },
        { "<leader>gm", diffview_smart_toggle, desc = "Toggle diff vs base" },
        { "<leader>gh", "<cmd>DiffviewFileHistory --follow %<cr>", desc = "File history" },
        { "<leader>gl", "<Cmd>.DiffviewFileHistory --follow<CR>", desc = "Line history" },
        { "<leader>gr", "<cmd>DiffviewFileHistory<cr>", desc = "Repo history" },
        { "<leader>gv", "<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>", desc = "Selection history", mode = "v" },
        { "<leader>gt", "<cmd>DiffviewToggleFiles<CR>", desc = "Toggle files panel" },
        { "<leader>gs", "<cmd>Git<CR>", desc = "Status (fugitive)" },
        { "<leader>gb", "<cmd>Git blame<CR>", desc = "Blame" },

        -- ══════════════════════════════════════════
        -- Haskell
        -- ══════════════════════════════════════════
        { "<leader>h", group = "Haskell" },
        { "<leader>hh", "<cmd>Telescope hoogle<cr>", desc = "Hoogle search" },
        { "<leader>hs", "<cmd>Telescope ht hoogle_signature<CR>", desc = "Hoogle signature" },
        { "<leader>hf", "<cmd>Telescope ht package_files<CR>", desc = "Package files" },
        { "<leader>hg", "<cmd>Telescope ht package_grep<CR>", desc = "Package grep" },
        { "<leader>he", function() ht.lsp.buf_eval_all() end, desc = "Eval all" },
        { "<leader>hl", function() ht.log.nvim_open_logfile() end, desc = "Logs" },
        { "<leader>hL", function() ht.log.nvim_open_hls_logfile() end, desc = "HLS Logs" },

        -- GHCI/REPL
        { "<leader>hr", group = "REPL" },
        { "<leader>hrt", function() ht.repl.toggle() end, desc = "Toggle" },
        { "<leader>hrb", function() ht.repl.toggle(vim.api.nvim_buf_get_name(0)) end, desc = "Toggle (buffer)" },
        { "<leader>hrq", function() ht.repl.quit() end, desc = "Quit" },
        { "<leader>hrl", function() ht.repl.reload() end, desc = "Reload" },
        { "<leader>hrc", function() ht.repl.cword_type() end, desc = "Type of word" },
        { "<leader>hri", function() ht.repl.cword_info() end, desc = "Info on word" },

        -- GHCID
        { "<leader>hd", group = "GHCID" },
        { "<leader>hds", "<cmd>Ghcid -c 'cabal repl --enable-multi-repl all'<CR>", desc = "Start" },
        { "<leader>hdt", "<cmd>Ghcid<CR>", desc = "Toggle" },
        { "<leader>hdq", "<cmd>GhcidKill<CR>", desc = "Kill" },
        { "<leader>hdh", "<cmd>GhcidKill<CR><cmd>Hls start<CR>", desc = "Switch to HLS" },

        -- ══════════════════════════════════════════
        -- Trouble (diagnostics)
        -- ══════════════════════════════════════════
        { "<leader>x", group = "Trouble" },
        { "<leader>xx", "<cmd>TroubleToggle<CR>", desc = "Toggle" },
        { "<leader>xq", "<cmd>Trouble quickfix<CR>", desc = "Quickfix" },
        { "<leader>xw", "<cmd>Trouble workspace_diagnostics<CR>", desc = "Workspace" },
        { "<leader>xd", "<cmd>Trouble document_diagnostics<CR>", desc = "Document" },

        -- ══════════════════════════════════════════
        -- Bookmarks
        -- ══════════════════════════════════════════
        { "<leader>b", group = "Bookmarks" },
        { "<leader>bt", "<Plug>BookmarkToggle", desc = "Toggle" },
        { "<leader>ba", "<Plug>BookmarkAnnotate", desc = "Annotate" },
        { "<leader>bn", "<Plug>BookmarkNext", desc = "Next" },
        { "<leader>bp", "<Plug>BookmarkPrev", desc = "Previous" },
        { "<leader>bl", "<Plug>BookmarkShowAll", desc = "List all" },

        -- ══════════════════════════════════════════
        -- Clipboard (system)
        -- ══════════════════════════════════════════
        { "<leader>y", group = "Clipboard" },
        { "<leader>yy", '"+y', desc = "Yank to clipboard", mode = {"n", "v"} },
        { "<leader>yl", '"+yy', desc = "Yank line to clipboard" },
        { "<leader>yp", '"+p', desc = "Paste from clipboard" },
        { "<leader>yP", '"+P', desc = "Paste before from clipboard" },

        -- ══════════════════════════════════════════
        -- Text case
        -- ══════════════════════════════════════════
        { "<leader>t", group = "Text case" },

        -- ══════════════════════════════════════════
        -- Jump (flash.nvim)
        -- ══════════════════════════════════════════
        { "<leader>j", group = "Jump" },
        { "<leader>jj", function() require("flash").jump() end, desc = "Jump to" },
        { "<leader>jt", function() require("flash").treesitter() end, desc = "Treesitter select" },
        { "<leader>jw", function() require("flash").jump({pattern = vim.fn.expand("<cword>")}) end, desc = "Jump to word" },
        { "<leader>jl", function() require("flash").jump({search = {mode = "search", max_length = 0}, label = {after = {0, 0}}, pattern = "^"}) end, desc = "Jump to line" },
        { "<leader>js", "<Plug>(golden_ratio_resize)<CR>", desc = "Golden ratio resize" },
        { "<leader>jg", "<Plug>(golden_ratio_toggle)<CR>", desc = "Golden ratio toggle" },

        -- ══════════════════════════════════════════
        -- Quick actions (no submenu)
        -- ══════════════════════════════════════════
        { "<leader>?", show_cheat_sheet, desc = "Cheat sheet" },
        { "<leader>w", "<cmd>w<CR>", desc = "Save" },
        { "<leader>q", "<cmd>q<CR>", desc = "Quit" },
        { "<leader>-", "<cmd>Yazi<cr>", desc = "Yazi" },

        -- Navigate back/forward
        { "<leader>[", "<C-o>", desc = "Jump back" },
        { "<leader>]", "<C-i>", desc = "Jump forward" },

        -- ══════════════════════════════════════════
        -- AI (Claude Code)
        -- ══════════════════════════════════════════
        { "<leader>a", group = "AI (Claude)" },
        { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude terminal" },
        { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
        { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection" },
        { "<leader>ao", "<cmd>ClaudeCodeOpen<cr>", desc = "Open Claude" },
        { "<leader>aa", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current file" },

        -- Diff handling (no vimdiff knowledge needed!)
        { "<leader>ad", group = "Diff" },
        { "<leader>ady", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Yes - accept changes" },
        { "<leader>adn", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "No - reject changes" },
      })

      -- ══════════════════════════════════════════
      -- Claude Code setup
      -- ══════════════════════════════════════════
      require("snacks").setup({})
      require("claudecode").setup({
        auto_start = true,
        terminal = {
          split_side = "right",
          split_width_percentage = 0.4,
          provider = "snacks",
        },
      })

      -- Window navigation (works in both normal + terminal mode)
      vim.keymap.set({'n', 't'}, '<C-h>', '<C-\\><C-n><C-w>h', { desc = 'Window left' })
      vim.keymap.set({'n', 't'}, '<C-j>', '<C-\\><C-n><C-w>j', { desc = 'Window down' })
      vim.keymap.set({'n', 't'}, '<C-k>', '<C-\\><C-n><C-w>k', { desc = 'Window up' })
      vim.keymap.set({'n', 't'}, '<C-l>', '<C-\\><C-n><C-w>l', { desc = 'Window right' })

      -- Quick toggle between editor and Claude
      vim.keymap.set({'n', 't'}, '<C-;>', function()
        if vim.bo.buftype == 'terminal' then
          vim.cmd('wincmd p')
        else
          vim.cmd('ClaudeCodeFocus')
        end
      end, { desc = 'Toggle Claude/Editor' })

      -- Direct shortcuts for most common LSP actions (no leader needed)
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = 'Hover docs' })
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
      vim.keymap.set('n', 'gr', '<cmd>Telescope lsp_references<cr>', { desc = 'References' })
      vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, { desc = 'Type definition' })

      local telescope = require('telescope')

      -- Telescope highlight groups for better visibility
      vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = "#ff9e64", bold = true })
      vim.api.nvim_set_hl(0, "TelescopeResultsComment", { fg = "#565f89" })

      telescope.setup{
        defaults = {
          path_display = { "filename_first" },
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

      -- Flash.nvim setup
      require('flash').setup({
        labels = "asdfghjklqwertyuiopzxcvbnm",
        search = { mode = "fuzzy" },
        label = { uppercase = false },
        modes = {
          char = { enabled = true },  -- Enhanced f/t/F/T motions
          search = { enabled = false },  -- Don't integrate with / search
        },
      })

      -- Flash keymaps (s to jump, S for treesitter)
      vim.keymap.set({"n", "x", "o"}, "s", function() require("flash").jump() end, { desc = "Flash jump" })
      vim.keymap.set({"n", "x", "o"}, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })
      vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote flash" })

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

      require('treesitter-context').setup({
        max_lines = 5,
        multiline_threshold = 1,
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
          ['<S-Tab>'] = cmp.mapping.select_prev_item({behavior = cmp.SelectBehavior.Select}),
          ['<Tab>'] = cmp.mapping.select_next_item({behavior = cmp.SelectBehavior.Select}),
          ['<C-Space>'] = cmp.mapping.complete(),
        }
      }

      require('kanagawa').setup()
      require("kanagawa").load("wave")
    '';
    extraConfig = ''
      map <Space> <Leader>
      set number
      set nu rnu
      set mouse=nicr
      set diffopt+=vertical
      filetype plugin indent on

      command -nargs=+ LspHover lua vim.lsp.buf.hover()
      set keywordprg=:LspHover

      " Window resizing
      noremap <silent> <C-S-Left> :vertical resize -3<CR>
      noremap <silent> <C-S-Right> :vertical resize +3<CR>

      " GHCID
      let g:ghcid_background = 1

      " Terminal mappings
      tnoremap <A-Left> <m-b>
      tnoremap <A-Right> <m-f>
      tnoremap <Esc> <C-\\><C-n>

      " Golden ratio
      let g:golden_ratio_exclude_nonmodifiable = 1
      let g:golden_ratio_autocommand = 0

      autocmd TermOpen * setlocal nonumber norelativenumber
    '';
  };
}