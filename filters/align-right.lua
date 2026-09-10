function Div(el)
  if not el.classes:includes("align-right") then
    return el
  end

  if FORMAT:match("latex") then
    local blocks = {
      pandoc.RawBlock("latex", "\\begin{flushright}")
    }

    for _, block in ipairs(el.content) do
      table.insert(blocks, block)
    end

    table.insert(blocks, pandoc.RawBlock("latex", "\\end{flushright}"))

    return blocks
  end

  return el
end