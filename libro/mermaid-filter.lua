-- mermaid-filter.lua
-- Converts plain ```mermaid code blocks into embedded PDFs for LaTeX/PDF
-- output, using the Mermaid CLI (`mmdc`). For HTML output the block is
-- preserved as-is so Quarto's HTML pipeline can render it client-side.
--
-- Requirements (PDF output only):
--   Node.js + Mermaid CLI:  npm install -g @mermaid-js/mermaid-cli
--
-- The filter writes generated PDFs to ./_mermaid/ within the project
-- directory and references them via \includegraphics.

local counter = 0

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function render_to_pdf(code)
  counter = counter + 1
  local outdir = "_mermaid"
  os.execute("mkdir -p " .. outdir)

  local input = outdir .. "/diagram-" .. counter .. ".mmd"
  local output = outdir .. "/diagram-" .. counter .. ".pdf"

  -- Write the mermaid source to a temp file
  local f, err = io.open(input, "w")
  if not f then
    io.stderr:write("[mermaid-filter] cannot write " .. input .. ": " .. tostring(err) .. "\n")
    return nil
  end
  f:write(code)
  f:close()

  -- Invoke mmdc to render the diagram as PDF.
  -- `--pdfFit` shrinks the PDF page bounds to the diagram, eliminating the
  -- large white margins that mmdc otherwise adds around the chart on a
  -- default-sized page.
  local cmd = string.format(
    "mmdc -i %s -o %s -t default --pdfFit 2>&1",
    shell_escape(input),
    shell_escape(output)
  )
  local ok = os.execute(cmd)
  if not ok or not file_exists(output) then
    io.stderr:write("[mermaid-filter] mmdc failed for diagram #" .. counter .. "\n")
    return nil
  end

  return output
end

if FORMAT:match("latex") or FORMAT:match("pdf") then
  function CodeBlock(block)
    -- Only act on plain ```mermaid (CodeBlock with class "mermaid")
    local is_mermaid = false
    if block.classes then
      for _, cls in ipairs(block.classes) do
        if cls == "mermaid" then is_mermaid = true; break end
      end
    end
    if not is_mermaid then return nil end

    local pdf_path = render_to_pdf(block.text)
    if pdf_path then
      -- Emit raw LaTeX directly to avoid Pandoc wrapping the image in a
      -- `\begin{figure}` float (which introduces large vertical gaps due to
      -- `\abovecaptionskip`/`\belowcaptionskip` and float placement rules).
      -- The compact `{\centering ... \par}` form keeps the image tight
      -- against the surrounding paragraphs.
      local latex = string.format(
        "{\\centering\\includegraphics[width=0.85\\textwidth]{%s}\\par}",
        pdf_path
      )
      return pandoc.RawBlock("latex", latex)
    else
      -- Graceful fallback: keep the source visible with a note
      return pandoc.BlockQuote({
        pandoc.Para({
          pandoc.Emph({
            pandoc.Str("Diagrama Mermaid no renderizado. Verifique que Mermaid CLI esté instalado:"),
            pandoc.Space(),
            pandoc.Code("npm install -g @mermaid-js/mermaid-cli")
          })
        }),
        block
      })
    end
  end
end
