-- strip-emojis.lua
-- Removes emoji codepoints from inline text when rendering to LaTeX/PDF.
-- HTML output is left untouched (emojis render natively in browsers).
--
-- Rationale: rendering color emojis in LuaLaTeX requires the Noto Color
-- Emoji font (or equivalent) plus Harfbuzz support, which is a non-trivial
-- prerequisite for many users. Stripping emojis at the inline level yields
-- a clean, professional PDF with zero external font dependencies.

local function is_emoji(c)
  -- Emoji & pictograph blocks (U+1F300..U+1FAFF)
  if c >= 0x1F300 and c <= 0x1FAFF then return true end
  -- Miscellaneous symbols and arrows (U+2600..U+26FF)
  if c >= 0x2600 and c <= 0x26FF then return true end
  -- Dingbats (U+2700..U+27BF)
  if c >= 0x2700 and c <= 0x27BF then return true end
  -- Regional indicator symbols (flags) (U+1F1E6..U+1F1FF)
  if c >= 0x1F1E6 and c <= 0x1F1FF then return true end
  -- Variation selectors (U+FE00..U+FE0F)
  if c >= 0xFE00 and c <= 0xFE0F then return true end
  -- Zero-width joiner (used in compound emojis)
  if c == 0x200D then return true end
  -- Information source (U+2139, usado en notas "ℹ️ …")
  if c == 0x2139 then return true end
  -- Miscellaneous Technical con presentación emoji (⌚ ⌛ ⏩..⏳ …) — U+2300..U+23FF
  if c >= 0x2300 and c <= 0x23FF then return true end
  -- Misc. Symbols and Arrows (estrellas ⭐, etc.) — U+2B00..U+2BFF
  if c >= 0x2B00 and c <= 0x2BFF then return true end
  -- Geometric play/triangle markers (▶ ◀) — U+25B6 / U+25C0
  if c == 0x25B6 or c == 0x25C0 then return true end
  -- NOTA: NO se incluyen las Flechas (U+2190..U+21FF) para preservar "→" (U+2192),
  -- ni los caracteres de dibujo de cajas (U+2500..U+257F) usados en los árboles
  -- de "Estructura del proyecto".
  -- Enclosed alphanumerics (some have emoji presentations)
  if c >= 0x2460 and c <= 0x24FF then return false end
  return false
end

local function strip(s)
  -- Si el string no contiene bytes en el rango del primer byte de caracteres
  -- de 3 o 4 bytes (>= U+0800, que incluye a todos los emojis), lo retornamos intacto.
  -- Esto evita decodificaciones erróneas de acentos en español y espacios de no separación.
  if not s:find("[\224-\255]") then
    return s
  end

  local out = {}
  for _, c in utf8.codes(s) do
    if not is_emoji(c) then
      table.insert(out, utf8.char(c))
    end
  end
  local cleaned = table.concat(out)
  -- Trim leading/trailing whitespace and collapse internal multi-spaces
  cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return cleaned
end

if FORMAT:match("latex") or FORMAT:match("pdf") then
  function Str(elem)
    return pandoc.Str(strip(elem.text))
  end

  -- After Str transformation, headers may have leading Spaces or empty Strs
  -- where emojis used to be. Clean up the inline list.
  function Header(elem)
    while #elem.content > 0 do
      local first = elem.content[1]
      if (first.t == "Str" and first.text == "") or first.t == "Space" then
        table.remove(elem.content, 1)
      else
        break
      end
    end
    while #elem.content > 0 do
      local last = elem.content[#elem.content]
      if (last.t == "Str" and last.text == "") or last.t == "Space" then
        table.remove(elem.content, #elem.content)
      else
        break
      end
    end
    return elem
  end
end
