-- This file contains the configuration for integrating GitHub Copilot and Copilot Chat plugins in Neovim.

local context = require("config.copilot_context")
local prompt_meta = require("config.copilot_prompts")

-- Define prompts for Copilot
-- This table contains various prompts that can be used to interact with Copilot.
local prompts = {
  Explain = "Explain how the selected code works. Describe the main flow, important functions, inputs, outputs, and any non-obvious behavior.",
  Review = "Review the selected code and suggest improvements for readability, maintainability, performance, security, and idiomatic style. Explain the reasons behind each suggestion.",
  Tests = "Explain how the selected code works, then generate meaningful unit tests for it. Cover normal cases, edge cases, and possible error cases. Use the appropriate testing framework for the detected language.",
  Refactor = "Refactor the selected code to improve clarity, readability, maintainability, and idiomatic style. Preserve the existing behavior unless a bug is clearly present. Briefly explain the changes.",
  FixCode = "Fix the selected code so it works as intended. Identify the issue, explain the cause, and provide the corrected version. Preserve the original intent and avoid unnecessary changes.",
  FixError = "Explain the error in the following text, identify the likely cause, and provide a clear solution. Include corrected code or commands when applicable.",
  BetterNamings = "Suggest better names for the selected variables, functions, classes, or files. Prefer clear, idiomatic, and intention-revealing names. Explain the most important suggestions briefly.",
  Documentation = "Generate clear and concise documentation for the selected code. Use the idiomatic documentation format for the detected programming language. Include purpose, parameters, return values, errors/exceptions, side effects, and usage notes when helpful.",
  GoDocs = "Generate idiomatic Go doc comments for the selected Go code. Follow standard Go documentation conventions: exported identifiers should have comments that start with the identifier name. Describe what the code does, its behavior, parameters, return values, errors, side effects, and usage notes when helpful.",
  JsDocs = "Generate JSDoc comments for the selected JavaScript or TypeScript code. Include descriptions, parameters, return values, thrown errors, types, and examples when helpful.",
  DocumentationForGithub = "Generate GitHub-ready Markdown documentation for the selected code. Include an overview, usage instructions, API/reference details, examples, configuration notes, and any important caveats.",
  CreateAPost = "Create a deep, well-explained, easy-to-understand social media post about the selected code, suitable for LinkedIn. Make it engaging, educational, and slightly fun while keeping a professional tone.",
  SwaggerApiDocs = "Generate Swagger/OpenAPI documentation for the selected API. Include endpoints, methods, parameters, request bodies, responses, status codes, schemas, and examples when possible.",
  SwaggerGoDocs = "Generate Swagger/OpenAPI annotations for the selected Go API code using idiomatic Go comments, compatible with common Go Swagger tools such as swaggo/swag when possible. Include @Summary, @Description, @Tags, @Accept, @Produce, @Param, @Success, @Failure, and @Router annotations when applicable.",
  SwaggerJsDocs = "Generate JSDoc comments with Swagger/OpenAPI annotations for the selected API code. Include routes, methods, parameters, request bodies, responses, status codes, schemas, and examples when possible.",
  Summarize = "Summarize the following text clearly and concisely. Focus on the main ideas, important details, and conclusions.",
  Spelling = "Correct grammar, spelling, punctuation, and minor style issues in the following text. Preserve the original meaning and tone.",
  Wording = "Improve the grammar, wording, clarity, and flow of the following text. Preserve the original meaning, but make it sound more natural and polished.",
  Concise = "Rewrite the following text to make it more concise while preserving the key meaning, tone, and important details.",
}

local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    return nil
  end

  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
  return table.concat(lines, "\n")
end

local function get_oil_entry()
  if vim.bo.filetype ~= "oil" then
    return nil
  end

  local ok, oil = pcall(require, "oil")
  if not ok then
    return nil
  end

  local entry = oil.get_cursor_entry()
  local dir = oil.get_current_dir()
  if not entry or not dir then
    return nil
  end

  local path = dir .. entry.name
  local entry_type = entry.type == "directory" and "directory" or "file"

  return { path = path, type = entry_type }
end

local function resolve_current_context()
  local selection = get_visual_selection()
  local oil_entry = get_oil_entry()

  return context.resolve({
    has_selection = selection ~= nil,
    selection_text = selection,
    filetype = vim.bo.filetype,
    oil_entry_path = oil_entry and oil_entry.path or nil,
    oil_entry_type = oil_entry and oil_entry.type or nil,
    buffer_path = vim.api.nvim_buf_get_name(0),
  })
end

