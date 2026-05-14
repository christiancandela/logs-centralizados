-- strip-svg-images.lua
-- Elimina imágenes SVG externas al compilar a PDF (LaTeX no puede procesarlas
-- sin herramientas externas como inkscape o pdf2svg).
-- En HTML y otros formatos las imágenes se conservan intactas.

function Image(el)
  if FORMAT:match("latex") and el.src:match("%.svg") then
    return {}
  end
  return el
end
