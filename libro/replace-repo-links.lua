-- replace-repo-links.lua
-- Filtro Lua de Quarto para traducir enlaces relativos del repositorio a
-- enlaces absolutos en GitHub o anclajes internos del libro consolidado.

local replacements = {
  -- Cabeceras internas (secciones/capítulos)
  ["./guia_estudio.md"] = "#sec-guia-estudio",
  ["guia_estudio.md"] = "#sec-guia-estudio",
  ["./guia_docente.md"] = "#sec-guia-docente",
  ["guia_docente.md"] = "#sec-guia-docente",

  -- Documento base (readme): apunta al capítulo de Marco conceptual
  ["./readme.md"] = "#sec-marco-conceptual",
  ["readme.md"] = "#sec-marco-conceptual",

  -- Directorio de guías (enlaza al primer capítulo de la parte III)
  ["./guias/"] = "#sec-guia-elk",
  ["guias/"] = "#sec-guia-elk",
  
  -- Enlaces a recursos externos del repositorio (enlaces absolutos en GitHub)
  ["./soluciones/"] = "https://github.com/christiancandela/logs-centralizados/tree/main/soluciones",
  ["soluciones/"] = "https://github.com/christiancandela/logs-centralizados/tree/main/soluciones",
  ["./LICENSE"] = "https://github.com/christiancandela/logs-centralizados/blob/main/LICENSE",
  ["LICENSE"] = "https://github.com/christiancandela/logs-centralizados/blob/main/LICENSE",
  
  -- Enlaces individuales de guías
  ["guias/elk-guide.md"] = "#sec-guia-elk",
  ["guias/olo-guide.md"] = "#sec-guia-olo",
  ["guias/fluentd-guide.md"] = "#sec-guia-fluentd",
  ["guias/promtail-guide.md"] = "#sec-guia-promtail",
  ["guias/gelf-graylog-guide.md"] = "#sec-guia-gelf-graylog",
  ["guias/otel-guide.md"] = "#sec-guia-otel",
  ["guias/vector-guide.md"] = "#sec-guia-vector",
  ["guias/signoz-guide.md"] = "#sec-guia-signoz",
  ["guias/alloy-guide.md"] = "#sec-guia-alloy"
}

-- Filtro de Enlaces relativos a absolutos/internos
function Link(el)
  local target = el.target
  local repl = replacements[target]
  if repl then
    el.target = repl
    return el
  end
  return el
end

-- Exportación ordenada de filtros
return {
  { Link = Link }
}
