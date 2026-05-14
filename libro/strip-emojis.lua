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
  -- Enclosed alphanumerics (some have emoji presentations)
  if c >= 0x2460 and c <= 0x24FF then return false end
  return false
end

local function strip(s)
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
