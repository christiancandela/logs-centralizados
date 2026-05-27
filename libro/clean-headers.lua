-- clean-headers.lua
-- Filtro Lua de Quarto para limpiar las cabeceras (removiendo emojis iniciales
-- y numeración manual) y asignar anclajes de sección dinámicos estáticos.

-- Función auxiliar para detectar emojis o iconografías UTF-8
local function is_emoji(c)
  -- Bloque de emojis y pictogramas (U+1F300..U+1FAFF)
  if c >= 0x1F300 and c <= 0x1FAFF then return true end
  -- Símbolos y flechas misceláneas (U+2600..U+27BF)
  if c >= 0x2600 and c <= 0x27BF then return true end
  -- Banderas y símbolos regionales (U+1F1E6..U+1F1FF)
  if c >= 0x1F1E6 and c <= 0x1F1FF then return true end
  -- Selectores de variación (U+FE00..U+FE0F)
  if c >= 0xFE00 and c <= 0xFE0F then return true end
  -- Flechas adicionales (U+2190..U+21FF)
  if c >= 0x2190 and c <= 0x21FF then return true end
  -- Símbolos adicionales (U+2B00..U+2BFF)
  if c >= 0x2B00 and c <= 0x2BFF then return true end
  -- Caracteres especiales como ZWJ o el triángulo ▶
  if c == 0x200D or c == 0x25B6 then return true end
  return false
end

-- Limpia emojis, numeraciones manuales y separadores del inicio de un string
local function clean_prefix(s)
  -- Quitar espacios iniciales
  s = s:gsub("^%s+", "")
  
  -- Remover emojis e iconografía al inicio usando códigos UTF-8
  local out = {}
  local skipping = true
  for _, c in utf8.codes(s) do
    if skipping then
      if not is_emoji(c) then
        skipping = false
        table.insert(out, utf8.char(c))
      end
    else
      table.insert(out, utf8.char(c))
    end
  end
  s = table.concat(out)
  
  -- Quitar espacios resultantes
  s = s:gsub("^%s+", "")
  
  -- Remover numeración manual como "4.7.1", "3.1", "1."
  s = s:gsub("^%d+%.%d+%.%d+%.?%s*", "") -- "4.7.1"
  s = s:gsub("^%d+%.%d+%.?%s*", "")      -- "3.1"
  s = s:gsub("^%d+%.?%s*", "")           -- "1."
  
  -- Quitar guiones, flechas o separadores decorativos de unión
  s = s:gsub("^%s+", "")
  s = s:gsub("^[%-%—%:%>%|]%s*", "")
  s = s:gsub("^%s+", "")
  
  return s
end

-- Filtro de Cabeceras
function Header(el)
  -- 1. Asignar identificadores de sección en nivel 1
  if el.level == 1 then
    local title = pandoc.utils.stringify(el)
    if title:find("Recurso Educativo para el Despliegue") then
      el.identifier = "sec-marco-conceptual"
    elseif title:find("Guía de Estudio") then
      el.identifier = "sec-guia-estudio"
    elseif title:find("Guía Docente") then
      el.identifier = "sec-guia-docente"
    elseif title:find("ELK Stack") then
      el.identifier = "sec-guia-elk"
    elseif title:find("OLO Stack") then
      el.identifier = "sec-guia-olo"
    elseif title:find("Fluentd") then
      el.identifier = "sec-guia-fluentd"
    elseif title:find("Promtail") then
      el.identifier = "sec-guia-promtail"
    elseif title:find("GELF") then
      el.identifier = "sec-guia-gelf-graylog"
    elseif title:find("OpenTelemetry") then
      el.identifier = "sec-guia-otel"
    elseif title:find("Vector") then
      el.identifier = "sec-guia-vector"
    elseif title:find("SigNoz") then
      el.identifier = "sec-guia-signoz"
    elseif title:find("Alloy") then
      el.identifier = "sec-guia-alloy"
    end
  end

  -- 2. Limpieza de numeración manual e iconos en todos los niveles
  local prefix_inlines = {}
  local remaining_inlines = {}
  local collecting_prefix = true

  for i, inline in ipairs(el.content) do
    if collecting_prefix then
      if inline.t == "Str" or inline.t == "Space" then
        table.insert(prefix_inlines, inline)
      else
        collecting_prefix = false
        table.insert(remaining_inlines, inline)
      end
    else
      table.insert(remaining_inlines, inline)
    end
  end

  local parts = {}
  for _, inline in ipairs(prefix_inlines) do
    if inline.t == "Str" then
      table.insert(parts, inline.text)
    elseif inline.t == "Space" then
      table.insert(parts, " ")
    end
  end
  local prefix_str = table.concat(parts)

  -- Limpiar el prefijo de texto
  local cleaned_str = clean_prefix(prefix_str)

  local new_content = {}
  if cleaned_str ~= "" then
    table.insert(new_content, pandoc.Str(cleaned_str))
  end
  for _, inline in ipairs(remaining_inlines) do
    table.insert(new_content, inline)
  end
  
  el.content = new_content
  return el
end

return {
  { Header = Header }
}
