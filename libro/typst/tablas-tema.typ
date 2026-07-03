// Fase 5 — Tema global de tablas que replica el estilo Word del documento
// ("Tabla con cuadrícula": bordes completos + encabezado sombreado en azul claro).
#set table(
  stroke: 0.5pt + rgb("#808080"),     // cuadrícula gris (estilo Word)
  inset: 4pt,
  fill: (_, y) => if y == 0 { rgb("#DBE5F1") },  // encabezado azul claro como el Word
  // Encabezado centrado; filas de datos alineadas a la izquierda (start).
  // La alineación explícita por columna en Pandoc (:--, --:, :--:) sobrescribe este valor.
  align: (_, y) => if y == 0 { center + horizon } else { start + horizon },
)
// Tamaño legible en las tablas.
// Las tablas extensas deben dividirse o trasladarse a anexos antes que reducir
// la letra hasta comprometer su consulta en pantalla o impresa.
#show table.cell: set text(size: 8.5pt)
#show table.cell.where(y: 0): set text(weight: "bold")

// Asegurar que las celdas con imágenes (como fotos incrustadas en fichas técnicas)
// tengan fondo blanco. Se reconstruye el table.cell con fill: white explícito
// (set table.cell(fill:…) dentro de un show rule no sobrescribe el fill ya asignado).
#show table.cell: it => {
  if repr(it.body).contains("image(") and it.fill != white {
    let fields = it.fields()
    let body = fields.remove("body")
    table.cell(..fields, fill: white)[#body]
  } else {
    it
  }
}


