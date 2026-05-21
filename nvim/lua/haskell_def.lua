local M = {}

local LSP_TIMEOUT_MS = 1200

local choices_cache = nil

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Haskell def" })
end

local function is_haskell_buf(bufnr)
  local ft = vim.bo[bufnr or 0].filetype
  return ft == "haskell" or ft == "lhaskell"
end

local function dirname(path)
  if vim.fs and vim.fs.dirname then
    return vim.fs.dirname(path)
  end
  return vim.fn.fnamemodify(path, ":h")
end

local function project_root(path)
  path = path ~= "" and path or vim.api.nvim_buf_get_name(0)
  local start = path ~= "" and dirname(path) or vim.loop.cwd()
  if vim.fs and vim.fs.find then
    local found = vim.fs.find({ "hie.yaml", "cabal.project", "stack.yaml", ".git" }, {
      upward = true,
      path = start,
      limit = 1,
    })[1]
    if found then
      if found:match("/%.git$") then
        return dirname(found)
      end
      return dirname(found)
    end
  end
  local git_root = vim.fn.systemlist({ "git", "-C", start, "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error == 0 and git_root and git_root ~= "" then
    return git_root
  end
  return start
end

local function relative_path(path, root)
  if root and path:sub(1, #root) == root then
    local rel = path:sub(#root + 1)
    return rel:gsub("^/", "")
  end
  return path
end

local function current_module(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)) do
    local module_name = line:match("^%s*module%s+([A-Z][%w_'.]*)")
    if module_name then
      return module_name
    end
  end
  return nil
end

local function cache_file()
  return vim.fn.stdpath("data") .. "/haskell_def_choices.json"
end

local function load_choices()
  if choices_cache then
    return choices_cache
  end

  choices_cache = {}
  local ok_read, lines = pcall(vim.fn.readfile, cache_file())
  if not ok_read or type(lines) ~= "table" or #lines == 0 then
    return choices_cache
  end

  local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if ok_decode and type(decoded) == "table" then
    choices_cache = decoded
  end
  return choices_cache
end

local function save_choices()
  local path = cache_file()
  pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p")
  pcall(vim.fn.writefile, { vim.fn.json_encode(choices_cache or {}) }, path)
end

local function candidate_id(candidate)
  return table.concat({ candidate.path or "", candidate.row or 0, candidate.col or 0 }, ":")
end

local function choice_key(info)
  local current = vim.api.nvim_buf_get_name(0)
  local root = project_root(current)
  local module_name = current_module(0) or relative_path(current, root)
  return table.concat({ root, module_name, info.qualifier or "", info.symbol or "" }, "\t")
end

local function remembered_candidate(key, candidates)
  if not key then
    return nil
  end

  local saved = load_choices()[key]
  if not saved then
    return nil
  end

  for _, candidate in ipairs(candidates) do
    if candidate_id(candidate) == saved then
      return candidate
    end
  end

  load_choices()[key] = nil
  save_choices()
  return nil
end

local function remember_candidate(key, candidate)
  if not key then
    return
  end

  load_choices()[key] = candidate_id(candidate)
  save_choices()
end

local function name_char(ch)
  return ch ~= "" and ch:match("[%w_'.]") ~= nil
end

local function symbol_info_from_text(text)
  local full = vim.trim(text or "")
  full = full:gsub("^%.", ""):gsub("%.$", ""):gsub("^'+", "")
  full = full:gsub("^%(", ""):gsub("%)$", "")
  local qualifier, symbol = full:match("^(.*)%.([^%.]+)$")
  symbol = symbol or full
  return {
    full = full,
    qualifier = qualifier,
    symbol = symbol,
    row = 0,
    col = 0,
  }
end

local function current_symbol()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local idx = col + 1
  if idx > #line then
    idx = #line
  end
  if idx < 1 then
    idx = 1
  end
  if not name_char(line:sub(idx, idx)) and idx > 1 and name_char(line:sub(idx - 1, idx - 1)) then
    idx = idx - 1
  end

  local start_col = idx
  while start_col > 1 and name_char(line:sub(start_col - 1, start_col - 1)) do
    start_col = start_col - 1
  end

  local end_col = idx
  while end_col <= #line and name_char(line:sub(end_col, end_col)) do
    end_col = end_col + 1
  end

  local info = symbol_info_from_text(line:sub(start_col, end_col - 1))
  if info.full == "" then
    info = symbol_info_from_text(vim.fn.expand("<cword>"))
  end
  info.row = row
  info.col = start_col - 1
  return info
end

local function flatten_lsp_locations(result, out)
  out = out or {}
  if not result then
    return out
  end
  if result.uri or result.targetUri then
    table.insert(out, result)
    return out
  end
  if vim.tbl_islist(result) then
    for _, item in ipairs(result) do
      flatten_lsp_locations(item, out)
    end
  end
  return out
end

local function try_lsp()
  local ok_params, params = pcall(vim.lsp.util.make_position_params, 0, "utf-8")
  if not ok_params then
    params = vim.lsp.util.make_position_params()
  end

  local responses = vim.lsp.buf_request_sync(0, "textDocument/definition", params, LSP_TIMEOUT_MS)
  local locations = {}
  for _, response in pairs(responses or {}) do
    flatten_lsp_locations(response.result, locations)
  end

  if #locations == 0 then
    return false
  end

  local ok, jumped = pcall(vim.lsp.util.jump_to_location, locations[1], "utf-8", true)
  return ok and jumped ~= false
end

local symbol_kind_names = {
  [1] = "file",
  [2] = "module",
  [3] = "namespace",
  [4] = "package",
  [5] = "class",
  [6] = "method",
  [7] = "property",
  [8] = "field",
  [9] = "constructor",
  [10] = "enum",
  [11] = "interface",
  [12] = "function",
  [13] = "variable",
  [14] = "constant",
  [15] = "string",
  [16] = "number",
  [17] = "boolean",
  [18] = "array",
  [19] = "object",
  [20] = "key",
  [21] = "null",
  [22] = "enum_member",
  [23] = "struct",
  [24] = "event",
  [25] = "operator",
  [26] = "type_parameter",
}

local function lsp_clean_name(text)
  text = vim.trim(text or "")
  text = text:gsub("^%(", ""):gsub("%)$", "")
  text = text:gsub("^'+", "")
  local tail = text:match("%.([^%.]+)$")
  return tail or text
end

local function lsp_pattern_escape(text)
  return (text:gsub("([^%w])", "%%%1"))
end

local function lsp_symbol_kind(kind)
  local name = symbol_kind_names[kind] or "symbol"
  if name == "class" or name == "struct" or name == "interface" or name == "enum" or name == "type_parameter" then
    return "type"
  elseif name == "constructor" or name == "enum_member" then
    return "constructor"
  elseif name == "field" or name == "property" then
    return "field"
  end
  return "value"
end

local function lsp_location_to_candidate(item, info)
  local location = item.location or item
  local uri = location.uri or location.targetUri
  if not uri then
    return nil
  end

  local range = location.range or location.targetSelectionRange or location.targetRange or {}
  local start = range.start or {}
  local path = vim.uri_to_fname(uri)
  local name = lsp_clean_name(item.name or info.symbol)
  if name ~= info.symbol and not (item.name or ""):match("%." .. lsp_pattern_escape(info.symbol) .. "$") then
    return nil
  end

  return {
    path = path,
    row = start.line or 0,
    col = start.character or 0,
    kind = lsp_symbol_kind(item.kind),
    score = name == info.symbol and 125 or 110,
    source = "hls",
    text = table.concat(vim.tbl_filter(function(part)
      return part and part ~= ""
    end, { item.name, item.containerName }), "  "),
  }
end

local function lsp_workspace_symbol_candidates(info)
  local responses = vim.lsp.buf_request_sync(0, "workspace/symbol", { query = info.symbol }, LSP_TIMEOUT_MS)
  local candidates = {}
  for _, response in pairs(responses or {}) do
    local result = response.result or {}
    for _, item in ipairs(result) do
      local candidate = lsp_location_to_candidate(item, info)
      if candidate then
        table.insert(candidates, candidate)
      end
    end
  end
  return candidates
end

local function lsp_reference_candidate(location, info)
  local uri = location.uri or location.targetUri
  if not uri then
    return nil
  end

  local range = location.range or location.targetSelectionRange or location.targetRange or {}
  local start = range.start or {}
  return {
    path = vim.uri_to_fname(uri),
    row = start.line or 0,
    col = start.character or 0,
    kind = "reference",
    score = 120,
    source = "hls",
    text = info.symbol,
  }
end

local function lsp_reference_candidates(info)
  local ok_params, params = pcall(vim.lsp.util.make_position_params, 0, "utf-8")
  if not ok_params then
    params = vim.lsp.util.make_position_params()
  end
  params.context = { includeDeclaration = false }

  local responses = vim.lsp.buf_request_sync(0, "textDocument/references", params, LSP_TIMEOUT_MS)
  local candidates = {}
  for _, response in pairs(responses or {}) do
    local locations = flatten_lsp_locations(response.result)
    for _, location in ipairs(locations) do
      local candidate = lsp_reference_candidate(location, info)
      if candidate then
        table.insert(candidates, candidate)
      end
    end
  end
  return candidates
end

local function location_key()
  local pos = vim.api.nvim_win_get_cursor(0)
  return table.concat({ vim.api.nvim_buf_get_name(0), pos[1], pos[2] }, ":")
end

local function taglist_for_symbol(symbol)
  local pattern = "\\C^" .. vim.fn.escape(symbol, [[\^$.*[]~]]) .. "$"
  local tags = vim.fn.taglist(pattern)
  if type(tags) ~= "table" then
    return {}
  end
  return tags
end

local function try_tags(symbol)
  if not symbol or symbol == "" then
    return false
  end

  local tags = taglist_for_symbol(symbol)
  if #tags == 0 then
    return false
  end

  local before = location_key()
  local ok = pcall(vim.cmd, "tag " .. vim.fn.escape(symbol, [[\ ]]))
  if ok and location_key() ~= before then
    return true
  end

  local tag = tags[1]
  if tag and tag.filename and tag.filename ~= "" then
    vim.cmd("edit " .. vim.fn.fnameescape(tag.filename))
    if tag.line and tonumber(tag.line) then
      vim.api.nvim_win_set_cursor(0, { tonumber(tag.line), 0 })
    elseif tag.cmd and tag.cmd ~= "" then
      pcall(vim.fn.search, tag.cmd:gsub("^/", ""):gsub("/$", ""), "w")
    end
    vim.cmd("normal! zvzz")
    return true
  end

  return false
end

local function tag_path(filename)
  if not filename or filename == "" then
    return nil
  end
  if filename:sub(1, 1) == "/" then
    return filename
  end
  return project_root(vim.api.nvim_buf_get_name(0)) .. "/" .. filename
end

local function tags_candidates(info)
  local candidates = {}
  for _, tag in ipairs(taglist_for_symbol(info.symbol)) do
    local path = tag_path(tag.filename)
    if path and vim.fn.filereadable(path) == 1 then
      local row = math.max(0, (tonumber(tag.line) or 1) - 1)
      table.insert(candidates, {
        path = path,
        row = row,
        col = 0,
        kind = tag.kind or "tag",
        score = 115,
        source = "ctags",
        text = tag.name or info.symbol,
      })
    end
  end
  return candidates
end

local function node_text(node, source)
  local ok, text = pcall(vim.treesitter.get_node_text, node, source)
  if not ok or not text then
    return ""
  end
  return vim.trim(text)
end

local function clean_name(text)
  text = vim.trim(text or "")
  text = text:gsub("^%(", ""):gsub("%)$", "")
  text = text:gsub("^'+", "")
  local tail = text:match("%.([^%.]+)$")
  return tail or text
end

local function field_nodes(node, field)
  local ok, nodes = pcall(node.field, node, field)
  if ok and nodes then
    return nodes
  end
  return {}
end

local leaf_name_types = {
  constructor = true,
  constructor_operator = true,
  field_name = true,
  name = true,
  prefix_id = true,
  variable = true,
}

local function collect_matching_names(node, source, symbol, out)
  if not node then
    return
  end
  if leaf_name_types[node:type()] and clean_name(node_text(node, source)) == symbol then
    table.insert(out, node)
  end
  for i = 0, node:named_child_count() - 1 do
    collect_matching_names(node:named_child(i), source, symbol, out)
  end
end

local function add_field_matches(candidates, path, source, container, fields, symbol, kind, score)
  for _, field in ipairs(fields) do
    for _, node in ipairs(field_nodes(container, field)) do
      local matches = {}
      collect_matching_names(node, source, symbol, matches)
      for _, match in ipairs(matches) do
        local row, col = match:range()
        table.insert(candidates, {
          path = path,
          row = row,
          col = col,
          kind = kind,
          score = score,
          source = "treesitter",
          text = vim.split(node_text(container, source), "\n", { plain = true })[1],
        })
      end
    end
  end
end

local type_decl_nodes = {
  class = true,
  data_family = true,
  data_type = true,
  kind_signature = true,
  newtype = true,
  type_family = true,
  type_instance = true,
  type_synomym = true,
}

local value_decl_nodes = {
  bind = true,
  ["function"] = true,
  signature = true,
}

local constructor_decl_nodes = {
  data_constructor = true,
  gadt_constructor = true,
  newtype_constructor = true,
}

local function scan_ts_defs(node, source, path, symbol, candidates)
  local typ = node:type()
  if type_decl_nodes[typ] then
    add_field_matches(candidates, path, source, node, { "name" }, symbol, "type", 90)
  elseif value_decl_nodes[typ] then
    add_field_matches(candidates, path, source, node, { "name", "names", "synonym" }, symbol, "value", 80)
  elseif constructor_decl_nodes[typ] then
    add_field_matches(candidates, path, source, node, { "constructor", "name", "names" }, symbol, "constructor", 100)
  elseif typ == "field" then
    add_field_matches(candidates, path, source, node, { "name" }, symbol, "field", 75)
  end

  for i = 0, node:named_child_count() - 1 do
    scan_ts_defs(node:named_child(i), source, path, symbol, candidates)
  end
end

local function scan_file_with_treesitter(path, symbol)
  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then
    return {}
  end
  local stat = vim.loop.fs_fstat(fd)
  local text = vim.loop.fs_read(fd, stat.size, 0) or ""
  vim.loop.fs_close(fd)

  local ok_parser, parser = pcall(vim.treesitter.get_string_parser, text, "haskell")
  if not ok_parser or not parser then
    return {}
  end
  local ok_parse, trees = pcall(parser.parse, parser)
  if not ok_parse or not trees or not trees[1] then
    return {}
  end

  local candidates = {}
  scan_ts_defs(trees[1]:root(), text, path, symbol, candidates)
  return candidates
end

local function import_aliases(bufnr)
  local aliases = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local qualified, alias = line:match("^%s*import%s+qualified%s+([A-Z][%w_'.]*)%s+as%s+([A-Z][%w_']*)")
    if qualified and alias then
      aliases[alias] = qualified
    end
    local mod = line:match("^%s*import%s+qualified%s+([A-Z][%w_'.]*)")
    if mod then
      aliases[mod] = mod
    end
    mod = line:match("^%s*import%s+([A-Z][%w_'.]*)")
    if mod then
      aliases[mod] = mod
    end
  end
  return aliases
end

local function valid_haskell_path(path)
  return path
    and path ~= ""
    and (path:match("%.hs$") or path:match("%.lhs$") or path:match("%.hs%-boot$"))
    and not path:match("/dist%-newstyle/")
    and not path:match("/%.stack%-work/")
    and not path:match("/%.direnv/")
    and not path:match("/vendor/")
end

local function add_unique_file(files, seen, path)
  if valid_haskell_path(path) and not seen[path] then
    seen[path] = true
    table.insert(files, path)
  end
end

local function module_files(root, module_name)
  if not module_name or module_name == "" or not module_name:match("^[A-Z]") then
    return {}
  end
  local rel = module_name:gsub("%.", "/")
  local files = {}
  for _, ext in ipairs({ ".hs", ".lhs", ".hs-boot" }) do
    for _, path in ipairs(vim.fn.globpath(root, "**/" .. rel .. ext, false, true)) do
      if valid_haskell_path(path) then
        table.insert(files, path)
      end
    end
  end
  return files
end

local function treesitter_candidates(info)
  local current = vim.api.nvim_buf_get_name(0)
  local root = project_root(current)
  local files, seen = {}, {}
  add_unique_file(files, seen, current)

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and is_haskell_buf(bufnr) then
      add_unique_file(files, seen, vim.api.nvim_buf_get_name(bufnr))
    end
  end

  if info.qualifier and info.qualifier ~= "" then
    local aliases = import_aliases(0)
    local module_name = aliases[info.qualifier] or info.qualifier
    for _, path in ipairs(module_files(root, module_name)) do
      add_unique_file(files, seen, path)
    end
  end

  local candidates = {}
  for _, path in ipairs(files) do
    for _, candidate in ipairs(scan_file_with_treesitter(path, info.symbol)) do
      if path == current then
        candidate.score = candidate.score + 20
      end
      table.insert(candidates, candidate)
    end
  end
  return candidates
end

local function rg_escape(text)
  return (text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%{}|\\])", "\\%1"))
end

local function lua_pattern_escape(text)
  return (text:gsub("([^%w])", "%%%1"))
end

local function ripgrep_patterns(symbol)
  local s = rg_escape(symbol)
  if symbol:match("^[A-Z]") then
    return {
      "^\\s*(data|newtype|type|class)\\s+" .. s .. "\\b",
      "^\\s*(type\\s+family|data\\s+family)\\s+" .. s .. "\\b",
      "^\\s*pattern\\s+" .. s .. "\\b",
      "^\\s*" .. s .. "\\s*::",
      "^\\s*(\\||=)\\s*" .. s .. "\\b",
      "\\b(=|\\|)\\s*" .. s .. "\\b",
      "\\b" .. s .. "\\b\\s*(,|::)",
    }
  end
  return {
    "^\\s*,?\\s*" .. s .. "\\s*::",
    "^\\s*" .. s .. "\\b.*=",
    "^\\s*let\\s+" .. s .. "\\b",
    "^\\s*" .. s .. "\\s*<-",
  }
end

local function ripgrep_candidates(info)
  if vim.fn.executable("rg") == 0 then
    return {}
  end

  local current = vim.api.nvim_buf_get_name(0)
  local root = project_root(current)
  local regex = table.concat(ripgrep_patterns(info.symbol), "|")
  local args = {
    "rg",
    "--vimgrep",
    "--no-heading",
    "--color", "never",
    "--glob", "*.hs",
    "--glob", "*.lhs",
    "--glob", "*.hs-boot",
    "--glob", "!dist-newstyle/**",
    "--glob", "!.stack-work/**",
    "--glob", "!.direnv/**",
    "--glob", "!vendor/**",
    regex,
    root,
  }
  local lines = vim.fn.systemlist(args)
  if vim.v.shell_error > 1 then
    return {}
  end

  local candidates, seen = {}, {}
  for _, line in ipairs(lines) do
    local path, lnum, _col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if path and valid_haskell_path(path) then
      local key = path .. ":" .. lnum
      if not seen[key] then
        seen[key] = true
        local start_col = (text:find(info.symbol, 1, true) or 1) - 1
        local score = 50
        local escaped = lua_pattern_escape(info.symbol)
        if path == current then
          score = score + 20
        end
        if text:match("^%s*[|=]%s*" .. escaped .. "%f[%W]") then
          score = score + 45
        elseif text:match("^%s*" .. escaped .. "%s*::") then
          score = score + 35
        elseif text:match("^%s*data%s+") or text:match("^%s*newtype%s+") then
          score = score + 30
        end
        table.insert(candidates, {
          path = path,
          row = tonumber(lnum) - 1,
          col = start_col,
          kind = "regex",
          score = score,
          source = "ripgrep",
          text = text,
        })
      end
    end
  end
  return candidates
end

local function reference_ripgrep_pattern(info)
  local symbol = rg_escape(info.symbol)
  local full = info.full and info.full ~= info.symbol and rg_escape(info.full) or nil
  local body = full and (full .. "|" .. symbol) or symbol
  return "(^|[^[:alnum:]_'])(" .. body .. ")($|[^[:alnum:]_'])"
end

local function ripgrep_reference_candidates(info)
  if vim.fn.executable("rg") == 0 then
    return {}
  end

  local root = project_root(vim.api.nvim_buf_get_name(0))
  local args = {
    "rg",
    "--vimgrep",
    "--no-heading",
    "--color", "never",
    "--glob", "*.hs",
    "--glob", "*.lhs",
    "--glob", "*.hs-boot",
    "--glob", "!dist-newstyle/**",
    "--glob", "!.stack-work/**",
    "--glob", "!.direnv/**",
    "--glob", "!vendor/**",
    reference_ripgrep_pattern(info),
    root,
  }
  local lines = vim.fn.systemlist(args)
  if vim.v.shell_error > 1 then
    return {}
  end

  local candidates = {}
  for _, line in ipairs(lines) do
    local path, lnum, _col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if path and valid_haskell_path(path) then
      local start_col = (text:find(info.full, 1, true) or text:find(info.symbol, 1, true) or 1) - 1
      table.insert(candidates, {
        path = path,
        row = tonumber(lnum) - 1,
        col = start_col,
        kind = "reference",
        score = 70,
        source = "ripgrep",
        text = text,
      })
    end
  end
  return candidates
end

local function candidate_sort(a, b)
  if a.score ~= b.score then
    return a.score > b.score
  end
  if a.path ~= b.path then
    return a.path < b.path
  end
  return a.row < b.row
end

local function dedupe_candidates(candidates)
  table.sort(candidates, candidate_sort)
  local out, seen = {}, {}
  for _, candidate in ipairs(candidates) do
    local key = candidate_id(candidate)
    if not seen[key] then
      seen[key] = true
      table.insert(out, candidate)
    end
  end
  return out
end

local function jump_candidate(candidate)
  if not candidate or not candidate.path or candidate.path == "" then
    return false
  end

  local ok = pcall(function()
    vim.cmd("normal! m'")
    local bufnr = vim.fn.bufadd(candidate.path)
    vim.fn.bufload(bufnr)
    vim.api.nvim_win_set_buf(0, bufnr)

    local row = math.max(1, math.min((candidate.row or 0) + 1, vim.api.nvim_buf_line_count(bufnr)))
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    local col = math.max(0, math.min(candidate.col or 0, #line))
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.cmd("normal! zvzz")
  end)
  return ok
end

local function set_quickfix(candidates, title)
  local items = {}
  for _, c in ipairs(candidates) do
    table.insert(items, {
      filename = c.path,
      lnum = c.row + 1,
      col = (c.col or 0) + 1,
      text = string.format("[%s:%s score=%s] %s", c.source, c.kind, c.score, c.text or ""),
    })
  end
  vim.fn.setqflist({}, " ", { title = title, items = items })
end

local file_line_cache = {}

local function file_lines(path)
  if file_line_cache[path] then
    return file_line_cache[path]
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    lines = {}
  end
  file_line_cache[path] = lines
  return lines
end

local function compact(text, max_len)
  text = vim.trim(text or ""):gsub("%s+", " ")
  if #text <= max_len then
    return text
  end
  return text:sub(1, max_len - 1) .. "…"
end

local function short_path(path, root)
  local rel = relative_path(path, root)
  local parts = vim.split(rel, "/", { plain = true })
  if #parts <= 4 then
    return rel
  end
  return table.concat({ parts[1], "…", parts[#parts - 2], parts[#parts - 1], parts[#parts] }, "/")
end

local function context_line(candidate)
  local lines = file_lines(candidate.path)
  local lnum = (candidate.row or 0) + 1
  local line = compact(lines[lnum] or candidate.text or "", 90)
  local header = nil

  for i = lnum, math.max(1, lnum - 120), -1 do
    local text = lines[i] or ""
    if text:match("^%S")
      and not text:match("^module%s")
      and not text:match("^import%s")
      and not text:match("^{%-") then
      header = compact(text, 55)
      break
    end
  end

  if header and header ~= "" and header ~= line then
    return header .. "  ›  " .. line
  end
  return line
end

local function kind_label(candidate)
  if candidate.kind == "reference" then
    return "REF"
  elseif candidate.source == "ctags" then
    return "TAG"
  elseif candidate.kind == "type" then
    return "TYPE"
  elseif candidate.kind == "constructor" then
    return "CTOR"
  elseif candidate.kind == "value" then
    return "VAL"
  elseif candidate.kind == "field" then
    return "FIELD"
  end
  return "REGEX"
end

local function format_candidate(candidate, root)
  return string.format(
    "%-6s %-68s %s:%d",
    kind_label(candidate),
    compact(context_line(candidate), 68),
    short_path(candidate.path, root),
    candidate.row + 1
  )
end

local function preview_lines(candidate, root)
  local lines = file_lines(candidate.path)
  local lnum = (candidate.row or 0) + 1
  local from = math.max(1, lnum - 12)
  local to = math.min(#lines, lnum + 18)
  local out = {
    string.format(
      "-- %s:%d:%d  [%s/%s score=%s]",
      relative_path(candidate.path, root),
      lnum,
      (candidate.col or 0) + 1,
      candidate.source,
      candidate.kind,
      candidate.score
    ),
    "",
  }

  for i = from, to do
    local marker = i == lnum and "▶" or " "
    table.insert(out, string.format("%s %5d │ %s", marker, i, lines[i] or ""))
  end

  return out, lnum - from + 3
end

local function candidate_previewer(previewers, root, title)
  local ns = vim.api.nvim_create_namespace("haskell_def_preview")
  return previewers.new_buffer_previewer({
    title = title or "Definition preview",
    define_preview = function(self, entry)
      local candidate = entry.value
      local bufnr = self.state.bufnr
      local lines, target_preview_row = preview_lines(candidate, root)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].filetype = "haskell"
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      vim.api.nvim_buf_add_highlight(bufnr, ns, "Search", target_preview_row - 1, 0, -1)
      pcall(vim.api.nvim_win_set_cursor, self.state.winid, { target_preview_row, 0 })
    end,
  })
end

local function pick_with_telescope(candidates, title, key)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return false
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local previewers = require("telescope.previewers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local root = project_root(vim.api.nvim_buf_get_name(0))

  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = candidates,
      entry_maker = function(candidate)
        local display = format_candidate(candidate, root)
        return {
          value = candidate,
          display = display,
          ordinal = display,
          filename = candidate.path,
          lnum = candidate.row + 1,
          col = (candidate.col or 0) + 1,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = candidate_previewer(previewers, root, title .. " preview"),
    layout_strategy = "horizontal",
    layout_config = {
      width = 0.98,
      height = 0.85,
      preview_width = 0.58,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection or not selection.value then
          return
        end
        remember_candidate(key, selection.value)
        if not jump_candidate(selection.value) then
          notify("Jump failed: " .. format_candidate(selection.value, root), vim.log.levels.ERROR)
        end
      end)
      return true
    end,
  }):find()

  return true
end

local function pick_with_ui_select(candidates, title, key)
  local root = project_root(vim.api.nvim_buf_get_name(0))
  vim.ui.select(candidates, {
    prompt = title,
    format_item = function(candidate)
      return format_candidate(candidate, root)
    end,
  }, function(candidate)
    if not candidate then
      return
    end
    remember_candidate(key, candidate)
    if not jump_candidate(candidate) then
      notify("Jump failed: " .. format_candidate(candidate, root), vim.log.levels.ERROR)
    end
  end)
  return true
end

local function resolve_candidates(candidates, title, key)
  candidates = dedupe_candidates(candidates)
  if #candidates == 0 then
    return false
  end

  set_quickfix(candidates, title)

  local remembered = remembered_candidate(key, candidates)
  if remembered then
    if jump_candidate(remembered) then
      notify(title .. ": remembered")
      return true
    end
    load_choices()[key] = nil
    save_choices()
  end

  if #candidates == 1 then
    remember_candidate(key, candidates[1])
    if jump_candidate(candidates[1]) then
      notify(title .. ": jumped")
      return true
    end
    notify("Jump failed: " .. title, vim.log.levels.ERROR)
    return true
  end

  if pick_with_telescope(candidates, title, key) then
    return true
  end
  return pick_with_ui_select(candidates, title, key)
end

local function resolve_references(candidates, title)
  candidates = dedupe_candidates(candidates)
  if #candidates == 0 then
    return false
  end

  set_quickfix(candidates, title)

  if #candidates == 1 then
    if jump_candidate(candidates[1]) then
      notify(title .. ": 1 reference")
      return true
    end
    notify("Jump failed: " .. title, vim.log.levels.ERROR)
    return true
  end

  if pick_with_telescope(candidates, title, nil) then
    return true
  end
  return pick_with_ui_select(candidates, title, nil)
end

local function list_extend(target, source)
  for _, item in ipairs(source or {}) do
    table.insert(target, item)
  end
  return target
end

local function lookup_info(info)
  if not info.symbol or info.symbol == "" then
    notify("No Haskell symbol given", vim.log.levels.WARN)
    return true
  end

  local candidates = {}
  list_extend(candidates, lsp_workspace_symbol_candidates(info))
  list_extend(candidates, tags_candidates(info))
  list_extend(candidates, treesitter_candidates(info))
  list_extend(candidates, ripgrep_candidates(info))

  if resolve_candidates(candidates, "lookup " .. info.symbol, choice_key(info)) then
    return true
  end

  notify("No definition found for " .. info.symbol, vim.log.levels.WARN)
  return true
end

function M.references()
  if not is_haskell_buf(0) then
    vim.lsp.buf.references()
    return
  end

  local info = current_symbol()
  if not info.symbol or info.symbol == "" then
    notify("No Haskell symbol under cursor", vim.log.levels.WARN)
    return
  end

  local candidates = lsp_reference_candidates(info)
  if #candidates > 0 and resolve_references(candidates, "references " .. info.symbol) then
    return
  end

  if resolve_references(ripgrep_reference_candidates(info), "ripgrep refs " .. info.symbol) then
    return
  end

  notify("No references found for " .. info.symbol, vim.log.levels.WARN)
end

function M.lookup_symbol()
  local default = current_symbol().full
  vim.ui.input({
    prompt = "Haskell symbol: ",
    default = default ~= "" and default or nil,
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    lookup_info(symbol_info_from_text(input))
  end)
end

function M.goto()
  if not is_haskell_buf(0) then
    vim.lsp.buf.definition()
    return
  end

  local info = current_symbol()
  if not info.symbol or info.symbol == "" then
    notify("No Haskell symbol under cursor", vim.log.levels.WARN)
    return
  end

  if try_lsp() then
    return
  end
  if try_tags(info.symbol) then
    return
  end

  local key = choice_key(info)
  if resolve_candidates(treesitter_candidates(info), "treesitter " .. info.symbol, key) then
    return
  end
  if resolve_candidates(ripgrep_candidates(info), "ripgrep " .. info.symbol, key) then
    return
  end

  notify("No definition found for " .. info.symbol, vim.log.levels.WARN)
end

function M.debug()
  local info = current_symbol()
  local key = choice_key(info)
  local current = vim.api.nvim_buf_get_name(0)
  print(vim.inspect({
    symbol = info,
    key = key,
    remembered = load_choices()[key],
    root = project_root(current),
    treesitter_candidates = treesitter_candidates(info),
    ripgrep_candidates = ripgrep_candidates(info),
  }))
end

function M.clear_cache()
  choices_cache = {}
  save_choices()
  notify("Cleared remembered Haskell definitions")
end

return M
