function Div(el)
  if not el.classes:includes("center") then
    return el
  end

  if FORMAT:match("latex") then
    local blocks = {
      pandoc.RawBlock("latex", "\\begin{center}")
    }

    for _, block in ipairs(el.content) do
      table.insert(blocks, block)
    end

    table.insert(blocks, pandoc.RawBlock("latex", "\\end{center}"))

    return blocks
  end

  el.attributes["style"] =
    (el.attributes["style"] or "") ..
    "text-align: center;"

  return el
end