-- Plugin configuration
-- This table contains the configuration for various plugins used in Neovim.
return {
  {
    -- Copilot Chat plugin configuration
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = false,
    branch = "main",
    cmd = "CopilotChat",

    keys = function()
      local function ask_prompt(prompt_name)
        return function()
          local chat = require("CopilotChat")
          local resolved = resolve_current_context()
          chat.ask(context.compose(prompt_name, resolved))
        end
      end

      local function open_quick_chat()
        local chat = require("CopilotChat")
        local resolved = resolve_current_context()
        chat.open()
        if resolved and resolved.resource then
          chat.chat:add_message({ role = "user", content = resolved.resource }, true)
        end
        chat.chat:focus()
      end

      local keys = {
        { "<leader>a", group = "AI" },
        {
          "<leader>aa",
          function()
            require("CopilotChat").open()
          end,
          desc = "Open chat",
        },
        {
          "<leader>aq",
          open_quick_chat,
          desc = function()
            return context.describe("Quick chat", resolve_current_context())
          end,
          mode = { "n", "v" },
        },
        { "<leader>ap", group = "Prompts" },
      }

      for _, prompt_name in ipairs(prompt_meta.order) do
        table.insert(keys, {
          "<leader>ap" .. prompt_meta.bindings[prompt_name],
          ask_prompt(prompt_name),
          desc = function()
            local resolved = resolve_current_context()
            return context.describe(prompt_meta.descriptions[prompt_name], resolved)
          end,
          mode = { "n", "v" },
        })
      end

      return keys
    end,

    opts = {
      prompts = prompts,
      system_prompt = "Este GPT es un clon del usuario, un arquitecto líder backend especializado en Go, Java, Kafka y SQL, con experiencia en arquitectura limpia, arquitectura hexagonal y separación de lógica en aplicaciones escalables. Tiene un enfoque técnico pero práctico, con explicaciones claras y aplicables, siempre con ejemplos útiles para desarrolladores con conocimientos intermedios y avanzados.\n\nHabla con un tono profesional pero cercano, relajado y con un toque de humor inteligente. Evita formalidades excesivas y usa un lenguaje directo, técnico cuando es necesario, pero accesible. Su estilo es gallego, sin caer en clichés, y utiliza expresiones como “pues aquí estamos” o “dale que va” según el contexto.\n\nSus principales áreas de conocimiento incluyen:\n- Desarrollo Java, Go, Kafka, Spark (Python), SQL, ClickHouse, Kubernetes, Docker.\n- Arquitectura de software con enfoque en Clean Architecture, Hexagonal Architecure, Domain Driven Development y Sistemas distribuidos.\n- Implementación de buenas prácticas, testing unitario y end-to-end.\n- Loco por la modularización y atomic design \n- Herramientas de productividad como LazyVim, Tmux.\n- Mentoría y enseñanza de conceptos avanzados de forma clara y efectiva.\n\nA la hora de explicar un concepto técnico:\n1. Explica el problema que el usuario enfrenta.\n2. Propone una solución clara y directa, con ejemplos si aplica.\n3. Menciona herramientas o recursos que pueden ayudar.\n\nSi el tema es complejo, usa analogías prácticas, especialmente relacionadas con construcción y arquitectura. Si menciona una herramienta o concepto, explica su utilidad y cómo aplicarlo sin redundancias.\n\nSu estilo de comunicación es directo, pragmático y sin rodeos, pero siempre accesible y ameno.",
      model = "auto",
      answer_header = "󱗞  The Gentleman 󱗞  ",
      auto_insert_mode = true,
      window = {
        layout = "vertical",
      },
      mappings = {
        complete = {
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-l>",
          insert = "<C-l>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        toggle_sticky = {
          normal = "grr",
        },
        clear_stickies = {
          normal = "grx",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        jump_to_diff = {
          normal = "gj",
        },
        quickfix_answers = {
          normal = "gqa",
        },
        quickfix_diffs = {
          normal = "gqd",
        },
        yank_diff = {
          normal = "gy",
          register = '"', -- Default register to use for yanking
        },
        show_diff = {
          normal = "gd",
          full_diff = false, -- Show full diff instead of unified diff when showing diff window
        },
        show_info = {
          normal = "gi",
        },
        show_context = {
          normal = "gc",
        },
        show_help = {
          normal = "gh",
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")

      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-chat",
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = false
        end,
      })

      chat.setup(opts)
    end,
  },
  -- Blink integration
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      sources = {
        providers = {
          path = {
            -- Path sources triggered by "/" interfere with CopilotChat commands
            enabled = function()
              return vim.bo.filetype ~= "copilot-chat"
            end,
          },
        },
      },
    },
  },
}
