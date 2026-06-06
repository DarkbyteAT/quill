-- Pandoc Lua filter: convert fenced ```dot blocks to raw TikZ via dot2tex.
--
-- Wired into quill's default pipeline via defaults/default.yaml so users get
-- this for free — a ```dot fenced block in markdown becomes a styled
-- tikzpicture in the rendered PDF, with no extra command-line flags or
-- per-document boilerplate.
--
-- The filter shells out to `dot2tex -ftikz --figonly`, which emits only the
-- tikzpicture environment (no document wrapper, no preamble). We extract
-- the tikzpicture verbatim and inline it as a RawBlock("latex"), so pandoc
-- passes it through unchanged into the LaTeX intermediate that xelatex
-- compiles. The required preamble (`\usepackage{tikz}` + libraries) is
-- declared in `defaults/default.yaml` under `header-includes`.
--
-- Code blocks in other languages fall through unchanged.

local function extract_tikzpicture(latex_source)
  local s = latex_source:find("\\begin{tikzpicture}", 1, true)
  local _, ee = latex_source:find("\\end{tikzpicture}", 1, true)
  if s and ee then
    return latex_source:sub(s, ee)
  end
  return nil
end

function CodeBlock(block)
  if not block.classes:includes("dot") then
    return nil
  end
  local ok, tikz = pcall(pandoc.pipe, "dot2tex", {"-ftikz", "--figonly"}, block.text)
  if not ok or not tikz or tikz == "" then
    io.stderr:write("quill: dot2tex failed for dot block; leaving code block in place\n")
    return nil
  end
  local extracted = extract_tikzpicture(tikz)
  if not extracted then
    io.stderr:write("quill: dot2tex output did not contain a tikzpicture environment\n")
    return nil
  end
  return pandoc.RawBlock("latex", extracted)
end
