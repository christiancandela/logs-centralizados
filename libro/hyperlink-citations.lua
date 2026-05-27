-- hyperlink-citations.lua
-- Filtro Lua de Quarto para enlazar de forma interactiva las citas
-- bibliográficas en el texto con su referencia correspondiente.

local bib_keys = {}
local in_bib = false

-- Fase 1: Identificar las referencias y asignarles un anclaje invisible
function Header(h)
  local title = pandoc.utils.stringify(h)
  if title:find("Referencias") then
    in_bib = true
  elseif h.level <= 2 then
    -- Salimos de la sección al encontrar otra sección principal
    in_bib = false
  end
  return h
end

function handle_bib_block(p)
  if in_bib then
    local text = pandoc.utils.stringify(p)
    -- Extraer el primer apellido del autor (primer conjunto de letras al inicio)
    local author = text:match("^([%a]+)")
    -- Extraer el año (primer conjunto de 4 dígitos entre paréntesis)
    local year = text:match("%((%d%d%d%d)%)")
    
    if author and year then
      -- Normalizar la clave de citación (p.ej. "newman-2015")
      local key = author:lower() .. "-" .. year
      -- Reemplazar acentos en español para asegurar consistencia
      key = key:gsub("í", "i"):gsub("ó", "o"):gsub("á", "a"):gsub("é", "e"):gsub("ú", "u"):gsub("ñ", "n")
      bib_keys[key] = true
      
      -- Envolver el contenido del párrafo en un Span que actúa como ancla
      p.content = { pandoc.Span(p.content, { id = "ref-" .. key }) }
      return p
    end
  end
  return p
end

-- Fase 2: Buscar en el cuerpo de todos los párrafos citas parentéticas y enlazarlas
local function hyperlink_citations(parens)
  -- Reemplazar saltos de línea por espacios en el interior de la cita para simplificar
  local content = parens:sub(2, -2):gsub("%s+", " ")
  
  -- Si no contiene un año de 4 dígitos, no es una cita
  if not content:match("%d%d%d%d") then
    return parens
  end
  
  local parts = {}
  local replaced = false
  -- Separar citas compuestas divididas por punto y coma (p.ej. "Newman, 2015; Richardson, 2018")
  for part in content:gmatch("[^;]+") do
    local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
    local year = trimmed:match("%d%d%d%d")
    if year then
      -- Buscar el primer apellido del autor citado
      local author = trimmed:match("^([%a]+)")
      if author then
        local key = author:lower() .. "-" .. year
        key = key:gsub("í", "i"):gsub("ó", "o"):gsub("á", "a"):gsub("é", "e"):gsub("ú", "u"):gsub("ñ", "n")
        
        -- Si la clave coincide con una entrada de la bibliografía recopilada en la Fase 1
        if bib_keys[key] then
          trimmed = "[" .. trimmed .. "](#ref-" .. key .. ")"
          replaced = true
        end
      end
    end
    table.insert(parts, trimmed)
  end
  
  if replaced then
    return "(" .. table.concat(parts, "; ") .. ")"
  else
    return parens
  end
end

function process_body_block(p)
  -- Si es una entrada de la bibliografía ya procesada en la Fase 1, la omitimos
  if p.content and #p.content > 0 and p.content[1].t == "Span" then
    local id = p.content[1].identifier
    if id and id:find("^ref%-") then
      return p
    end
  end
  
  -- Convertir el párrafo/plain temporalmente a Markdown plano
  local doc_para = pandoc.Pandoc({pandoc.Para(p.content)})
  local markdown_str = pandoc.write(doc_para, "markdown")
  
  -- Buscar y reemplazar citas encerradas entre paréntesis balanceados %b()
  local replaced_str = markdown_str:gsub("%b()", hyperlink_citations)
  if replaced_str ~= markdown_str then
    -- Analizar de vuelta el Markdown modificado a AST de Pandoc
    local parsed = pandoc.read(replaced_str, "markdown")
    if parsed.blocks and #parsed.blocks > 0 and parsed.blocks[1].content then
      p.content = parsed.blocks[1].content
      return p
    end
  end
  return p
end

function Pandoc(doc)
  -- Fase 1: Identificar las referencias en la bibliografía
  doc.blocks = doc.blocks:walk({
    Header = Header,
    Para = handle_bib_block,
    Plain = handle_bib_block
  })
  
  -- Fase 2: Enlazar citas en el cuerpo del documento
  doc.blocks = doc.blocks:walk({
    Para = process_body_block,
    Plain = process_body_block
  })
  
  return doc
end

-- Exportación ordenada de filtros
return {
  { Pandoc = Pandoc }
}
