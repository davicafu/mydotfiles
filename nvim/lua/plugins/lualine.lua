-- Plugin: lualine.nvim
-- URL: https://github.com/nvim-lualine/lualine.nvim
-- Description: A fast and customizable statusline for Neovim.

local mode = {
  "mode",
  icon = "󱗞",
  fmt = function(s)
    local mode_map = {
      ["NORMAL"] = "N",
      ["O-PENDING"] = "N?",
      ["INSERT"] = "I",
      ["VISUAL"] = "V",
      ["V-BLOCK"] = "VB",
      ["V-LINE"] = "VL",
      ["V-REPLACE"] = "VR",
      ["REPLACE"] = "R",
      ["COMMAND"] = "!",
      ["SHELL"] = "SH",
      ["TERMINAL"] = "T",
      ["EX"] = "X",
      ["S-BLOCK"] = "SB",
      ["S-LINE"] = "SL",
      ["SELECT"] = "S",
      ["CONFIRM"] = "Y?",
      ["MORE"] = "M",
    }

    return mode_map[s] or s
  end,
}

local filename = {
  "filename",
  path = 1,
  symbols = {
    modified = " ●",
    readonly = " ",
    unnamed = "[No Name]",
    newfile = "[New]",
  },
}

local diagnostics = {
  "diagnostics",
  sources = { "nvim_diagnostic" },
  symbols = {
    error = " ",
    warn = " ",
    info = " ",
    hint = "󰌵 ",
  },
}

local lsp = function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    return ""
  end

  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end

  return " " .. table.concat(names, ",")
end

local diff = {
  "diff",
  symbols = {
    added = " ",
    modified = " ",
    removed = " ",
  },
}

local function oil_path()
  local ok, oil = pcall(require, "oil")
  if not ok then
    return ""
  end

  local dir = oil.get_current_dir()
  if not dir then
    return ""
  end

  return vim.fn.fnamemodify(dir, ":~")
end

local recording = {
  function()
    local reg = vim.fn.reg_recording()

    if reg == "" then
      return ""
    end

    return "󰑋 REC @" .. reg
  end,
  color = { fg = "#ff9e64", gui = "bold" },
}

return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },

    opts = {
      options = {
        theme = "auto",
        icons_enabled = true,
        globalstatus = true,
        component_separators = "",
        section_separators = "",
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
      },

      sections = {
        lualine_a = {
          mode,
        },

        lualine_b = {
          "branch",
        },

        lualine_c = {
          filename,
        },

        lualine_x = {
          recording,
          diagnostics,
          diff,
          lsp,
        },

        lualine_y = {
          "filetype",
          "encoding",
          "fileformat",
        },

        lualine_z = {
          "progress",
          "location",
        },
      },

      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          filename,
        },
        lualine_x = {
          "location",
        },
        lualine_y = {},
        lualine_z = {},
      },

      extensions = {
        "quickfix",

        {
          filetypes = { "oil" },

          sections = {
            lualine_a = {
              mode,
            },

            lualine_b = {
              oil_path,
            },

            lualine_c = {},

            lualine_x = {},

            lualine_y = {},

            lualine_z = {},
          },
        },
      },
    },
  },
}
