---@tag telescope-file-browser.finders
---@config { ["module"] = "telescope-file-browser.finders" }

---@brief [[
--- The file browser finders power the picker with both a file and folder browser.
---@brief ]]

local fb_utils = require "telescope._extensions.file_browser.utils"
local fb_make_entry = require "telescope._extensions.file_browser.make_entry"

local async_oneshot_finder = require "telescope.finders.async_oneshot_finder"
local finders = require "telescope.finders"

local Path = require "plenary.path"

local fb_finders = {}
local has_fd = vim.fn.executable "fd" == 1


fb_finders.browse = function(opts)
  local cwd = opts.path
  local entry_maker = opts.entry_maker { cwd = cwd, display_stat = opts.display_stat }
  local fd_args = opts.fd_args or {}

  local args = opts.make_args(fd_args)

  return async_oneshot_finder {
    fn_command = function()
      return { command = "fd", args = args }
    end,
    entry_maker = entry_maker,
    results = {},
    cwd = cwd,
  }
end

--- Returns a finder that combines |fb_finders.browse_files| and |fb_finders.browse_folders| into a unified finder.
---@param opts table: options to pass to the picker
---@field path string: root dir to file_browse from (default: vim.loop.cwd())
---@field cwd string: root dir (default: vim.loop.cwd())
---@field cwd_to_path bool: folder browser follows `path` of file browser
---@field files boolean: start in file (true) or folder (false) browser (default: true)
---@field grouped boolean: group initial sorting by directories and then files; uses plenary.scandir (default: false)
---@field depth number: file tree depth to display (default: 1)
---@field hidden boolean: determines whether to show hidden files or not (default: false)
---@field respect_gitignore boolean: induces slow-down w/ plenary finder (default: false, true if `fd` available)
---@field hide_parent_dir boolean: hide `../` in the file browser (default: false)
---@field dir_icon string: change the icon for a directory (default: )
---@field dir_icon_hl string: change the highlight group of dir icon (default: "Default")
fb_finders.finder = function(opts)
  opts = opts or {}
  -- cache entries such that multi selections are maintained across {file, folder}_browsers
  -- otherwise varying metatables misalign selections
  opts.entry_cache = {}
  return setmetatable({
    display_stat = opts.display_stat,
    fd_args = opts.fd_args,
    make_args = opts.make_args,
    cwd_to_path = opts.cwd_to_path,
    cwd = opts.cwd_to_path and opts.path or opts.cwd, -- nvim cwd
    path = vim.F.if_nil(opts.path, opts.cwd), -- current path for file browser
    -- ensure we forward make_entry opts adequately
    entry_maker = vim.F.if_nil(opts.entry_maker, function(local_opts)
      return fb_make_entry(vim.tbl_extend("force", opts, local_opts))
    end),
    _browse = vim.F.if_nil(opts.browse_folders, fb_finders.browse),
    close = function(self)
      self._finder = nil
    end,
    prompt_title = opts.custom_prompt_title,
    results_title = opts.custom_results_title,
  }, {
    __call = function(self, ...)
      -- (re-)initialize finder on first start or refresh due to action
      if not self._finder then
        self._finder = self:_browse()
      end
      self._finder(...)
    end,
    __index = function(self, k)
      -- finder pass through for e.g. results
      if rawget(self, "_finder") then
        local finder_val = self._finder[k]
        if finder_val ~= nil then
          return finder_val
        end
      end
    end,
  })
end

return fb_finders
