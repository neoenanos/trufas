local function hardbreaks(block)
  return pandoc.walk_block(block, {
    SoftBreak = function()
      return pandoc.LineBreak()
    end
  })
end

local function process_quotes(block, inside_quote)
  if block.t ~= "BlockQuote" then
    return block
  end

  -- First process children
  local newcontent = {}

  for _, child in ipairs(block.content) do
    local result = process_quotes(child, true)

    if result.t then
      table.insert(newcontent, result)
    else
      for _, b in ipairs(result) do
        table.insert(newcontent, b)
      end
    end
  end

  block.content = newcontent

  -- This blockquote is the attribution (nested quote)
  if inside_quote and #block.content == 1 and block.content[1].t == "Para" then
    if FORMAT:match("latex") then
      return {
        pandoc.RawBlock("latex", "\\begin{flushright}\\upshape"),
        block.content[1],
        pandoc.RawBlock("latex", "\\end{flushright}")
      }
    end

    return block
  end

  -- This is a normal quote
  if FORMAT:match("latex") then
    return {
      pandoc.RawBlock("latex", "\\begin{itshape}"),
      block,
      pandoc.RawBlock("latex", "\\end{itshape}")
    }
  end

  return block
end

function Pandoc(doc)
  local newblocks = {}
  local i = 1
  local blocks = doc.blocks

  while i <= #blocks do
    local el = blocks[i]

    -- If this is a verse header
    if el.t == "Header" and el.classes:includes("verse") then

      -- Remove the class so it doesn't affect other formats
      local newclasses = {}
      for _, c in ipairs(el.classes) do
        if c ~= "verse" then
          table.insert(newclasses, c)
        end
      end
      el.classes = newclasses

      -- Output header first
      table.insert(newblocks, el)

      -- Open verse
      table.insert(newblocks, pandoc.RawBlock("latex", "\\begin{verse}"))

      i = i + 1

      -- Collect everything until the next header (any level)
      while i <= #blocks and blocks[i].t ~= "Header" do
        local nextel = blocks[i]

        -- Convert soft breaks inside paragraphs
        nextel = hardbreaks(nextel)

        table.insert(newblocks, nextel)
        i = i + 1
      end

      -- Close verse
      table.insert(newblocks, pandoc.RawBlock("latex", "\\end{verse}"))

    else
      table.insert(newblocks, el)
      i = i + 1
    end
  end

  local processed = {}

  for _, block in ipairs(newblocks) do
    local result = process_quotes(block, false)

    if result.t then
      table.insert(processed, result)
    else
      for _, b in ipairs(result) do
        table.insert(processed, b)
      end
    end
  end

  newblocks = processed

  return pandoc.Pandoc(newblocks, doc.meta)
end

function Div(el)

  if el.classes:includes("verse") then
    local blocks = {}

    table.insert(
      blocks,
      pandoc.RawBlock("latex", "\\begin{verse}")
    )

    for _, block in ipairs(el.content) do
      table.insert(blocks, hardbreaks(block))
    end

    table.insert(
      blocks,
      pandoc.RawBlock("latex", "\\end{verse}")
    )

    return blocks
  end


  if FORMAT:match("latex") and el.classes:includes("indent") then
    local blocks = {}

    table.insert(
      blocks,
      pandoc.RawBlock("latex", "{\\leftskip=2em")
    )

    for _, block in ipairs(el.content) do
      table.insert(blocks, hardbreaks(block))
    end

    table.insert(
      blocks,
      pandoc.RawBlock("latex", "}")
    )

    return blocks
  end

  return el
end

function Span(el)
  local indent = nil

  for _, class in ipairs(el.classes) do
    if class == "inline-indent" then
      indent = "2"   -- default
      break
    end

    indent = class:match("^inline%-indent%-(%d+)$")
    if indent then
      break
    end
  end

  if indent then
    return {
      pandoc.RawInline("latex", "\\hspace{" .. indent .. "em}"),
      pandoc.Span(el.content)
    }
  end
end