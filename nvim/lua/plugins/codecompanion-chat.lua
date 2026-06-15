-- plugin: codecompanion.nvim
-- url: https://github.com/olimorris/codecompanion.nvim
-- description: AI coding assistant for Neovim with chat, inline prompts, and contextual actions.
--
return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/which-key.nvim",
    "stevearc/oil.nvim",
  },
  config = function()
    local persona = require("config.ai-behaviour")
    require("codecompanion").setup({

      opts = {
        system_prompt = function()
          return persona.system_prompt
        end,
      },

      strategies = {
        chat = {
          adapter = "copilot",
        },
        inline = {
          adapter = "copilot",
          keymaps = {
            accept_change = {
              modes = { n = "gda" },
              description = "Accept the suggested change",
            },
            reject_change = {
              modes = { n = "gdr" },
              description = "Reject the suggested change",
            },
          },
        },
        cmd = {
          adapter = "copilot",
        },
      },

      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = {
              api_key = "OPENAI_API_KEY",
            },
            schema = {
              model = {
                default = "gpt-5.4",
              },
            },
          })
        end,
      },
    })

    local prompt_cfg = require("config.ai-prompts")
    local prompts = prompt_cfg.prompts
    local order = prompt_cfg.order
    local bindings = prompt_cfg.bindings
    local descriptions = prompt_cfg.descriptions

    local function get_visual_selection()
      local mode = vim.fn.mode()

      if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
        return nil
      end

      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")

      local start_line = start_pos[2]
      local end_line = end_pos[2]

      if start_line > end_line then
        start_line, end_line = end_line, start_line
      end

      local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

      if not lines or vim.tbl_isempty(lines) then
        return nil
      end

      return table.concat(lines, "\n")
    end

    local function get_oil_context()
      if vim.bo.filetype ~= "oil" then
        return nil
      end

      local ok, oil = pcall(require, "oil")
      if not ok then
        return nil
      end

      local dir = oil.get_current_dir()
      if not dir then
        return nil
      end

      local entry = oil.get_cursor_entry()
      local path = dir

      if entry and entry.name and entry.name ~= ".." then
        path = vim.fs.joinpath(dir, entry.name)
      end

      local stat = vim.uv.fs_stat(path)

      if stat and stat.type == "directory" then
        return {
          kind = "directory",
          label = "directory",
          path = path,
          content = string.format("Use this directory as context:\n\n#glob:%s/**\n@CodeCompanion", path),
        }
      end

      if stat and stat.type == "file" then
        local ok_read, lines = pcall(vim.fn.readfile, path)

        if ok_read and lines then
          return {
            kind = "file",
            label = "file",
            path = path,
            filetype = vim.filetype.match({ filename = path }) or "",
            content = table.concat(lines, "\n"),
          }
        end
      end

      return {
        kind = "directory",
        label = "directory",
        path = dir,
        content = string.format("Use this directory as context:\n\n#glob:%s/**\n@CodeCompanion", dir),
      }
    end

    local function get_buffer_context()
      local path = vim.api.nvim_buf_get_name(0)
      local ft = vim.bo.filetype
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      return {
        kind = "buffer",
        label = "buffer",
        path = path ~= "" and path or "[No name]",
        filetype = ft,
        content = table.concat(lines, "\n"),
      }
    end

    local function resolve_context()
      local selected = get_visual_selection()

      if selected and selected ~= "" then
        return {
          kind = "selection",
          label = "selection",
          path = vim.api.nvim_buf_get_name(0),
          filetype = vim.bo.filetype,
          content = selected,
        }
      end

      local oil_ctx = get_oil_context()
      if oil_ctx then
        return oil_ctx
      end

      return get_buffer_context()
    end

    local function context_title(ctx)
      if ctx.kind == "selection" then
        return "selection"
      end

      if ctx.kind == "directory" then
        return "directory"
      end

      if ctx.kind == "file" then
        return "file"
      end

      return "buffer"
    end

    local function make_user_prompt(prompt, ctx)
      local title = context_title(ctx)

      if ctx.kind == "directory" then
        return table.concat({
          persona.behaviour_hint,
          "",
          prompt,
          "",
          "Context: " .. title,
          "Path: " .. ctx.path,
          "",
          ctx.content,
        }, "\n")
      end

      return table.concat({
        persona.behaviour_hint,
        "",
        prompt,
        "",
        "Context: " .. title,
        "Path: " .. (ctx.path or "[No name]"),
        "",
        "```" .. (ctx.filetype or ""),
        ctx.content,
        "```",
      }, "\n")
    end

    local function get_current_folder_context()
      local current_file = vim.api.nvim_buf_get_name(0)
      local dir

      if current_file ~= "" then
        dir = vim.fs.dirname(current_file)
      else
        dir = vim.uv.cwd()
      end

      return {
        kind = "directory",
        label = "directory",
        path = dir,
        content = string.format("Use this directory as project context:\n\n#glob:%s/**\n@CodeCompanion", dir),
      }
    end

    local function open_chat()
      local ctx = get_current_folder_context()

      require("codecompanion").chat({
        user_prompt = make_user_prompt(
          "The following is the current project directory context. Do not answer yet. Wait for my next message.",
          ctx
        ) .. "\n\n---\n\n❯  ",
        auto_submit = false,
      })
    end

    local function leave_visual_mode()
      if vim.fn.mode():match("[vV\22]") then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      end
    end

    local function run_prompt(name)
      local prompt = prompts[name]

      if not prompt then
        vim.notify("CodeCompanion prompt not found: " .. name, vim.log.levels.ERROR)
        return
      end

      local ctx = resolve_context()

      leave_visual_mode()

      vim.schedule(function()
        require("codecompanion").chat({
          user_prompt = make_user_prompt(prompt, ctx),
          auto_submit = true,
        })
      end)
    end

    local function make_quick_chat_prompt(ctx)
      if ctx.kind == "selection" then
        return table.concat({
          persona.behaviour_hint,
          "",
          "The following is the current visual selection. Use it as context for my next request.",
          "Do not answer yet. Wait for my next message.",
          "",
          "Context: selection",
          "Path: " .. (ctx.path or "[No name]"),
          "",
          "```" .. (ctx.filetype or ""),
          ctx.content,
          "```",
          "",
          "---",
          "",
          "❯  ",
        }, "\n")
      end

      return make_user_prompt("The following is the current context. Do not answer yet. Wait for my next message.", ctx)
        .. "\n\n---\n\n❯  "
    end

    local function quick_chat()
      local ctx = resolve_context()

      leave_visual_mode()

      vim.schedule(function()
        require("codecompanion").chat({
          user_prompt = make_quick_chat_prompt(ctx),
          auto_submit = false,
        })
      end)
    end

    local function inline_prompt()
      local ctx = resolve_context()

      leave_visual_mode()

      vim.ui.input({ prompt = "Inline edit ❯ " }, function(input)
        if not input or input == "" then
          return
        end

        vim.schedule(function()
          local escaped = vim.fn.escape(input, "|")

          if ctx.kind == "selection" then
            vim.cmd("'<,'>CodeCompanion " .. escaped)
            return
          end

          vim.cmd("CodeCompanion #{buffer} " .. escaped)
        end)
      end)
    end

    local function desc_for(base)
      local ctx = resolve_context()
      return base .. " " .. context_title(ctx)
    end

    local wk = require("which-key")

    wk.add({
      { "<leader>a", group = "AI", mode = "n" },
      { "<leader>a", group = "AI selection", mode = "v" },

      { "<leader>aa", open_chat, desc = "Open AI chat", mode = "n" },

      {
        "<leader>ai",
        inline_prompt,
        desc = function()
          return desc_for("Inline edit for")
        end,
        mode = { "n", "v" },
      },

      {
        "<leader>aq",
        quick_chat,
        desc = function()
          return desc_for("Quick chat for")
        end,
        mode = { "n", "v" },
      },

      { "<leader>ap", group = "AI prompts", mode = { "n", "v" } },
    })

    local prompt_mappings = {}

    for _, name in ipairs(order) do
      local key = bindings[name]
      local description = descriptions[name] or name

      table.insert(prompt_mappings, {
        "<leader>ap" .. key,
        function()
          run_prompt(name)
        end,
        desc = function()
          return desc_for(description .. " for")
        end,
        mode = { "n", "v" },
      })
    end

    wk.add(prompt_mappings)
  end,
}
