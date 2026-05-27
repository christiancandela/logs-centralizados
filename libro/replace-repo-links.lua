-- replace-repo-links.lua
-- Filtro Lua de Quarto para traducir enlaces relativos del repositorio 
-- en referencias internas del libro o enlaces absolutos de GitHub.

local replacements = {
  -- Cabeceras internas (secciones/capítulos)
  ["./guia_estudio.md"] = "#sec-guia-estudio",
  ["guia_estudio.md"] = "#sec-guia-estudio",
  ["./guia_docente.md"] = "#sec-guia-docente",
  ["guia_docente.md"] = "#sec-guia-docente",
  
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

-- Modifica los identificadores de cabeceras de nivel 1 (capítulos)
-- para que coincidan exactamente con las etiquetas usadas en los enlaces internos.
function Header(el)
  if el.level == 1 then
    local title = pandoc.utils.stringify(el)
    if title:find("Recurso Educativo para el Despliegue") then
      el.identifier = "sec-marco-conceptual"
      return el
    elseif title:find("Guía de Estudio") then
      el.identifier = "sec-guia-estudio"
      return el
    elseif title:find("Guía Docente") then
      el.identifier = "sec-guia-docente"
      return el
    elseif title:find("ELK Stack") then
      el.identifier = "sec-guia-elk"
      return el
    elseif title:find("OLO Stack") then
      el.identifier = "sec-guia-olo"
      return el
    elseif title:find("Fluentd") then
      el.identifier = "sec-guia-fluentd"
      return el
    elseif title:find("Promtail") then
      el.identifier = "sec-guia-promtail"
      return el
    elseif title:find("GELF") then
      el.identifier = "sec-guia-gelf-graylog"
      return el
    elseif title:find("OpenTelemetry") then
      el.identifier = "sec-guia-otel"
      return el
    elseif title:find("Vector") then
      el.identifier = "sec-guia-vector"
      return el
    elseif title:find("SigNoz") then
      el.identifier = "sec-guia-signoz"
      return el
    elseif title:find("Alloy") then
      el.identifier = "sec-guia-alloy"
      return el
    end
  end
  return el
end

-- Reemplaza los enlaces
function Link(el)
  local target = el.target
  local repl = replacements[target]
  if repl then
    el.target = repl
    return el
  end
  return el
end

-- Retornamos los filtros ordenados: primero asignamos cabeceras y luego traducimos enlaces
return {
  { Header = Header },
  { Link = Link }
}
