local M = {}

local PRETTIER = vim.fn.expand("~/.local/share/nvim/mason/packages/prettier/node_modules/prettier/bin/prettier.cjs")
local PLACEHOLDER_PREFIX = "__HTTP_JSON_TEMPLATE_"
local WRAPPER_PREFIX = "const __kulala_formatter_value = "
local WRAPPER_SUFFIX = ";"

local function has_backend()
  return vim.fn.executable("node") == 1 and vim.fn.filereadable(PRETTIER) == 1
end

local function get_body_kind(text)
  local i = 1
  local len = #text
  local state = "normal"

  while i <= len do
    local ch = text:sub(i, i)
    local next_ch = text:sub(i, i + 1)

    if state == "normal" then
      if ch:match("%s") then
        i = i + 1
      elseif next_ch == "//" then
        state = "line_comment"
        i = i + 2
      elseif next_ch == "/*" then
        state = "block_comment"
        i = i + 2
      else
        if ch == "{" then
          return "object"
        end
        if ch == "[" then
          return "array"
        end
        return nil
      end
    elseif state == "line_comment" then
      if ch == "\n" then
        state = "normal"
      end
      i = i + 1
    elseif state == "block_comment" then
      if next_ch == "*/" then
        state = "normal"
        i = i + 2
      else
        i = i + 1
      end
    end
  end

  return nil
end

local function protect_templates(text)
  local templates = {}
  local out = {}
  local i = 1
  local len = #text
  local state = "normal"

  while i <= len do
    local ch = text:sub(i, i)
    local next_ch = text:sub(i, i + 1)

    if state == "normal" then
      if next_ch == "{{" then
        local close = text:find("}}", i + 2, true)
        if not close then
          out[#out + 1] = ch
          i = i + 1
        else
          local id = #templates + 1
          templates[id] = text:sub(i, close + 1)
          out[#out + 1] = ('"%s%d__"'):format(PLACEHOLDER_PREFIX, id)
          i = close + 2
        end
      elseif next_ch == "//" then
        state = "line_comment"
        out[#out + 1] = next_ch
        i = i + 2
      elseif next_ch == "/*" then
        state = "block_comment"
        out[#out + 1] = next_ch
        i = i + 2
      elseif ch == '"' then
        state = "double_quote"
        out[#out + 1] = ch
        i = i + 1
      elseif ch == "'" then
        state = "single_quote"
        out[#out + 1] = ch
        i = i + 1
      else
        out[#out + 1] = ch
        i = i + 1
      end
    elseif state == "double_quote" then
      out[#out + 1] = ch
      if ch == "\\" and i < len then
        out[#out + 1] = text:sub(i + 1, i + 1)
        i = i + 2
      elseif ch == '"' then
        state = "normal"
        i = i + 1
      else
        i = i + 1
      end
    elseif state == "single_quote" then
      out[#out + 1] = ch
      if ch == "\\" and i < len then
        out[#out + 1] = text:sub(i + 1, i + 1)
        i = i + 2
      elseif ch == "'" then
        state = "normal"
        i = i + 1
      else
        i = i + 1
      end
    elseif state == "line_comment" then
      out[#out + 1] = ch
      if ch == "\n" then
        state = "normal"
      end
      i = i + 1
    elseif state == "block_comment" then
      out[#out + 1] = ch
      if next_ch == "*/" then
        out[#out + 1] = "/"
        state = "normal"
        i = i + 2
      else
        i = i + 1
      end
    end
  end

  return table.concat(out), templates
end

local function restore_templates(text, templates)
  for index, template in ipairs(templates) do
    local placeholder = ("%s%d__"):format(PLACEHOLDER_PREFIX, index)
    text = text:gsub(('"%s"'):format(placeholder), template)
    text = text:gsub(("'%s'"):format(placeholder), template)
  end

  return text
end

local function quote_object_keys(text)
  local lines = vim.split(text, "\n", { plain = true })

  for index, line in ipairs(lines) do
    if not line:match("^%s*//") then
      lines[index] = line:gsub('^(%s*)([$%a_][%w_$]*)(%s*:)', '%1"%2"%3')
    end
  end

  return table.concat(lines, "\n")
end

local function unwrap_formatted_output(text)
  local lines = vim.split(text, "\n", { plain = true })
  if #lines == 0 then
    return nil
  end

  if not vim.startswith(lines[1], WRAPPER_PREFIX) then
    return nil
  end

  lines[1] = lines[1]:gsub("^" .. vim.pesc(WRAPPER_PREFIX), "", 1)
  lines[#lines] = lines[#lines]:gsub(vim.pesc(WRAPPER_SUFFIX) .. "$", "", 1)

  if lines[#lines] == "" then
    table.remove(lines, #lines)
  end

  return table.concat(lines, "\n")
end

local function run_prettier(text)
  local wrapped = WRAPPER_PREFIX .. text .. WRAPPER_SUFFIX .. "\n"
  local result = vim.system({
    "node",
    PRETTIER,
    "--parser",
    "babel-ts",
    "--quote-props",
    "preserve",
    "--trailing-comma",
    "none",
  }, {
    text = true,
    stdin = wrapped,
  }):wait()

  if result.code ~= 0 or not result.stdout or result.stdout == "" then
    return nil
  end

  return unwrap_formatted_output(result.stdout:gsub("\n*$", ""))
end

function M.format_json_like_body(text)
  if not has_backend() or not get_body_kind(text) then
    return nil
  end

  local protected, templates = protect_templates(text)
  local formatted = run_prettier(protected)
  if not formatted then
    return nil
  end

  return restore_templates(quote_object_keys(formatted), templates)
end

return M
