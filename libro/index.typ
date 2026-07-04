// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
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


// Configuración personalizada de estilos para el documento Typst
#import "@preview/orange-book:0.7.1": main-color-state, part-change, appendix-state
#import "@preview/shadowed:0.3.0": shadow

#show: doc => {
  set page(
    header: context {
      set text(size: 9pt)
      let page_number = counter(page).at(here()).first()
      let odd_page = calc.odd(page_number)
      let part_change_val = part-change.at(here())
      let all = query(heading.where(level: 1))
      if all.any(it => it.location().page() == page_number) or part_change_val {
        return
      }
      let appendix = appendix-state.at(here())      
      if odd_page {
        let before = query(selector(heading.where(level: 2)).before(here()))
        let counterInt = counter(heading).at(here())
        if before != () and counterInt.len()> 1 {
          box(width: 100%, inset: (bottom: 5pt), stroke: (bottom: 0.5pt))[
            #text(if appendix != none {numbering("A.1", ..counterInt.slice(0,2)) + " " + before.last().body} else {numbering("1.1", ..counterInt.slice(0,2)) + " " + before.last().body})
            #h(1fr)
            #page_number
          ]
        }
      } else{
        let before = query(selector(heading.where(level: 1)).before(here()))
        let counterInt = counter(heading).at(here()).first()

        if before != () and counterInt > 0 {
          box(width: 100%, inset: (bottom: 5pt), stroke: (bottom: 0.5pt))[
            #set par(justify: false)
            #grid(
              columns: (auto, 1fr),
              align: (left + horizon, right + horizon),
              column-gutter: 0.3em,
              [#page_number],
              text(weight: "bold")[
                #if appendix != none {
                  numbering("A.1", counterInt) + ". " + before.last().body
                } else {
                  before.last().supplement + " " + str(counterInt) + ". " + before.last().body
                }
              ]
            )
          ]
        }
      }
    }
  )
  doc
}


// Los capítulos y las partes inician en la página siguiente, no forzosamente
// en página impar: se neutralizan los saltos 'to: "odd"' de la plantilla
// orange-book, que insertaban una página en blanco al final de los capítulos
// que terminan en página impar (convención de impresión a doble cara que no
// aplica a este PDF de lectura digital).
#show pagebreak.where(to: "odd"): it => pagebreak(weak: true)

// Referencias cruzadas (@fig-, @tbl-, @sec-) en el mismo color azul que citas y enlaces
#show ref: it => context {
  let mc = main-color-state.at(here())
  if mc != none { text(fill: mc, it) } else { it }
}

// Ajuste del espaciado entre párrafos (mayor separación que el valor predeterminado)
#show par: set par(spacing: 1.5em)

// Incrementar la altura del cuadro azul (bloque de la portada) de 7.5cm a 10.5cm
#show block: it => {
  if it.has("height") and it.height == 7.5cm {
    let fields = it.fields()
    let body = fields.remove("body")
    fields.height = 10.5cm
    if fields.at("below", default: none) != none and fields.below != auto {
      fields.below = fields.below.abs
    }
    block.with(..fields)(body)
  } else {
    it
  }
}

// Formato de bibliografía según estilo APA v7 (sangría francesa de 1.27cm y espaciado)
#show <refs>: it => {
  set par(hanging-indent: 1.27cm, justify: true)
  show block: set block(spacing: 1.5em)
  it
}



// Evitar página en blanco después de la portada removiendo el salto de página del índice
#show outline: it => {
  if it.title == none {
    // Reducir el tamaño de letra de la tabla de contenido a 10pt
    set text(size: 10pt)

    // Función auxiliar para extraer el texto de un bloque de contenido
    let to-string(content) = {
      if content == none {
        ""
      } else if type(content) == str {
        content
      } else if content.has("text") {
        content.text
      } else if content.has("children") {
        let ch = content.children
        if ch.len() == 0 { "" } else { ch.map(to-string).join("") }
      } else if content.has("body") {
        to-string(content.body)
      } else {
        ""
      }
    }

    // Interceptar la cuadrícula de my-outline-row para ajustar dinámicamente el ancho de la numeración
    show grid: it => {
      if it.columns == (1.2cm, 1fr, auto) {
        let fields = it.fields()
        let children = fields.remove("children")
        
        let number-str = to-string(children.at(0).body)
        let num-dots = number-str.clusters().filter(c => c == ".").len()
        
        // Ancho dinámico: nivel 3 obtiene 2.2cm, nivel 2 obtiene 1.6cm, nivel 1 obtiene 1.2cm
        let col-width = if num-dots >= 2 { 2.2cm } else if num-dots == 1 { 1.6cm } else { 1.2cm }
        
        if col-width != 1.2cm {
          fields.columns = (col-width, 1fr, auto)
          grid(..fields, ..children)
        } else {
          it
        }
      } else {
        it
      }
    }

    it
  } else {
    let fields = it.fields()
    fields.title = none
    
    // Iniciar el índice en página nueva
    pagebreak()

    // Título personalizado que no dispara el pagebreak(to: "odd").
    // El color deriva del color principal del libro (oscurecido), de modo que
    // cambiar el tono en typst-show.typ re-tiñe también este título.
    align(center)[
      #v(1cm)
      #context {
        let mc = main-color-state.at(here())
        let title-color = if mc != none { mc.darken(50%) } else { rgb("#003b4f") }
        text(size: 2.2em, weight: "bold", fill: title-color)[Índice]
      }
      #v(1cm)
    ]
    
    outline(..fields)
  }
}

// Tamaño 9pt para los títulos (pies de figura/tabla) de ilustraciones y tablas
#show figure.caption: set text(size: 9pt)

// Separador de los títulos de figuras y tablas: "Tabla 2.1. Título" (punto en
// lugar del ":" por defecto de Typst)
#set figure.caption(separator: [. ])

// Evitar la división silábica con guiones en todos los títulos (capítulos y secciones)
#show heading: set text(hyphenate: false)

// Sombra suave para ilustraciones con título.
// Quarto genera figuras con kind: "quarto-float-fig" (no kind: image).
// Técnica: bloque exterior con relleno semitransparente e inset solo en derecha+abajo.
// El bloque interior con fill:white tapa ese fondo; la sombra queda visible
// únicamente en las franjas derecha y abajo.
#show figure.where(kind: "quarto-float-fig"): fig => {
  if fig.body.func() == block and fig.body.has("inset") and type(fig.body.inset) == dictionary and fig.body.inset.at("top", default: none) == 0.123pt {
    fig
  } else {
    // En Typst el contador de figuras se incrementa a nivel del elemento,
    // independientemente de la regla show: la figura original Y la figura
    // envolvente creada aquí incrementan ambas el contador, lo que hacía
    // saltar la numeración visible (2.2, 2.4, 2.6, ...). Se compensa
    // decrementando el contador antes de emitir la figura envolvente.
    counter(figure.where(kind: "quarto-float-fig")).update(n => n - 1)
    figure(
      placement: fig.placement,
      caption: fig.caption,
      kind: fig.kind,
      supplement: fig.supplement,
      numbering: fig.numbering,
      gap: fig.gap,
      block(
        stroke: none,
        fill: none,
        inset: (top: 0.123pt),
        shadow(
          dx: 3.5pt,
          dy: 3.5pt,
          blur: 8pt,
          fill: rgb(0, 0, 0, 20%),
          radius: 0pt,
        )[
          #block(
            fill: white,
            stroke: 0.5pt + luma(200),
            inset: 0pt,
            fig.body
          )
        ]
      )
    )
  }
}

#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
// #import "orange-book/lib.typ": book, part, chapter, appendices
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#import "./typst/cover.typ": cover

// Color principal del libro. Este único valor controla: el bloque de la portada
// interior (posterior a la cubierta), el título y los acentos del índice, las
// franjas y numerales de las páginas de Parte, los títulos de capítulo y las
// referencias cruzadas. Cambiar el tono = editar este hex.
#let color-principal = rgb("#0d2942ff")

#page(margin: 0pt, numbering: none, header: none, footer: none)[

#cover(
  [Recurso Educativo para el Despliegue de Ecosistemas de Centralización de Logs Mediante Docker],
  [Marco conceptual, guía de estudio, guía docente y nueve guías prácticas reproducibles],
  [
        Christian Andrés Candela Uribe, Ph.D.\
        Paola Andrea Acero Franco, M.Sc.\
        Luis Eduardo Sepúlveda Rodríguez, Ph.D.\
      ],
  [2026],
)
]


#show: book.with(
  image-index: image("images/chapter_header.png"),
  title: [Recurso Educativo para el Despliegue de Ecosistemas de Centralización de Logs Mediante Docker],
  subtitle: [Marco conceptual, guía de estudio, guía docente y nueve guías prácticas reproducibles],

  author: "Christian Andrés Candela Uribe, Ph.D.\nPaola Andrea Acero Franco, M.Sc.\nLuis Eduardo Sepúlveda Rodríguez, Ph.D.",
  date: "2025",
  lang: "es",

  supplement-chapter: "Capítulo",
  copyright: [
    #set text(size: 9pt)

    *Recurso Educativo para el Despliegue de Ecosistemas de Centralización de Logs Mediante Docker* \
    _Marco conceptual, guía de estudio, guía docente y nueve guías prácticas reproducibles_

    #v(0.3em)
    *Autores* \
        
        Christian Andrés Candela Uribe, Ph.D.\

        
        Paola Andrea Acero Franco, M.Sc.\

        
        Luis Eduardo Sepúlveda Rodríguez, Ph.D.\

        


    #v(0.3em)
    Universidad del Quindío — Facultad de Ingeniería \
    Programa de Ingeniería de Sistemas y Computación \
    Armenia, Quindío, Colombia — 2026

    #v(0.6em)
    #line(length: 100%, stroke: 0.5pt)
    #v(0.4em)

    #image("images/by-sa.png", width: 2.8cm)

    #v(0.15em)
    #text(weight: "bold")[Licencia Creative Commons]

    #v(0.1em)
    Atribución – Compartir Igual 4.0 Internacional (CC BY-SA 4.0) \
    #link("https://creativecommons.org/licenses/by-sa/4.0/deed.es")[creativecommons.org/licenses/by-sa/4.0]

    #v(0.15em)
    #text(size: 8.5pt)[Esta licencia permite a otros distribuir, remezclar, retocar y crear a partir de esta obra, incluso con fines comerciales, siempre y cuando den crédito a los autores y licencien sus nuevas creaciones bajo las mismas condiciones.]

    #v(0.3em)
    © 2026  Christian Andrés Candela Uribe, Paola Andrea Acero Franco, Luis Eduardo Sepúlveda Rodríguez

    #v(0.4em)
    #line(length: 100%, stroke: 0.5pt)
    #v(0.4em)

    #text(weight: "bold", size: 9.5pt)[Sobre los autores]

    #v(0.4em)
    #grid(
      columns: (2cm, 1fr),
      column-gutter: 0.7em,
      align: (top, top),
      image("images/foto-sepulveda.jpg", width: 2cm),
      [
        #text(weight: "bold", size: 8.5pt)[Luis Eduardo Sepúlveda Rodríguez, PhD.] \
        #v(0.1em)
        #text(size: 8pt)[Doctor en Ingeniería con énfasis en Ciencias de la Computación, Universidad Tecnológica de Pereira. Colombia. Profesor Asociado en la Universidad del Quindío, Colombia. Áreas de interés: infraestructura de TI, sistemas operativos y cloud computing. ORCID: #link("https://orcid.org/0000-0003-2446-0602")[0000-0003-2446-0602]]
      ]
    )

    #v(0.35em)
    #grid(
      columns: (2cm, 1fr),
      column-gutter: 0.7em,
      align: (top, top),
      image("images/foto-acero.jpg", width: 2cm),
      [
        #text(weight: "bold", size: 8.5pt)[Paola Andrea Acero Franco, MSc.] \
        #v(0.1em)
        #text(size: 8pt)[Magíster en E-Learning, Universidad Autónoma de Bucaramanga. Colombia. Profesora Asociada en la Universidad del Quindío, Colombia. Áreas de interés: diseño instruccional, recursos educativos abiertos y tecnología educativa. ORCID: #link("https://orcid.org/0009-0005-6538-5030")[0009-0005-6538-5030]]
      ]
    )


    #v(0.35em)
    #grid(
      columns: (2cm, 1fr),
      column-gutter: 0.7em,
      align: (top, top),
      image("images/foto-candela.jpg", width: 2cm),
      [
        #text(weight: "bold", size: 8.5pt)[Christian Andrés Candela Uribe, PhD.] \
        #v(0.1em)
        #text(size: 8pt)[Doctor en Ingeniería con énfasis en Ciencias de la Computación, Universidad Tecnológica de Pereira. Profesor Asociado en la Universidad del Quindío, Colombia. Áreas de interés: Arquitectura de Software, Ingeniería de Software y Microservicios. ORCID: #link("https://orcid.org/0000-0002-3961-1840")[0000-0002-3961-1840]]
      ]
    )

  ],
  supplement-part: "Parte",
  // cover-height: auto,
  // title-size: 2.2em,
  // subtitle-size: 1.4em,
  // author-size: 1.6em,
  main-color: color-principal,
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  outline-small-depth: 1,
  font-size: 11pt,
)

// Numeración de figuras y tablas en los capítulos no numerados (la
// Presentación): sin prefijo de capítulo ("Tabla 1" en lugar de "Tabla 0.1").
// Debe declararse DESPUÉS de book.with() para prevalecer sobre el patrón
// "1.1" que fija la plantilla.
#set figure(numbering: num => {
  let ch = counter(heading).get().first()
  if ch == 0 { numbering("1", num) } else { numbering("1.1", ch, num) }
})


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Presentación]
<presentación>
Este libro recoge en un único volumen el #strong[Recurso Educativo para el Despliegue de Ecosistemas de Centralización de Logs Mediante Docker], producto resultante del trabajo académico de los tres profesores autores adscritos al Programa de Ingeniería de Sistemas y Computación de la Universidad del Quindío. No es un manual de herramientas: es un recurso educativo abierto que articula un marco conceptual tecnológicamente neutral, instrumentos de estudio y de docencia, y nueve laboratorios reproducibles en el equipo personal del estudiante.

#heading(level: 2, numbering: none)[El recurso en un vistazo]
<el-recurso-en-un-vistazo>
#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Problema formativo], [Solución propuesta], [Evidencia principal], [Uso esperado],),
  table.hline(),
  [La observabilidad suele enseñarse de forma instrumental, acoplada a herramientas que cambian con rapidez.], [Marco conceptual neutral con una arquitectura de cuatro etapas, seis desafíos de diseño y tres paradigmas de almacenamiento.], [#ref(<sec-marco-conceptual>, supplement: [Capítulo])], [Fundamentación teórica de la unidad temática.],
  [Los laboratorios dependen de infraestructura institucional o de entornos difíciles de reproducir.], [Nueve ecosistemas autocontenidos con Docker Compose, dimensionados, parametrizados y con prueba de humo automatizada.], [Parte III y #link("https://github.com/christiancandela/logs-centralizados/tree/main/soluciones")[repositorio público de soluciones].], [Laboratorios en el equipo personal del estudiante.],
  [La evaluación de los laboratorios técnicos suele desalinearse de los resultados de aprendizaje.], [Guía docente con rutas de planificación, rúbrica analítica homogénea y evaluación de tres componentes.], [#link(<sec-guia-docente>)[Guía docente]], [Planificación y evaluación del curso.],
)
], caption: figure.caption(
position: top, 
[
Síntesis del problema formativo, la solución propuesta y el uso esperado del recurso.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-pres-vistazo>


#heading(level: 2, numbering: none)[¿Para quién y cómo se usa?]
<para-quién-y-cómo-se-usa>
#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Público], [Punto de partida sugerido], [Qué encontrará],),
  table.hline(),
  [Docente], [#link(<sec-guia-docente>)[Guía docente]], [Rutas de una y dos semanas, pares de stacks contrastantes, rúbricas y dificultades frecuentes con orientaciones.],
  [Estudiante], [#ref(<sec-marco-conceptual>, supplement: [Capítulo]) y #link(<sec-guia-estudio>)[guía de estudio]], [Fundamentos conceptuales, glosario y cuestionario de autoevaluación con articulación teoría--práctica.],
  [Lector autodidacta], [#link(<sec-guia-elk>)[Guía ELK] en adelante], [Ruta progresiva de nueve laboratorios reproducibles, del ecosistema clásico al estado del arte.],
  [Par académico evaluador], [#ref(<sec-metodologia>, supplement: [Capítulo]) y #ref(<sec-resultados>, supplement: [Capítulo])], [Trazabilidad con la propuesta aprobada, gestión de evidencias y correspondencia objetivos--resultados.],
)
], caption: figure.caption(
position: top, 
[
Públicos del recurso y puntos de partida sugeridos.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-pres-publicos>


#heading(level: 2, numbering: none)[Indicadores del recurso]
<indicadores-del-recurso>
#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Componente], [Magnitud], [Valor formativo],),
  table.hline(),
  [Marco conceptual], [Arquitectura de 4 etapas, 6 desafíos de diseño, 3 paradigmas de almacenamiento.], [Modelo mental transferible entre tecnologías.],
  [Guías prácticas], [9 stacks, del ecosistema tradicional al estado del arte.], [Independencia instrumental demostrada empíricamente.],
  [Material de estudio], [20 preguntas resueltas y glosario terminológico.], [Autoevaluación y articulación teoría--práctica.],
  [Instrumentos docentes], [3 rutas de planificación y rúbrica analítica de 4 criterios.], [Adopción realista en cursos semestrales.],
  [Reproducibilidad], [9 pruebas de humo automatizadas y límites de memoria parametrizados.], [Verificación objetiva del entorno en equipos heterogéneos.],
)
], caption: figure.caption(
position: top, 
[
Indicadores de magnitud y valor formativo del recurso.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-pres-indicadores>


#heading(level: 2, numbering: none)[Estructura del libro]
<estructura-del-libro>
El volumen se organiza en tres partes complementarias:

- #strong[Parte I --- Documento base.] Desarrolla, desde un enfoque teórico y tecnológicamente neutral, los fundamentos de la observabilidad en sistemas distribuidos, con énfasis en la centralización de logs. Documenta además la metodología de construcción del recurso y su gestión de evidencias, los resultados obtenidos y su correspondencia con los objetivos comprometidos, la discusión académica, pedagógica e institucional, las conclusiones y el trabajo futuro.

- #strong[Parte II --- Material de estudio y docencia.] Reúne dos instrumentos pedagógicos: la #emph[Guía de estudio], organizada en formato pregunta--respuesta con un glosario terminológico y un bloque de preguntas de articulación teoría--práctica; y la #emph[Guía docente], que ofrece un panorama de consulta rápida de las nueve guías, una matriz de alineación con los resultados de aprendizaje, planificaciones sugeridas, rúbricas de evaluación y orientaciones para la integración del recurso en cursos universitarios reales.

- #strong[Parte III --- Guías prácticas.] Reúne nueve laboratorios reproducibles, cada uno orientado a una pila tecnológica distinta de centralización y observabilidad. Las guías comparten una estructura común (objetivo, tiempo estimado y evidencias esperadas, prerrequisitos, despliegue con Docker Compose, validación, profundización) y se diseñaron para permitir tanto la lectura lineal como el uso selectivo según los intereses del lector o el tiempo disponible en clase.

#heading(level: 2, numbering: none)[Ruta de lectura sugerida]
<ruta-de-lectura-sugerida>
El libro admite una lectura lineal, pero también rutas selectivas según el propósito del lector:

- #strong[Adopción docente:] guía docente, seguida de dos guías prácticas contrastantes según los pares sugeridos en ella.
- #strong[Comprensión conceptual:] Parte I completa y guía de estudio, dejando las guías prácticas como profundización.
- #strong[Práctica autónoma:] guías prácticas en el orden propuesto, consultando el marco conceptual cuando cada guía lo remita.
- #strong[Evaluación académica del trabajo:] metodología (#ref(<sec-metodologia>, supplement: [Capítulo])), resultados (#ref(<sec-resultados>, supplement: [Capítulo])) y discusión (#ref(<sec-discusion>, supplement: [Capítulo])), que concentran la trazabilidad con la propuesta aprobada, las evidencias y el análisis crítico del alcance.

#heading(level: 2, numbering: none)[Sobre el uso autónomo y supervisado del recurso]
<sobre-el-uso-autónomo-y-supervisado-del-recurso>
Aunque el recurso fue diseñado pensando en su uso supervisado dentro del aula, su estructura es deliberadamente autónoma: un lector autodidacta puede recorrer las tres partes en orden y construir una comprensión sólida del tema sin requerir acompañamiento docente. Las guías prácticas son particularmente diseñadas para ser ejecutables en un único equipo personal, sin depender de infraestructura institucional ni de credenciales externas.

#heading(level: 2, numbering: none)[Acceso al material complementario]
<acceso-al-material-complementario>
El código fuente completo de las nueve guías prácticas, incluidos los archivos #NormalTok("docker-compose.yml");, las configuraciones de cada herramienta y la aplicación Java/Quarkus productora de logs, está disponible en el repositorio público del recurso: #link("https://github.com/christiancandela/logs-centralizados"). Este libro cuenta, además, con una versión web navegable en #link("https://christiancandela.github.io/logs-centralizados/"), útil para la consulta en línea y para copiar los fragmentos de configuración durante los laboratorios. Las versiones digitales de este libro y de sus componentes individuales se distribuyen bajo licencia #strong[Creative Commons Atribución-CompartirIgual 4.0 Internacional (CC BY-SA 4.0)], lo que habilita su reutilización, adaptación y redistribución por parte de docentes, estudiantes e instituciones que deseen incorporarlo a sus propios procesos formativos.

#heading(level: 2, numbering: none)[Forma de cita sugerida]
<forma-de-cita-sugerida>
#quote(block: true)[
Candela Uribe, C. A., Acero Franco, P. A., & Sepúlveda Rodríguez, L. E. (2026). #emph[Recurso educativo para el despliegue de ecosistemas de centralización de logs mediante Docker] (Versión 1.0.0) \[Recurso educativo abierto\]. Universidad del Quindío. #link("https://doi.org/10.5281/zenodo.20187576")
]

Los autores agradecen a la Universidad del Quindío y al Programa de Ingeniería de Sistemas y Computación por el espacio institucional que hizo posible la elaboración de este recurso, así como a los estudiantes que, en su rol de primeros lectores, contribuyeron con sus dudas y observaciones a mejorar la claridad del material final.

#emph[Armenia, Quindío. Mayo de 2026.]

#part[Documento base]
= Introducción
<introducción>
La adopción creciente de arquitecturas basadas en sistemas distribuidos y microservicios ha transformado de manera significativa el desarrollo y la operación del software contemporáneo \(#link(<ref-bosch-2016>)[Bosch, 2016]\; #link(<ref-newman-2015>)[Newman, 2015]\; #link(<ref-richardson-2018>)[Richardson, 2018]). Estas arquitecturas aportan beneficios claros en términos de escalabilidad, resiliencia y evolución independiente de los componentes; sin embargo, también introducen un aumento considerable en la complejidad asociada a su análisis y gestión.

En este escenario, comprender el comportamiento interno de los sistemas en ejecución se convierte en un reto central para la formación en ingeniería de sistemas y computación, y disciplinas afines. La #strong[observabilidad] surge como un principio fundamental que permite abordar este reto, al posibilitar la inferencia del estado interno de un sistema a partir de las señales externas que este produce durante su operación \(#link(<ref-beyer-2016>)[Beyer et~al., 2016]\; #link(<ref-majors-2022>)[Majors et~al., 2022]\; #link(<ref-sridharan-2018>)[Sridharan, 2018]).

El presente trabajo escrito tiene como propósito desarrollar, desde un enfoque académico y formativo, los fundamentos conceptuales de la observabilidad en sistemas distribuidos, con énfasis en la #strong[centralización de logs] como uno de sus pilares principales. El documento se concibe como un recurso educativo orientado a facilitar el aprendizaje progresivo de estos conceptos, priorizando los principios y la arquitectura conceptual sobre el uso de herramientas o tecnologías específicas. Esta separación entre el marco teórico y las guías prácticas es una decisión metodológica deliberada: mantener el documento conceptual neutral en términos tecnológicos permite que los fundamentos presentados conserven validez con independencia de la evolución del ecosistema de herramientas, mientras que las guías prácticas ofrecen la experiencia concreta necesaria para anclar el aprendizaje en contextos reales \(#link(<ref-kolb-1984>)[Kolb, 1984]).

Las guías prácticas complementarias cubren un espectro tecnológico más amplio que el enunciado originalmente en la propuesta de trabajo. Esta ampliación es una decisión consciente: el estado del arte de la observabilidad ha evolucionado de forma acelerada durante el período de desarrollo del recurso, incorporando estándares de protocolo unificado y plataformas de nueva generación que ofrecen un valor pedagógico significativo y mejoran la transferibilidad del conocimiento. Las guías adicionales se diseñaron con el mismo rigor y estructura que las originalmente propuestas, manteniendo coherencia con el marco conceptual presentado en este documento.

= Justificación
<justificación>
La formación en ingeniería de sistemas y computación enfrenta el desafío de preparar a los estudiantes para comprender y gestionar sistemas de software cada vez más complejos y distribuidos. Si bien los programas académicos suelen abordar con profundidad los aspectos relacionados con el diseño y la construcción de software, los elementos asociados a su operación, análisis y diagnóstico suelen recibir una atención limitada o fragmentada.

En particular, la observabilidad y la centralización de logs suelen introducirse desde enfoques predominantemente instrumentales, centrados en el uso de herramientas específicas. Esta aproximación dificulta la transferencia del conocimiento a contextos tecnológicos diversos y limita la comprensión de los principios conceptuales que subyacen a dichas prácticas \(#link(<ref-cito-2015>)[Cito et~al., 2015]).

En este contexto, se justifica el desarrollo de un trabajo académico que aborde la observabilidad y la centralización de logs desde una perspectiva teórica y estructurada, orientada al aprendizaje. Al priorizar un enfoque neutral en términos tecnológicos, el documento busca fortalecer el pensamiento sistémico, la capacidad analítica y la comprensión profunda de arquitecturas distribuidas, aportando así a la formación integral de los estudiantes.

= Objetivos
<objetivos>
Los objetivos que orientan este trabajo son los comprometidos en la propuesta de ascenso aprobada por la Universidad del Quindío. Se presentan en tres niveles complementarios: el objetivo general y los objetivos específicos del trabajo (el compromiso institucional), los objetivos formativos del componente conceptual (el nivel del diseño instruccional de este documento) y los resultados de aprendizaje esperados (lo observable en el estudiante). Esta jerarquía aplica el mismo principio de alineación constructiva que estructura todo el recurso.

== Objetivo general
<objetivo-general>
Construir un recurso educativo que integre fundamentos teóricos y un conjunto de guías prácticas para el despliegue de ecosistemas de centralización de logs mediante Docker, con el propósito de apoyar la enseñanza y el aprendizaje en la asignatura #emph[Arquitectura Orientada a Microservicios] del Programa de Ingeniería de Sistemas y Computación de la Universidad del Quindío.

== Objetivos específicos
<objetivos-específicos>
Los tres objetivos específicos (OE) comprometidos en la propuesta aprobada son:

+ #strong[OE1:] Establecer los elementos teóricos relacionados con los logs centralizados en microservicios.
+ #strong[OE2:] Elaborar guías prácticas para el despliegue progresivo de soluciones para centralización de logs utilizando Docker.
+ #strong[OE3:] Implementar cada guía en entornos funcionales y reproducibles para los estudiantes.

La materialización de cada objetivo en componentes concretos del recurso se detalla en la matriz de trazabilidad de la #ref(<tbl-base-4>, supplement: [Tabla]), y su cumplimiento se sintetiza, objetivo por objetivo, en el capítulo de resultados.

== Objetivos formativos del componente conceptual
<objetivos-formativos-del-componente-conceptual>
En el nivel del diseño instruccional, el presente documento (el componente teórico del recurso, que desarrolla el OE1) se orienta a:

- Analizar los fundamentos conceptuales de la observabilidad y su relevancia en arquitecturas distribuidas.
- Examinar el rol de los logs como fuente primaria de información sobre la ejecución de sistemas de software.
- Describir la centralización de logs como un mecanismo para reducir la complejidad cognitiva y operativa.
- Identificar beneficios y desafíos conceptuales asociados al diseño de soluciones de centralización de logs.

Estos objetivos formativos preparan, además, la articulación con las guías prácticas en las que se materializan el OE2 y el OE3.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados>
Al finalizar el estudio de este documento, el estudiante será capaz de:

- #strong[Definir] la observabilidad como principio de ingeniería y distinguirla de la monitorización tradicional en el contexto de sistemas distribuidos.
- #strong[Explicar] por qué los logs constituyen una fuente primaria de información sobre el comportamiento interno de un sistema en ejecución.
- #strong[Describir] la problemática de la dispersión de logs en arquitecturas de microservicios y argumentar la necesidad de su centralización.
- #strong[Identificar] los componentes de la arquitectura conceptual de centralización de logs (recolección, procesamiento, almacenamiento y visualización) y el rol de cada uno dentro del flujo de información.
- #strong[Analizar] los desafíos de diseño asociados a la estandarización semántica, el ciclo de vida de los datos y la protección de información sensible.
- #strong[Relacionar] los conceptos teóricos desarrollados en este documento con las implementaciones prácticas abordadas en las guías complementarias.

= Metodología de Construcción del Recurso Educativo y Trazabilidad con la Propuesta
<sec-metodologia>
La construcción de este recurso educativo se concibe como un proceso aplicado de diseño, desarrollo, verificación y validación de un #strong[artefacto instruccional y tecnológico]. Este trabajo tiene como propósito diseñar un #strong[Recurso Educativo Abierto (REA) portable y modular].

Por consiguiente, la metodología se enfoca en la articulación sistémica entre directrices curriculares de la Ingeniería de Sistemas y Computación, estándares contemporáneos de observabilidad industrial (DevOps/SRE) y la viabilidad instruccional en entornos heterogéneos mediante contenedores Docker.

== Enfoque metodológico adoptado
<enfoque-metodológico-adoptado>
El desarrollo metodológico integra cuatro referentes teóricos de la educación en ingeniería y el diseño de sistemas:

#figure([
#block[
#box(image("_generated/04-metodologia_files/figure-typst/mermaid-figure-1.png", height: 2.02in, width: 6.5in))

]
], caption: figure.caption(
position: bottom, 
[
Referentes metodológicos que orientan el diseño del recurso educativo.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-enfoque-metodologico>


+ #strong[Design Science Research (DSR):] Permite tratar el recurso educativo (compuesto por el marco conceptual, las 9 guías en markdown, las plantillas de configuración y la guía docente) como un #strong[artefacto diseñado] para resolver un problema práctico: la complejidad cognitiva que enfrentan los estudiantes al comprender arquitecturas de observabilidad distribuidas y heterogéneas \(#link(<ref-hevner-2004>)[Hevner et~al., 2004]\; #link(<ref-peffers-2007>)[Peffers et~al., 2007]). La evaluación del artefacto se realiza bajo criterios de utilidad pedagógica, claridad procedimental y reproducibilidad multiplataforma.
+ #strong[Design-Based Research (DBR):] Aporta los principios de diseño orientado a contextos reales de aprendizaje y de refinamiento iterativo que guían la construcción del recurso con miras a su puesta en práctica en el aula de la asignatura #emph[Arquitectura Orientada a Microservicios] \(#link(<ref-design-2003>)[Design-Based Research Collective, 2003]\; #link(<ref-mckenney-2018>)[McKenney & Reeves, 2018]). La validación empírica con estudiantes (análisis de las curvas de aprendizaje y depuración del código Docker ante la heterogeneidad de sus equipos personales) se plantea como fase de #strong[trabajo futuro], dado que esta versión corresponde a la primera publicación del recurso.
+ #strong[Modelo ADDIE:] Estructura de forma sistemática el ciclo de vida instruccional del recurso a través de sus fases de Análisis (de necesidades curriculares y de los entornos de ejecución del estudiante), Diseño (de los RAE y la estructura de las guías), Desarrollo (configuración de los entornos Docker Compose y mockups de microservicios), Implementación (preparación del despliegue local para su ejecución por parte de los estudiantes) y Evaluación (diseño de rúbricas cualitativas y cuantitativas) \(#link(<ref-branch-2009>)[Branch, 2009]).
+ #strong[Alineación Constructiva (Biggs):] Garantiza que no haya desconexión entre los objetivos de aprendizaje de la asignatura, las actividades técnicas requeridas en las guías y los criterios e instrumentos de evaluación declarados en la guía docente \(#link(<ref-biggs-2011>)[Biggs & Tang, 2011]).

== Naturaleza del trabajo y tipo de producto esperado
<naturaleza-del-trabajo-y-tipo-de-producto-esperado>
El trabajo se clasifica como un #strong[desarrollo académico aplicado con orientación instruccional y tecnológica]. El producto final esperado es un #strong[Recurso Educativo Abierto (REA)] compuesto por:

+ Un marco conceptual neutro respecto a las herramientas.
+ Una arquitectura conceptual general del flujo de logs (recolección, procesamiento, almacenamiento y visualización).
+ Nueve (9) guías prácticas e independientes que materializan dicha arquitectura mediante diferentes combinaciones tecnológicas (#emph[stacks]).
+ Una guía didáctica para docentes y una guía de estudio para estudiantes.

El valor del producto radica en su #strong[portabilidad, modularidad y transferibilidad], permitiendo que cualquier docente o estudiante de Ingeniería de Sistemas y Computación pueda replicar los ecosistemas con el único requisito de contar con un motor de contenedores Docker.

== Principios metodológicos
<principios-metodológicos>
El diseño del recurso se sustenta en los siguientes principios metodológicos:

- #strong[Interoperabilidad Curricular y Adaptabilidad (Filosofía REA):] Los contenidos didácticos y stacks prácticos deben estar diseñados para ser independientes de los programas de curso de una institución específica. Se estructuran alineándose con las directrices de currículo globales de computación (ACM/IEEE) y se suministran #strong[rutas de aprendizaje flexibles], facilitando que el recurso pueda ser extrapolado y adoptado en diferentes materias del área de Infraestructura y Desarrollo de TI (ej. Sistemas Distribuidos, DevOps, Arquitectura de Software).
- #strong[Reproducibilidad multiplataforma:] Los procedimientos técnicos y los contenedores deben estar diseñados para ser agnósticos respecto al sistema operativo del host local (compatibles con Windows/WSL2, macOS y GNU/Linux).
- #strong[Transparencia y visibilidad de recursos (Capacity Planning):] El recurso exige la #strong[visibilidad, parametrización y dimensionamiento explícito] de los requerimientos de CPU, memoria RAM y dependencias de software de cada una de las prácticas. Esto permite que el REA pueda ser extrapolado y dimensionado de forma adaptativa a contextos educativos con diferentes restricciones de recursos.
- #strong[Independencia instrumental (Neutralidad):] Las guías prácticas deben funcionar de forma modular, permitiendo al estudiante comprender que las herramientas tecnológicas cambian de un stack a otro, pero las etapas funcionales del pipeline permanecen constantes.
- #strong[Estructura pedagógica experiencial:] Cada guía debe estructurarse internamente bajo el ciclo de aprendizaje de Kolb (Experiencia, Observación, Conceptualización y Experimentación).

== Fases del desarrollo metodológico
<fases-del-desarrollo-metodológico>
Para la consecución de los objetivos propuestos, el proyecto se organizó en siete fases sistemáticas. Cada fase produce insumos o evidencias que estructuran el recurso educativo final.

#figure([
#block[
#box(image("_generated/04-metodologia_files/figure-typst/mermaid-figure-3.png", height: 2.35in, width: 6.5in))

]
], caption: figure.caption(
position: bottom, 
[
Cronograma de las fases metodológicas del proyecto.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-fases-metodologicas>


A continuación, la #ref(<tbl-base-1>, supplement: [Tabla]) detalla las actividades principales, los productos esperados y los criterios de aceptación de cada una de las fases a la luz de los requerimientos de portabilidad y adaptabilidad que definen a un Recurso Educativo Abierto (REA):

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Fase], [Actividades Principales], [Producto Esperado], [Criterio de Aceptación (Calidad/REA)],),
  table.hline(),
  [#strong[\1. Análisis Curricular y Tecnológico]], [\* Revisión de literatura sobre observabilidad, DevOps y prácticas instruccionales de SRE.\* Análisis del microcurrículo de #emph[Arquitectura Orientada a Microservicios] y las directrices globales ACM/IEEE (CS2023).], [Marco conceptual inicial y justificación pedagógica.], [El marco conceptual fundamenta la necesidad de la observabilidad, es neutro respecto a herramientas y se alinea con competencias internacionales.],
  [#strong[\2. Especificación de Requisitos y Entornos]], [\* Análisis de la heterogeneidad de entornos locales de ejecución y definición de variables de portabilidad multiplataforma.\* Especificación de requisitos funcionales, pedagógicos de interoperabilidad y directrices de dimensionamiento de recursos (CPU/RAM).], [Catálogo estructurado de requisitos del REA y especificaciones de dimensionamiento técnico.], [Los requisitos detallan de forma medible la portabilidad multi-OS y establecen la transparencia técnica (visibilidad y parametrización de límites de CPU/RAM) como directriz obligatoria para todas las guías.],
  [#strong[\3. Diseño de Pipelines]], [\* Modelado conceptual de los flujos de logs de 4 etapas (Recolección, Procesamiento, Almacenamiento, Visualización).\* Planificación y estructuración lógica de los 9 escenarios prácticos.], [Arquitectura conceptual y lógica de observabilidad.], [El diseño demuestra la independencia de herramientas y define flujos de datos abstractos, modulares y reutilizables.],
  [#strong[\4. Desarrollo de los Ecosistemas Docker]], [\* Escritura de archivos #NormalTok("docker-compose.yml"); autocontenidos y parametrizados.\* Configuración de colectores, motores de almacenamiento e indexación, y paneles de visualización.], [Código y scripts de configuración funcionales en el repositorio.], [Los entornos Docker Compose corren de forma modular y portable, con límites de recursos (#NormalTok("mem_limit");) ajustables de manera sencilla.],
  [#strong[\5. Diseño Instruccional del REA]], [\* Redacción de las guías didácticas prácticas, docente y de estudio.\* Formulación de Resultados de Aprendizaje Esperados (RAE), preguntas basadas en Kolb y rúbricas.], [Guías académicas complementarias e instrumentos de evaluación.], [Cada práctica contiene un RAE observable, un fundamento teórico neutral, procedimiento reproducible y rúbricas cualitativas homogéneas.],
  [#strong[\6. Verificación Técnica (V&V Multi-OS)]], [\* Despliegue y pruebas de portabilidad (verificación ejecutada sobre macOS Apple Silicon ARM; Windows 11/WSL2 y Ubuntu Linux como objetivos de verificación en curso).\* Monitoreo de consumos con #NormalTok("docker stats");.], [Matriz de pruebas y reportes de portabilidad del entorno.], [Cada stack se despliega en un host limpio e indica sus prerrequisitos técnicos de forma transparente; la cobertura multi-OS completa se documenta como verificación en curso.],
  [#strong[\7. Sistematización y Licenciamiento]], [\* Empaquetado final de códigos y documentación base.\* Configuración de licencia Creative Commons (CC BY-SA 4.0).\* Publicación e indexación del recurso en Zenodo (generación de DOI).], [Repositorio definitivo publicado, archivo CITATION.cff y DOI.], [El recurso cuenta con un DOI válido, licencia abierta compatible con REA y directrices claras de citación estructurada para adopción externa.],
)
], caption: figure.caption(
position: top, 
[
Fases metodológicas, productos esperados y criterios de aceptación.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-1>


== Especificación de requisitos del recurso educativo
<especificación-de-requisitos-del-recurso-educativo>
El catálogo de requisitos del REA se estructura a partir de criterios técnicos e instruccionales, aplicables en cualquier equipo personal con un motor de contenedores:

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Categoría de Requisito], [Origen del Requisito], [Especificación Aplicada], [Criterio de Verificación / Evidencia],),
  table.hline(),
  [#strong[Requisitos Funcionales]], [Demandas de la temática de Microservicios.], [El ecosistema Docker debe aprovisionar un flujo completo donde una aplicación mock genera logs JSON, un colector los procesa estructuradamente y los ingesta en un indexador para ser consultados en un dashboard.], [Visualización de los logs formateados en el panel del stack correspondiente, evidenciada en la sección de capturas de las soluciones.],
  [#strong[Requisitos No Funcionales]], [Criterios de calidad, modularidad y portabilidad de software.], [Las configuraciones e imágenes de los contenedores Docker deben ser portables y construidas de forma que no tengan dependencias locales del sistema de desarrollo de los autores.], [Ejecución exitosa de #NormalTok("docker compose up"); en un entorno host limpio y sin preconfiguraciones del sistema de archivos.],
  [#strong[Requisitos Pedagógicos (Interoperabilidad)]], [Filosofía REA y adaptabilidad curricular.], [El diseño didáctico debe alinearse con estándares de computación internacionales (ACM/IEEE) y estructurarse mediante #strong[Rutas de Aprendizaje Modulares] e instrumentos de evaluación genéricos. Esto facilita que cualquier docente de asignaturas afines (DevOps, Redes, Sistemas Distribuidos, Arquitectura) pueda reusar y adoptar el recurso de forma modular en sus propios LMS (Moodle, Canvas, Classroom).], [Estructuración homogénea de la Guía del Docente (#NormalTok("guia_docente.md");) con matrices de mapeo temático multiplan, rúbricas de evaluación genéricas y planeaciones adaptativas según el enfoque del curso.],
  [#strong[Restricción de Entorno (Transparencia)]], [Filosofía REA y adaptabilidad de contextos educativos.], [El recurso didáctico debe declarar de forma explícita los requisitos mínimos y recomendados de hardware (RAM/CPU) y software de cada práctica, y parametrizar los límites de memoria de Docker (#NormalTok("mem_limit");) para permitir su escalado o atenuación adaptativa.], [Sección estructurada "Dimensionamiento y Prerrequisitos de Recursos" al inicio de cada una de las 9 guías prácticas en el repositorio.],
)
], caption: figure.caption(
position: top, 
[
Clasificación de requisitos del recurso educativo abierto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-2>


== Diseño instruccional y pedagógico de las guías prácticas
<diseño-instruccional-y-pedagógico-de-las-guías-prácticas>
El diseño de las prácticas académicas asume el computador personal del estudiante como laboratorio de experimentación activa, reproducible en cualquier equipo que disponga de un motor de contenedores Docker. Cada una de las 9 guías prácticas se diseña bajo la estructura del #strong[Ciclo de Aprendizaje Experiencial de Kolb], garantizando que el paso a paso sea una oportunidad de reflexión teórica:

#figure([
#block[
#box(image("_generated/04-metodologia_files/figure-typst/mermaid-figure-2.png", height: 3.5in, width: 1.94in))

]
], caption: figure.caption(
position: bottom, 
[
Ciclo de aprendizaje experiencial de Kolb aplicado a la estructura de las guías prácticas.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-ciclo-kolb>


Para asegurar la coherencia sistémica, cada guía didáctica en el repositorio cumple con la siguiente estructura formal:

+ #strong[Resultados de Aprendizaje Esperados (RAE):] Definición exacta de las habilidades conceptuales y operativas que el estudiante adquirirá.
+ #strong[Dimensionamiento y Prerrequisitos de Recursos:] Estimación explícita del consumo de memoria RAM y CPU del stack, advertencias de configuración del host (ej. límites del sistema operativo) y parametrización de los límites de memoria de los contenedores (#NormalTok("mem_limit"); vía variables de entorno #NormalTok(".env");).
+ #strong[Diagrama del Pipeline Lógico:] Ilustración de la arquitectura de la guía en función de las 4 etapas del ciclo de logs.
+ #strong[Procedimiento Técnico Paso a Paso:] Comandos y configuraciones limpias, reproducibles y ordenadas.
+ #strong[Cuestionario de Análisis Crítico:] Preguntas diseñadas para la conceptualización abstracta y el diagnóstico reflexivo de fallos.

Los #strong[instrumentos de evaluación] (entregables exigibles y rúbrica analítica de niveles de desempeño) se proveen de forma #strong[homogénea y centralizada] en la guía docente (#NormalTok("guia_docente.md"); §8), aplicables de manera uniforme a cualquiera de las nueve guías. Esta centralización es una decisión deliberada de diseño REA: garantiza criterios de evaluación consistentes entre stacks, evita la duplicación de rúbricas y facilita que el docente adopte y adapte un único conjunto de instrumentos.

== Marco de Verificación y Validación (V&V)
<marco-de-verificación-y-validación-vv>
El marco de verificación y validación del recurso se centra en dos dimensiones propias de un artefacto educativo abierto: la #strong[calidad de la portabilidad] (reproducibilidad multiplataforma) y la #strong[claridad didáctica]:

- #strong[Verificación del Artefacto (Calidad Técnica de los Entornos):]
  - #emph[Verificación de portabilidad multiplataforma:] Los archivos de Docker Compose se diseñaron para ser portables sobre los sistemas operativos y arquitecturas de uso común en los equipos de los estudiantes:
    + #strong[Windows 11 Home/Pro] sobre WSL2 (arquitectura x86).
    + #strong[macOS] Sequoia/Sonoma (Apple Silicon ARM y x86 Intel).
    + #strong[Ubuntu Linux 22.04 LTS] (arquitectura x86).

    La verificación de despliegue se ejecutó sobre #strong[macOS (Apple Silicon ARM)], entorno disponible para los autores; la verificación sistemática sobre Windows 11/WSL2 y Ubuntu Linux, así como sobre la matriz completa de sistemas operativos y arquitecturas, se contempla como verificación en curso y trabajo futuro.
  - #emph[Verificación de Parametrización:] Comprobación de que las guías incluyan la parametrización de recursos necesaria para que los límites del contenedor puedan modificarse editando archivos de variables de entorno #NormalTok(".env"); o directivas en el archivo Compose.
  - #emph[Validación de Imágenes Libres:] Empleo exclusivo de imágenes oficiales de Docker Hub o de registros de código abierto para evitar licenciamientos privativos.
- #strong[Validación del Artefacto (Eficacia Didáctica y Curricular):]
  - #emph[Validación de Coherencia Pedagógica:] Revisión de que las tareas solicitadas permitan alcanzar y evaluar empíricamente los Resultados de Aprendizaje Esperados (RAE) de la asignatura #emph[Arquitectura Orientada a Microservicios].
  - #emph[Evaluación Editorial y Estructura Docente:] Revisión de la portabilidad e inteligibilidad de la guía docente (#NormalTok("guia_docente.md");) para asegurar que el recurso pueda ser fácilmente reutilizado por otros docentes del programa de Ingeniería de Sistemas y Computación.

#strong[Delimitación del alcance evaluativo.] Los #strong[Resultados de Aprendizaje Esperados (RAE)] declarados en el recurso son objetivos de diseño instruccional, no mediciones empíricas. Los objetivos comprometidos en la propuesta aprobada se circunscriben al #strong[diseño, desarrollo y verificación técnica] del REA (fundamentación teórica, guías prácticas y entornos reproducibles); la #strong[medición del impacto pedagógico] (la evaluación empírica de los resultados de aprendizaje al aplicar el recurso con estudiantes) excede dichos objetivos y se proyecta como una #strong[fase posterior] de validación en aula, que incluirá analítica de uso, encuestas de percepción y ajuste iterativo conforme a los principios de la investigación basada en diseño (DBR), dado que esta versión corresponde a la primera publicación del recurso. La proyección detallada de esta fase, con sus indicadores de evaluación de impacto, se desarrolla en el capítulo de trabajo futuro.

=== Prueba de humo estandarizada
<prueba-de-humo-estandarizada>
Cada una de las nueve soluciones incorpora un script de prueba de humo (#NormalTok("smoke_test.sh");) que automatiza la verificación de extremo a extremo del pipeline: levanta el ecosistema, espera a que la aplicación productora esté lista, emite un log de prueba con un marcador único y confirma su registro en el motor de almacenamiento correspondiente. Este procedimiento de prueba materializa empíricamente el principio de #strong[independencia instrumental]: la fase de #strong[generación] del log es idéntica en los nueve stacks, mientras que solo la #strong[verificación del registro] varía según la herramienta. La siguiente tabla separa ambas partes:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Fase del procedimiento], [¿Estándar entre stacks?], [Detalle],),
  table.hline(),
  [Despliegue y ciclo de vida], [Invariante], [#NormalTok("docker compose up -d --build"); → ejecución → #NormalTok("down -v"); con limpieza ante error (#NormalTok("trap");).],
  [Sonda de disponibilidad del productor], [Invariante], [#NormalTok("POST /logs"); con #NormalTok("{\"level\": \"INFO\", \"message\": \"PING\"}");, reintentos hasta obtener HTTP 200.],
  [Estabilización de la ingesta], [Invariante], [Espera fija previa al envío del mensaje de prueba.],
  [#strong[Emisión del log de prueba]], [#strong[Invariante]], [#NormalTok("POST /logs"); con el esquema #NormalTok("{\"level\": \"WARN\", \"message\": \"<marcador único>\"}"); hacia la misma interfaz del productor.],
  [Verificación del registro], [Específica de la herramienta], [Consulta #NormalTok("_search"); en Elasticsearch/OpenSearch, #NormalTok("query_range"); (LogQL) en Loki o SQL en ClickHouse, según el motor.],
)
], caption: figure.caption(
position: top, 
[
Estandarización de la prueba de humo: fase de generación (invariante) frente a verificación del registro (específica de la herramienta).
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-3>


Las únicas variaciones en la fase de generación responden a restricciones técnicas justificadas: el puerto del productor cambia en el stack que coexiste con servicios que ocupan el puerto por defecto, y dos stacks añaden pasos previos de aprovisionamiento (creación del #emph[input] de ingesta o clonado del repositorio base). Que la interfaz de emisión de logs permanezca constante mientras el conjunto de herramientas cambia por completo constituye evidencia operativa directa de la tesis central del recurso: #strong[las etapas funcionales del pipeline son invariantes; las tecnologías que las implementan, no].

== Matriz de trazabilidad con la propuesta aprobada
<matriz-de-trazabilidad-con-la-propuesta-aprobada>
La siguiente matriz detalla de forma explícita cómo cada uno de los tres objetivos específicos (OE) comprometidos en la propuesta oficial aprobada de ascenso a Titular se materializa formalmente en los capítulos, guías, configuraciones y criterios del presente recurso educativo:

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Objetivo Específico (OE) de la Propuesta Aprobada], [Componentes y Archivos de Desarrollo], [Evidencias y Artefactos Técnicos y Didácticos], [Criterio y Métrica de Cumplimiento del Objetivo],),
  table.hline(),
  [#strong[OE1:] Establecer los elementos teóricos relacionados con los logs centralizados en microservicios.], [\* Capítulos 1, 2, 3 y 4 del libro base (#NormalTok("readme.md");).\* Cuestionario de estudio conceptual (#NormalTok("guia_estudio.md");).], [\* Marco conceptual de la observabilidad (recolección, procesamiento, almacenamiento, visualización).\* Bibliografía de referencia especializada indexada.], [El marco conceptual es agnóstico a las herramientas, fundamenta científicamente la observabilidad en sistemas distribuidos y analiza las implicaciones del esquema semántico y la privacidad.],
  [#strong[OE2:] Elaborar guías prácticas para el despliegue progresivo de soluciones para centralización de logs utilizando Docker.], [\* Carpeta de guías didácticas (#NormalTok("guias/"); de la 1 a la 9).\* Rúbricas y planeación sugerida (#NormalTok("guia_docente.md");).], [\* 9 Guías académicas estructuradas bajo el modelo instruccional de Kolb.\* Rúbrica analítica homogénea y entregables exigibles definidos en la guía docente, aplicables a las 9 guías.], [Se diseñan 9 guías instruccionales que cubren desde los stacks tradicionales hasta soluciones en el estado del arte, ordenadas por complejidad progresiva.],
  [#strong[OE3:] Implementar cada guía en entornos funcionales y reproducibles para los estudiantes.], [\* Carpeta de configuraciones y entornos (#NormalTok("soluciones/"); de la 1 a la 9).\* Repositorio de código con archivos #NormalTok("docker-compose.yml"); y configs.], [\* Archivos YAML de Docker Compose funcionales.\* Archivos de configuración de colectores e indexadores.\* Aplicaciones mocks generadoras de logs.\* Logs e historiales de comandos.], [Las 9 soluciones y contenedores de observabilidad son funcionales, portables y reproducibles, estructuradas de forma parametrizada y con guías de dimensionamiento técnico.],
)
], caption: figure.caption(
position: top, 
[
Trazabilidad entre los objetivos específicos de la propuesta aprobada y los componentes del recurso.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-4>


== Gestión de evidencias del trabajo
<gestión-de-evidencias-del-trabajo>
Para que el cumplimiento de los objetivos sea verificable por pares académicos, el recurso adopta una gestión explícita de evidencias: todo resultado declarado en este documento está respaldado por un artefacto observable dentro del repositorio público. Este enfoque es coherente con la naturaleza del trabajo como artefacto de Design Science Research, cuyo valor se demuestra mediante productos tangibles y auditables, y aprovecha una característica diferencial del recurso: al publicarse como repositorio navegable con DOI (#link("https://github.com/christiancandela/logs-centralizados")), cualquier evaluador puede inspeccionar las evidencias e incluso reproducirlas en su propio equipo. La #ref(<tbl-base-5>, supplement: [Tabla]) inventaría las evidencias del trabajo, su ubicación y el objetivo específico al que aportan.

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Evidencia], [Ubicación en el repositorio], [Descripción], [Objetivo al que aporta],),
  table.hline(),
  [Marco conceptual tecnológicamente neutral], [#NormalTok("readme.md"); (este documento)], [Desarrollo teórico de la observabilidad y de la arquitectura conceptual de cuatro etapas, con sus desafíos y paradigmas de almacenamiento.], [OE1],
  [Guía de estudio], [#NormalTok("guia_estudio.md");], [Veinte preguntas de comprensión con respuesta, glosario terminológico y bloque de articulación teoría--práctica.], [OE1],
  [Guías prácticas], [#NormalTok("guias/"); (9 documentos)], [Guías instruccionales bajo el ciclo de Kolb, con RAE, dimensionamiento de recursos, procedimiento reproducible y cuestionario de análisis crítico.], [OE2],
  [Guía docente], [#NormalTok("guia_docente.md");], [Rutas de planificación, instrumentos de evaluación homogéneos (entregables y rúbrica) y anticipación de dificultades frecuentes.], [OE2],
  [Soluciones ejecutables], [#NormalTok("soluciones/"); (9 entornos)], [Archivos #NormalTok("docker-compose.yml");, configuraciones de colectores e indexadores y aplicación productora de logs de cada stack.], [OE3],
  [Pruebas de humo automatizadas], [#NormalTok("smoke_test.sh"); en cada solución], [Verificación automatizada de extremo a extremo del pipeline de cada stack, con marcador único y consulta de confirmación en el motor de almacenamiento.], [OE3],
  [Parametrización de recursos], [Archivos #NormalTok(".env"); de cada solución], [Límites de memoria de los contenedores (#NormalTok("mem_limit");) ajustables mediante variables de entorno, en cumplimiento del principio de transparencia de recursos.], [OE3],
  [Metadatos de publicación abierta], [#NormalTok("CITATION.cff");, #NormalTok(".zenodo.json");, #NormalTok("LICENSE");], [Citación estructurada, DOI persistente y licenciamiento abierto que habilitan la adopción y trazabilidad externa del recurso.], [Transversal],
)
], caption: figure.caption(
position: top, 
[
Inventario de evidencias verificables del recurso educativo.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-5>


Cada evidencia se presenta acompañada de su propósito y de su relación con el objetivo que soporta: las capturas y salidas incluidas en las guías se contextualizan con el paso del procedimiento al que corresponden, los scripts de verificación declaran qué comprueban y cómo interpretarlo, y la matriz de trazabilidad de la #ref(<tbl-base-4>, supplement: [Tabla]) vincula formalmente cada conjunto de evidencias con sus criterios y métricas de cumplimiento. El capítulo de resultados retoma este inventario para sintetizar, objetivo por objetivo, lo efectivamente producido y su evidencia asociada.

= Desarrollo de la temática
<sec-marco-conceptual>
Esta sección desarrolla de manera progresiva los fundamentos conceptuales de la observabilidad y la centralización de logs en sistemas distribuidos. El recorrido inicia con la definición y alcance del concepto de observabilidad, avanza hacia el análisis del rol de los logs como fuente primaria de información y culmina con la presentación de una arquitectura conceptual que integra los distintos componentes involucrados. Esta progresión busca facilitar una comprensión gradual y coherente, orientada al aprendizaje y a la posterior aplicación práctica de los conceptos abordados.

== Observabilidad en sistemas distribuidos
<sec-5-1>
La observabilidad se define como la capacidad de inferir el estado interno de un sistema complejo a partir de las señales externas que este produce durante su ejecución \(#link(<ref-beyer-2016>)[Beyer et~al., 2016]\; #link(<ref-majors-2022>)[Majors et~al., 2022]\; #link(<ref-sridharan-2018>)[Sridharan, 2018]). En sistemas distribuidos, esta capacidad resulta crítica debido a la concurrencia, la comunicación asincrónica y la distribución de responsabilidades entre múltiples componentes autónomos, factores que dificultan la identificación directa de causas y efectos \(#link(<ref-usman-2022>)[Usman et~al., 2022]).

Desde la ingeniería de software, la observabilidad se ha consolidado como un principio complementario a la monitorización tradicional. Mientras esta última se enfoca en indicadores previamente definidos, la observabilidad busca responder preguntas no anticipadas, permitiendo explorar el comportamiento del sistema cuando surgen fallos o degradaciones inesperadas \(#link(<ref-turnbull-2016>)[Turnbull, 2016]). Este enfoque resulta particularmente relevante en arquitecturas de microservicios, donde los comportamientos emergentes no pueden ser previstos completamente en tiempo de diseño \(#link(<ref-newman-2015>)[Newman, 2015]).

Conviene precisar que el término #emph[observabilidad] no se originó en la ingeniería de software, sino en la teoría de control, donde Kalman (#link(<ref-kalman-1960>)[1960]) lo definió formalmente como la propiedad que permite reconstruir el estado interno de un sistema dinámico a partir del conocimiento de sus salidas externas. Esta raíz conceptual resulta esclarecedora: un sistema es observable no por la cantidad de datos que emite, sino por la posibilidad de inferir su estado interno a partir de ellos. Trasladada al software, la observabilidad no se reduce, por tanto, a "generar abundantes registros", sino a disponer de señales suficientes y bien estructuradas para responder preguntas sobre el comportamiento del sistema.

En la práctica, la observabilidad de un sistema de software se construye sobre tres tipos de señales complementarias, conocidas como los #strong[tres pilares de la observabilidad] \(#link(<ref-majors-2022>)[Majors et~al., 2022]\; #link(<ref-sridharan-2018>)[Sridharan, 2018]):

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Señal], [Naturaleza], [Pregunta que ayuda a responder], [Ejemplo conceptual],),
  table.hline(),
  [#strong[Logs]], [Registros textuales de eventos discretos], [¿Qué ocurrió exactamente y por qué?], [#NormalTok("ERROR pago rechazado: saldo insuficiente, usuario=4827");],
  [#strong[Métricas]], [Valores numéricos agregados en el tiempo], [¿Cuánto, con qué frecuencia, con qué tendencia?], [#NormalTok("solicitudes_por_segundo = 1450");],
  [#strong[Trazas]], [Recorrido de una solicitud a través de varios servicios], [¿Por dónde pasó la solicitud y dónde se demoró?], [#NormalTok("petición #abc: API (2 ms) → pagos (310 ms) → BD (15 ms)");],
)
], caption: figure.caption(
position: top, 
[
Los tres pilares de la observabilidad.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-6>


Aunque los tres pilares se complementan, presentan diferencias importantes en su costo de almacenamiento y en su riqueza contextual. Las métricas son altamente compactas, pero pierden el detalle de los eventos individuales; las trazas revelan la topología de las interacciones, pero requieren instrumentación explícita; los logs, en cambio, preservan el contexto semántico completo de cada evento, razón por la cual constituyen el foco de este documento. Un concepto transversal a los tres pilares es el de #strong[cardinalidad] (el número de valores distintos que puede tomar un atributo), cuya gestión inadecuada constituye uno de los principales retos de costo y rendimiento de los sistemas de observabilidad, como se discute en la #ref(<sec-5-6>, supplement: [Sección]).

== Logs como fuente primaria de información
<sec-5-2>
Los logs constituyen registros textuales de eventos discretos que ocurren durante la ejecución de un sistema y representan una de las formas más expresivas de instrumentación del software \(#link(<ref-turnbull-2016>)[Turnbull, 2016]). A diferencia de las métricas, que capturan valores agregados, y de las trazas, que describen recorridos de solicitudes, los logs preservan el contexto semántico de los eventos, facilitando la comprensión del #emph[qué] y el #emph[por qué] de una situación determinada.

Diversos estudios destacan que los logs no solo cumplen una función operativa, sino que actúan como artefactos de conocimiento que reflejan decisiones de diseño, supuestos implícitos y modelos mentales de los desarrolladores \(#link(<ref-he-2021>)[S. He et~al., 2021]\; #link(<ref-oliner-2012>)[Oliner et~al., 2012]\; #link(<ref-xu-2009>)[Xu et~al., 2009]). Desde una perspectiva formativa, esta característica permite a los estudiantes analizar evidencias reales de ejecución y vincular los conceptos teóricos de arquitectura y diseño con su manifestación práctica.

Para comprender el valor de los logs conviene examinar su anatomía. Un registro típico se compone de, al menos, una #strong[marca temporal] (cuándo ocurrió el evento), un #strong[nivel de severidad] (qué tan importante es), un #strong[mensaje] descriptivo y, idealmente, un conjunto de #strong[campos de contexto] (qué servicio, qué usuario, qué operación). La forma en que estos elementos se representan determina la facilidad con que pueden analizarse de manera automatizada. Históricamente, los logs se escribían como texto libre no estructurado, legible para las personas pero difícil de procesar por las máquinas:

#Skylighting(([#NormalTok("2026-05-14 10:32:01 ERROR El pago del usuario 4827 fue rechazado por saldo insuficiente");],));
El #strong[logging estructurado] propone, en cambio, representar cada evento como un objeto con campos explícitos (habitualmente en formato JSON), de modo que cada dato sea identificable y consultable sin necesidad de interpretar la cadena de texto \(#link(<ref-chuvakin-2012>)[Chuvakin et~al., 2012]):

#Skylighting(([#FunctionTok("{");],
[#NormalTok("  ");#DataTypeTok("\"timestamp\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"2026-05-14T10:32:01Z\"");#FunctionTok(",");],
[#NormalTok("  ");#DataTypeTok("\"level\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"ERROR\"");#FunctionTok(",");],
[#NormalTok("  ");#DataTypeTok("\"event\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"pago_rechazado\"");#FunctionTok(",");],
[#NormalTok("  ");#DataTypeTok("\"usuario_id\"");#FunctionTok(":");#NormalTok(" ");#DecValTok("4827");#FunctionTok(",");],
[#NormalTok("  ");#DataTypeTok("\"motivo\"");#FunctionTok(":");#NormalTok(" ");#StringTok("\"saldo_insuficiente\"");],
[#FunctionTok("}");],));
Esta diferencia es determinante para la centralización: los logs estructurados pueden filtrarse, agregarse y correlacionarse de forma sistemática, mientras que el texto libre exige un procesamiento adicional (y frecuentemente frágil) para extraer su significado, como se detalla en la #ref(<sec-5-7-2>, supplement: [Sección]).

Los niveles de severidad constituyen otra convención fundamental. La mayoría de los marcos de registro adoptan una jerarquía estándar (comúnmente TRACE, DEBUG, INFO, WARN, ERROR y FATAL) que expresa la importancia relativa de cada evento y permite regular el volumen de información según el contexto: un registro detallado durante el desarrollo y la depuración, y un registro selectivo de advertencias y errores en producción. Comprender la semántica de estos niveles es esencial para equilibrar la riqueza informativa con el costo de almacenamiento y el ruido analítico que un exceso de registros de bajo nivel puede introducir.

== Problemática de la dispersión de logs
<sec-5-3>
En sistemas distribuidos, cada componente genera sus propios registros de manera local, lo que conduce a una dispersión de la información que dificulta su análisis integral. Esta fragmentación incrementa la carga cognitiva requerida para el diagnóstico de fallos y limita la capacidad de correlacionar eventos entre servicios independientes \(#link(<ref-cito-2015>)[Cito et~al., 2015]).

La literatura señala que, a medida que aumenta el número de servicios y nodos, el análisis manual de logs locales se vuelve inviable, generando opacidad operativa y dependencia excesiva de conocimiento tácito \(#link(<ref-burns-2016>)[Burns et~al., 2016]\; #link(<ref-oliner-2012>)[Oliner et~al., 2012]). Esta problemática refuerza la necesidad de enfoques sistemáticos para la gestión y análisis de registros en entornos distribuidos.

Más allá del volumen, la dispersión plantea dos problemas conceptualmente profundos. El primero es el de la #strong[correlación de eventos]: cuando una sola solicitud de usuario atraviesa varios servicios, cada uno genera registros de forma independiente, y sin un mecanismo que los vincule resulta imposible reconstruir la secuencia completa. La solución conceptual a este problema es la propagación de un #strong[identificador de correlación] (#emph[correlation ID] o #emph[trace ID]) que acompaña a la solicitud a lo largo de todos los servicios que la procesan, permitiendo agrupar a posteriori todos los eventos que pertenecen a la misma operación \(#link(<ref-sigelman-2010>)[Sigelman et~al., 2010]).

El segundo problema es el del #strong[orden temporal]. En un sistema distribuido, cada nodo posee su propio reloj físico, y estos relojes nunca están perfectamente sincronizados. En consecuencia, ordenar eventos provenientes de máquinas distintas únicamente por su marca temporal puede producir secuencias incorrectas. Lamport (#link(<ref-lamport-1978>)[1978]) demostró que, en ausencia de un reloj global, lo determinante no es el tiempo absoluto sino la relación de causalidad entre eventos (la relación #emph[happened-before]), y propuso los relojes lógicos como mecanismo para establecer un orden coherente. Esta noción es fundamental para comprender por qué la correlación y el ordenamiento de logs distribuidos constituyen un problema no trivial, y no una simple cuestión de comparar fechas.

== Centralización de logs
<sec-5-4>
La centralización de logs surge como una estrategia para mitigar la dispersión de información mediante la recolección, consolidación y almacenamiento de los registros generados por los distintos componentes del sistema en un repositorio común \(#link(<ref-majors-2022>)[Majors et~al., 2022]\; #link(<ref-turnbull-2016>)[Turnbull, 2016]). Este enfoque facilita la consulta unificada, la correlación temporal y el análisis transversal de eventos.

Desde el punto de vista conceptual, la centralización de logs transforma un conjunto fragmentado de mensajes en una fuente coherente de conocimiento operativo, habilitando procesos de diagnóstico distribuido y análisis post-mortem de incidentes complejos \(#link(<ref-beyer-2016>)[Beyer et~al., 2016]). Asimismo, permite reconstruir narrativas de ejecución que son fundamentales para comprender fallos en cascada y comportamientos no deterministas.

Desde el punto de vista de su materialización, la centralización admite distintos #strong[modelos de recolección]. En el modelo de #emph[envío] (#emph[push]), cada componente (o un agente asociado a él) transmite activamente sus registros hacia el sistema central. En el modelo de #emph[extracción] (#emph[pull]), el sistema central consulta periódicamente a las fuentes para obtener los registros disponibles. La captura, a su vez, puede realizarse mediante distintos patrones: un agente recolector instalado en cada host, un componente acompañante dedicado a un único servicio (#emph[sidecar]) o el envío directo desde la propia aplicación mediante una biblioteca de instrumentación. La elección entre estos modelos afecta el acoplamiento, la resiliencia y la sobrecarga operativa de la solución, y constituye una de las primeras decisiones de diseño que el estudiante debe aprender a razonar de forma crítica.

== Beneficios conceptuales de la centralización de logs
<sec-5-5>
La centralización de logs aporta beneficios que trascienden el ámbito técnico inmediato. Entre los más relevantes se encuentran:

- Mejora de la visibilidad global del sistema y de sus interacciones internas.
- Reducción de la complejidad cognitiva asociada al análisis de fallos distribuidos.
- Posibilidad de correlacionar eventos en función del tiempo y del contexto.
- Apoyo a procesos de aprendizaje, investigación formativa y análisis de casos reales.

Estos beneficios refuerzan el valor de la centralización de logs como herramienta conceptual para la formación en arquitectura de software y sistemas distribuidos \(#link(<ref-bosch-2016>)[Bosch, 2016]).

== Desafíos y criterios conceptuales
<sec-5-6>
El diseño de soluciones de centralización de logs implica enfrentar diversos desafíos técnicos y operativos \(#link(<ref-beyer-2016>)[Beyer et~al., 2016]\; #link(<ref-kitchin-2014>)[Kitchin, 2014]). Abordarlos adecuadamente requiere la adopción de criterios conceptuales sólidos:

- #strong[Estandarización Semántica:] En arquitecturas heterogéneas, consolidar logs carece de valor si no comparten un esquema común. La adopción de estándares de esquema semántico ampliamente reconocidos en la industria (que definen convenciones uniformes para nombres de campos, tipos de datos y niveles de severidad) es fundamental para garantizar que los eventos de distintos servicios puedan correlacionarse correctamente \(#link(<ref-he-2021>)[S. He et~al., 2021]), facilitando así la reconstrucción de flujos de ejecución distribuidos que atraviesan múltiples microservicios \(#link(<ref-sigelman-2010>)[Sigelman et~al., 2010]). Las guías prácticas complementarias ilustran la aplicación concreta de varios de estos estándares en diferentes ecosistemas tecnológicos.
- #strong[Ciclo de Vida y Retención de Datos:] Dado el inmenso volumen de información operativa, los sistemas de centralización deben implementar políticas de retención, rotación y almacenamiento por niveles (#emph[Hot/Cold storage]) para gestionar el impacto en la infraestructura sin perder capacidades de auditoría a largo plazo.
- #strong[Seguridad y Privacidad (Sanitización):] Los logs suelen capturar inadvertidamente información sensible (contraseñas, tokens, datos de usuarios PII). Es imperativo que las arquitecturas incluyan mecanismos de censura o enmascaramiento de datos durante la fase de procesamiento antes de su indexación \(#link(<ref-aghili-2025>)[Aghili et~al., 2025]).
- #strong[Volumen, Cardinalidad y Costo:] El valor analítico de un sistema de centralización depende de su capacidad de indexar los datos para consultarlos con rapidez, pero indexar tiene un costo. Los atributos de alta #emph[cardinalidad] (aquellos con un número muy elevado de valores distintos, como los identificadores de usuario o de petición) pueden provocar un crecimiento desproporcionado de los índices y degradar el rendimiento. Diseñar una solución de centralización implica, por tanto, decidir conscientemente qué campos justifican el costo de ser indexados y cuáles no, decisión que se relaciona directamente con el paradigma de almacenamiento elegido (#ref(<sec-5-7-3>, supplement: [Sección])).
- #strong[Orden Temporal y Relojes Distribuidos:] Como se discutió en la #ref(<sec-5-3>, supplement: [Sección]), los relojes de los distintos nodos no están perfectamente sincronizados, lo que dificulta establecer el orden real de los eventos a partir de sus marcas temporales \(#link(<ref-lamport-1978>)[Lamport, 1978]). Las soluciones de centralización deben asumir esta limitación y apoyarse en identificadores de correlación y en marcas temporales coherentes para reconstruir las secuencias de ejecución.
- #strong[Confiabilidad de la Entrega y Contrapresión:] El transporte de logs desde su origen hasta el repositorio central no está exento de fallos. Las soluciones deben definir garantías de entrega, desde #emph[at-most-once] (se prioriza no duplicar, a riesgo de perder eventos) hasta #emph[at-least-once] (se prioriza no perder, a riesgo de duplicar), así como mecanismos de amortiguación (#emph[buffering]) y contrapresión (#emph[backpressure]) que eviten que un pico en la generación de logs sature o derribe los componentes intermedios.

Desde una perspectiva académica, el análisis de estos desafíos permite a los estudiantes desarrollar criterios transferibles a distintos contextos tecnológicos, fomentando una comprensión crítica de las decisiones de diseño y sus implicaciones operativas y éticas.

== Arquitectura conceptual de las soluciones de centralización de logs
<sec-5-7>
Aunque las implementaciones prácticas de la centralización de logs pueden variar ampliamente en función de las tecnologías empleadas, la literatura y la experiencia industrial coinciden en que dichas soluciones comparten una #strong[arquitectura conceptual común], compuesta por varios componentes claramente diferenciables \(#link(<ref-newman-2015>)[Newman, 2015]\; #link(<ref-turnbull-2016>)[Turnbull, 2016]).

Introducir esta arquitectura a nivel conceptual resulta pertinente desde el punto de vista formativo, ya que permite a los estudiantes comprender la lógica subyacente de las soluciones antes de enfrentarse a su implementación práctica, facilitando la transferencia de conocimiento entre distintos ecosistemas tecnológicos.

#figure([
#block[
#box(image("_generated/05-desarrollo-tematica_files/figure-typst/mermaid-figure-1.png", height: 1.09in, width: 6.5in))

]
], caption: figure.caption(
position: bottom, 
[
Arquitectura conceptual de la centralización de logs en cuatro etapas.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-arquitectura-conceptual>


#quote(block: true)[
#strong[Nota sobre el alcance del diagrama:] Los sistemas distribuidos generan tres tipos de señales de observabilidad: #strong[logs] (eventos discretos con contexto semántico), #strong[métricas] (mediciones numéricas agregadas en el tiempo) y #strong[trazas] (recorridos de solicitudes a través de múltiples servicios). La arquitectura conceptual de cuatro etapas (recolección, procesamiento, almacenamiento y visualización) aplica a las tres señales. Este documento centra su desarrollo en los #strong[logs], por ser la señal de mayor riqueza contextual y la más directamente vinculada a la comprensión del comportamiento interno del sistema \(#link(<ref-majors-2022>)[Majors et~al., 2022]). Las guías prácticas complementarias amplían el tratamiento hacia métricas y trazas en los ecosistemas que las integran de forma nativa.
]

=== Recolección de logs
<sec-5-7-1>
El componente de #strong[recolección de logs] es responsable de capturar los registros generados por aplicaciones, servicios y componentes de infraestructura. En términos conceptuales, este componente actúa como el punto de entrada del flujo de observabilidad y debe operar de manera desacoplada, de modo que la captura de eventos no interfiera con la ejecución normal del sistema.

Desde una perspectiva formativa, resulta relevante comprender que la recolección de logs involucra decisiones relacionadas con la ubicación de los agentes de captura, la frecuencia de recolección y el tipo de información registrada. Estas decisiones influyen directamente en la calidad, utilidad y confiabilidad de la observabilidad obtenida, y condicionan los análisis posteriores que pueden realizarse sobre los datos recolectados \(#link(<ref-xu-2009>)[Xu et~al., 2009]).

Una propiedad conceptual central de esta etapa es el desacoplamiento temporal entre la generación y el consumo de los registros. Para que la captura no interfiera con la aplicación cuando el sistema central se ralentiza o deja de responder, los recolectores suelen incorporar mecanismos de amortiguación (#emph[buffering]) que almacenan temporalmente los eventos. Comprender este principio permite razonar sobre las garantías de entrega y la contrapresión introducidas en la #ref(<sec-5-6>, supplement: [Sección]), y entender por qué un buen recolector debe ser, ante todo, robusto frente a la indisponibilidad de los componentes que lo suceden.

=== Procesamiento y enriquecimiento de logs
<sec-5-7-2>
El #strong[procesamiento de logs] comprende el conjunto de actividades orientadas a transformar los registros crudos en información estructurada y significativa. Entre estas actividades se incluyen el filtrado de eventos irrelevantes, la normalización de formatos, el enriquecimiento semántico y la correlación básica de eventos.

Desde el punto de vista conceptual, este procesamiento permite reducir el ruido inherente a grandes volúmenes de datos operativos y preparar los logs para su almacenamiento y análisis posterior. En el ámbito educativo, este componente introduce a los estudiantes en la noción de que los datos generados por los sistemas requieren un tratamiento previo para convertirse en información útil y accionable \(#link(<ref-he-2017>)[P. He et~al., 2017]\; #link(<ref-oliner-2012>)[Oliner et~al., 2012]\; #link(<ref-zhu-2019>)[Zhu et~al., 2019]).

La viabilidad y el costo de esta etapa dependen en gran medida de la estructura de los datos de entrada. Cuando los logs llegan ya estructurados (#ref(<sec-5-2>, supplement: [Sección])), el procesamiento se reduce a operaciones directas sobre campos identificados; cuando llegan como texto libre, es necesario aplicar técnicas de análisis sintáctico (expresiones regulares o gramáticas de extracción) que resultan más frágiles y costosas de mantener \(#link(<ref-he-2017>)[P. He et~al., 2017]\; #link(<ref-zhu-2019>)[Zhu et~al., 2019]). El procesamiento es también el punto natural donde se aplican dos operaciones críticas: el #emph[muestreo] (#emph[sampling]), que descarta deliberadamente parte de los eventos para controlar el volumen, y la #emph[sanitización] o enmascaramiento de información sensible antes de su almacenamiento (#ref(<sec-5-6>, supplement: [Sección])), lo que convierte a esta etapa en un punto de decisión tanto técnico como ético.

=== Almacenamiento y búsqueda
<sec-5-7-3>
El #strong[almacenamiento y motor de búsqueda] constituye el núcleo analítico de una solución de centralización de logs. Su función principal es conservar los registros de manera eficiente y habilitar mecanismos de consulta flexibles que faciliten el análisis exploratorio y el diagnóstico de incidentes.

A nivel conceptual, este componente introduce nociones fundamentales relacionadas con la indexación de datos, la gestión de la retención de información y la ejecución de consultas temporales. Estos aspectos resultan esenciales para comprender cómo se construye la visibilidad del sistema a lo largo del tiempo y cómo se posibilita el análisis retrospectivo de eventos \(#link(<ref-kitchin-2014>)[Kitchin, 2014]\; #link(<ref-kleppmann-2017>)[Kleppmann, 2017]).

Desde una perspectiva más avanzada, no existe un único modelo de almacenamiento óptimo: las soluciones adoptan distintos #strong[paradigmas de indexación], cada uno con compromisos diferentes entre velocidad de consulta, flexibilidad y costo. Comprender estos paradigmas permite entender por qué soluciones distintas resultan más adecuadas para necesidades distintas, y constituye uno de los criterios de diseño más transferibles del área:

#figure([
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Paradigma], [Qué indexa], [Fortaleza de consulta], [Perfil de costo], [Orientación típica],),
  table.hline(),
  [#strong[Índice invertido] (búsqueda de texto completo)], [Cada término de cada mensaje], [Búsqueda libre y flexible sobre cualquier palabra del contenido], [Alto costo de indexación y almacenamiento], [Exploración y búsqueda ad hoc],
  [#strong[Almacén columnar] (analítico / OLAP)], [Columnas completas de atributos estructurados], [Agregaciones y análisis sobre grandes volúmenes], [Eficiente en compresión; menos flexible para texto libre], [Análisis cuantitativo a gran escala],
  [#strong[Índice de solo etiquetas]], [Únicamente un conjunto reducido de etiquetas (metadatos)], [Filtrado rápido por etiquetas; el contenido se examina al consultar], [Muy bajo costo de indexación y almacenamiento], [Grandes volúmenes con consultas acotadas por etiquetas],
)
], caption: figure.caption(
position: top, 
[
Paradigmas de indexación y almacenamiento y sus compromisos.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-7>


El #strong[índice invertido], heredado de la disciplina de recuperación de información, asocia cada término al conjunto de registros que lo contienen, lo que habilita búsquedas de texto completo muy flexibles a cambio de un alto costo de indexación y almacenamiento \(#link(<ref-manning-2008>)[Manning et~al., 2008]). El #strong[almacenamiento columnar], propio de los sistemas analíticos, organiza los datos por columnas en lugar de por filas, lo que permite comprimir y agregar grandes volúmenes de datos estructurados con notable eficiencia, aunque resulta menos apto para la búsqueda libre de texto \(#link(<ref-abadi-2008>)[Abadi et~al., 2008]). Finalmente, el #strong[índice de solo etiquetas] minimiza deliberadamente lo que se indexa (apenas un conjunto reducido de metadatos), reduciendo de forma drástica el costo a cambio de exigir que el contenido se examine en el momento de la consulta. Estas tres aproximaciones no son excluyentes, y las guías prácticas complementarias permiten contrastar empíricamente sus implicaciones en ecosistemas tecnológicos concretos.

=== Visualización y análisis
<sec-5-7-4>
El componente de #strong[visualización] tiene como propósito presentar la información contenida en los logs de manera comprensible para los usuarios humanos. Mediante representaciones gráficas, tablas y paneles, se facilita la identificación de patrones, tendencias y posibles anomalías en el comportamiento del sistema.

Desde una perspectiva formativa, la visualización cumple un rol clave al reducir la carga cognitiva asociada al análisis de grandes volúmenes de información y al permitir que los estudiantes desarrollen habilidades de interpretación y análisis de datos operativos. De este modo, se establece un vínculo directo entre los registros técnicos y los procesos de toma de decisiones informadas \(#link(<ref-bosch-2016>)[Bosch, 2016]).

A un nivel más avanzado, la visualización se apoya en #strong[lenguajes de consulta] especializados que permiten filtrar, agregar y transformar los registros almacenados, y cuya expresividad está condicionada por el paradigma de almacenamiento subyacente (#ref(<sec-5-7-3>, supplement: [Sección])). Sobre esta capacidad de consulta se construye, además, la noción de #strong[alertamiento]: la definición de condiciones que, al cumplirse sobre el flujo de logs, notifican automáticamente a los responsables del sistema. De este modo, la visualización no es únicamente un mecanismo de exploración retrospectiva, sino también un soporte para la detección proactiva de anomalías.

=== Integración conceptual de los componentes
<sec-5-7-5>
Los componentes de recolección, procesamiento, almacenamiento y visualización no deben entenderse como elementos aislados, sino como partes interdependientes de un flujo continuo de información. Cada uno cumple una función específica dentro de la arquitectura, pero su valor emerge plenamente cuando se articulan de manera coherente.

Desde el punto de vista conceptual, esta integración permite comprender cómo los eventos generados durante la ejecución de un sistema se transforman progresivamente en información significativa para el análisis y la toma de decisiones. Para los estudiantes, esta visión integrada facilita el tránsito desde la comprensión teórica hacia la implementación práctica, al proporcionar un modelo mental claro que puede ser instanciado mediante distintas tecnologías en los ejercicios aplicados.

De este modo, la arquitectura conceptual presentada establece un puente entre los fundamentos teóricos desarrollados en este trabajo escrito y las actividades prácticas abordadas en los materiales complementarios, manteniendo la neutralidad tecnológica del documento.

= Alcance y articulación con las actividades prácticas
<alcance-y-articulación-con-las-actividades-prácticas>
== Alcance del documento
<alcance-del-documento>
Este #strong[marco conceptual] se centra en el desarrollo teórico de la centralización de logs como pilar de la observabilidad y se mantiene deliberadamente neutral en términos tecnológicos. Su instanciación práctica se desarrolla en las guías complementarias que forman parte del mismo recurso educativo abierto (REA), de modo que el componente conceptual y el práctico se articulan como partes de un único producto académico, sin que la neutralidad del primero se vea comprometida por las decisiones tecnológicas del segundo.

El trabajo abarca el #strong[diseño, desarrollo y verificación técnica] del recurso; la #strong[medición empírica del impacto pedagógico] al aplicarlo con estudiantes no forma parte de los objetivos comprometidos y se proyecta como una fase posterior de validación en aula (véase la delimitación del alcance evaluativo en el Marco de Verificación y Validación).

#horizontalrule

Este capítulo conceptual se limita intencionalmente a la #strong[fundamentación teórica] de la centralización de logs y su rol en la observabilidad. Las guías prácticas, laboratorios y escenarios de despliegue progresivo se desarrollan como guías complementarias del mismo REA, con el objetivo de:

- Mantener la neutralidad tecnológica del contenido central.
- Facilitar su reutilización en distintos cursos y programas académicos.
- Permitir la actualización incremental de las guías prácticas sin afectar el marco teórico.

== Articulación con las actividades prácticas
<articulación-con-las-actividades-prácticas>
Con el propósito de afianzar los fundamentos teóricos desarrollados a lo largo de este trabajo escrito, se han diseñado y documentado un conjunto de #strong[guías prácticas] orientadas a la implementación de soluciones de centralización de logs mediante diferentes #emph[stacks] tecnológicos. Estas guías permiten a los estudiantes materializar los conceptos de observabilidad y arquitectura conceptual estudiados, favoreciendo un aprendizaje activo y progresivo.

Las actividades prácticas no se conciben como ejercicios aislados ni como simples tutoriales de herramientas, sino como escenarios de aplicación que permiten reconocer, en contextos concretos, los componentes conceptuales analizados: recolección, procesamiento, almacenamiento, búsqueda y visualización de logs. De este modo, las guías prácticas refuerzan la transferencia del conocimiento teórico hacia entornos reales de operación, manteniendo la neutralidad tecnológica del marco conceptual presentado.

#strong[Requisitos técnicos:] El despliegue de estos ecosistemas mediante contenedores requiere un uso intensivo de memoria. Se recomienda disponer de al menos #strong[8 GB de RAM] libres y configurar adecuadamente los límites del sistema operativo (como #NormalTok("vm.max_map_count"); en Linux/WSL) según se detalla en las guías, para evitar caídas en los servicios.

#strong[Ruta de Aprendizaje Sugerida:]

Aunque las guías son independientes, se sugiere el siguiente orden de consumo para una progresión pedagógica óptima:

+ #strong[#link(<sec-guia-elk>)[ELK Stack]:] Ideal para comenzar, siendo el ecosistema tradicional más extendido en la industria.
+ #strong[#link(<sec-guia-olo>)[OLO Stack (OpenSearch)]:] Permite explorar la evolución natural y el #emph[fork] Open Source de Elasticsearch.
+ #strong[#link(<sec-guia-fluentd>)[Fluentd]:] Introduce enfoques alternativos y desacoplados para la recolección y ruteo de logs.
+ #strong[#link(<sec-guia-promtail>)[Promtail y Loki (Grafana)]:] Aborda un modelo altamente eficiente basado en la indexación exclusiva de etiquetas, integrando las herramientas exactas mencionadas en la propuesta original.
+ #strong[#link(<sec-guia-gelf-graylog>)[GELF y Graylog]:] Presenta formatos de transporte específicos y plataformas enfocadas exclusivamente en la gestión de logs.
+ #strong[#link(<sec-guia-otel>)[OpenTelemetry]:] Presenta el estándar unificador actual y más interoperable para la observabilidad unificada.
+ #strong[#link(<sec-guia-vector>)[Vector, Loki y Grafana]:] (#emph[Estado del Arte]) Introduce el concepto de #emph[Pipeline de Observabilidad] de alto rendimiento utilizando Rust para desplazar a recolectores pesados.
+ #strong[#link(<sec-guia-signoz>)[SigNoz (ClickHouse)]:] (#emph[Estado del Arte]) Plataforma "Todo en Uno" que utiliza OpenTelemetry nativamente y almacenamiento analítico columnar, representando la alternativa libre a plataformas comerciales.
+ #strong[#link(<sec-guia-alloy>)[Grafana Alloy]:] (#emph[Guía complementaria]) Migración de Promtail al sucesor oficial. Introduce el modelo de configuración orientado al flujo de datos (#emph[dataflow]) con componentes explícitamente conectados.

= Resultados
<sec-resultados>
Este capítulo sintetiza los resultados obtenidos durante el desarrollo del recurso educativo, organizándolos en correspondencia con los tres objetivos específicos (OE) comprometidos en la propuesta aprobada de ascenso. Cada resultado se enuncia junto con la evidencia verificable que lo respalda, en coherencia con la gestión de evidencias descrita en la metodología, de modo que un evaluador externo pueda contrastar lo declarado con los artefactos publicados en el repositorio.

== Resultados de la fundamentación conceptual
<resultados-de-la-fundamentación-conceptual>
En cumplimiento del OE1 se produjo un marco conceptual tecnológicamente neutral que desarrolla la observabilidad desde su raíz en la teoría de control \(#link(<ref-kalman-1960>)[Kalman, 1960]) hasta su consolidación como principio de la ingeniería de software contemporánea. Los resultados concretos de esta dimensión son: (a) la caracterización de los tres pilares de la observabilidad y del rol de los logs como fuente primaria de información semánticamente rica; (b) el análisis de la problemática de la dispersión, incluyendo los problemas no triviales de correlación de eventos y orden temporal en sistemas distribuidos; (c) la arquitectura conceptual de cuatro etapas (recolección, procesamiento, almacenamiento y visualización) como modelo mental transferible entre tecnologías; (d) el análisis de seis desafíos transversales de diseño, desde la estandarización semántica hasta la confiabilidad de la entrega; y (e) la caracterización de los tres paradigmas de indexación y almacenamiento con sus compromisos de costo y flexibilidad.

El marco se complementa con la guía de estudio, que operacionaliza la fundamentación en veinte preguntas de comprensión con respuesta, un glosario terminológico y un bloque de preguntas de articulación teoría--práctica que conecta explícitamente los conceptos del marco con las implementaciones de las guías. El conjunto se sustenta en más de treinta referencias especializadas con identificadores persistentes.

== Resultados del diseño instruccional y las prácticas académicas
<resultados-del-diseño-instruccional-y-las-prácticas-académicas>
En cumplimiento del OE2 se diseñaron nueve guías prácticas con estructura formal homogénea (RAE observables, dimensionamiento explícito de recursos, diagrama del pipeline lógico, procedimiento reproducible y cuestionario de análisis crítico), organizadas bajo el ciclo de aprendizaje experiencial de Kolb y ordenadas por complejidad progresiva, desde el ecosistema tradicional más extendido hasta las plataformas del estado del arte. El diseño instruccional se completa con la guía docente, que aporta una alineación explícita con el microcurrículo oficial de la asignatura (resultados de aprendizaje, núcleos temáticos, unidades de competencia y ejes Ser--Saber--Saber Hacer del sílabo, donde los patrones de observabilidad figuran como temática declarada), tres rutas de planificación según el tiempo disponible, una estrategia de evaluación de tres componentes con rúbrica analítica homogénea aplicable a cualquiera de las nueve guías, y un repertorio de dificultades frecuentes con orientaciones para anticiparlas en el aula.

La #ref(<tbl-base-8>, supplement: [Tabla]) sintetiza la cobertura conceptual del conjunto: cada guía materializa la misma arquitectura de cuatro etapas con un aporte conceptual diferencial, de modo que la progresión completa expone al estudiante a los tres paradigmas de almacenamiento caracterizados en la #ref(<sec-5-7-3>, supplement: [Sección]) y a los principales patrones de recolección y transporte.

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([\#], [Guía (stack)], [Paradigma de almacenamiento], [Aporte conceptual diferencial],),
  table.hline(),
  [1], [ELK], [Índice invertido], [Ecosistema tradicional de búsqueda de texto completo; punto de partida de la ruta.],
  [2], [OLO (OpenSearch)], [Índice invertido], [Evolución y bifurcación de código abierto del ecosistema anterior.],
  [3], [Fluentd], [Índice invertido], [Desacoplamiento del recolector como componente independiente del almacenamiento.],
  [4], [Promtail y Loki], [Índice de solo etiquetas], [Compromiso costo--flexibilidad de la indexación mínima.],
  [5], [GELF y Graylog], [Índice invertido], [Formatos de transporte específicos y plataformas dedicadas a la gestión de logs.],
  [6], [OpenTelemetry (LGTM)], [Índice de solo etiquetas], [Estándar de protocolo unificado y tratamiento integrado de los tres pilares.],
  [7], [Vector, Loki y Grafana], [Índice de solo etiquetas], [Pipeline de alto rendimiento y sanitización programable de campos sensibles.],
  [8], [SigNoz (ClickHouse)], [Almacén columnar], [Plataforma integrada con almacenamiento analítico columnar y OTLP nativo.],
  [9], [Grafana Alloy], [Índice de solo etiquetas], [Configuración orientada al flujo de datos y migración entre recolectores.],
)
], caption: figure.caption(
position: top, 
[
Resultados del diseño instruccional: cobertura conceptual de las nueve guías prácticas.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-8>


== Resultados técnicos verificables
<resultados-técnicos-verificables>
En cumplimiento del OE3, cada guía cuenta con una solución implementada como entorno funcional, autocontenido y reproducible. La #ref(<tbl-base-9>, supplement: [Tabla]) enuncia los resultados técnicos junto con su evidencia:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Resultado], [Evidencia verificable], [Ubicación],),
  table.hline(),
  [Nueve ecosistemas de centralización desplegables en un equipo personal.], [Archivos #NormalTok("docker-compose.yml"); autocontenidos, configuraciones de colectores e indexadores y aplicación productora de logs.], [#NormalTok("soluciones/01-ELK"); a #NormalTok("soluciones/09-Alloy");],
  [Verificación automatizada de extremo a extremo del pipeline en los nueve stacks.], [Prueba de humo estandarizada que emite un log con marcador único y confirma su registro en el motor de almacenamiento.], [#NormalTok("smoke_test.sh"); en cada solución],
  [Transparencia y dimensionamiento adaptativo de recursos.], [Límites de memoria parametrizados mediante variables de entorno y tablas de dimensionamiento al inicio de cada guía.], [Archivos #NormalTok(".env"); de cada solución y guías prácticas],
  [Verificación de portabilidad sobre la primera plataforma objetivo.], [Despliegue verificado sobre macOS Apple Silicon (ARM); la cobertura de Windows 11/WSL2 y Ubuntu Linux se documenta como verificación en curso.], [Marco de verificación y validación de la metodología],
  [Publicación abierta, citable e indexada del recurso completo.], [DOI persistente, metadatos de citación estructurada, licencia abierta, repositorio público y versión web navegable.], [#NormalTok("CITATION.cff");, #NormalTok(".zenodo.json");, registro en Zenodo y repositorio en GitHub con su versión web],
)
], caption: figure.caption(
position: top, 
[
Resultados técnicos verificables y sus evidencias.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-9>


Un resultado transversal merece mención explícita: la prueba de humo estandarizada demostró que la fase de generación del log es idéntica en los nueve stacks mientras solo varía la verificación del registro, lo que constituye evidencia operativa directa de la tesis central del recurso: las etapas funcionales del pipeline son invariantes; las tecnologías que las implementan, no.

== Síntesis y correspondencia con los objetivos del trabajo
<síntesis-y-correspondencia-con-los-objetivos-del-trabajo>
La #ref(<tbl-base-10>, supplement: [Tabla]) consolida la correspondencia entre los objetivos específicos comprometidos, los resultados obtenidos y sus evidencias:

#figure([
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Objetivo específico], [Componente donde se desarrolla], [Resultado principal], [Evidencia verificable],),
  table.hline(),
  [#strong[OE1:] Establecer los elementos teóricos relacionados con los logs centralizados en microservicios.], [Marco conceptual (este documento) y guía de estudio.], [Fundamentación neutral con arquitectura de cuatro etapas, seis desafíos de diseño y tres paradigmas de almacenamiento.], [#NormalTok("readme.md");, #NormalTok("guia_estudio.md");],
  [#strong[OE2:] Elaborar guías prácticas para el despliegue progresivo de soluciones de centralización de logs con Docker.], [Guías prácticas y guía docente.], [Nueve guías instruccionales progresivas bajo el ciclo de Kolb, con instrumentos de evaluación homogéneos.], [#NormalTok("guias/");, #NormalTok("guia_docente.md");],
  [#strong[OE3:] Implementar cada guía en entornos funcionales y reproducibles para los estudiantes.], [Soluciones del repositorio.], [Nueve ecosistemas reproducibles, parametrizados y con verificación automatizada de extremo a extremo.], [#NormalTok("soluciones/");, #NormalTok("smoke_test.sh");],
)
], caption: figure.caption(
position: top, 
[
Correspondencia entre objetivos específicos, resultados y evidencias.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-base-10>


En conjunto, los resultados demuestran que el recurso educativo cumple los compromisos formulados en la propuesta aprobada y genera evidencias verificables en cada dimensión: conceptual (marco teórico neutral y material de estudio), instruccional (guías y evaluación alineadas constructivamente), técnica (entornos reproducibles con verificación automatizada) y de publicación abierta (repositorio navegable, DOI y licenciamiento explícito). Adicionalmente, la ampliación del espectro tecnológico respecto de lo enunciado originalmente (justificada en la introducción por la evolución del estado del arte) constituye un resultado que excede los compromisos iniciales sin alterar su naturaleza.

= Discusión académica, pedagógica e institucional
<sec-discusion>
Este capítulo analiza críticamente los resultados desde tres perspectivas complementarias, contrastándolos con los compromisos de la propuesta aprobada, con los referentes metodológicos adoptados y con la literatura pertinente. El propósito no es reiterar los resultados, sino delimitar su alcance, reconocer sus limitaciones y argumentar su valor diferencial.

== Discusión académica
<discusión-académica>
Los tres objetivos específicos comprometidos en la propuesta se cumplieron y quedaron materializados en artefactos verificables. El único punto que se aparta del enunciado original es la cantidad de guías prácticas: el recurso terminó cubriendo más stacks tecnológicos de los inicialmente previstos. Esta ampliación fue una decisión deliberada. Durante el período de desarrollo, el estado del arte cambió con rapidez: se consolidaron estándares de protocolo unificado y aparecieron plataformas de nueva generación. Un recurso limitado al enunciado original habría nacido incompleto. Las guías adicionales se construyeron con el mismo rigor y la misma estructura que las inicialmente propuestas, de modo que la ampliación no altera los compromisos adquiridos: los amplifica. Su justificación se documenta en la introducción y su trazabilidad en la metodología.

El valor diferencial del recurso frente a los materiales disponibles en el área está en combinar cuatro elementos que rara vez aparecen juntos. La observabilidad suele enseñarse de forma instrumental, centrada en herramientas específicas \(#link(<ref-cito-2015>)[Cito et~al., 2015]), y los materiales de referencia dominantes (la documentación de los fabricantes y los tutoriales) no ofrecen fundamento pedagógico ni neutralidad tecnológica. Este recurso, en cambio, reúne un marco conceptual neutral, un diseño instruccional formal, instrumentos de evaluación homogéneos y una verificación automatizada de la reproducibilidad. Esta última característica, materializada en las pruebas de humo, es poco común incluso en recursos educativos técnicos de buena calidad.

También debe reconocerse una limitación del alcance actual: la verificación técnica completa se ejecutó sobre una sola plataforma (macOS Apple Silicon), y la cobertura de Windows y Linux quedó como verificación en curso. La decisión es razonable dados los tiempos y recursos de un trabajo de ascenso, y su riesgo está mitigado por el propio diseño de las soluciones: las imágenes empleadas son oficiales y multiarquitectura, y los recursos están parametrizados. Aun así, es una limitación real, y se prefiere declararla de forma explícita antes que omitirla.

== Discusión pedagógica
<discusión-pedagógica>
Un aspecto central es la distinción entre el #strong[diseño del recurso] y su #strong[uso en el aula]. El trabajo produce un recurso instruccional completo y evaluable: resultados de aprendizaje observables, actividades alineadas constructivamente y rúbricas homogéneas \(#link(<ref-biggs-2011>)[Biggs & Tang, 2011]). Sin embargo, la experiencia de uso solo puede observarse en una implementación piloto: los errores reales de los estudiantes, los tiempos efectivos de práctica, la retroalimentación docente y las evidencias de aprendizaje. La validación pedagógica en sentido estricto queda así planteada como necesidad metodológica reconocida y coherente con el ciclo iterativo de la investigación basada en diseño \(#link(<ref-design-2003>)[Design-Based Research Collective, 2003]), no como defecto estructural del diseño.

En la misma línea, la coherencia del diseño con el ciclo de Kolb garantiza la oportunidad de aprendizaje, no el aprendizaje mismo: la efectividad dependerá de condiciones que el recurso no controla, como la mediación docente, los conocimientos previos del estudiante (particularmente Docker y formatos estructurados) y la disponibilidad de equipos con recursos suficientes. La guía docente anticipa estas condiciones mediante rutas alternativas para equipos limitados y un repertorio de dificultades frecuentes, lo que reduce el riesgo sin eliminarlo.

Finalmente, la centralización de los instrumentos de evaluación en la guía docente, en lugar de replicarlos en cada guía, es un compromiso consciente de diseño: prioriza la consistencia de criterios entre stacks y la facilidad de adopción docente sobre la autosuficiencia de cada guía tomada de forma aislada. Para el uso autónomo, cada guía declara sus evidencias esperadas y remite a los instrumentos homogéneos del recurso.

== Discusión institucional
<discusión-institucional>
La sostenibilidad del recurso constituye el principal reto institucional. El ecosistema de observabilidad evoluciona con rapidez y las versiones de las imágenes de contenedores quedan obsoletas en plazos de doce a dieciocho meses; el recurso mitiga este riesgo con imágenes oficiales versionadas, parametrización explícita y la recomendación de revisión al inicio de cada semestre, pero su vigencia depende de un mantenimiento activo. La publicación como repositorio abierto habilita un mecanismo de evolución que la distribución como documento cerrado no permite: el reporte de errores y las contribuciones externas, incluidas las de los propios estudiantes como actividad complementaria de aprendizaje.

En términos de gobernanza y transferibilidad, el recurso presenta una fortaleza estructural: se publica como repositorio navegable con DOI persistente, metadatos de citación estructurada y licencia abierta, lo que permite su adopción total o parcial por otros docentes, asignaturas e instituciones con el único requisito de un motor de contenedores y las condiciones de memoria declaradas. La alineación con directrices curriculares internacionales y las rutas de aprendizaje modulares facilitan esa transferencia más allá de la asignatura de origen.

Quedan, sin embargo, preguntas institucionales abiertas que exceden el alcance de este trabajo: la integración formal del recurso en el microcurrículo, la asignación de responsabilidades de actualización periódica y la articulación con otras asignaturas del área dependen de decisiones del programa académico. El recurso habilita esas decisiones, pues aporta el material, los instrumentos y la evidencia de viabilidad, pero no las sustituye.

== Síntesis de la discusión
<síntesis-de-la-discusión>
El análisis precedente permite identificar como fortalezas la integración coherente entre fundamentación conceptual neutral, diseño instruccional formal y entornos técnicos verificables, junto con una publicación abierta que garantiza trazabilidad y transferibilidad. Como limitaciones se reconocen la ausencia de validación empírica con estudiantes, la verificación multiplataforma parcial y la dependencia de mantenimiento activo frente a la obsolescencia tecnológica. Estas limitaciones no deslegitiman el trabajo: delimitan con claridad el alcance alcanzado y estructuran la agenda que se desarrolla en el capítulo de trabajo futuro.

= Conclusiones
<sec-conclusiones>
Las conclusiones se organizan en correspondencia con los tres objetivos específicos comprometidos en la propuesta aprobada, seguidas de una conclusión integradora, las limitaciones reconocidas y la contribución del trabajo a la formación en ingeniería de sistemas y computación.

== Sobre la fundamentación teórica de la centralización de logs
<sobre-la-fundamentación-teórica-de-la-centralización-de-logs>
La observabilidad se consolida como un principio fundamental para la comprensión, análisis y gestión de sistemas distribuidos, al permitir inferir su comportamiento interno a partir de las señales externas generadas durante su ejecución. En arquitecturas basadas en microservicios, donde la complejidad operativa y los comportamientos emergentes son inherentes, este principio resulta indispensable para el diagnóstico, la toma de decisiones y la mejora continua de los sistemas \(#link(<ref-beyer-2016>)[Beyer et~al., 2016]\; #link(<ref-majors-2022>)[Majors et~al., 2022]). El marco conceptual desarrollado demuestra que es posible enseñar la centralización de logs sin acoplar la formación a herramientas específicas: la arquitectura de cuatro etapas, los desafíos transversales y los paradigmas de almacenamiento constituyen un núcleo conceptual estable sobre el cual las tecnologías concretas son instancias intercambiables.

== Sobre el diseño instruccional de las guías prácticas
<sobre-el-diseño-instruccional-de-las-guías-prácticas>
La estructuración de las nueve guías bajo el ciclo de aprendizaje experiencial y el principio de alineación constructiva demuestra que un laboratorio técnico puede convertirse en una experiencia de aprendizaje evaluable: cada guía articula resultados de aprendizaje observables, un procedimiento reproducible y un cuestionario de análisis crítico, y los instrumentos homogéneos de la guía docente garantizan una evaluación consistente con independencia del stack elegido. La progresión de complejidad, del ecosistema tradicional al estado del arte, materializa el principio de independencia instrumental: el estudiante comprueba que las etapas del pipeline permanecen constantes mientras las herramientas cambian por completo.

== Sobre la implementación de entornos reproducibles
<sobre-la-implementación-de-entornos-reproducibles>
La materialización de los nueve ecosistemas con Docker Compose confirma la viabilidad del computador personal del estudiante como laboratorio de experimentación, sin dependencia de infraestructura institucional ni de servicios externos. La prueba de humo estandarizada aporta, además, una conclusión metodológica: la automatización de la verificación no solo asegura la calidad técnica del recurso, sino que constituye en sí misma evidencia empírica de su tesis central, al demostrar operativamente que la interfaz de emisión de logs permanece invariante mientras el conjunto de herramientas varía por completo.

== Conclusión integradora
<conclusión-integradora>
La integración de los tres objetivos produce un recurso educativo que articula fundamentación conceptual, diseño instruccional formal y entornos técnicos verificables como partes de un único producto académico. Este es su valor diferencial frente a manuales técnicos, tutoriales o documentación de fabricantes: el recurso no solo describe cómo desplegar soluciones de centralización de logs, sino que fundamenta por qué la observabilidad es un principio de diseño y no un complemento operativo, cómo verificar objetivamente la reproducibilidad de cada entorno, y de qué manera convertir el despliegue técnico en una experiencia de aprendizaje evaluable. Al priorizar los principios y la arquitectura sobre las herramientas, el recurso contribuye a una formación más sólida, crítica y adaptable a la evolución constante del ecosistema tecnológico.

== Limitaciones
<limitaciones>
Se reconocen tres limitaciones principales. Primera, la ausencia de validación empírica con estudiantes: el diseño instruccional y las rúbricas son académicamente coherentes, pero su impacto real solo podrá verificarse en el aula mediante el análisis de evidencias de aprendizaje, lo que se propone como línea prioritaria de trabajo futuro. Segunda, la verificación de portabilidad se ejecutó de forma completa sobre una única plataforma, quedando la cobertura multiplataforma como verificación en curso. Tercera, la dependencia del mantenimiento activo: la obsolescencia natural de las versiones de las imágenes exige revisiones periódicas para preservar la reproducibilidad de las soluciones.

== Contribución a la formación en ingeniería de sistemas y computación
<contribución-a-la-formación-en-ingeniería-de-sistemas-y-computación>
El trabajo fortalece el área de arquitectura de software y sistemas distribuidos del programa al aportar un escenario reproducible, documentado y evaluable para experimentar con la observabilidad, un contenido habitualmente relegado a la documentación de fabricantes. Su diseño modular y su alineación con directrices curriculares internacionales lo hacen transferible a asignaturas afines (sistemas distribuidos, DevOps, infraestructura de TI) y a otras instituciones. Adicionalmente, la publicación del recurso como repositorio abierto con DOI y metadatos de citación posiciona una práctica de producción académica replicable en futuros trabajos del programa: la creación de recursos educativos abiertos, trazables y verificables.

= Trabajo futuro
<sec-trabajo-futuro>
El desarrollo del recurso abre líneas de evolución en tres planos complementarios. La primera y prioritaria es su implementación en escenarios reales de enseñanza en la asignatura #emph[Arquitectura Orientada a Microservicios], que habilita el ciclo de validación empírica proyectado desde la metodología.

== Proyección pedagógica: validación empírica en aula
<proyección-pedagógica-validación-empírica-en-aula>
En coherencia con la investigación basada en diseño (DBR) y el modelo ADDIE, la aplicación del recurso con grupos de estudiantes deberá evaluarse mediante indicadores observables que permitan tanto medir su impacto como identificar oportunidades de mejora iterativa:

+ #strong[Logro de los resultados de aprendizaje:] proporción de estudiantes que despliegan y validan de forma autónoma al menos un stack completo, según el criterio de despliegue funcional de la rúbrica.
+ #strong[Desempeño en los componentes de evaluación:] resultados en los componentes conceptual, práctico e integrador definidos en la guía docente.
+ #strong[Capacidad de diagnóstico:] tiempo y efectividad en la resolución de las fricciones documentadas (memoria insuficiente, límites del sistema operativo, conflictos de puertos, formatos de configuración).
+ #strong[Apropiación conceptual:] desempeño en el cuestionario de la guía de estudio, con especial atención al bloque de articulación teoría--práctica.
+ #strong[Calidad del análisis comparativo:] nivel argumentativo del ensayo integrador al contrastar paradigmas y decisiones arquitectónicas entre stacks.
+ #strong[Satisfacción y percepción de utilidad:] valoración de los estudiantes sobre la claridad, aplicabilidad y carga de trabajo del recurso.
+ #strong[Uso efectivo del material:] guías consultadas más allá de las trabajadas en aula, ejecución de las pruebas de humo y contribuciones de estudiantes al repositorio.

Los hallazgos de esta fase alimentarán versiones sucesivas del recurso, publicadas con nuevos identificadores de versión en el repositorio y en Zenodo.

== Proyección técnica
<proyección-técnica>
En el plano técnico se proyecta: completar la matriz de verificación multiplataforma (Windows 11/WSL2 y Ubuntu Linux); automatizar la ejecución periódica de las pruebas de humo mediante integración continua, de modo que la obsolescencia de las imágenes se detecte de forma temprana y objetiva; y extender el recurso hacia escenarios que prolonguen la ruta de aprendizaje, como la orquestación con Kubernetes, la profundización en métricas y trazas, y la incorporación de nuevos stacks que consoliden el estado del arte.

== Proyección institucional
<proyección-institucional>
En el plano institucional se proyecta la integración formal del recurso en el microcurrículo de la asignatura y su articulación con asignaturas afines del área; la consolidación de un modelo de mantenimiento que incorpore las contribuciones estudiantiles como actividad de aprendizaje; y la difusión del recurso en comunidades docentes y repositorios de recursos educativos abiertos, aprovechando su licenciamiento abierto y su citabilidad estructurada para favorecer la adopción externa y la mejora colaborativa.

#part[Material de estudio y docencia]
= Guía de Estudio: Observabilidad y Centralización de Logs en Sistemas Distribuidos
<sec-guia-estudio>
== ¿Cómo se define la observabilidad en el contexto de los sistemas distribuidos?
<cómo-se-define-la-observabilidad-en-el-contexto-de-los-sistemas-distribuidos>
La observabilidad se define como la capacidad de inferir el estado interno de un sistema complejo utilizando las señales externas que este produce mientras se encuentra en ejecución. Esta capacidad es crítica en los sistemas distribuidos debido a que la concurrencia y la distribución de responsabilidades complican la identificación directa de causas y efectos.

== ¿Cuál es la diferencia clave entre la monitorización tradicional y la observabilidad?
<cuál-es-la-diferencia-clave-entre-la-monitorización-tradicional-y-la-observabilidad>
La monitorización tradicional se centra en vigilar indicadores que han sido previamente definidos, mientras que la observabilidad tiene como objetivo responder preguntas no anticipadas. Esto permite explorar el comportamiento del sistema ante degradaciones o fallos inesperados, lo cual es vital en microservicios donde surgen comportamientos emergentes.

== ¿Por qué se considera a los logs como una fuente primaria de información por encima de las métricas o las trazas?
<por-qué-se-considera-a-los-logs-como-una-fuente-primaria-de-información-por-encima-de-las-métricas-o-las-trazas>
A diferencia de las métricas (que son valores agregados) y las trazas (que describen recorridos), los logs son registros textuales de eventos discretos que logran preservar el contexto semántico de dichos eventos. Esto facilita comprender exactamente el qué y el por qué de una situación determinada.

== ¿En qué consiste la problemática de la "dispersión de logs" en arquitecturas de microservicios?
<en-qué-consiste-la-problemática-de-la-dispersión-de-logs-en-arquitecturas-de-microservicios>
En sistemas distribuidos, cada componente o microservicio genera de manera local sus propios registros, fragmentando la información. Esta dispersión aumenta considerablemente la carga cognitiva necesaria para diagnosticar fallos, limita la correlación de eventos entre servicios autónomos y puede volver inviable el análisis manual a medida que escalan los nodos.

== ¿Qué beneficios conceptuales aporta la centralización de logs a un sistema distribuido?
<qué-beneficios-conceptuales-aporta-la-centralización-de-logs-a-un-sistema-distribuido>
Consolidar los logs en un repositorio común mitiga el problema de la dispersión y proporciona múltiples beneficios: mejora la visibilidad global de las interacciones internas, reduce la complejidad cognitiva al diagnosticar incidentes distribuidos y permite correlacionar eventos por tiempo y contexto. Además, facilita la reconstrucción de narrativas de ejecución esenciales para entender fallos en cascada.

== ¿Por qué es fundamental el criterio de "Estandarización Semántica" al recolectar logs?
<por-qué-es-fundamental-el-criterio-de-estandarización-semántica-al-recolectar-logs>
Centralizar logs de sistemas heterogéneos carece de valor si no comparten un esquema en común. El uso de convenciones estandarizadas, como Elastic Common Schema (ECS) o OpenTelemetry, resulta fundamental para garantizar que los eventos generados por diferentes servicios se puedan correlacionar y así trazar flujos completos de ejecución.

== ¿Qué desafío introduce la centralización de logs respecto a la seguridad y la privacidad?
<qué-desafío-introduce-la-centralización-de-logs-respecto-a-la-seguridad-y-la-privacidad>
Los sistemas de registro a menudo capturan accidentalmente información sensible, como contraseñas, tokens de acceso o datos de identificación personal (PII). Por tanto, es imperativo diseñar arquitecturas que incorporen mecanismos de censura o enmascaramiento de datos en la fase de procesamiento, previniendo su indexación de forma expuesta.

== ¿Cuál es el rol del componente de "Recolección" en la arquitectura conceptual de centralización?
<cuál-es-el-rol-del-componente-de-recolección-en-la-arquitectura-conceptual-de-centralización>
Es el punto de entrada que se encarga de capturar los eventos generados por las aplicaciones e infraestructura. Conceptualmente, este componente debe operar de manera completamente desacoplada para garantizar que el proceso de captura de logs no interfiera con la ejecución normal de los sistemas.

== ¿Qué actividades específicas abarca el componente de "Procesamiento y enriquecimiento"?
<qué-actividades-específicas-abarca-el-componente-de-procesamiento-y-enriquecimiento>
Este componente se orienta a transformar registros crudos mediante actividades como el filtrado de eventos sin relevancia, la normalización de formatos y el enriquecimiento semántico. El objetivo principal es reducir el ruido inherente a los datos masivos y organizar la información para que sea estructurada y significativa antes de llegar al motor de almacenamiento.

== ¿De qué manera ayuda el componente de "Visualización y análisis" a la resolución de incidentes?
<de-qué-manera-ayuda-el-componente-de-visualización-y-análisis-a-la-resolución-de-incidentes>
La visualización presenta la información contenida en los registros de manera gráfica y comprensible para humanos mediante paneles y tablas. Esto reduce la carga cognitiva requerida para el análisis masivo, permitiendo identificar rápidamente patrones, tendencias y anomalías en el sistema, conectando así los datos operativos con la toma de decisiones informadas.

== ¿Cuáles son los tres pilares de la observabilidad y en qué se diferencian?
<cuáles-son-los-tres-pilares-de-la-observabilidad-y-en-qué-se-diferencian>
Los tres pilares son los #strong[logs], las #strong[métricas] y las #strong[trazas]. Los logs son registros textuales de eventos discretos que preservan el contexto semántico (el #emph[qué] y el #emph[porqué]). Las métricas son valores numéricos agregados en el tiempo, muy compactos pero sin detalle de los eventos individuales. Las trazas describen el recorrido de una solicitud a través de varios servicios, revelando dónde se invierte el tiempo. Se complementan: las métricas suelen detectar que #emph[algo] va mal, las trazas localizan #emph[dónde] ocurre, y los logs explican #emph[por qué].

== ¿Qué distingue al logging estructurado del texto libre, y por qué importa para la centralización?
<qué-distingue-al-logging-estructurado-del-texto-libre-y-por-qué-importa-para-la-centralización>
El logging no estructurado escribe los eventos como texto libre, legible para las personas pero difícil de procesar por las máquinas. El #strong[logging estructurado] representa cada evento como un objeto con campos explícitos (típicamente en JSON), de modo que cada dato es identificable y consultable directamente. Importa porque los logs estructurados pueden filtrarse, agregarse y correlacionarse de forma sistemática, mientras que el texto libre exige un análisis sintáctico posterior y frágil (expresiones regulares) para extraer su significado.

== El marco conceptual describe tres paradigmas de almacenamiento e indexación. ¿Cuáles son y qué compromiso ofrece cada uno?
<el-marco-conceptual-describe-tres-paradigmas-de-almacenamiento-e-indexación.-cuáles-son-y-qué-compromiso-ofrece-cada-uno>
#block[
#set enum(numbering: "(1)", start: 1)
+ El #strong[índice invertido] (búsqueda de texto completo) indexa cada término de cada mensaje, habilitando búsquedas libres muy flexibles a un alto costo de indexación y almacenamiento. (2) El #strong[almacén columnar] (OLAP) organiza los datos por columnas, optimizado para comprimir y agregar grandes volúmenes de datos estructurados, aunque resulta menos apto para el texto libre. (3) El #strong[índice de solo etiquetas] indexa apenas un conjunto reducido de metadatos, con un costo mínimo, a cambio de escanear el contenido en el momento de la consulta. No existe un paradigma óptimo: cada uno responde a necesidades distintas.
]

== ¿Por qué el orden temporal de los eventos es un problema no trivial en sistemas distribuidos?
<por-qué-el-orden-temporal-de-los-eventos-es-un-problema-no-trivial-en-sistemas-distribuidos>
Porque cada nodo posee su propio reloj físico y estos nunca están perfectamente sincronizados (#emph[clock skew]); ordenar eventos provenientes de máquinas distintas únicamente por su marca temporal puede producir secuencias incorrectas. Lamport demostró que, en ausencia de un reloj global, lo determinante es la relación de causalidad entre eventos (la relación #emph[happened-before]), y no el tiempo absoluto. Por ello, la correlación de logs distribuidos se apoya en identificadores de correlación, y no únicamente en las marcas temporales.

== ¿Qué se entiende por cardinalidad y por qué constituye un reto de costo en la centralización?
<qué-se-entiende-por-cardinalidad-y-por-qué-constituye-un-reto-de-costo-en-la-centralización>
La #strong[cardinalidad] es el número de valores distintos que puede tomar un atributo. Indexar atributos de alta cardinalidad (como un identificador de usuario o de petición) provoca un crecimiento desproporcionado de los índices y degrada el rendimiento. Por eso, diseñar una solución de centralización implica decidir conscientemente qué campos justifican el costo de ser indexados, decisión directamente ligada al paradigma de almacenamiento elegido.

== Glosario
<glosario>
#strong[Observabilidad:] Es la #strong[capacidad de inferir el estado interno de un sistema complejo a partir de las señales externas] que produce durante su ejecución. A diferencia de la monitorización tradicional, busca #strong[responder preguntas no anticipadas] permitiendo explorar el sistema frente a fallos o degradaciones inesperadas.

#strong[Sistemas Distribuidos / Arquitecturas de Microservicios:] Entornos de software caracterizados por la #strong[concurrencia, la comunicación asincrónica y la distribución de responsabilidades] entre múltiples componentes autónomos. Introducen aumentos de complejidad en su análisis operativo debido a los comportamientos emergentes.

#strong[Logs (Registros):] Son #strong[registros textuales de eventos discretos] que ocurren en el sistema y constituyen una fuente primaria de información. Destacan frente a otras señales porque #strong[preservan el contexto semántico] y ayudan a responder el #emph[qué] y el #emph[por qué] de una situación.

#strong[Métricas:] Señales de observabilidad enfocadas en capturar #strong[valores agregados] sobre el estado y rendimiento del sistema.

#strong[Trazas:] Señales de observabilidad que #strong[describen recorridos completos de solicitudes] a través de distintos componentes de software.

#strong[Monitorización tradicional:] Enfoque operativo convencional centrado en vigilar #strong[indicadores y variables previamente definidos], lo cual suele ser insuficiente por sí solo en entornos con comportamientos imprevistos.

#strong[Dispersión de logs:] Problemática que se produce cuando #strong[cada componente de un entorno distribuido genera y guarda sus registros de forma local], fragmentando la información y limitando el análisis integral y la correlación de eventos.

#strong[Centralización de logs:] Estrategia orientada a #strong[recolectar, consolidar y almacenar eventos dispersos en un único repositorio común], facilitando su consulta unificada, correlación temporal y el diagnóstico de fallos en cascada.

#strong[Estandarización Semántica:] El uso de un #strong[esquema común (como Elastic Common Schema o las convenciones de OpenTelemetry)] para unificar el formato de los eventos generados, de modo que puedan ser correlacionados correctamente entre distintos microservicios heterogéneos.

#strong[Almacenamiento por niveles (Hot/Cold storage):] Políticas implementadas para gestionar el #strong[ciclo de vida y retención masiva de datos], optimizando el impacto en la infraestructura mientras se mantienen capacidades de auditoría a largo plazo.

#strong[Sanitización (Seguridad y Privacidad):] Mecanismos enfocados en el #strong[enmascaramiento o censura de información sensible] (como tokens, PII o contraseñas) durante el procesamiento previo de los logs para evitar que sean almacenados o indexados en texto plano.

#strong[Recolección de logs:] Es el componente que opera como #strong[punto de entrada del flujo de observabilidad], responsable de capturar los eventos de forma completamente #strong[desacoplada] para no entorpecer el funcionamiento normal del sistema.

#strong[Procesamiento y enriquecimiento de logs:] Etapa intermedia del #emph[pipeline] orientada a transformar los datos crudos en información útil, realizando el #strong[filtrado de eventos irrelevantes, normalización de formatos, enriquecimiento semántico] y la estructuración de la información.

#strong[Tres pilares de la observabilidad:] Los tres tipos de señales complementarias sobre los que se construye la observabilidad: #strong[logs] (eventos discretos con contexto semántico), #strong[métricas] (valores numéricos agregados en el tiempo) y #strong[trazas] (recorridos de una solicitud a través de varios servicios).

#strong[Logging estructurado:] Práctica de emitir cada evento como un #strong[objeto con campos explícitos] (típicamente JSON), en lugar de como texto libre, de modo que pueda filtrarse, agregarse y correlacionarse de forma automatizada sin necesidad de un análisis sintáctico posterior.

#strong[Niveles de severidad:] Jerarquía estándar (comúnmente TRACE, DEBUG, INFO, WARN, ERROR y FATAL) que expresa la #strong[importancia relativa] de cada evento y permite regular el volumen de registro según el contexto (depuración vs.~producción).

#strong[Identificador de correlación (correlation ID / trace ID):] Identificador que #strong[acompaña a una solicitud] a lo largo de todos los servicios que la procesan, permitiendo agrupar a posteriori todos los eventos que pertenecen a la misma operación y resolver así el problema de correlación inherente a la dispersión.

#strong[Cardinalidad:] Número de #strong[valores distintos] que puede tomar un atributo. La alta cardinalidad (p.~ej., identificadores de usuario) encarece la indexación y degrada el rendimiento, por lo que condiciona qué campos conviene indexar.

#strong[Índice invertido:] Paradigma de almacenamiento que #strong[indexa cada término] de cada mensaje, asociándolo a la lista de registros que lo contienen. Habilita búsquedas de texto completo muy flexibles a un alto costo de indexación y almacenamiento.

#strong[Almacenamiento columnar (OLAP):] Paradigma que organiza los datos #strong[por columnas] en lugar de por filas, optimizado para comprimir y #strong[agregar/analizar] grandes volúmenes de datos estructurados; menos apto para la búsqueda libre de texto.

#strong[Índice de solo etiquetas:] Paradigma que indexa #strong[únicamente un conjunto reducido de metadatos] (etiquetas), minimizando el costo de almacenamiento a cambio de escanear el contenido en el momento de la consulta.

#strong[Modelos de recolección (push / pull):] Estrategias de captura de logs. En el modelo #emph[push] (envío), la fuente transmite activamente sus registros al sistema central; en el modelo #emph[pull] (extracción), el sistema central consulta periódicamente a las fuentes.

#strong[Contrapresión (backpressure):] Mecanismo que evita que un #strong[pico en la generación de logs] sature o derribe los componentes intermedios, típicamente combinado con amortiguación (#emph[buffering]) y con una garantía de entrega definida (#emph[at-least-once] / #emph[at-most-once]).

== Articulación teoría--práctica
<articulación-teoríapráctica>
Las siguientes preguntas proponen un puente entre los conceptos del documento central y las implementaciones concretas de las guías prácticas. Para responderlas es necesario haber revisado tanto el marco teórico como al menos algunas de las guías correspondientes.

=== La arquitectura de cuatro etapas describe la "Recolección" como un componente idealmente desacoplado del sistema productor. ¿Qué guías del recurso instancian ese desacoplamiento con un agente independiente? ¿Cuál es su ventaja operativa frente a enviar los logs directamente desde la aplicación?
<la-arquitectura-de-cuatro-etapas-describe-la-recolección-como-un-componente-idealmente-desacoplado-del-sistema-productor.-qué-guías-del-recurso-instancian-ese-desacoplamiento-con-un-agente-independiente-cuál-es-su-ventaja-operativa-frente-a-enviar-los-logs-directamente-desde-la-aplicación>
Las guías ELK, OLO, Fluentd, Promtail, Vector y Alloy utilizan un agente o recolector externo (Logstash, Fluentd, Promtail, Vector, Alloy) separado de la aplicación. Las guías GELF/Graylog, OpenTelemetry y SigNoz trasladan la responsabilidad del transporte al protocolo (GELF UDP) o al SDK de instrumentación (OTLP). El desacoplamiento mediante agente evita que los fallos o la latencia del sistema centralizado afecten la disponibilidad de la aplicación productora, cumpliendo el principio de no interferencia descrito en #ref(<sec-5-7-1>, supplement: [Sección]) del documento central.

=== El marco conceptual describe tres paradigmas de almacenamiento e indexación con compromisos diferentes. ¿Qué guías implementan cada uno? ¿Qué consecuencia tiene esa elección sobre el tipo de consultas posibles?
<el-marco-conceptual-describe-tres-paradigmas-de-almacenamiento-e-indexación-con-compromisos-diferentes.-qué-guías-implementan-cada-uno-qué-consecuencia-tiene-esa-elección-sobre-el-tipo-de-consultas-posibles>
Las guías ELK, OLO y GELF/Graylog emplean el #strong[índice invertido] (Elasticsearch u OpenSearch), que permite búsquedas de texto libre sobre cualquier campo a un alto costo de almacenamiento. La guía SigNoz usa un #strong[almacén columnar] (ClickHouse), optimizado para comprimir y agregar grandes volúmenes de datos estructurados a gran escala. Las guías Promtail, Vector y Alloy usan Loki, cuyo #strong[índice de solo etiquetas] reduce drásticamente el almacenamiento pero limita el filtrado rápido a los campos promovidos a etiquetas; el resto del contenido se escanea en el momento de la consulta. La guía OpenTelemetry (LGTM) también usa Loki para los logs. De este modo, el recurso permite contrastar empíricamente los tres paradigmas descritos en el marco conceptual (#ref(<sec-5-7-3>, supplement: [Sección])).

=== El desafío de "sanitización" (#ref(<sec-5-6>, supplement: [Sección])) establece que la información sensible debe enmascararse antes de ser almacenada. ¿En qué guía práctica se propone explícitamente una actividad de censura de campos sensibles? ¿Qué mecanismo técnico lo implementa?
<el-desafío-de-sanitización-sec-5-6-establece-que-la-información-sensible-debe-enmascararse-antes-de-ser-almacenada.-en-qué-guía-práctica-se-propone-explícitamente-una-actividad-de-censura-de-campos-sensibles-qué-mecanismo-técnico-lo-implementa>
La guía Vector (§9, actividades de profundización) propone usar #strong[VRL (Vector Remap Language)] para enmascarar campos como contraseñas o tokens antes de enviarlos a Loki. VRL permite expresiones del tipo #NormalTok("redact!(.message, filters: [r'\\bpassword=\\S+'i])");, operando en la etapa de transformación del pipeline, antes de que el dato llegue al almacenamiento. Este es el mecanismo más directo del recurso para ilustrar la sanitización como práctica operativa concreta.

=== El documento teórico menciona que los tres pilares de la observabilidad son logs, métricas y trazas, pero el recurso se enfoca en logs. ¿Cuál de las guías prácticas es la única que aborda los tres pilares de forma integrada? ¿Qué diferencia conceptual introduce respecto a las demás guías?
<el-documento-teórico-menciona-que-los-tres-pilares-de-la-observabilidad-son-logs-métricas-y-trazas-pero-el-recurso-se-enfoca-en-logs.-cuál-de-las-guías-prácticas-es-la-única-que-aborda-los-tres-pilares-de-forma-integrada-qué-diferencia-conceptual-introduce-respecto-a-las-demás-guías>
La guía OpenTelemetry (LGTM stack) es la única que recolecta y visualiza los tres pilares simultáneamente: logs vía Loki, métricas vía Prometheus/Mimir y trazas vía Tempo, utilizando el protocolo #strong[OTLP] como transporte unificado. La diferencia conceptual es que OpenTelemetry no es una herramienta de un solo dominio sino un estándar de telemetría agnóstico al #emph[backend], lo que permite cambiar el sistema de almacenamiento sin modificar la instrumentación de las aplicaciones.

=== Las guías Promtail y Alloy implementan el mismo stack subyacente (Loki + Grafana). ¿Cuál es la diferencia arquitectónica fundamental entre ambos agentes? ¿Qué razón motivó la transición en el ecosistema de Grafana?
<las-guías-promtail-y-alloy-implementan-el-mismo-stack-subyacente-loki-grafana.-cuál-es-la-diferencia-arquitectónica-fundamental-entre-ambos-agentes-qué-razón-motivó-la-transición-en-el-ecosistema-de-grafana>
Promtail es un agente de propósito único diseñado exclusivamente para enviar logs a Loki, con un modelo de configuración declarativo pero estático. Alloy adopta un #strong[modelo orientado a componentes y flujos de datos] (heredado del proyecto Grafana Agent Flow), donde cada pieza del pipeline es un componente con entradas y salidas explícitas que pueden conectarse de forma flexible. Esto permite que Alloy procese no solo logs sino también métricas y trazas con el mismo agente. La transición fue motivada por la consolidación de múltiples agentes (Grafana Agent, Prometheus Agent, Promtail) en una única herramienta mantenible y más expresiva.

= Guía Docente
<sec-guia-docente>
#emph[Planificación pedagógica, rúbricas y orientaciones para la incorporación del recurso educativo en la asignatura #strong[Arquitectura Orientada a Microservicios].]

== Propósito de esta guía
<propósito-de-esta-guía>
Este documento está dirigido al #strong[docente] que utilizará el recurso en su curso. Su objetivo es facilitar la integración del material en una planificación realista, sugerir rutas de aprendizaje según el tiempo disponible, proponer instrumentos de evaluación y anticipar las dificultades más frecuentes que enfrentan los estudiantes.

El recurso completo está pensado para una unidad temática de #strong[dos semanas] dentro de un curso semestral de 16 semanas. No se espera (ni es deseable) cubrir las nueve guías prácticas en ese tiempo; el diseño asume que el docente seleccionará dos o tres guías para trabajo en aula y dejará el resto como material de profundización para estudiantes interesados o como base para trabajos finales.

== Ubicación pedagógica dentro del curso
<ubicación-pedagógica-dentro-del-curso>
La unidad sobre #strong[observabilidad y centralización de logs] se inserta de forma natural después de que el estudiante ha trabajado los conceptos fundacionales de una arquitectura orientada a microservicios: descomposición de servicios, comunicación sincrónica/asincrónica, contenerización y orquestación básica. Específicamente, se recomienda ubicarla:

- #strong[Después] de: introducción a microservicios, contenerización con Docker, comunicación entre servicios.
- #strong[Antes] de: temas avanzados de resiliencia (circuit breakers, retries), seguridad distribuida y despliegue continuo, ya que estos requieren capacidad de observación operacional para razonar sobre ellos.

Una ubicación común y efectiva es entre #strong[las semanas 9 y 11] del curso, una vez los estudiantes tienen aplicaciones distribuidas funcionales sobre las cuales aplicar el material.

== Prerrequisitos del estudiante
<prerrequisitos-del-estudiante>
Antes de iniciar la unidad, el estudiante debería ser capaz de:

- Levantar contenedores y stacks multi-servicio con #NormalTok("docker compose");.
- Comprender el modelo cliente-servidor y los conceptos básicos de redes (puertos, protocolos TCP/UDP).
- Tener nociones básicas de formatos estructurados como JSON.
- Haber escrito al menos una aplicación Java/Quarkus simple, ya que todas las guías usan este #emph[stack] como productor de logs.

== Resultados de aprendizaje de la unidad
<resultados-de-aprendizaje-de-la-unidad>
Al finalizar las dos semanas, el estudiante debe ser capaz de:

+ #strong[Explicar] qué es la observabilidad y por qué es un requisito de diseño (no un complemento operativo) en arquitecturas distribuidas.
+ #strong[Describir] la arquitectura conceptual de cuatro etapas (recolección, procesamiento, almacenamiento, visualización) y reconocerla en al menos dos implementaciones tecnológicamente distintas.
+ #strong[Justificar] los desafíos transversales de estandarización semántica, ciclo de vida del dato y sanitización de información sensible.
+ #strong[Desplegar y validar] al menos un stack completo de centralización de logs sobre un entorno reproducible con Docker Compose.
+ #strong[Contrastar] decisiones arquitectónicas entre stacks (por ejemplo: indexación completa vs.~solo etiquetas; protocolo específico vs.~estándar unificado).

La correspondencia de estos resultados de la unidad con los resultados de aprendizaje y las unidades de competencia del sílabo oficial de la asignatura se detalla en la sección 5.

== Alineación con el microcurrículo oficial de la asignatura
<alineación-con-el-microcurrículo-oficial-de-la-asignatura>
El recurso está calibrado para el espacio académico #strong[Profundización Arquitectura Orientada a Microservicios] (Área de Infraestructura de Tecnología Informática, Programa de Ingeniería de Sistemas y Computación, Universidad del Quindío; códigos 12344, 12345, 12350 y 12351). Esta sección instancia, para el sílabo oficial vigente de ese espacio académico, el mapeo curricular que el recurso declara como principio de interoperabilidad; un docente de otra institución puede replicar este mismo ejercicio con su propio plan de curso.

La relación de este trabajo con el sílabo es directa. El Núcleo Temático 3, dedicado a los patrones de diseño en la arquitectura de microservicios, incluye los #strong[patrones de observabilidad] entre sus temáticas declaradas, y esa es exactamente la temática que esta unidad desarrolla. El recurso aporta, además, lo que el sílabo por sí solo no detalla: el fundamento conceptual, los escenarios de práctica reproducibles y los instrumentos para evaluarla. En otras palabras, el docente que adopta este material no está agregando un tema nuevo al curso; está desplegando uno que el curso ya tiene comprometido.

=== Contribución a los resultados de aprendizaje del sílabo
<contribución-a-los-resultados-de-aprendizaje-del-sílabo>
#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([RA oficial del sílabo], [Contribución de la unidad], [Componentes que la materializan],),
  table.hline(),
  [#strong[R.A.1] --- Diseño soluciones basadas en la arquitectura orientada a microservicios, considerando patrones de diseño aceptados por la industria y los desafíos técnicos, funcionales y no funcionales.], [La unidad desarrolla la observabilidad como familia de patrones de diseño: la arquitectura conceptual de cuatro etapas, los patrones de recolección (agente, sidecar, envío directo) y los desafíos transversales (estandarización, retención, sanitización, cardinalidad) son criterios que el estudiante aprende a razonar y contrastar.], [Marco conceptual; componente integrador (ensayo comparativo de decisiones arquitectónicas).],
  [#strong[R.A.2] --- Construyo soluciones software basadas en la arquitectura orientada a microservicios, desplegadas mediante contenedores y cloud computing.], [Todas las guías despliegan ecosistemas multicontenedor con Docker Compose, configuran aplicaciones para emitir logs estructurados y validan la operación de extremo a extremo.], [Las nueve guías prácticas con sus soluciones; componente práctico (informe de laboratorio).],
  [#strong[R.A.3] --- Construyo recursos documentales acerca de tecnologías basadas en microservicios, en primera y segunda lengua, con perspectiva ética y estándares de la industria.], [Los entregables son recursos documentales técnicos (informe de laboratorio y ensayo comparativo); las guías exigen leer documentación oficial en inglés; el desafío de sanitización de datos sensibles aporta la perspectiva ética; el formato ECS y OTLP ilustran los estándares de la industria.], [Entregables de los componentes práctico e integrador; guía de estudio; guía de Vector (sanitización).],
)
], caption: figure.caption(
position: top, 
[
Contribución de la unidad a los resultados de aprendizaje del sílabo oficial.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-1>


=== Cobertura de los núcleos temáticos
<cobertura-de-los-núcleos-temáticos>
#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Núcleo temático del sílabo], [Temáticas que la unidad desarrolla], [Aporte del recurso],),
  table.hline(),
  [#strong[NT1] --- Introducción a microservicios.], [Características de los problemas de los microservicios; contenedores y computación en la nube.], [La dispersión de logs se presenta como problema característico de los microservicios; todas las guías refuerzan el trabajo con contenedores.],
  [#strong[NT2] --- Tecnologías para la implementación y ejecución de microservicios.], [Formatos de transferencia de datos (JSON); escenarios de despliegue (virtualización y cloud); automatización de pruebas.], [Logging estructurado en JSON/ECS; despliegue contenerizado en las nueve guías; la prueba de humo (#NormalTok("smoke_test.sh");) como ejemplo trabajado de prueba automatizada de extremo a extremo.],
  [#strong[NT3] --- Patrones de diseño en la arquitectura de microservicios.], [#strong[Patrones de observabilidad] (temática explícita del sílabo) y su relación con los patrones de despliegue y de fiabilidad.], [Cobertura directa y en profundidad: la unidad completa desarrolla esta temática. Los modelos de recolección y los paradigmas de almacenamiento se presentan como decisiones de patrón con ventajas y desventajas contrastables.],
)
], caption: figure.caption(
position: top, 
[
Cobertura de los núcleos temáticos del sílabo por la unidad.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-2>


=== Aporte a las unidades de competencia del programa
<aporte-a-las-unidades-de-competencia-del-programa>
El sílabo declara mayor nivel de aporte a cinco unidades de competencia (UC) del programa; la unidad contribuye a cada una así:

#figure([
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([UC del programa], [Cómo aporta la unidad],),
  table.hline(),
  [#strong[U.C.2 --- El Diseño.]], [El estudiante analiza y contrasta arquitecturas de centralización de logs, y justifica la elección de paradigmas según requisitos de costo, consulta y volumen.],
  [#strong[U.C.3 --- La Implementación.]], [El estudiante construye, verifica y valida un stack completo: despliegue, ingesta, consulta y prueba de humo de extremo a extremo.],
  [#strong[U.C.4 --- La Operación.]], [El estudiante gestiona sistemas en ejecución: diagnóstico de fallos con el visualizador, resolución de fricciones documentadas y dimensionamiento de recursos.],
  [#strong[U.C.6 --- Lo Complementario.]], [El estudiante produce documentos técnicos formales (informe de laboratorio y ensayo comparativo) con las convenciones del área.],
  [#strong[U.C.7 --- La Formación Integral.]], [El estudiante analiza críticamente la dimensión ética del manejo de datos (sanitización de información sensible) y procesa documentación técnica en primera y segunda lengua.],
)
], caption: figure.caption(
position: top, 
[
Aporte de la unidad a las unidades de competencia del programa.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-3>


=== Correspondencia con los ejes Ser, Saber y Saber Hacer
<correspondencia-con-los-ejes-ser-saber-y-saber-hacer>
El sílabo organiza cada núcleo temático en ejes actitudinales (Ser), conceptuales (Saber) y procedimentales (Saber Hacer). La unidad los desarrolla de la siguiente manera:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Eje], [Cómo lo desarrolla la unidad], [Dónde se evalúa],),
  table.hline(),
  [#strong[Ser] (actitudinal)], [Cumplimiento de compromisos y calidad técnica de los entregables; postura crítica frente a la documentación técnica en inglés y español; respeto por la producción intelectual (uso y citación de material con licencia abierta).], [Criterio de calidad técnica de la rúbrica; discusión de las dificultades frecuentes.],
  [#strong[Saber] (conceptual)], [Comprensión de la observabilidad, los tres pilares, la arquitectura de cuatro etapas, los desafíos de diseño y los paradigmas de almacenamiento.], [Componente conceptual (cuestionario de la guía de estudio).],
  [#strong[Saber Hacer] (procedimental)], [Despliegue de soluciones en ambientes virtuales, evaluación del funcionamiento mediante pruebas automatizadas y proposición de soluciones contrastadas a problemas reales.], [Componentes práctico e integrador (informe de laboratorio y ensayo comparativo).],
)
], caption: figure.caption(
position: top, 
[
Correspondencia de la unidad con los ejes Ser, Saber y Saber Hacer del sílabo.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-4>


Finalmente, la estrategia de evaluación del recurso instrumenta varias de las estrategias previstas por el propio sílabo: las #strong[prácticas] y el #strong[estudio de caso] corresponden al componente práctico; los #strong[talleres y exámenes] al componente conceptual; las #strong[exposiciones o debates] pueden apoyar el componente integrador; y la rúbrica del recurso puede entregarse al estudiante como #strong[matriz de evaluación personal], tal como el sílabo lo sugiere.

== Panorama de las nueve guías prácticas
<panorama-de-las-nueve-guías-prácticas>
Esta sección permite al docente preparar una sesión de laboratorio sin recorrer cada guía completa, y hace explícita la correspondencia entre las guías y los resultados de aprendizaje de la unidad.

=== Tabla de consulta rápida
<tabla-de-consulta-rápida>
Cada fila resume el reto de la guía, las condiciones que conviene verificar antes de la sesión y el entregable mínimo con el que el estudiante demuestra el logro. Los números de la última columna corresponden a los resultados de aprendizaje (RA) enumerados en la sección 4.

#figure([
#table(
  columns: (3.9%, 7.79%, 33.77%, 23.38%, 24.68%, 6.49%),
  align: (auto,auto,auto,auto,auto,auto,),
  table.header([\#], [Guía], [Reto y logro verificable], [Antes de iniciar], [Entregable mínimo], [RA],),
  table.hline(),
  [1], [#link(<sec-guia-elk>)[ELK]], [Desplegar el stack clásico de indexación de texto completo y consultar logs estructurados en Kibana.], [8 GB de RAM libres; #NormalTok("vm.max_map_count"); en Linux/WSL.], [Compose funcional, captura de consulta en Kibana y #NormalTok("smoke_test.sh"); exitoso.], [2, 4],
  [2], [#link(<sec-guia-olo>)[OLO]], [Repetir el pipeline sobre la bifurcación de código abierto y contrastarla con ELK.], [8 GB de RAM libres; #NormalTok("vm.max_map_count"); en Linux/WSL.], [Compose funcional, captura en OpenSearch Dashboards y #NormalTok("smoke_test.sh"); exitoso.], [2, 4, 5],
  [3], [#link(<sec-guia-fluentd>)[Fluentd]], [Desacoplar la recolección en un agente independiente del almacenamiento.], [8 GB de RAM libres (usa Elasticsearch); #NormalTok("vm.max_map_count");.], [Compose funcional, captura en Kibana y #NormalTok("smoke_test.sh"); exitoso.], [2, 4],
  [4], [#link(<sec-guia-promtail>)[Promtail y Loki]], [Comprobar el compromiso costo--consulta de la indexación de solo etiquetas.], [Funciona cómodamente con 4 GB de RAM libres.], [Compose funcional, captura en Grafana y #NormalTok("smoke_test.sh"); exitoso.], [2, 4, 5],
  [5], [#link(<sec-guia-gelf-graylog>)[GELF y Graylog]], [Transportar logs mediante un formato de protocolo específico hacia una plataforma dedicada.], [8 GB de RAM libres.], [Compose funcional, captura en Graylog y #NormalTok("smoke_test.sh"); exitoso.], [2, 4],
  [6], [#link(<sec-guia-otel>)[OpenTelemetry]], [Integrar logs, métricas y trazas bajo un protocolo unificado.], [4 GB suelen bastar (almacenamiento sobre Loki).], [Compose funcional, captura en Grafana y #NormalTok("smoke_test.sh"); exitoso.], [1, 2, 4, 5],
  [7], [#link(<sec-guia-vector>)[Vector]], [Construir un pipeline de alto rendimiento con sanitización programable de campos sensibles.], [Funciona cómodamente con 4 GB de RAM libres.], [Compose funcional, captura en Grafana y #NormalTok("smoke_test.sh"); exitoso.], [3, 4, 5],
  [8], [#link(<sec-guia-signoz>)[SigNoz]], [Operar una plataforma integrada con almacenamiento analítico columnar y OTLP nativo.], [8 GB de RAM libres.], [Compose funcional, captura en SigNoz y #NormalTok("smoke_test.sh"); exitoso.], [2, 4, 5],
  [9], [#link(<sec-guia-alloy>)[Alloy]], [Migrar el recolector a su sucesor oficial con configuración orientada al flujo de datos.], [Funciona cómodamente con 4 GB de RAM libres.], [Compose funcional, captura en Grafana y #NormalTok("smoke_test.sh"); exitoso.], [4, 5],
)
], caption: figure.caption(
position: top, 
[
Consulta rápida de las nueve guías prácticas.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-5>


Cada guía declara, además, su tiempo estimado (2 horas de laboratorio acompañado y 2 horas de trabajo independiente) y sus evidencias esperadas.

=== Matriz de alineación con los resultados de aprendizaje de la unidad
<matriz-de-alineación-con-los-resultados-de-aprendizaje-de-la-unidad>
La siguiente matriz vincula cada resultado de aprendizaje de la unidad con las guías que lo desarrollan, la evidencia observable y el instrumento con que se evalúa, en aplicación del principio de alineación constructiva:

#figure([
#table(
  columns: (19.35%, 27.96%, 23.66%, 29.03%),
  align: (auto,auto,auto,auto,),
  table.header([RA de la unidad], [Guías que lo desarrollan], [Evidencia observable], [Instrumento de evaluación],),
  table.hline(),
  [#strong[RA1] --- Explicar la observabilidad como requisito de diseño.], [Marco conceptual; se refuerza en cualquiera de las guías.], [Respuestas al cuestionario conceptual.], [Componente conceptual de la estrategia de evaluación.],
  [#strong[RA2] --- Describir la arquitectura de cuatro etapas y reconocerla en al menos dos implementaciones distintas.], [Cualquier par contrastante de guías (ver rutas sugeridas).], [Mapeo etapa--componente en el informe de laboratorio.], [Criterio de identificación arquitectónica de la rúbrica.],
  [#strong[RA3] --- Justificar los desafíos de estandarización, ciclo de vida y sanitización.], [Vector (sanitización), ELK y OLO (indexación y retención), OpenTelemetry (estandarización semántica).], [Reflexión escrita del informe de laboratorio.], [Criterio de reflexión escrita de la rúbrica.],
  [#strong[RA4] --- Desplegar y validar un stack completo sobre un entorno reproducible.], [Cualquiera de las nueve guías.], [Repositorio con configuraciones, capturas de validación y salida del #NormalTok("smoke_test.sh");.], [Criterios de despliegue funcional y calidad técnica de la rúbrica.],
  [#strong[RA5] --- Contrastar decisiones arquitectónicas entre stacks.], [Pares contrastantes de la ruta mínima.], [Ensayo comparativo sobre al menos dos criterios del marco.], [Componente integrador de la estrategia de evaluación.],
)
], caption: figure.caption(
position: top, 
[
Matriz de alineación entre resultados de aprendizaje de la unidad, guías, evidencias e instrumentos.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-6>


== Rutas sugeridas
<rutas-sugeridas>
=== Ruta mínima (2 semanas, 4 sesiones)
<ruta-mínima-2-semanas-4-sesiones>
Es la ruta recomendada para la unidad estándar. Cubre teoría completa y dos guías prácticas que ilustran enfoques contrastados.

#figure([
#table(
  columns: (20.51%, 25.64%, 28.21%, 25.64%),
  align: (auto,auto,auto,auto,),
  table.header([Sesión], [Duración], [Contenido], [Material],),
  table.hline(),
  [#strong[1]], [2 h], [Observabilidad, logs como pilar, dispersión y centralización. Beneficios de la centralización.], [#link(<sec-marco-conceptual>)[Marco conceptual]: observabilidad → beneficios],
  [#strong[2]], [2 h], [Arquitectura conceptual de cuatro etapas. Desafíos de diseño (estandarización, retención, sanitización). Presentación de los stacks disponibles.], [#link(<sec-marco-conceptual>)[Marco conceptual]: desafíos y arquitectura · recorrido de las #link(<sec-guia-elk>)[guías prácticas]],
  [#strong[3]], [2 h], [#strong[Laboratorio 1] --- Stack base: ELK #emph[o] PLG. Despliegue, ingreso de logs y consultas básicas.], [#link(<sec-guia-elk>)[Guía ELK] #emph[o] #link(<sec-guia-promtail>)[Guía PLG]],
  [#strong[4]], [2 h], [#strong[Laboratorio 2 + Cierre] --- Stack contrastante: OpenTelemetry #emph[o] Vector. Discusión comparada y evaluación.], [#link(<sec-guia-otel>)[Guía OpenTelemetry] #emph[o] #link(<sec-guia-vector>)[Guía Vector]],
)
], caption: figure.caption(
position: top, 
[
Planeación de la ruta mínima en cuatro sesiones.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-7>


#strong[Recomendación de pares contrastantes:]

- #strong[ELK + OpenTelemetry:] contrapone el stack clásico de indexación completa con el estándar unificado moderno.
- #strong[PLG + Vector:] ambos usan Loki como #emph[backend], pero el agente cambia radicalmente (Promtail vs.~Vector); pedagógicamente valioso para mostrar que la elección del recolector es independiente del almacenamiento.
- #strong[ELK + PLG:] contrapone los dos paradigmas de almacenamiento (texto completo vs.~solo etiquetas), ideal si se quiere foco en decisiones de almacenamiento.

=== Ruta extendida (electiva o trabajo final)
<ruta-extendida-electiva-o-trabajo-final>
Para estudiantes que desarrollarán un trabajo final, electiva especializada o semillero de investigación, se propone la ruta progresiva descrita en el documento base: ELK → OLO → Fluentd → PLG → GELF/Graylog → OpenTelemetry → Vector → SigNoz → Alloy. Esta ruta puede cubrirse en un semestre completo de electiva o como guion de un módulo de profundización.

=== Ruta corta (1 semana, 2 sesiones)
<ruta-corta-1-semana-2-sesiones>
Si la unidad debe condensarse en una sola semana:

#figure([
#table(
  columns: (42.11%, 57.89%),
  align: (auto,auto,),
  table.header([Sesión], [Contenido],),
  table.hline(),
  [#strong[1]], [Toda la teoría conceptual del #link(<sec-marco-conceptual>)[documento base], centrándose en los conceptos esenciales y delegando lecturas a casa.],
  [#strong[2]], [Un único laboratorio con la guía de #strong[OpenTelemetry], por ser la más representativa del estado del arte y cubrir los tres pilares en una sola implementación.],
)
], caption: figure.caption(
position: top, 
[
Planeación de la ruta corta en dos sesiones.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-8>


== Estrategia de evaluación
<estrategia-de-evaluación>
Se propone una evaluación de #strong[tres componentes] con peso ponderado, alineada con los resultados de aprendizaje siguiendo el principio de #strong[alineación constructiva] (coherencia explícita entre resultados de aprendizaje, actividades y criterios de evaluación). Los porcentajes son sugerencias; el docente debe ajustarlos a la ponderación general del curso. La rúbrica y los entregables definidos en esta sección constituyen los #strong[instrumentos de evaluación homogéneos] del recurso, aplicables de forma uniforme a cualquiera de las nueve guías prácticas.

=== Componente conceptual (30 %)
<componente-conceptual-30>
#strong[Instrumento:] Cuestionario corto con preguntas seleccionadas de la #link(<sec-guia-estudio>)[guía de estudio].

#strong[Recomendación:] seleccionar 5 preguntas mezclando el bloque teórico (preguntas conceptuales y glosario) y el bloque de articulación teoría--práctica. Las preguntas de articulación son las que mejor discriminan entre estudiantes que leyeron y estudiantes que comprendieron.

=== Componente práctico (40 %)
<componente-práctico-40>
#strong[Instrumento:] Informe de laboratorio sobre el despliegue de uno de los stacks trabajados en clase.

#strong[Entregables exigibles:]

- Repositorio o carpeta con el #NormalTok("docker-compose.yml"); y archivos de configuración funcionales.
- Capturas del estado de validación (contenedores arriba, logs visibles, consulta efectiva en el visualizador).
- Reflexión escrita (máx. 500 palabras) que responda explícitamente: #emph[¿qué etapas de la arquitectura conceptual identifica en su despliegue y qué componente concreto cumple cada una?]

#block[
#callout(
body: 
[
#strong[Ayuda de validación:] cada solución del repositorio incluye un script #NormalTok("smoke_test.sh"); que despliega el stack, emite un log de prueba y verifica su registro de extremo a extremo. El estudiante puede ejecutarlo para comprobar objetivamente que su entorno funciona antes de capturar las evidencias.

]
, 
title: 
[
Sugerencia
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
#strong[Rúbrica sugerida:]

#figure([
#table(
  columns: (14.08%, 8.45%, 23.94%, 23.94%, 29.58%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Criterio], [Peso], [Excelente (5.0)], [Aceptable (3.0)], [Insuficiente (1.0)],),
  table.hline(),
  [Despliegue funcional], [40 %], [Stack completo en ejecución, logs fluyendo, consultas efectivas], [Stack arriba pero con fallos parciales], [No logra arrancar el stack],
  [Identificación arquitectónica], [30 %], [Mapea correctamente las cuatro etapas a componentes concretos], [Identifica algunas etapas con imprecisiones menores], [Confunde etapas o no las identifica],
  [Reflexión escrita], [20 %], [Articula decisiones de diseño y compromisos], [Describe lo realizado sin análisis], [Reproduce contenido de la guía sin elaboración],
  [Calidad técnica], [10 %], [Configuración limpia, versionada, reproducible], [Configuración funcional pero desordenada], [Configuración no reproducible],
)
], caption: figure.caption(
position: top, 
[
Rúbrica analítica del componente práctico.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-9>


=== Componente integrador (30 %)
<componente-integrador-30>
#strong[Instrumento:] Ensayo comparativo breve (máx. 1000 palabras) que contraste #strong[dos stacks] vistos en clase a partir de #strong[al menos dos criterios] del marco teórico (por ejemplo: modelo de almacenamiento, acoplamiento del recolector, soporte para los tres pilares, gestión de la sanitización).

Este componente evalúa el resultado de aprendizaje 5 (capacidad de contrastar decisiones arquitectónicas), que es el de mayor nivel cognitivo y el que distingue una formación conceptual de una meramente operativa.

== Dificultades frecuentes y cómo anticiparlas
<dificultades-frecuentes-y-cómo-anticiparlas>
A continuación se enumeran las fricciones más comunes que experimentan los estudiantes al trabajar con el recurso, junto con orientaciones para anticiparlas en clase.

=== Memoria RAM insuficiente
<memoria-ram-insuficiente>
Los stacks ELK, OLO, GELF/Graylog y SigNoz consumen entre 4 y 6 GB en estado estable. En equipos con 8 GB totales o menos, el sistema entra en #emph[swapping] y los contenedores fallan con #NormalTok("OOMKilled"); o tiempos de arranque muy largos.

#strong[Recomendación docente:] Antes de iniciar el laboratorio, validar que cada equipo tenga al menos 8 GB de RAM libres. Para estudiantes con equipos limitados, redirigir hacia las guías de #strong[PLG, Vector o Alloy], que funcionan cómodamente con 4 GB. Como alternativa, los límites de memoria de cada contenedor están parametrizados mediante variables #NormalTok("*_MEM_LIMIT"); en el archivo #NormalTok(".env"); de cada solución, por lo que pueden reducirse para ajustar un stack a equipos con menos memoria (a costa de un arranque más lento).

=== #NormalTok("vm.max_map_count"); en Linux/WSL
<vm.max_map_count-en-linuxwsl>
Elasticsearch y OpenSearch requieren #NormalTok("vm.max_map_count ≥ 262144"); en el #emph[kernel] del #emph[host]. En Linux y WSL este valor no se ajusta automáticamente y el contenedor falla en el arranque sin mensaje claro.

#strong[Recomendación docente:] Cubrir este punto en la sesión 2, antes del laboratorio. Las guías afectadas incluyen el comando correctivo en su sección de troubleshooting.

=== Conflictos de puertos
<conflictos-de-puertos>
Varias guías exponen puertos comunes (3000 para Grafana, 5601 para Kibana, 9200 para Elasticsearch, 8080 para la aplicación de prueba). Si el estudiante ya tiene servicios escuchando en esos puertos, los contenedores fallan.

#strong[Recomendación docente:] Recordar el comando #NormalTok("lsof -i :PUERTO"); (macOS/Linux) o #NormalTok("netstat -ano | findstr :PUERTO"); (Windows) para diagnosticar el conflicto.

=== Formato ECS y claves planas con punto
<formato-ecs-y-claves-planas-con-punto>
Quarkus emite logs en formato ECS con claves planas como #NormalTok("{\"log.level\":\"INFO\"}");. Las etapas de procesamiento basadas en #NormalTok("json"); interpretan el punto como ruta anidada, lo que impide extraer el campo. Por eso varias guías usan expresiones regulares en lugar del #emph[parser] JSON estándar.

#strong[Recomendación docente:] Discutir este caso explícitamente como ilustración de la #strong[estandarización semántica imperfecta]: aún con ECS, hay matices de interpretación que pueden romper un pipeline.

=== Confusión entre los formatos de configuración
<confusión-entre-los-formatos-de-configuración>
Cada herramienta introduce su propio lenguaje de configuración: YAML (Promtail, ELK), TOML (Vector), #NormalTok(".alloy"); (Alloy), #NormalTok("fluent.conf"); (Fluentd), Logstash DSL. Los estudiantes suelen pegar configuraciones de una guía en otra y obtener errores.

#strong[Recomendación docente:] Enfatizar desde la sesión 2 que cada herramienta tiene su propio lenguaje y que la habilidad transferible es leer la documentación del producto, no memorizar sintaxis.

== Recomendaciones de articulación con otras unidades del curso
<recomendaciones-de-articulación-con-otras-unidades-del-curso>
#figure([
#table(
  columns: (45%, 55%),
  align: (auto,auto,),
  table.header([Unidad del curso], [Articulación posible],),
  table.hline(),
  [Comunicación entre microservicios], [Usar las trazas de OpenTelemetry para visualizar las llamadas REST/gRPC trabajadas en esa unidad],
  [Resiliencia (retries, circuit breakers)], [Usar los logs centralizados para observar el comportamiento del circuit breaker bajo fallo simulado],
  [Seguridad], [Usar el ejercicio de sanitización con VRL (guía Vector) para discutir manejo de credenciales en logs],
  [Despliegue continuo], [El recurso completo se despliega con #NormalTok("docker compose");\; puede extenderse a Kubernetes en una unidad posterior],
)
], caption: figure.caption(
position: top, 
[
Articulación de la unidad con otras unidades del curso.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gd-10>


== Mantenimiento y evolución del recurso
<mantenimiento-y-evolución-del-recurso>
El ecosistema de observabilidad evoluciona rápidamente; las versiones de las imágenes Docker quedan obsoletas en plazos de 12 a 18 meses. Se recomienda al docente que reutilice este material:

- Verificar las versiones de las imágenes en las guías al inicio de cada semestre.
- Reportar errores o sugerencias al equipo autor a través del repositorio del recurso (#link("https://github.com/christiancandela/logs-centralizados/issues")).
- Considerar contribuciones de los propios estudiantes (actualización de versiones, nuevas guías) como actividad complementaria de aprendizaje.

== Contacto
<contacto>
Para consultas sobre el uso pedagógico, propuestas de mejora o solicitudes de colaboración:

- PhD Christian Andrés Candela Uribe --- Profesor Asociado, Universidad del Quindío
- MSc Paola Andrea Acero Franco --- Profesor Asociado, Universidad del Quindío
- PhD Luis Eduardo Sepúlveda Rodríguez --- Profesor Asociado, Universidad del Quindío

Repositorio del recurso: #link("https://github.com/christiancandela/logs-centralizados") · Versión web: #link("https://christiancandela.github.io/logs-centralizados/")

#horizontalrule

#quote(block: true)[
Este documento forma parte del #emph[Recurso educativo para el despliegue de ecosistemas de centralización de logs mediante Docker] (Versión 1.0.0). Licencia CC BY-SA 4.0.
]

#part[Guías prácticas]
= Centralización de Logs con ELK Stack
<sec-guia-elk>
#quote(block: true)[
#emph[Guía práctica para implementar una solución básica de centralización de logs usando Docker Compose y el stack ELK, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía>
Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y el stack ELK, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-1>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Kibana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso>
El propósito principal de este recurso es guiar el diseño, despliegue y uso de una #strong[arquitectura básica de centralización de logs] utilizando contenedores Docker y el stack ELK (Elasticsearch, Logstash y Kibana).

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la #strong[centralización y visualización de logs]. No se abordan en profundidad otros pilares de la observabilidad, como métricas o trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

Aunque la implementación se apoya en el stack ELK, los principios abordados son #strong[transferibles a otros ecosistemas de observabilidad].

== Observabilidad y centralización de logs
<observabilidad-y-centralización-de-logs>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas. Los #strong[logs] constituyen una fuente primaria de información debido a su riqueza semántica y contextual, y la #strong[centralización de logs] mitiga la dispersión inherente a los sistemas distribuidos, consolidando los registros de múltiples componentes en un repositorio común.

Hasta aquí, nada nuevo respecto al marco conceptual. La pregunta que esta guía busca responder es más concreta: una vez centralizado un log, #emph[¿cómo se almacena y cómo se busca entre millones de registros?] El stack ELK responde con un paradigma específico (el #strong[índice invertido]), y entenderlo es la clave para comprender por qué ELK es tan potente para la búsqueda y, al mismo tiempo, tan exigente en recursos.

=== El paradigma de ELK: el índice invertido
<el-paradigma-de-elk-el-índice-invertido>
En el documento conceptual se presentaron tres paradigmas de almacenamiento (marco conceptual, #ref(<sec-5-7-3>, supplement: [Sección])). ELK encarna el primero, heredado de los motores de búsqueda. La idea es sencilla pero poderosa: en lugar de guardar los logs como simples líneas de texto, #strong[Elasticsearch] descompone cada mensaje en sus términos individuales y construye un diccionario que asocia cada término con la lista de registros que lo contienen:

#Skylighting(([#NormalTok("término \"saldo\"        → [log#42, log#118, log#349, ...]");],
[#NormalTok("término \"insuficiente\" → [log#42, log#349, ...]");],));
¿Por qué importa esto? Porque cuando buscas "saldo insuficiente", el motor no recorre millones de logs uno por uno: consulta directamente el diccionario y obtiene la respuesta de forma casi instantánea. Es la misma técnica que emplean los buscadores web, y es lo que convierte a Elasticsearch en una herramienta de búsqueda de texto completo extraordinariamente flexible.

Observa que esta potencia tiene un precio: construir y mantener el índice invertido consume CPU, memoria y disco. Por eso ELK es el stack más demandante en recursos de todo el recurso (ver la sección 2), y por eso otros paradigmas (como el de #emph[solo etiquetas] que estudiarás en la guía de Promtail/Loki) renuncian deliberadamente a parte de esta flexibilidad para ganar eficiencia. No hay un paradigma "mejor": hay compromisos distintos para necesidades distintas.

ELK está compuesto por tres piezas que mapean directamente a la arquitectura conceptual de cuatro etapas:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Componente], [Etapa conceptual], [Rol],),
  table.hline(),
  [#strong[Logstash]], [Recolección + Procesamiento], [Recibe, parsea y transforma los logs antes de almacenarlos],
  [#strong[Elasticsearch]], [Almacenamiento + Búsqueda], [Indexa (índice invertido) y responde las consultas],
  [#strong[Kibana]], [Visualización], [Explora y grafica los logs centralizados],
)
], caption: figure.caption(
position: top, 
[
Correspondencia entre los componentes de ELK y las etapas de la arquitectura conceptual.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-elk-1>


#block[
#callout(
body: 
[
El nombre "ELK" corresponde a las iniciales de sus tres componentes: #strong[E]lasticsearch, #strong[L]ogstash y #strong[K]ibana. Es la denominación de industria más extendida para este stack.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Requisitos previos
<requisitos-previos>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos>
#strong[Consumo estimado del stack:] \~5 GB de RAM en estado estable.

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("elasticsearch");], [Almacenamiento e indexación de los logs], [2g],
  [#NormalTok("logstash");], [Recolección y procesamiento (parsing, transformación)], [1g],
  [#NormalTok("kibana");], [Visualización y exploración de los datos], [1g],
  [#NormalTok("logs.producer");], [Aplicación Quarkus productora de logs], [512m],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack ELK, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-elk-2>


Los límites están parametrizados vía #NormalTok(".env"); y pueden ajustarse sin editar el #NormalTok("docker-compose.yml");:

#Skylighting(([#VariableTok("ELASTICSEARCH_MEM_LIMIT");#OperatorTok("=");#NormalTok("2g");],
[#VariableTok("LOGSTASH_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("KIBANA_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
#block[
#callout(
body: 
[
En Linux/WSL, Elasticsearch requiere que el host tenga #NormalTok("vm.max_map_count ≥ 262144");.

]
, 
title: 
[
Advertencia
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Estructura del proyecto
<estructura-del-proyecto>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("├──");#NormalTok(" logstash/");],
[#ExtensionTok("│");#NormalTok("   └── pipelines/");],
[#ExtensionTok("│");#NormalTok("       └── ecs.conf");],
[#ExtensionTok("└──");#NormalTok(" .env");],));
== Arquitectura de la solución
<arquitectura-de-la-solución>
#Skylighting(([#NormalTok("[Aplicaciones Java/Quarkus] --- (TCP JSON) ---> [Logstash] ---> [Elasticsearch] ---> [Kibana]");],));
La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- #strong[Logstash]: encargado de la ingestión, procesamiento y transformación de logs generados por las aplicaciones.
- #strong[Elasticsearch]: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- #strong[Kibana]: capa de visualización y exploración de los datos centralizados.

El uso de #strong[Docker Compose] permite describir y desplegar la arquitectura como código, garantizando la #strong[portabilidad, reproducibilidad y facilidad de experimentación] del entorno, características fundamentales en un contexto formativo.

== Implementación de la arquitectura conceptual con ELK
<implementación-de-la-arquitectura-conceptual-con-elk>
=== docker-compose.yml
<docker-compose.yml>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("LOGSTASH_HOST");#KeywordTok(":");#AttributeTok(" logstash");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("logstash");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" docker.io/elasticsearch:9.4.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" elasticsearch");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${ELASTICSEARCH_MEM_LIMIT:-2g}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9200:9200\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9300:9300\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("ES_JAVA_OPTS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"-Xms512m -Xmx512m\"");],
[#AttributeTok("      ");#FunctionTok("discovery.type");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"single-node\"");],
[#AttributeTok("      ");#FunctionTok("cluster.routing.allocation.disk.threshold_enabled");#KeywordTok(":");#AttributeTok(" ");#CharTok("false");],
[#AttributeTok("      ");#FunctionTok("xpack.security.enabled");#KeywordTok(":");#AttributeTok(" ");#CharTok("false");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" es_data:/usr/share/elasticsearch/data");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9200/_cluster/health || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 30s");],
[],
[#AttributeTok("  ");#FunctionTok("logstash");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" docker.io/logstash:9.4.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" logstash");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${LOGSTASH_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./logstash/pipelines");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /usr/share/logstash/pipeline");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4560:4560\"");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9600/ || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 3s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("10");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("kibana");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" docker.io/kibana:9.4.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" kibana");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${KIBANA_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"5601:5601\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("ELASTICSEARCH_HOSTS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"http://elasticsearch:9200\"");],
[#AttributeTok("      ");#FunctionTok("xpack.fleet.enabled");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"false\"");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("es_data");#KeywordTok(":");],));
=== Pipeline de Logstash (#NormalTok("ecs.conf");)
<pipeline-de-logstash-ecs.conf>
#Skylighting(([#NormalTok("input {");],
[#NormalTok("  tcp {");],
[#NormalTok("    port => 4560");],
[#NormalTok("    codec => json");],
[#NormalTok("  }");],
[#NormalTok("}");],
[],
[#NormalTok("filter {");],
[#NormalTok("  if ![span][id] and [mdc][spanId] {");],
[#NormalTok("    mutate { rename => { \"[mdc][spanId]\" => \"[span][id]\" } }");],
[#NormalTok("  }");],
[#NormalTok("  if ![trace][id] and [mdc][traceId] {");],
[#NormalTok("    mutate { rename => { \"[mdc][traceId]\" => \"[trace][id]\" } }");],
[#NormalTok("  }");],
[#NormalTok("}");],
[],
[#NormalTok("output {");],
[#NormalTok("  stdout {}");],
[#NormalTok("  elasticsearch {");],
[#NormalTok("    hosts => [\"http://elasticsearch:9200\"]");],
[#NormalTok("    data_stream => true");],
[#NormalTok("    data_stream_auto_routing => false");],
[#NormalTok("    data_stream_type => \"logs\"");],
[#NormalTok("    data_stream_dataset => \"producer\"");],
[#NormalTok("    data_stream_namespace => \"default\"");],
[#NormalTok("  }");],
[#NormalTok("}");],));
#block[
#callout(
body: 
[
#strong[Elasticsearch 9.x:] A partir de la versión 9, el output de Logstash utiliza #emph[data streams] en lugar de índices con fecha (#NormalTok("logstash-YYYY.MM.dd");). La configuración anterior crea el data stream #NormalTok("logs-producer-default");, que sigue la convención #NormalTok("{type}-{dataset}-{namespace}"); definida por ECS. Esto es transparente para la visualización en Kibana.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Despliegue y validación
<despliegue-y-validación>
=== Inicialización de los servicios
<inicialización-de-los-servicios>
El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo #NormalTok("docker-compose.yml");.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios>
La validación del entorno permite comprobar que los contenedores asociados a Elasticsearch, Logstash y Kibana se encuentran en ejecución y disponibles.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
=== Persistencia y configuración del entorno
<persistencia-y-configuración-del-entorno>
Se emplean #strong[volúmenes Docker] para garantizar la persistencia de los datos almacenados en #strong[Elasticsearch], incluso ante reinicios del entorno.

== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones>
=== Aplicaciones Quarkus
<aplicaciones-quarkus>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], utilizando #strong[logging estructurado en formato JSON] y el estándar #strong[ECS (Elastic Common Schema)]. \
Esta aproximación favorece la #strong[normalización semántica de los eventos], facilitando su procesamiento, correlación y análisis posterior dentro de la plataforma de centralización de logs.

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados a Logstash. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[#NormalTok("quarkus.log.socket.enable=true");],
[#NormalTok("quarkus.log.socket.json=true");],
[#NormalTok("# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta LOGSTASH_HOST=logstash");],
[#NormalTok("quarkus.log.socket.endpoint=${LOGSTASH_HOST:localhost}:4560");],
[#NormalTok("quarkus.log.socket.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.socket.json.log-format=ECS");],));
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback)
<otras-aplicaciones-java-logback>
Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en #strong[Logback], empleando un #emph[encoder] compatible con Logstash para la generación de logs estructurados en formato JSON.

Este enfoque permite ilustrar cómo aplicaciones Java tradicionales pueden integrarse a una arquitectura de centralización de logs, aun cuando no provean soporte nativo para estándares como ECS, resaltando la importancia de la estructuración y consistencia de los eventos generados.

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">ch.qos.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logback-classic</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">1.5.18</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">net.logstash.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logstash-logback-encoder</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">8.1</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
Configura #NormalTok("logback.xml"); para enviar logs a Logstash:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"logstash\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.appender.LogstashTcpSocketAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("destination");#NormalTok(">localhost:4560</");#KeywordTok("destination");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("encoder");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.encoder.LogstashEncoder\"");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("customFields");#NormalTok(">{\"appname\":\"tu-aplicacion\",\"environment\":\"dev\"}</");#KeywordTok("customFields");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("includeContext");#NormalTok(">true</");#KeywordTok("includeContext");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("timeZone");#NormalTok(">UTC</");#KeywordTok("timeZone");#NormalTok(">");],
[#NormalTok("    </");#KeywordTok("encoder");#NormalTok(">");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"logstash\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
== Visualización en Kibana
<visualización-en-kibana>
Una vez centralizados, los logs pueden ser explorados mediante Kibana, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

#Skylighting(([#NormalTok("http://localhost:5601");],));
#strong[Opción A --- Logs Explorer (recomendada):]

#strong[Observability → Logs → Logs Explorer]

Selecciona la fuente #NormalTok("logs-producer-default"); para ver únicamente los eventos de la aplicación.

#strong[Opción B --- Discover:]

#strong[Hamburger menu → Discover]

Crea o selecciona el data view #NormalTok("logs-*"); con campo de tiempo #NormalTok("@timestamp");. Esta vista muestra todos los data streams que coinciden con el patrón.

== Actividades de profundización
<actividades-de-profundización>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); de la aplicación de ejemplo genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y utilice Kibana para localizar el #emph[stacktrace] del error, validando la ventaja del campo #NormalTok("exception"); en formato ECS estructurado.
- Comparar ECS con esquemas personalizados: modifique el pipeline de Logstash para agregar un campo personalizado y observe cómo se indexa en Elasticsearch.
- Desplegar dos instancias de #NormalTok("logs.producer"); en puertos distintos y correlacionar sus eventos en Kibana mediante el campo #NormalTok("service.name");.
- Identificar las implicaciones de seguridad del envío TCP sin autenticación ni cifrado.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico>
+ ¿Qué ventaja concreta ofrece el Elastic Common Schema (ECS) frente a un esquema de logs personalizado cuando se correlacionan eventos de múltiples servicios en Kibana Discover?
+ El pipeline de Logstash de esta guía usa un appender TCP sin TLS. Analice qué riesgos de seguridad introduce este diseño y qué cambios de configuración serían necesarios para mitigarlos en un entorno productivo.
+ Evalúe las diferencias arquitectónicas entre los data streams de Elasticsearch 9.x (usados en esta guía) y los índices con fecha (#NormalTok("logs-YYYY.MM.dd");): ¿en qué escenarios concretos justificaría elegir uno sobre el otro?

== Troubleshooting
<troubleshooting>
#strong[Error común:] El contenedor #NormalTok("elasticsearch"); se detiene inesperadamente o marca estado #NormalTok("Exit 78"); / #NormalTok("Exit 137");.

#strong[Solución:] Elasticsearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar #NormalTok("docker compose up -d");:

#Skylighting(([#FunctionTok("sudo");#NormalTok(" sysctl ");#AttributeTok("-w");#NormalTok(" vm.max_map_count=262144");],));

#horizontalrule

#strong[Error común:] Kibana muestra el mensaje #emph["Kibana cannot connect to the Elastic Package Registry"] al abrir la interfaz.

#strong[Explicación:] Kibana 9.x intenta conectarse por defecto al registro externo de integraciones de Fleet (#NormalTok("epr.elastic.co");). En un entorno de laboratorio local sin acceso a internet este intento falla. El aviso es #strong[no bloqueante]: Kibana funciona correctamente para visualización de logs.

#strong[Solución:] El archivo #NormalTok("docker-compose.yml"); de esta guía ya incluye #NormalTok("xpack.fleet.enabled: \"false\""); en el servicio Kibana, lo que elimina el aviso. Si crea su propio #NormalTok("docker-compose.yml");, asegúrese de incluir esa variable de entorno.

== Referencias
<referencias>
- Logstash -- https:\/\/www.elastic.co/docs/reference/logstash
- Elasticsearch -- https:\/\/www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Kibana -- https:\/\/www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker
- Elastic Common Schema -- https:\/\/www.elastic.co/guide/en/ecs/current/ecs-reference.html

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con OLO Stack (OpenSearch + Logstash)
<sec-guia-olo>
#quote(block: true)[
#emph[Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y el stack OLO, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-1>
Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y el stack #strong[OLO (OpenSearch, Logstash y OpenSearch Dashboards)], como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

#block[
#callout(
body: 
[
#strong[La denominación "OLO":] Este acrónimo es una convención adoptada en este recurso educativo para nombrar el stack OpenSearch + Logstash + OpenSearch Dashboards, de manera análoga a como la industria denomina "ELK" al stack Elasticsearch + Logstash + Kibana. No es un término estándar de la industria; al buscar referencias externas sobre este stack conviene usar los nombres individuales de los componentes o buscar documentación de OpenSearch directamente.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-2>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en OpenSearch Dashboards que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-1>
El propósito principal de este recurso es guiar el diseño, despliegue y uso de una #strong[arquitectura básica de centralización de logs] utilizando OpenSearch, Logstash y OpenSearch Dashboards.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la #strong[centralización y visualización de logs]. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

== Observabilidad y centralización de logs
<observabilidad-y-centralización-de-logs-1>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de las señales externas que este produce durante su ejecución. Los #strong[logs] constituyen una fuente primaria de información debido a su riqueza semántica y contextual, y la #strong[centralización de logs] mitiga la dispersión inherente a los sistemas distribuidos consolidando los registros de múltiples componentes en un repositorio común.

Si ya recorriste la guía de ELK, buena parte de esta te resultará familiar (y eso es precisamente lo interesante). El stack #strong[OLO] (OpenSearch + Logstash + OpenSearch Dashboards) comparte exactamente el mismo paradigma de almacenamiento que ELK: el #strong[índice invertido] (marco conceptual, #ref(<sec-5-7-3>, supplement: [Sección])). La diferencia entre ambos no es, en el fondo, técnica, sino de gobernanza del software libre.

=== ¿Por qué existe OpenSearch si ya existía Elasticsearch?
<por-qué-existe-opensearch-si-ya-existía-elasticsearch>
En 2021, Elastic (la empresa detrás de Elasticsearch) cambió la licencia de su producto, abandonando la licencia open source Apache 2.0 por una licencia más restrictiva (SSPL). En respuesta, Amazon y la comunidad crearon un #emph[fork] (una bifurcación) a partir de la última versión Apache 2.0 de Elasticsearch y Kibana, dando origen a #strong[OpenSearch] y #strong[OpenSearch Dashboards].

Observa la lección de fondo: la elección de una tecnología no depende únicamente de sus capacidades técnicas, sino también del modelo de licenciamiento y de la gobernanza del proyecto que la sostiene. Para un ingeniero, anticipar estas implicaciones es tan importante como dominar la herramienta misma.

En lo conceptual, OLO se mapea a la arquitectura de cuatro etapas igual que ELK, componente por componente:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Componente], [Etapa conceptual], [Equivalente en ELK],),
  table.hline(),
  [#strong[Logstash]], [Recolección + Procesamiento], [Logstash],
  [#strong[OpenSearch]], [Almacenamiento + Búsqueda (índice invertido)], [Elasticsearch],
  [#strong[OpenSearch Dashboards]], [Visualización], [Kibana],
)
], caption: figure.caption(
position: top, 
[
Correspondencia entre los componentes de OLO, las etapas conceptuales y sus equivalentes en ELK.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-olo-1>


Esta correspondencia casi exacta no es casual: ambos stacks descienden del mismo código base. Comprenderla te permite transferir de inmediato a OLO todo lo aprendido sobre el paradigma de índice invertido en la guía de ELK.

== Requisitos previos
<requisitos-previos-1>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres

#block[
#callout(
body: 
[
#strong[Versiones:] Esta guía usa #strong[OpenSearch 3.0], la versión más reciente de la línea principal. La guía GELF/Graylog utiliza OpenSearch 2.12 porque Graylog 7.1 requiere compatibilidad con la API de Elasticsearch 7.x que solo mantiene la rama 2.x. Ambas elecciones son intencionadas y correctas para cada contexto.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-1>
El stack OLO es intensivo en memoria, ya que combina un motor de indexación distribuida (OpenSearch), un procesador de logs sobre la JVM (Logstash) y una capa de visualización (OpenSearch Dashboards). El #strong[consumo estimado del stack es de \~5 GB de RAM en estado estable], por lo que se recomienda disponer de al menos 8 GB libres para operar con holgura.

Cada servicio del #NormalTok("docker-compose.yml"); declara un límite de memoria (#NormalTok("mem_limit");) que acota su consumo y previene que un único contenedor agote la memoria del anfitrión:

#figure([
#table(
  columns: (16.95%, 40.68%, 42.37%),
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("opensearch");], [Almacenamiento e indexación de eventos], [#NormalTok("2g");],
  [#NormalTok("logstash");], [Ingestión, procesamiento y transformación de logs], [#NormalTok("1g");],
  [#NormalTok("dashboards");], [Visualización y exploración (OpenSearch Dashboards)], [#NormalTok("1g");],
  [#NormalTok("logs.producer");], [Aplicación productora de logs (Quarkus)], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack OLO, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-olo-2>


Estos límites están #strong[parametrizados mediante variables de entorno], de modo que pueden ajustarse sin modificar el #NormalTok("docker-compose.yml");. Defina los valores en un archivo #NormalTok(".env"); ubicado junto al #NormalTok("docker-compose.yml");:

#Skylighting(([#VariableTok("OPENSEARCH_MEM_LIMIT");#OperatorTok("=");#NormalTok("2g");],
[#VariableTok("LOGSTASH_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("DASHBOARDS_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
#block[
#callout(
body: 
[
En sistemas #strong[Linux o entornos WSL], OpenSearch requiere que la memoria virtual del anfitrión cumpla #NormalTok("vm.max_map_count ≥ 262144");. Configúrelo antes de iniciar el entorno (véase la sección de #emph[Troubleshooting]).

]
, 
title: 
[
Importante
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
== Estructura del proyecto
<estructura-del-proyecto-1>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("├──");#NormalTok(" logstash/");],
[#ExtensionTok("│");#NormalTok("   ├── Dockerfile");],
[#ExtensionTok("│");#NormalTok("   └── pipelines/");],
[#ExtensionTok("│");#NormalTok("       └── logstash.conf");],
[#ExtensionTok("└──");#NormalTok(" .env");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-1>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("        |");],
[#NormalTok("        | (TCP JSON)");],
[#NormalTok("        v");],
[#NormalTok("     [Logstash]");],
[#NormalTok("        |");],
[#NormalTok("        v");],
[#NormalTok("   [OpenSearch] ---> [OpenSearch Dashboards]");],));
La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- #strong[Logstash]: encargado de la ingestión, procesamiento y transformación de logs generados por las aplicaciones.
- #strong[OpenSearch]: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- #strong[OpenSearch Dashboards]: capa de visualización y exploración de los datos centralizados.

El uso de #strong[Docker Compose] permite describir y desplegar la arquitectura como código, garantizando la #strong[portabilidad, reproducibilidad y facilidad de experimentación] del entorno, características fundamentales en un contexto formativo.

== Implementación de la arquitectura conceptual con OLO
<implementación-de-la-arquitectura-conceptual-con-olo>
=== docker-compose.yml
<docker-compose.yml-1>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("LOGSTASH_HOST");#KeywordTok(":");#AttributeTok(" logstash");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("logstash");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("opensearch");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" opensearchproject/opensearch:3.0.0");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${OPENSEARCH_MEM_LIMIT:-2g}");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" opensearch");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" discovery.type=single-node");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" DISABLE_SECURITY_PLUGIN=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" bootstrap.memory_lock=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g");],
[#AttributeTok("    ");#FunctionTok("ulimits");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("memlock");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("soft");#KeywordTok(":");#AttributeTok(" ");#DecValTok("-1");],
[#AttributeTok("        ");#FunctionTok("hard");#KeywordTok(":");#AttributeTok(" ");#DecValTok("-1");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" opensearch_data:/usr/share/opensearch/data");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9200:9200\"");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9200/_cluster/health || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 30s");],
[],
[#AttributeTok("  ");#FunctionTok("dashboards");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" opensearchproject/opensearch-dashboards:3.0.0");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${DASHBOARDS_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" dashboards");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"5601:5601\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" OPENSEARCH_HOSTS=http://opensearch:9200");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" DISABLE_SECURITY_DASHBOARDS_PLUGIN=true");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("opensearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("logstash");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");#AttributeTok(" ./logstash");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${LOGSTASH_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" logstash");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./logstash/pipelines");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /usr/share/logstash/pipeline");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4560:4560\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" xpack.monitoring.enabled=false");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9600/ || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 3s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("10");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("opensearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("opensearch_data");#KeywordTok(":");],));
=== Pipeline de Logstash (#NormalTok("logstash.conf");)
<pipeline-de-logstash-logstash.conf>
#Skylighting(([#NormalTok("input {");],
[#NormalTok("  tcp {");],
[#NormalTok("    port => 4560");],
[#NormalTok("    codec => json");],
[#NormalTok("  }");],
[#NormalTok("}");],
[],
[#NormalTok("filter {");],
[#NormalTok("  if ![span][id] and [mdc][spanId] {");],
[#NormalTok("    mutate { rename => { \"[mdc][spanId]\" => \"[span][id]\" } }");],
[#NormalTok("  }");],
[#NormalTok("  if ![trace][id] and [mdc][traceId] {");],
[#NormalTok("    mutate { rename => { \"[mdc][traceId]\" => \"[trace][id]\" } }");],
[#NormalTok("  }");],
[#NormalTok("}");],
[],
[#NormalTok("output {");],
[#NormalTok("  stdout {}");],
[#NormalTok("  opensearch {");],
[#NormalTok("    hosts => [\"http://opensearch:9200\"]");],
[#NormalTok("    index => \"logs-producer-%{+YYYY.MM.dd}\"");],
[#NormalTok("    manage_template => false");],
[#NormalTok("  }");],
[#NormalTok("}");],));
=== Dockerfile de Logstash
<dockerfile-de-logstash>
#Skylighting(([#KeywordTok("FROM");#NormalTok(" docker.io/logstash:9.4.1");],
[#KeywordTok("RUN");#NormalTok(" ");#ExtensionTok("logstash-plugin");#NormalTok(" install logstash-output-opensearch");],));
#block[
#callout(
body: 
[
La versión 2.x del plugin #NormalTok("logstash-output-opensearch"); tiene un bug de compatibilidad con JRuby 10 (incluido en Logstash 9.x) que impide la instalación de templates. Por eso el pipeline incluye #NormalTok("manage_template => false");, lo que hace que Logstash cree los índices dinámicamente sin plantilla previa. En producción se recomienda definir un index template explícito en OpenSearch.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Despliegue y validación
<despliegue-y-validación-1>
=== Inicialización de los servicios
<inicialización-de-los-servicios-1>
El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo #NormalTok("docker-compose.yml");.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios-1>
La validación del entorno permite comprobar que los contenedores asociados a OpenSearch, Logstash y OpenSearch Dashboards se encuentran en ejecución y disponibles.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
=== Persistencia y configuración del entorno
<persistencia-y-configuración-del-entorno-1>
Se emplean #strong[volúmenes Docker] para garantizar la persistencia de los datos almacenados en #strong[OpenSearch], incluso ante reinicios del entorno.

Opensearch-dashboards requiere una configuración adicional para facilitar la visualización de logs. El siguiente comando pretende crear un index-pattern en el Dashboard con el fin de poder visualizar los logs generados por logstash.

#block[
#callout(
body: 
[
Antes de ejecutar el siguiente comando, asegúrese de que OpenSearch Dashboards haya finalizado su inicialización y sea accesible desde el navegador.

]
, 
title: 
[
Importante
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
#Skylighting(([#NormalTok("curl -XPOST \"http://localhost:5601/api/saved_objects/index-pattern\" \\");],
[#NormalTok("  -H \"Content-Type: application/json\" \\");],
[#NormalTok("  -H \"osd-xsrf: true\" \\");],
[#NormalTok("  -d '{");],
[#NormalTok("    \"attributes\": {");],
[#NormalTok("      \"title\": \"logs-producer-*\",");],
[#NormalTok("      \"timeFieldName\": \"@timestamp\"");],
[#NormalTok("    }");],
[#NormalTok("  }'");],));
== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-1>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-1>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], utilizando #strong[logging estructurado en formato JSON] y el estándar #strong[ECS (Elastic Common Schema)]. \
Esta aproximación favorece la #strong[normalización semántica de los eventos], facilitando su procesamiento, correlación y análisis posterior dentro de la plataforma de centralización de logs.

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados a Logstash. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[#NormalTok("quarkus.log.socket.enable=true");],
[#NormalTok("quarkus.log.socket.json=true");],
[#NormalTok("# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta LOGSTASH_HOST=logstash");],
[#NormalTok("quarkus.log.socket.endpoint=${LOGSTASH_HOST:localhost}:4560");],
[#NormalTok("quarkus.log.socket.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.socket.json.log-format=ECS");],));
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback)
<otras-aplicaciones-java-logback-1>
Para otras aplicaciones Java que no utilizan Quarkus, el recurso presenta un ejemplo basado en #strong[Logback], empleando un #emph[encoder] compatible con Logstash para la generación de logs estructurados en formato JSON.

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">ch.qos.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logback-classic</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">1.5.18</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">net.logstash.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logstash-logback-encoder</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">8.1</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
Configura #NormalTok("logback.xml"); para enviar logs a Logstash:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"logstash\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.appender.LogstashTcpSocketAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("destination");#NormalTok(">localhost:4560</");#KeywordTok("destination");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("encoder");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.encoder.LogstashEncoder\"");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("customFields");#NormalTok(">{\"appname\":\"tu-aplicacion\",\"environment\":\"dev\"}</");#KeywordTok("customFields");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("includeContext");#NormalTok(">true</");#KeywordTok("includeContext");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("timeZone");#NormalTok(">UTC</");#KeywordTok("timeZone");#NormalTok(">");],
[#NormalTok("    </");#KeywordTok("encoder");#NormalTok(">");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"logstash\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
== Visualización en OpenSearch Dashboards
<visualización-en-opensearch-dashboards>
Una vez centralizados, los logs pueden ser explorados mediante OpenSearch Dashboards, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

#Skylighting(([#NormalTok("http://localhost:5601");],));
Ingrese a #strong[OpenSearch Dashboards → Discover]: una vez creado el index pattern #NormalTok("logs-producer-*"); (paso anterior), selecciónelo y verá el registro de los logs con todos sus campos ECS.

Alternativamente, acceda a #strong[Observability → Logs] y en el campo PPL ingrese:

#Skylighting(([#NormalTok("source = logs-producer-*");],));
== Actividades de profundización
<actividades-de-profundización-1>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); de la aplicación de ejemplo genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y utilice OpenSearch Dashboards para localizar el evento de error e inspeccionar el stacktrace estructurado.
- Comparar el modelo de índices con fecha (#NormalTok("logs-producer-YYYY.MM.dd");) de este stack frente a los data streams de Elasticsearch 9.x de la guía anterior.
- Desplegar dos instancias de #NormalTok("logs.producer"); y distinguirlas en Discover por el campo #NormalTok("service.name");.
- Identificar las implicaciones de seguridad del envío TCP sin autenticación ni cifrado.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-1>
+ OpenSearch es un fork de Elasticsearch. Explique qué es el campo #NormalTok("manage_template => false"); en el pipeline de Logstash de esta guía y por qué es necesario específicamente con el plugin #NormalTok("logstash-output-opensearch"); 2.x sobre Logstash 9.x.
+ Compare el modelo de índices con fecha (#NormalTok("logs-producer-YYYY.MM.dd");) que usa este stack frente a los data streams de Elasticsearch 9.x de la guía ELK: ¿qué implicaciones tiene cada enfoque para la gestión del ciclo de vida de los datos (ILM)?
+ Evalúe las razones técnicas y de gobernanza que llevaron a la bifurcación de OpenSearch desde Elasticsearch 7.10. ¿Cómo afecta esa historia a la elección de versión en esta guía (OpenSearch 3.0) frente a la guía GELF (OpenSearch 2.12)?

== Troubleshooting
<troubleshooting-1>
#strong[Error común:] El contenedor #NormalTok("opensearch"); se detiene inesperadamente o marca estado #NormalTok("Exit 78"); / #NormalTok("Exit 137");.

#strong[Solución:] OpenSearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar #NormalTok("docker compose up -d");:

#Skylighting(([#FunctionTok("sudo");#NormalTok(" sysctl ");#AttributeTok("-w");#NormalTok(" vm.max_map_count=262144");],));

#horizontalrule

#strong[Error común:] Logstash arranca pero no indexa documentos; en sus logs aparece #NormalTok("undefined method 'exists?' for class File");.

#strong[Explicación:] El plugin #NormalTok("logstash-output-opensearch"); 2.x tiene un bug de compatibilidad con JRuby 10 (Logstash 9.x) al intentar instalar templates de índice. El pipeline de esta guía ya incluye #NormalTok("manage_template => false"); para evitarlo. Si crea su propio pipeline, asegúrese de incluir esa opción.

== Referencias
<referencias-1>
- OpenSearch -- https:\/\/opensearch.org
- OpenSearch (Docker) -- https:\/\/docs.opensearch.org/docs/latest/install-and-configure/install-opensearch/docker/
- OpenSearch Dashboards -- https:\/\/docs.opensearch.org/docs/latest/dashboards/
- Logstash -- https:\/\/www.elastic.co/docs/reference/logstash
- Elastic Common Schema -- https:\/\/www.elastic.co/guide/en/ecs/current/ecs-reference.html

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con Fluentd
<sec-guia-fluentd>
#quote(block: true)[
#emph[Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y Fluentd, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-2>
Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose y Fluentd, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-3>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs hacia Fluentd.
- Analizar y correlacionar eventos centralizados.
- Reconocer desafíos y limitaciones de una solución básica de logging.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Kibana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-2>
El propósito principal de este recurso es guiar el diseño, despliegue y uso de una #strong[arquitectura básica de centralización de logs] utilizando Fluentd, Elasticsearch y Kibana.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra la integración entre aplicaciones Java y una plataforma de observabilidad.

El alcance del recurso se limita a la #strong[centralización y visualización de logs]. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas las bases conceptuales para su integración futura.

== Observabilidad y centralización de logs
<observabilidad-y-centralización-de-logs-2>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de las señales externas que este produce durante su ejecución. Los #strong[logs] constituyen una fuente primaria de información debido a su riqueza semántica y contextual, y la #strong[centralización de logs] mitiga la dispersión inherente a los sistemas distribuidos consolidando los registros de múltiples componentes en un repositorio común.

Las guías de ELK y OLO presentaban stacks "verticales", en los que el recolector (Logstash) venía estrechamente atado a un motor de almacenamiento concreto. Fluentd propone una idea distinta y muy influyente: #strong[desacoplar por completo la recolección del almacenamiento].

=== Fluentd como "capa de logging unificada"
<fluentd-como-capa-de-logging-unificada>
Fluentd se sitúa en las etapas de #strong[recolección y procesamiento] de la arquitectura conceptual (marco conceptual, #ref(<sec-5-7-1>, supplement: [Sección]) y #ref(<sec-5-7-2>, supplement: [Sección])), pero no impone ningún destino. Su filosofía es actuar como una #emph[capa de logging unificada] (#emph[unified logging layer]): un punto central que recibe logs desde cualquier fuente, los normaliza a un formato común y los reenvía hacia cualquier destino.

¿Cómo logra esta flexibilidad? Mediante un modelo de #strong[plugins]: entradas (#emph[inputs]), filtros (#emph[filters]) y salidas (#emph[outputs]) que se combinan como piezas de un mecano. Una misma instancia de Fluentd puede recibir logs por TCP, desde archivos y vía syslog, y enviarlos simultáneamente a un motor de búsqueda, a un archivo de respaldo y a un servicio en la nube, sin recompilar nada.

Observa una propiedad clave que conecta directamente con el marco conceptual: Fluentd implementa #emph[buffering] (amortiguación) configurable para no perder eventos cuando el destino se ralentiza o cae, materializando el principio de desacoplamiento temporal y las garantías de entrega discutidos en el marco conceptual (#ref(<sec-5-7-1>, supplement: [Sección]) y #ref(<sec-5-6>, supplement: [Sección])).

#block[
#callout(
body: 
[
Fluentd es un proyecto graduado de la #strong[CNCF] (Cloud Native Computing Foundation), la misma fundación que alberga a Kubernetes. Esto refleja su adopción como uno de los estándares de facto para la recolección de logs en entornos nativos de la nube.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Requisitos previos
<requisitos-previos-2>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-2>
El #strong[consumo estimado del stack] es de #strong[\~4 GB de RAM] en estado estable, distribuidos entre los servicios que componen el pipeline de centralización de logs.

#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("elasticsearch");], [Almacenamiento e indexación de eventos], [#NormalTok("2g");],
  [#NormalTok("kibana");], [Visualización y exploración de logs], [#NormalTok("1g");],
  [#NormalTok("fluentd");], [Recolección y procesamiento de eventos], [#NormalTok("512m");],
  [#NormalTok("logs.producer");], [Aplicación productora (Quarkus)], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack Fluentd, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-fluentd-1>


Cada límite de memoria es #strong[parametrizable vía el archivo #NormalTok(".env");], lo que permite ajustar el dimensionamiento del entorno según los recursos disponibles en la máquina anfitriona:

#Skylighting(([#VariableTok("ELASTICSEARCH_MEM_LIMIT");#OperatorTok("=");#NormalTok("2g");],
[#VariableTok("KIBANA_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("FLUENTD_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
#block[
#callout(
body: 
[
En sistemas Linux/WSL, Elasticsearch requiere que la memoria virtual del anfitrión cumpla #NormalTok("vm.max_map_count ≥ 262144");. Consulte la sección de Troubleshooting para el comando de ajuste.

]
, 
title: 
[
Advertencia
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Estructura del proyecto
<estructura-del-proyecto-2>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("├──");#NormalTok(" fluentd/");],
[#ExtensionTok("│");#NormalTok("   ├── Dockerfile");],
[#ExtensionTok("│");#NormalTok("   └── conf/");],
[#ExtensionTok("│");#NormalTok("       └── fluent.conf");],
[#ExtensionTok("└──");#NormalTok(" .env");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-2>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("        |");],
[#NormalTok("        | (TCP JSON)");],
[#NormalTok("        v");],
[#NormalTok("     [Fluentd]");],
[#NormalTok("        |");],
[#NormalTok("        v");],
[#NormalTok(" [Elasticsearch] ---> [Kibana]");],));
La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- #strong[Fluentd]: actúa como componente de #strong[recolección y procesamiento], desacoplando la generación de eventos de su almacenamiento y análisis posterior.
- #strong[Elasticsearch]: motor de almacenamiento e indexación distribuida, que permite la búsqueda eficiente de eventos.
- #strong[Kibana]: capa de visualización y exploración de los datos centralizados.

El uso de #strong[Docker Compose] permite describir y desplegar la arquitectura como código, garantizando la #strong[portabilidad, reproducibilidad y facilidad de experimentación] del entorno, características fundamentales en un contexto formativo.

== Implementación de la arquitectura conceptual con Fluentd
<implementación-de-la-arquitectura-conceptual-con-fluentd>
=== docker-compose.yml
<docker-compose.yml-2>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("FLUENTD_HOST");#KeywordTok(":");#AttributeTok(" fluentd");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("fluentd");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${ELASTICSEARCH_MEM_LIMIT:-2g}");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" docker.io/elasticsearch:9.4.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" elasticsearch");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9200:9200\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9300:9300\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("ES_JAVA_OPTS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"-Xms512m -Xmx512m\"");],
[#AttributeTok("      ");#FunctionTok("discovery.type");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"single-node\"");],
[#AttributeTok("      ");#FunctionTok("cluster.routing.allocation.disk.threshold_enabled");#KeywordTok(":");#AttributeTok(" ");#CharTok("false");],
[#AttributeTok("      ");#FunctionTok("xpack.security.enabled");#KeywordTok(":");#AttributeTok(" ");#CharTok("false");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" es_data:/usr/share/elasticsearch/data");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9200/_cluster/health || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 30s");],
[],
[#AttributeTok("  ");#FunctionTok("kibana");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${KIBANA_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" docker.io/kibana:9.4.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" kibana");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"5601:5601\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("ELASTICSEARCH_HOSTS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"http://elasticsearch:9200\"");],
[#AttributeTok("      ");#FunctionTok("xpack.fleet.enabled");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"false\"");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("fluentd");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${FLUENTD_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");#AttributeTok(" ./fluentd");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" fluentd");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./fluentd/conf");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /fluentd/etc");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4560:4560\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ELASTICSEARCH_HOST=elasticsearch");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ELASTICSEARCH_PORT=9200");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"ruby -rsocket -e 'TCPSocket.new(");#SpecialCharTok("\\\"");#StringTok("127.0.0.1");#SpecialCharTok("\\\"");#StringTok(", 4560).close' 2>/dev/null\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("6");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 15s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("elasticsearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("es_data");#KeywordTok(":");],));
=== Configuración de Fluentd (#NormalTok("fluent.conf");)
<configuración-de-fluentd-fluent.conf>
#Skylighting(([#NormalTok("<");#KeywordTok("source");#NormalTok(">");],
[#NormalTok("  @type tcp");],
[#NormalTok("  port 4560");],
[#NormalTok("  bind 0.0.0.0");],
[#NormalTok("  <");#KeywordTok("parse");#NormalTok(">");],
[#NormalTok("    @type json");],
[#NormalTok("  </");#KeywordTok("parse");#NormalTok(">");],
[#NormalTok("  tag app.logs");],
[#NormalTok("</");#KeywordTok("source");#NormalTok(">");],
[],
[#NormalTok("<");#KeywordTok("match");#NormalTok(" ");#OtherTok("app.logs");#ErrorTok(">");],
[#NormalTok("  @type elasticsearch");],
[#NormalTok("  host \"#{ENV['ELASTICSEARCH_HOST'] || 'elasticsearch'}\"");],
[#NormalTok("  port \"#{ENV['ELASTICSEARCH_PORT'] || 9200}\"");],
[#NormalTok("  logstash_format true");],
[#NormalTok("  logstash_prefix logs");],
[#NormalTok("  <");#KeywordTok("buffer");#NormalTok(">");],
[#NormalTok("    @type file");],
[#NormalTok("    path /fluentd/log/buffers/app");],
[#NormalTok("    flush_interval 5s");],
[#NormalTok("  </");#KeywordTok("buffer");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("match");#NormalTok(">");],));
#block[
#callout(
body: 
[
A diferencia de Logstash, la imagen oficial de Fluentd #strong[no incluye] el plugin de Elasticsearch. El plugin #NormalTok("fluent-plugin-elasticsearch"); debe instalarse al construir la imagen personalizada (ver Dockerfile en la siguiente sección). El archivo de configuración debe llamarse #NormalTok("fluent.conf");, que es el nombre esperado por el entrypoint del contenedor.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Dockerfile de Fluentd
<dockerfile-de-fluentd>
#Skylighting(([#KeywordTok("FROM");#NormalTok(" fluent/fluentd:v1.18.0-debian");],
[#KeywordTok("USER");#NormalTok(" root");],
[#KeywordTok("RUN");#NormalTok(" ");#ExtensionTok("gem");#NormalTok(" install fluent-plugin-elasticsearch ");#AttributeTok("--no-document");],
[#KeywordTok("USER");#NormalTok(" fluent");],));
#block[
#callout(
body: 
[
La imagen base de Fluentd corre como usuario no privilegiado #NormalTok("fluent");. La instalación de gems requiere cambiar temporalmente al usuario #NormalTok("root"); y volver a #NormalTok("fluent"); al finalizar.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Despliegue y validación
<despliegue-y-validación-2>
=== Inicialización de los servicios
<inicialización-de-los-servicios-2>
El despliegue del entorno se realiza mediante un único comando, el cual levanta de forma coordinada todos los componentes definidos en el archivo #NormalTok("docker-compose.yml");.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios-2>
La validación del entorno permite comprobar que los contenedores asociados a Elasticsearch, Fluentd y Kibana se encuentran en ejecución y disponibles.

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
=== Persistencia y configuración del entorno
<persistencia-y-configuración-del-entorno-2>
Se emplean #strong[volúmenes Docker] para garantizar la persistencia de los datos almacenados en #strong[Elasticsearch], incluso ante reinicios del entorno.

== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-2>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-2>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], utilizando #strong[logging estructurado en formato JSON] y el estándar #strong[ECS (Elastic Common Schema)]. \
Fluentd recibe estos eventos a través de su plugin #NormalTok("in_tcp"); configurado con un parser JSON, aprovechando la misma interfaz de red que ya ofrece la extensión de logging de Quarkus.

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados a Fluentd. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[#NormalTok("quarkus.log.socket.enable=true");],
[#NormalTok("quarkus.log.socket.json=true");],
[#NormalTok("# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta FLUENTD_HOST=fluentd");],
[#NormalTok("quarkus.log.socket.endpoint=${FLUENTD_HOST:localhost}:4560");],
[#NormalTok("quarkus.log.socket.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.socket.json.log-format=ECS");],));
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback con Syslog)
<otras-aplicaciones-java-logback-con-syslog>
#quote(block: true)[
#strong[SECCIÓN DE REFERENCIA --- NO EJECUTABLE TAL COMO ESTÁ]

Esta sección ilustra un patrón de integración alternativo (Syslog UDP) con fines pedagógicos. #strong[No forma parte del #NormalTok("docker-compose.yml"); del recurso] y no puede ejecutarse directamente sin modificaciones. Para experimentar con ella deberá: (1) agregar el source #NormalTok("in_syslog"); a #NormalTok("fluent.conf");, y (2) exponer el puerto #NormalTok("5140:5140/udp"); en el servicio #NormalTok("fluentd"); del compose. Se incluye aquí para ampliar la comprensión de la versatilidad de Fluentd como colector multi-protocolo.
]

Para aplicaciones Java que no utilizan Quarkus, Fluentd puede actuar como receptor #strong[Syslog (RFC5424) vía UDP]. Esto ilustra cómo Fluentd se integra con protocolos clásicos de red, ampliando el espectro de productores de logs compatibles.

En este caso, Fluentd expone el puerto #NormalTok("5140/udp"); con el plugin #NormalTok("in_syslog"); y la aplicación utiliza el #NormalTok("SyslogAppender"); de Logback:

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">ch.qos.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logback-classic</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">1.5.18</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
Configuración de #NormalTok("logback.xml");:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"FLUENTD\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"ch.qos.logback.classic.net.SyslogAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("syslogHost");#NormalTok(">fluentd</");#KeywordTok("syslogHost");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("port");#NormalTok(">5140</");#KeywordTok("port");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("suffixPattern");#NormalTok(">%logger{36} - %msg</");#KeywordTok("suffixPattern");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("protocol");#NormalTok(">UDP</");#KeywordTok("protocol");#NormalTok(">");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"FLUENTD\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
Configuración de Fluentd para recibir Syslog:

#Skylighting(([#NormalTok("<");#KeywordTok("source");#NormalTok(">");],
[#NormalTok("  @type syslog");],
[#NormalTok("  port 5140");],
[#NormalTok("  bind 0.0.0.0");],
[#NormalTok("  message_format rfc5424");],
[#NormalTok("  tag app.logs");],
[#NormalTok("</");#KeywordTok("source");#NormalTok(">");],));
#block[
#callout(
body: 
[
A diferencia del transporte TCP JSON (sección 7.1), el protocolo Syslog no transporta campos estructurados: el cuerpo del mensaje es texto plano. Esta diferencia es pedagógicamente relevante al comparar el nivel de observabilidad obtenido con cada protocolo.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Visualización en Kibana
<visualización-en-kibana-1>
Una vez centralizados, los logs pueden ser explorados mediante Kibana, permitiendo:

- Búsqueda textual y estructurada.
- Filtros temporales.
- Identificación de patrones y anomalías.

Estas capacidades resultan especialmente relevantes en contextos educativos para ilustrar procesos de diagnóstico y análisis de fallos.

Accede a:

#Skylighting(([#NormalTok("http://localhost:5601");],));
#strong[Discover:]

Navegue a #strong[Hamburger menu → Discover]. Cree un data view con el patrón #NormalTok("logs-*"); y campo de tiempo #NormalTok("@timestamp");. Esta vista muestra todos los índices generados por Fluentd con el prefijo #NormalTok("logs-YYYY.MM.dd");.

== Actividades de profundización
<actividades-de-profundización-2>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); de la aplicación de ejemplo genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y utilice Kibana para localizar el evento de error e inspeccionar el stacktrace estructurado.
- Comparar Fluentd y Logstash como componentes de procesamiento: ¿qué diferencias existen en su modelo de configuración y su ecosistema de plugins?
- Desplegar dos instancias de #NormalTok("logs.producer"); y distinguirlas en Kibana por el campo #NormalTok("service.name");.
- Modificar #NormalTok("fluent.conf"); para agregar un campo personalizado (ej. #NormalTok("environment: dev");) usando el plugin #NormalTok("record_transformer"); y observar cómo se indexa en Elasticsearch.
- Analizar las implicaciones de usar índices con fecha (#NormalTok("logs-YYYY.MM.dd");) frente a data streams de Elasticsearch 9.x.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-2>
+ En la configuración de Fluentd de esta guía, el bloque #NormalTok("<buffer>"); usa #NormalTok("@type file"); con #NormalTok("flush_interval 5s");. Explique qué papel cumple este buffer en términos de confiabilidad de entrega y qué ocurriría si el contenedor de Fluentd se reinicia antes de que el buffer se vacíe.
+ Compare el modelo de configuración de Fluentd (#NormalTok("fluent.conf"); con directivas #NormalTok("<source>");, #NormalTok("<filter>");, #NormalTok("<match>");) frente al pipeline de Logstash (#NormalTok("input");, #NormalTok("filter");, #NormalTok("output");): ¿qué diferencias de diseño se observan en la forma de enrutar eventos a múltiples destinos?
+ La sección 7.2 describe el transporte Syslog UDP como alternativa al TCP JSON. Evalúe las implicaciones de observabilidad de cada protocolo: ¿cuál ofrece mayor fidelidad semántica y por qué el enfoque TCP JSON es preferible para sistemas modernos?

== Troubleshooting
<troubleshooting-2>
#strong[Error común:] El contenedor #NormalTok("elasticsearch"); se detiene inesperadamente o marca estado #NormalTok("Exit 78"); / #NormalTok("Exit 137");.

#strong[Solución:] Elasticsearch requiere configurar la memoria virtual del sistema anfitrión. En sistemas Linux o entornos WSL, ejecute el siguiente comando en la terminal de su máquina (fuera del contenedor) antes de iniciar #NormalTok("docker compose up -d");:

#Skylighting(([#FunctionTok("sudo");#NormalTok(" sysctl ");#AttributeTok("-w");#NormalTok(" vm.max_map_count=262144");],));

#horizontalrule

#strong[Error común:] Kibana muestra el mensaje #emph["Kibana cannot connect to the Elastic Package Registry"] al abrir la interfaz.

#strong[Explicación:] Kibana 9.x intenta conectarse por defecto al registro externo de integraciones de Fleet. En un entorno de laboratorio local sin acceso a internet, este intento falla. El aviso es #strong[no bloqueante].

#strong[Solución:] El archivo #NormalTok("docker-compose.yml"); de esta guía ya incluye #NormalTok("xpack.fleet.enabled: \"false\""); en el servicio Kibana. Si crea su propio #NormalTok("docker-compose.yml");, asegúrese de incluir esa variable de entorno.

#horizontalrule

#strong[Error común:] Fluentd no inicia y reporta #NormalTok("No such file or directory @ rb_sysopen - /fluentd/etc/fluent.conf");.

#strong[Explicación:] El entrypoint del contenedor de Fluentd busca el archivo de configuración con el nombre exacto #NormalTok("fluent.conf"); (no #NormalTok("fluentd.conf");).

#strong[Solución:] Asegúrese de que el archivo de configuración se llame #NormalTok("fluent.conf");.

== Referencias
<referencias-2>
- Fluentd - https:\/\/docs.fluentd.org
- Fluentd (plugins) - https:\/\/www.fluentd.org/plugins
- fluent-plugin-elasticsearch - https:\/\/github.com/uken/fluent-plugin-elasticsearch
- Elasticsearch -- https:\/\/www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Kibana -- https:\/\/www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con Promtail, Loki y Grafana (PLG Stack)
<sec-guia-promtail>
#quote(block: true)[
#emph[Guía práctica para implementar una solución de centralización de logs utilizando Docker Compose con el ecosistema de Grafana (Promtail y Loki), como instanciación de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

#quote(block: true)[
#strong[Estado de Promtail:] A partir de 2023, Grafana Labs ha puesto Promtail en #strong[modo mantenimiento]. Se siguen publicando correcciones de seguridad, pero no se añaden nuevas funcionalidades. La versión #NormalTok("3.0.0"); es la última de la rama principal y no se prevén versiones posteriores. La herramienta recomendada para nuevos proyectos es #link("https://grafana.com/docs/alloy/")[#strong[Grafana Alloy]], el sucesor unificado que incorpora las capacidades de Promtail y del Grafana Agent. Esta guía usa Promtail porque su modelo conceptual (#emph[file tailing] hacia Loki) es más directo para el aprendizaje y sigue siendo completamente funcional. Una vez comprendido Promtail, la migración a Alloy es natural.
]

== Objetivo de la guía
<objetivo-de-la-guía-3>
Implementar y validar una arquitectura de centralización de logs mediante #strong[Docker Compose], utilizando #strong[Promtail] como agente recolector, #strong[Loki] como motor de indexación y almacenamiento, y #strong[Grafana] para la visualización y análisis.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-4>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs basada en el ecosistema Grafana.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar aplicaciones para emitir logs estructurados hacia archivos.
- Configurar Promtail para recolectar y enviar (#emph[scrape]) logs desde volúmenes compartidos.
- Analizar y correlacionar eventos centralizados utilizando el lenguaje LogQL en Grafana.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Grafana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-3>
El propósito principal de este recurso es guiar el diseño, despliegue y uso de una #strong[arquitectura de centralización de logs] eficiente, basada en la filosofía de Loki (indexación ligera basada en etiquetas en lugar de texto completo).

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software y observabilidad.
- Un #strong[entorno de laboratorio reproducible], para experimentar con flujos de generación, recolección y análisis.
- Un #strong[caso de estudio técnico], que ilustra la recolección de logs a través de lectura directa de archivos (#emph[file tailing]) utilizando Promtail.

== Observabilidad y centralización de logs
<observabilidad-y-centralización-de-logs-3>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas. Los #strong[logs] constituyen una fuente primaria de información debido a su riqueza contextual.

Si las guías de ELK y OLO te mostraron el paradigma del índice invertido, esta guía te presenta su contrapunto más interesante. El ecosistema de Grafana (Promtail y Loki) parte de una pregunta provocadora: #emph[¿y si no indexáramos el contenido de los logs en absoluto?]

=== El paradigma de Loki: indexar solo etiquetas
<el-paradigma-de-loki-indexar-solo-etiquetas>
Recordando los tres paradigmas de almacenamiento del marco conceptual (#ref(<sec-5-7-3>, supplement: [Sección])), Loki encarna el tercero: el #strong[índice de solo etiquetas]. La diferencia con ELK es radical y vale la pena detenerse en ella:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([], [ELK / OpenSearch], [Loki],),
  table.hline(),
  [Qué indexa], [Cada término de cada mensaje], [Solo un puñado de etiquetas (metadatos)],
  [Buscar texto libre], [Inmediato (índice invertido)], [Escaneo en tiempo de consulta],
  [Costo de almacenamiento], [Alto], [Muy bajo],
  [Analogía], [El índice temático de un libro], [Las etiquetas de las carpetas de un archivador],
)
], caption: figure.caption(
position: top, 
[
Comparación de los modelos de indexación de ELK/OpenSearch y Loki.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-promtail-1>


¿Por qué renunciar a indexar el contenido? Porque indexarlo todo es caro (marco conceptual, #ref(<sec-5-7-3>, supplement: [Sección])). La apuesta de Loki es que, en la práctica, casi siempre acotas tu búsqueda primero por metadatos ("dame los logs del servicio #NormalTok("pagos"); en el entorno #NormalTok("prod"); durante la última hora") y solo entonces buscas dentro de ese subconjunto ya reducido. Loki indexa esas etiquetas (#NormalTok("servicio");, #NormalTok("entorno");…) para filtrar a gran velocidad, y deja el contenido sin indexar, comprimido en bloques baratos que solo se escanean cuando hace falta.

El resultado es un sistema mucho más ligero en disco y memoria que un motor de indexación completa, a cambio de búsquedas de texto libre más lentas. De nuevo: no es "mejor" ni "peor", es un compromiso distinto.

El stack PLG (Promtail, Loki, Grafana) se reparte las etapas conceptuales de esta forma:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Componente], [Etapa conceptual], [Rol],),
  table.hline(),
  [#strong[Promtail]], [Recolección], [Descubre y lee archivos de log (#emph[file tailing]) y los envía a Loki],
  [#strong[Loki]], [Almacenamiento + Búsqueda], [Indexa solo etiquetas; responde consultas mediante #strong[LogQL]],
  [#strong[Grafana]], [Visualización], [Explora y grafica los logs con LogQL],
)
], caption: figure.caption(
position: top, 
[
Correspondencia entre los componentes del stack PLG y las etapas conceptuales.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-promtail-2>


#block[
#callout(
body: 
[
El diseño cuidadoso de las etiquetas es crítico en Loki: usar como etiqueta un campo de alta #strong[cardinalidad] (marco conceptual, #ref(<sec-5-6>, supplement: [Sección])), como un identificador de usuario, multiplica el número de flujos internos y degrada el rendimiento. La regla práctica es: etiquetas de baja cardinalidad, y el resto de la información dentro del mensaje.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Requisitos previos
<requisitos-previos-3>
- Docker instalado (https:\/\/docs.docker.com/engine/install/)
- Docker Compose (https:\/\/docs.docker.com/compose/install/)
- Al menos #strong[8 GB de RAM] libres.

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-3>
#strong[Consumo estimado del stack:] \~2.5 GB de RAM en estado estable. Se trata de un stack ligero (la indexación de Loki se basa solo en etiquetas), apto incluso para equipos con 4 GB de RAM.

Cada servicio declara un #NormalTok("mem_limit"); en el #NormalTok("docker-compose.yml"); para acotar su consumo de memoria:

#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("logs.producer");], [Aplicación Quarkus productora de logs], [#NormalTok("512m");],
  [#NormalTok("loki");], [Motor de indexación (solo labels) y almacenamiento], [#NormalTok("512m");],
  [#NormalTok("promtail");], [Agente recolector (#emph[file tailing])], [#NormalTok("256m");],
  [#NormalTok("grafana");], [Visualización y consulta (LogQL)], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack PLG, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-promtail-3>


Estos valores son parametrizables mediante variables de entorno definidas en un archivo #NormalTok(".env"); junto al #NormalTok("docker-compose.yml");, lo que permite ajustarlos sin modificar el compose:

#Skylighting(([#VariableTok("LOKI_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("PROMTAIL_MEM_LIMIT");#OperatorTok("=");#NormalTok("256m");],
[#VariableTok("GRAFANA_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
== Estructura del proyecto
<estructura-del-proyecto-3>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("├──");#NormalTok(" promtail/");],
[#ExtensionTok("│");#NormalTok("   └── promtail-config.yaml");],
[#ExtensionTok("├──");#NormalTok(" grafana/");],
[#ExtensionTok("│");#NormalTok("   └── provisioning/");],
[#ExtensionTok("│");#NormalTok("       └── datasources/");],
[#ExtensionTok("│");#NormalTok("           └── loki.yaml");],
[#ExtensionTok("└──");#NormalTok(" logs/                 ");#OperatorTok("<");#NormalTok("-- Volumen compartido para archivos de log");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-3>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("         |");],
[#NormalTok("    (Escribe en archivo .log)");],
[#NormalTok("         v");],
[#NormalTok("  [Volumen Compartido ./logs]");],
[#NormalTok("         |");],
[#NormalTok("    (Lee archivo / tailing)");],
[#NormalTok("         v");],
[#NormalTok("     [Promtail]");],
[#NormalTok("         |");],
[#NormalTok("     (API HTTP push)");],
[#NormalTok("         v");],
[#NormalTok("       [Loki] ---> [Grafana]");],));
La arquitectura implementada en este recurso se fundamenta en tres componentes principales:

- #strong[Promtail]: agente de recolección que vigila (#emph[tail]) archivos de log en un volumen compartido y los envía a Loki.
- #strong[Loki]: motor de almacenamiento ligero que indexa solo etiquetas (labels), no el contenido textual de los logs.
- #strong[Grafana]: capa de visualización y exploración mediante el lenguaje de consulta #strong[LogQL].

== Implementación de la arquitectura conceptual
<implementación-de-la-arquitectura-conceptual>
=== docker-compose.yml
<docker-compose.yml-3>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ./logs:/deployments/logs");],
[],
[#AttributeTok("  ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/loki:3.0.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" loki");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${LOKI_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3100:3100\"");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");#AttributeTok(" -config.file=/etc/loki/local-config.yaml");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"wget -q --spider http://localhost:3100/ready || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 15s");],
[],
[#AttributeTok("  ");#FunctionTok("promtail");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/promtail:3.0.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" promtail");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PROMTAIL_MEM_LIMIT:-256m}");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ./logs:/var/log/app_logs:ro");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./promtail/promtail-config.yaml");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /etc/promtail/config.yml");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");#AttributeTok(" -config.file=/etc/promtail/config.yml");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("grafana");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/grafana:13.0.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" grafana");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${GRAFANA_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ENABLED=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ORG_ROLE=Admin");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_DISABLE_LOGIN_FORM=true");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3000:3000\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /etc/grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],));
#block[
#callout(
body: 
[
La carpeta #NormalTok("./logs"); actúa como volumen compartido: #NormalTok("logs.producer"); escribe los archivos allí y Promtail los lee en modo solo lectura (#NormalTok(":ro");). La carpeta #NormalTok("./grafana/provisioning"); configura automáticamente Loki como fuente de datos en Grafana.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Configuración de Promtail (#NormalTok("promtail-config.yaml");)
<configuración-de-promtail-promtail-config.yaml>
#Skylighting(([#FunctionTok("server");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("http_listen_port");#KeywordTok(":");#AttributeTok(" ");#DecValTok("9080");],
[#AttributeTok("  ");#FunctionTok("grpc_listen_port");#KeywordTok(":");#AttributeTok(" ");#DecValTok("0");],
[],
[#FunctionTok("positions");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("filename");#KeywordTok(":");#AttributeTok(" /tmp/positions.yaml");],
[],
[#FunctionTok("clients");#KeywordTok(":");],
[#AttributeTok("  ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("url");#KeywordTok(":");#AttributeTok(" http://loki:3100/loki/api/v1/push");],
[],
[#FunctionTok("scrape_configs");#KeywordTok(":");],
[#AttributeTok("  ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("job_name");#KeywordTok(":");#AttributeTok(" java_apps");],
[#AttributeTok("    ");#FunctionTok("static_configs");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("targets");#KeywordTok(":");],
[#AttributeTok("          ");#KeywordTok("-");#AttributeTok(" localhost");],
[#AttributeTok("        ");#FunctionTok("labels");#KeywordTok(":");],
[#AttributeTok("          ");#FunctionTok("job");#KeywordTok(":");#AttributeTok(" quarkus_app");],
[#AttributeTok("          ");#FunctionTok("environment");#KeywordTok(":");#AttributeTok(" dev");],
[#AttributeTok("          ");#FunctionTok("__path__");#KeywordTok(":");#AttributeTok(" /var/log/app_logs/*.log");],
[#AttributeTok("    ");#FunctionTok("pipeline_stages");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("regex");#KeywordTok(":");],
[#AttributeTok("          ");#FunctionTok("expression");#KeywordTok(":");#AttributeTok(" ");#StringTok("'\"log\\.level\":\"(?P<level>[^\"]+)\"'");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("labels");#KeywordTok(":");],
[#AttributeTok("          ");#FunctionTok("level");#KeywordTok(":");],));
#block[
#callout(
body: 
[
La etapa #NormalTok("regex"); extrae el campo #NormalTok("log.level"); del JSON de cada línea y lo convierte en un #strong[label de Loki] (#NormalTok("level");). Esto permite filtrar logs por nivel directamente en LogQL sin necesidad de analizar el contenido. Las claves con punto (como #NormalTok("log.level");) no pueden ser extraídas con la etapa #NormalTok("json"); estándar de Promtail porque gjson las interpreta como rutas anidadas; el enfoque #NormalTok("regex"); resuelve este caso.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Aprovisionamiento de Grafana (#NormalTok("grafana/provisioning/datasources/loki.yaml");)
<aprovisionamiento-de-grafana-grafanaprovisioningdatasourcesloki.yaml>
#Skylighting(([#FunctionTok("apiVersion");#KeywordTok(":");#AttributeTok(" ");#DecValTok("1");],
[],
[#FunctionTok("datasources");#KeywordTok(":");],
[#AttributeTok("  ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("name");#KeywordTok(":");#AttributeTok(" Loki");],
[#AttributeTok("    ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" loki");],
[#AttributeTok("    ");#FunctionTok("access");#KeywordTok(":");#AttributeTok(" proxy");],
[#AttributeTok("    ");#FunctionTok("url");#KeywordTok(":");#AttributeTok(" http://loki:3100");],
[#AttributeTok("    ");#FunctionTok("isDefault");#KeywordTok(":");#AttributeTok(" ");#CharTok("true");],));
#block[
#callout(
body: 
[
Este archivo configura Loki como fuente de datos de Grafana automáticamente al arrancar el contenedor. No es necesario agregarla manualmente desde la interfaz.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Despliegue y validación
<despliegue-y-validación-3>
Antes de levantar el stack, cree el directorio compartido para los logs:

#Skylighting(([#FunctionTok("mkdir");#NormalTok(" ");#AttributeTok("-p");#NormalTok(" logs");],));
Luego ejecute:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
Verifique que los servicios estén activos:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-3>
A diferencia de otras guías donde se usa envío por red (TCP/UDP), Promtail se especializa en #strong[leer archivos de log]. La aplicación escribe en un archivo dentro del volumen compartido #NormalTok("./logs");, y Promtail lo vigila continuamente.

=== Aplicaciones Quarkus
<aplicaciones-quarkus-3>
- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para escribir logs en formato JSON al archivo compartido. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[],
[#NormalTok("# Escribir logs estructurados en formato JSON al archivo compartido con Promtail");],
[#NormalTok("quarkus.log.file.enable=true");],
[#NormalTok("quarkus.log.file.json=true");],
[#NormalTok("quarkus.log.file.path=/deployments/logs/application.log");],
[#NormalTok("quarkus.log.file.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.file.json.log-format=ECS");],));
#block[
#callout(
body: 
[
La ruta #NormalTok("/deployments/logs/application.log"); es la ruta #strong[dentro del contenedor]. El #NormalTok("docker-compose.yml"); monta #NormalTok("./logs"); en #NormalTok("/deployments/logs");, por lo que el archivo quedará disponible en #NormalTok("./logs/application.log"); en el host.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback)
<otras-aplicaciones-java-logback-2>
Si usa Logback, configure un #NormalTok("FileAppender"); con el codificador JSON de Logstash.

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">ch.qos.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logback-classic</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">1.5.18</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">net.logstash.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logstash-logback-encoder</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">8.1</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
#NormalTok("logback.xml");:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"FILE\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"ch.qos.logback.core.FileAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("file");#NormalTok(">/deployments/logs/application.log</");#KeywordTok("file");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("encoder");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.encoder.LogstashEncoder\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"FILE\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
== Visualización en Grafana
<visualización-en-grafana>
Acceda a Grafana en #NormalTok("http://localhost:3000");. La fuente de datos Loki ya está preconfigurada.

Navegue a #strong[Explore] (icono de brújula en el menú izquierdo) y seleccione #strong[Loki] como fuente de datos.

#strong[Consultas LogQL de ejemplo:]

Todos los logs de la aplicación:

#Skylighting(([#NormalTok("{job=\"quarkus_app\"}");],));
Filtrar por nivel:

#Skylighting(([#NormalTok("{job=\"quarkus_app\", level=\"ERROR\"}");],));
Buscar errores por contenido:

#Skylighting(([#NormalTok("{job=\"quarkus_app\"} |= \"NullPointerException\"");],));
Analizar los campos del JSON y mostrar solo el mensaje:

#Skylighting(([#NormalTok("{job=\"quarkus_app\"} | json | line_format \"{{.message}}\"");],));
== Actividades de profundización
<actividades-de-profundización-3>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y utilice la consulta LogQL #NormalTok("{job=\"quarkus_app\"} |= \"NullPointerException\""); para localizarlo en Grafana.
- Analizar cómo Promtail maneja la lectura del archivo (#emph[tailing]) y la posición de lectura (archivo #NormalTok("positions.yaml");).
- Comparar el enfoque basado en archivos contra el envío directo por red (TCP/UDP): ¿qué ventajas y desventajas ofrece cada uno en términos de acoplamiento, confiabilidad y rendimiento?
- Desplegar dos instancias de #NormalTok("logs.producer"); escribiendo en archivos distintos y distinguirlas mediante labels de Promtail.
- Analizar las implicaciones del modelo de indexación de Loki (solo labels) frente a la indexación completa de Elasticsearch.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-3>
+ La configuración de Promtail usa una etapa #NormalTok("regex"); para extraer #NormalTok("log.level"); como label de Loki. Explique por qué no se puede usar la etapa #NormalTok("json"); estándar para esta tarea con el formato ECS de Quarkus.
+ Analice el mecanismo de #emph[file tailing] de Promtail y el archivo #NormalTok("positions.yaml");: ¿qué garantías de entrega ofrece este enfoque si el contenedor de Promtail se reinicia inesperadamente? ¿Es equivalente al buffer de Fluentd o al TCP de Logstash?
+ Loki indexa solo etiquetas (labels) y no el contenido textual de los logs. Evalúe las ventajas e inconvenientes de este diseño frente a la indexación completa de Elasticsearch: ¿qué tipos de consultas se vuelven más costosas con Loki y cuáles se benefician de su ligereza?

== Troubleshooting
<troubleshooting-3>
#strong[Error común:] El archivo #NormalTok("./logs/application.log"); no se crea.

#strong[Solución:] Verifique que el directorio #NormalTok("./logs"); exista en el host antes de ejecutar #NormalTok("docker compose up");. El contenedor #NormalTok("logs.producer"); escribe en #NormalTok("/deployments/logs/"); que debe estar montado correctamente. Cree el directorio con #NormalTok("mkdir -p logs");.

#horizontalrule

#strong[Error común:] Grafana no muestra datos al consultar en Explore.

#strong[Solución:] Verifique que Promtail esté enviando logs con #NormalTok("docker compose logs promtail");. Asegúrese de que el archivo de log exista en #NormalTok("./logs/"); y que Loki esté saludable (#NormalTok("docker compose ps");). Confirme que la URL de la datasource en Grafana sea #NormalTok("http://loki:3100");.

#horizontalrule

#strong[Error común:] Loki devuelve error al iniciar por permisos en #NormalTok("/tmp/loki");.

#strong[Solución:] Loki en modo single-node almacena datos en #NormalTok("/tmp/loki"); por defecto. Si el contenedor se reinicia frecuentemente, agregue un volumen persistente:

#Skylighting(([#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("    ");#KeywordTok("-");#AttributeTok(" loki_data:/tmp/loki");],));
Y declare #NormalTok("loki_data:"); en la sección #NormalTok("volumes:"); del compose.

== Referencias
<referencias-3>
- Loki Documentation: https:\/\/grafana.com/docs/loki/latest/
- Promtail Documentation: https:\/\/grafana.com/docs/loki/latest/send-data/promtail/
- LogQL (Loki Query Language): https:\/\/grafana.com/docs/loki/latest/query/
- Grafana -- https:\/\/grafana.com/docs/grafana/latest/

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con GELF y Graylog
<sec-guia-gelf-graylog>
#quote(block: true)[
#emph[Guía práctica para implementar una solución básica de centralización de logs utilizando Docker Compose y GELF/Graylog, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-4>
Implementar y validar una arquitectura básica de centralización de logs mediante Docker Compose, utilizando #strong[GELF] como protocolo de transporte y #strong[Graylog] como plataforma de ingestión y visualización, como ejercicio aplicado de los conceptos de observabilidad estudiados previamente.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-5>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de una arquitectura de centralización de logs basada en Graylog.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica.
- Configurar Graylog para recibir eventos vía #strong[GELF UDP].
- Configurar aplicaciones Java para emitir logs mediante GELF (Quarkus y Logback).
- Explorar y consultar logs centralizados desde la interfaz de Graylog.
- Reconocer desafíos y limitaciones de un envío basado en UDP y mensajes fragmentados.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Graylog que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-4>
El propósito principal de este recurso es guiar el despliegue y uso de una #strong[arquitectura básica de centralización de logs] basada en Graylog, en un entorno local y reproducible mediante Docker Compose.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra la integración entre aplicaciones Java (Quarkus y Logback) y una plataforma de observabilidad.

El alcance del recurso se limita a la #strong[centralización y visualización de logs]. No se abordan métricas ni trazas distribuidas, aunque se dejan sentadas bases conceptuales para integraciones futuras.

== Observabilidad y centralización de logs
<observabilidad-y-centralización-de-logs-4>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas que este produce durante su ejecución. Los #strong[logs] constituyen una fuente primaria de información por su riqueza semántica y contextual, y la #strong[centralización de logs] mitiga la dispersión inherente a los sistemas distribuidos consolidando los registros de múltiples componentes en un repositorio común.

Las guías anteriores se centraban en cómo se #emph[almacenan] los logs. Esta pone el foco en un eslabón previo y a menudo subestimado: #emph[¿cómo viajan los logs desde la aplicación hasta el sistema central?] La respuesta nos lleva al concepto de #strong[protocolo de transporte].

=== Del syslog clásico a GELF
<del-syslog-clásico-a-gelf>
Durante décadas, el protocolo estándar para transmitir logs por red fue #strong[syslog]. Pero syslog arrastra limitaciones serias para los sistemas modernos: trunca los mensajes largos y carece de un concepto nativo de campos estructurados (todo es una cadena de texto plana).

#strong[GELF (Graylog Extended Log Format)] nació precisamente para resolver esto. Es un protocolo que:

- transmite cada evento como un objeto #strong[estructurado en JSON], con campos explícitos (recuerda la discusión sobre logging estructurado del marco conceptual, #ref(<sec-5-2>, supplement: [Sección]));
- #strong[fragmenta] (#emph[chunking]) los mensajes largos para que no se trunquen;
- suele enviarse sobre #strong[UDP], priorizando la baja latencia y el desacoplamiento: la aplicación "dispara y olvida", sin esperar confirmación, de modo que el envío de logs nunca bloquee la lógica de negocio.

Observa que GELF es un #strong[protocolo], no una herramienta: define #emph[cómo] se empaquetan y transmiten los logs, no dónde se guardan. Esta distinción conceptual es importante y conviene tenerla clara antes de continuar.

=== Graylog y su arquitectura de dos almacenes
<graylog-y-su-arquitectura-de-dos-almacenes>
#strong[Graylog] es la plataforma que recibe los logs vía GELF, los procesa y los pone a disposición para búsqueda y visualización. Para ello se apoya en dos almacenes con roles bien diferenciados:

#figure([
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Componente], [Rol],),
  table.hline(),
  [#strong[Graylog]], [Ingestión (vía GELF), búsqueda y visualización],
  [#strong[OpenSearch]], [Almacenamiento e indexación de los eventos (índice invertido)],
  [#strong[MongoDB]], [Configuración y metadatos de la propia plataforma Graylog],
)
], caption: figure.caption(
position: top, 
[
Componentes de la plataforma Graylog y su rol.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gelf-graylog-1>


#block[
#callout(
body: 
[
El envío por UDP prioriza el rendimiento sobre la garantía de entrega: es un caso concreto de la semántica #emph[at-most-once] discutida en el marco conceptual (#ref(<sec-5-6>, supplement: [Sección])). Para escenarios donde no puede perderse ningún log, GELF también admite TCP.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Requisitos previos
<requisitos-previos-4>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres

#block[
#callout(
body: 
[
#strong[Versiones:] Esta guía usa #strong[OpenSearch 2.12], no la versión 3.x empleada en la guía OLO. Graylog 7.1 requiere compatibilidad con la API de Elasticsearch 7.x, que OpenSearch 2.x mantiene; la rama 3.x introdujo cambios de API que Graylog aún no soporta. Ambas elecciones son intencionadas y correctas para cada contexto.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-4>
El #strong[consumo estimado del stack] es de #strong[\~5 GB de RAM en estado estable]. Para evitar que un contenedor agote la memoria del anfitrión, cada servicio del #NormalTok("docker-compose.yml"); declara un límite de memoria (#NormalTok("mem_limit");):

#figure([
#table(
  columns: (16.95%, 40.68%, 42.37%),
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("graylog");], [Ingestión, búsqueda y visualización de logs], [#NormalTok("1g");],
  [#NormalTok("opensearch");], [Almacenamiento e indexación de eventos (backend de búsqueda)], [#NormalTok("2g");],
  [#NormalTok("mongo");], [Configuración y metadatos de Graylog], [#NormalTok("512m");],
  [#NormalTok("logs.producer");], [Aplicación productora de logs (Quarkus)], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack Graylog, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-gelf-graylog-2>


Estos límites se #strong[parametrizan vía #NormalTok(".env");], de modo que puede ajustarlos sin editar el #NormalTok("docker-compose.yml");:

#Skylighting(([#VariableTok("GRAYLOG_MEM_LIMIT");#OperatorTok("=");#NormalTok("1g");],
[#VariableTok("OPENSEARCH_MEM_LIMIT");#OperatorTok("=");#NormalTok("2g");],
[#VariableTok("MONGODB_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
#block[
#callout(
body: 
[
el backend de búsqueda (Elasticsearch/OpenSearch) requiere #NormalTok("vm.max_map_count ≥ 262144"); en Linux/WSL. De lo contrario, el contenedor #NormalTok("opensearch"); no arrancará.

]
, 
title: 
[
Advertencia
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
== Estructura del proyecto
<estructura-del-proyecto-4>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-4>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("        |");],
[#NormalTok("        |   GELF (UDP 12201)");],
[#NormalTok("        v");],
[#NormalTok("     [Graylog 7.1]");],
[#NormalTok("        |             \\");],
[#NormalTok("        v              v");],
[#NormalTok("  [OpenSearch 2.12]  [MongoDB 7.0]");],
[#NormalTok("  (almacenamiento)  (configuración)");],));
La arquitectura implementada en este recurso se fundamenta en #strong[un protocolo de transporte y tres servicios]:

- #strong[GELF (Graylog Extended Log Format)]: protocolo estructurado de envío de logs vía #strong[UDP] (puerto 12201). A diferencia de los stacks anteriores, el transporte es responsabilidad del protocolo, no de un agente recolector separado.
- #strong[Graylog]: plataforma de ingestión, búsqueda y visualización de logs.
- #strong[OpenSearch]: motor de almacenamiento e indexación de eventos.
- #strong[MongoDB]: almacenamiento de configuración y metadatos de Graylog.

El uso de #strong[Docker Compose] permite describir y desplegar la arquitectura como código, garantizando la #strong[portabilidad, reproducibilidad y facilidad de experimentación] del entorno.

== Implementación de la arquitectura conceptual con GELF y Graylog
<implementación-de-la-arquitectura-conceptual-con-gelf-y-graylog>
=== docker-compose.yml
<docker-compose.yml-4>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_HOST");#KeywordTok(":");#AttributeTok(" graylog");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("graylog");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("mongo");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" mongo:7.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" mongo");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${MONGODB_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" mongo_data:/data/db");],
[],
[#AttributeTok("  ");#FunctionTok("opensearch");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" opensearchproject/opensearch:2.12.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" opensearch");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${OPENSEARCH_MEM_LIMIT:-2g}");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" discovery.type=single-node");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" DISABLE_SECURITY_PLUGIN=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" bootstrap.memory_lock=true");],
[#AttributeTok("    ");#FunctionTok("ulimits");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("memlock");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("soft");#KeywordTok(":");#AttributeTok(" ");#DecValTok("-1");],
[#AttributeTok("        ");#FunctionTok("hard");#KeywordTok(":");#AttributeTok(" ");#DecValTok("-1");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" opensearch_data:/usr/share/opensearch/data");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9200/_cluster/health || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 30s");],
[],
[#AttributeTok("  ");#FunctionTok("graylog");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" graylog/graylog:7.1.1-1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" graylog");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${GRAYLOG_MEM_LIMIT:-1g}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"9000:9000\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"12201:12201/udp\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"1514:1514\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_MONGODB_URI");#KeywordTok(":");#AttributeTok(" mongodb://mongo:27017/graylog");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_HTTP_EXTERNAL_URI");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"http://127.0.0.1:9000/\"");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_HTTP_BIND_ADDRESS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"0.0.0.0:9000\"");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_ELASTICSEARCH_HOSTS");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"http://opensearch:9200\"");],
[#CommentTok("      # Reduce journal size para entornos con disco limitado (por defecto 5 GB)");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_MESSAGE_JOURNAL_MAX_SIZE");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"512mb\"");],
[#CommentTok("      # CHANGE ME (must be at least 16 characters)");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_PASSWORD_SECRET");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"forpasswordencryption\"");],
[#CommentTok("      # Password: admin");],
[#AttributeTok("      ");#FunctionTok("GRAYLOG_ROOT_PASSWORD_SHA2");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" graylog_data:/usr/share/graylog/data");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"curl -sf http://localhost:9000/api/system/lbstatus | grep -q ALIVE || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 15s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("20");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 60s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("mongo");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_started");],
[#AttributeTok("      ");#FunctionTok("opensearch");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[#AttributeTok("    ");#FunctionTok("entrypoint");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"/usr/bin/tini -- /docker-entrypoint.sh\"");],
[],
[#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("mongo_data");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("opensearch_data");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("graylog_data");#KeywordTok(":");],));
== Despliegue y validación
<despliegue-y-validación-4>
=== Inicialización de los servicios
<inicialización-de-los-servicios-3>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios-3>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
Salida esperada (referencial):

#Skylighting(([#NormalTok("NAME         STATUS");],
[#NormalTok("mongo        Up");],
[#NormalTok("opensearch   Up (healthy)");],
[#NormalTok("graylog      Up (healthy)");],
[#NormalTok("logs.producer  Up");],));
=== Creación de la entrada GELF UDP (Input)
<creación-de-la-entrada-gelf-udp-input>
Antes de que los logs puedan ser recibidos, Graylog debe tener configurado un #strong[input]. Espere a que Graylog esté disponible en #NormalTok("http://localhost:9000");, luego ejecute:

#Skylighting(([#ExtensionTok("curl");#NormalTok(" ");#AttributeTok("-H");#NormalTok(" ");#StringTok("\"Content-Type: application/json\"");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-H");#NormalTok(" ");#StringTok("\"Authorization: Basic YWRtaW46YWRtaW4=\"");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-H");#NormalTok(" ");#StringTok("\"X-Requested-By: curl\"");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-X");#NormalTok(" POST ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-d");#NormalTok(" ");#StringTok("'{\"title\":\"GELF UDP\",\"configuration\":{\"recv_buffer_size\":262144,\"bind_address\":\"0.0.0.0\",\"port\":12201,\"decompress_size_limit\":8388608},\"type\":\"org.graylog2.inputs.gelf.udp.GELFUDPInput\",\"global\":true}'");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("     http://localhost:9000/api/system/inputs");],));
#quote(block: true)[
La cabecera #NormalTok("Authorization: Basic YWRtaW46YWRtaW4="); corresponde a #NormalTok("admin:admin"); en Base64. Alternativamente, puede crear el input desde la interfaz web: #strong[System → Inputs → GELF UDP → Launch new input].
]

== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-4>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-4>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], utilizando la extensión #NormalTok("logging-gelf"); que envía logs directamente a Graylog mediante el protocolo GELF/UDP.

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-gelf' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados a Graylog. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.handler.gelf.enabled=true");],
[#NormalTok("# Cuando se ejecuta desde el IDE apunta a localhost; docker compose inyecta GRAYLOG_HOST=graylog");],
[#NormalTok("quarkus.log.handler.gelf.host=${GRAYLOG_HOST:localhost}");],
[#NormalTok("quarkus.log.handler.gelf.port=12201");],));
#block[
#callout(
body: 
[
Al usar #NormalTok("logging-gelf");, no se requiere la extensión #NormalTok("logging-json");. La consola mostrará logs en formato estándar (texto plano) y los eventos estructurados se enviarán por UDP a Graylog.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback)
<otras-aplicaciones-java-logback-3>
Para aplicaciones Java que no utilizan Quarkus, se puede enviar GELF mediante Logback con la librería #NormalTok("logback-gelf");.

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">de.siegmar</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logback-gelf</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">3.0.0</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
Configuración de #NormalTok("logback.xml");:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"GELF\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"de.siegmar.logbackgelf.GelfUdpAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("graylogHost");#NormalTok(">graylog</");#KeywordTok("graylogHost");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("graylogPort");#NormalTok(">12201</");#KeywordTok("graylogPort");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("maxChunkSize");#NormalTok(">508</");#KeywordTok("maxChunkSize");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("useCompression");#NormalTok(">true</");#KeywordTok("useCompression");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("layout");#NormalTok(" ");#OtherTok("class=");#StringTok("\"de.siegmar.logbackgelf.GelfLayout\"");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("originHost");#NormalTok(">mi_host</");#KeywordTok("originHost");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("includeRawMessage");#NormalTok(">false</");#KeywordTok("includeRawMessage");#NormalTok(">");],
[#NormalTok("      <");#KeywordTok("includeLevelName");#NormalTok(">true</");#KeywordTok("includeLevelName");#NormalTok(">");],
[#NormalTok("    </");#KeywordTok("layout");#NormalTok(">");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"GELF\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
== Visualización en Graylog
<visualización-en-graylog>
Acceda a Graylog en #NormalTok("http://localhost:9000"); con usuario #NormalTok("admin"); y contraseña #NormalTok("admin");.

Ruta sugerida:

#strong[Search → All messages]

Desde allí puede: - Filtrar por campos (#NormalTok("level");, #NormalTok("source");, #NormalTok("facility");). - Consultar con el lenguaje de búsqueda de Graylog (ej: #NormalTok("level:3"); para errores, #NormalTok("message:Exception");). - Crear streams y dashboards para análisis continuo.

== Actividades de profundización
<actividades-de-profundización-4>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); de la aplicación de ejemplo genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y utilice Graylog para localizar el evento de error, inspeccionando el stacktrace y los campos de origen.
- Comparar GELF UDP frente a envíos basados en TCP/JSON (en términos de confiabilidad y pérdida de mensajes).
- Evaluar el impacto de #strong[fragmentación] (#NormalTok("maxChunkSize");) en mensajes grandes con stacktraces extensos.
- Implementar múltiples productores de logs y distinguirlos por el campo #NormalTok("source");.
- Analizar consideraciones de seguridad (TLS, autenticación, control de acceso) para escenarios productivos.
- #strong[Hardening de credenciales (actividad de seguridad):] El #NormalTok("docker-compose.yml"); de esta guía contiene credenciales de laboratorio (#NormalTok("GRAYLOG_PASSWORD_SECRET: \"forpasswordencryption\"");, contraseña #NormalTok("admin");). Esto es un #strong[anti-patrón] para cualquier entorno que no sea exclusivamente local. Practique el ciclo correcto:
  + Genere un secreto seguro con #NormalTok("openssl rand -hex 32"); y reemplace el valor de #NormalTok("GRAYLOG_PASSWORD_SECRET");.
  + Calcule el hash SHA-256 de su nueva contraseña con #NormalTok("echo -n \"nuevaContraseña\" | sha256sum"); y reemplace #NormalTok("GRAYLOG_ROOT_PASSWORD_SHA2");.
  + Verifique que Graylog arranque correctamente con las nuevas credenciales.
  + Analice por qué estos valores #strong[nunca deben almacenarse en texto claro en un repositorio de código] y explore cómo Docker Compose soporta archivos #NormalTok(".env"); y secretos como alternativa.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-4>
+ GELF en esta guía utiliza transporte UDP (puerto 12201). Explique qué ocurre con los mensajes de log cuando la red experimenta congestión o pérdida de paquetes, y por qué este comportamiento puede ser aceptable o no según el contexto de uso.
+ La fragmentación de mensajes GELF (parámetro #NormalTok("maxChunkSize");) es necesaria cuando el payload supera el MTU de la red. Analice cómo un stacktrace de Java de 50 líneas podría afectar la entrega de mensajes GELF y qué estrategia de configuración mitigaría el riesgo de pérdida de fragmentos.
+ Compare la arquitectura de Graylog (con su propio journal, OpenSearch y MongoDB) frente al stack ELK: ¿qué ventajas ofrece Graylog al integrar en una sola plataforma la ingestión, el almacenamiento y la visualización, y qué complejidades operativas introduce el componente MongoDB?

== Troubleshooting
<troubleshooting-4>
#strong[Error común:] Graylog falla al iniciar con #NormalTok("PreflightCheckException: Journal directory has not enough free space");.

#strong[Explicación:] Graylog reserva por defecto #strong[5 GB] para el journal de mensajes. En entornos con Docker Desktop donde el disco del VM es limitado, esto puede fallar.

#strong[Solución:] El #NormalTok("docker-compose.yml"); de esta guía ya incluye #NormalTok("GRAYLOG_MESSAGE_JOURNAL_MAX_SIZE: \"512mb\""); para reducir la reserva. Si crea su propio compose, asegúrese de incluir esta variable.

#horizontalrule

#strong[Error común:] El contenedor #NormalTok("opensearch"); se detiene con #NormalTok("Exit 78"); / #NormalTok("Exit 137");.

#strong[Solución:] OpenSearch requiere configurar la memoria virtual del sistema anfitrión. En Linux o WSL:

#Skylighting(([#FunctionTok("sudo");#NormalTok(" sysctl ");#AttributeTok("-w");#NormalTok(" vm.max_map_count=262144");],));

#horizontalrule

#strong[Error común:] Los logs no aparecen en Graylog aunque la aplicación está corriendo.

#strong[Solución:] Verifique que el input GELF UDP haya sido creado (sección 6). Sin el input, Graylog descarta los paquetes UDP recibidos en el puerto 12201. Confirme su existencia en #strong[System → Inputs].

== Referencias
<referencias-4>
- Graylog -- https:\/\/graylog.org
- Graylog Docs (Docker) -- https:\/\/docs.graylog.org/docs/docker
- GELF Format -- https:\/\/go2docs.graylog.org/current/getting\_in\_log\_data/gelf.html
- Quarkus logging-gelf -- https:\/\/quarkus.io/guides/logging\#gelf-log-handler

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con OpenTelemetry (LGTM)
<sec-guia-otel>
#quote(block: true)[
#emph[Guía práctica para implementar una solución de centralización de logs utilizando Docker Compose y OpenTelemetry, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-5>
Implementar y validar una arquitectura de centralización de logs mediante #strong[Docker Compose], usando #strong[OpenTelemetry] para la recolección y exportación de logs vía el protocolo #strong[OTLP], y #strong[Grafana] (integrado en el stack #NormalTok("grafana/otel-lgtm");) como herramienta de exploración.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-6>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes del stack #NormalTok("grafana/otel-lgtm"); y el papel del OTel Collector.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica basada en OpenTelemetry.
- Configurar aplicaciones Quarkus para exportar logs mediante OTLP/gRPC.
- Configurar aplicaciones Java (Logback) para enviar logs usando el agente de OpenTelemetry.
- Explorar y correlacionar logs centralizados desde Grafana, aprovechando campos como #NormalTok("trace_id");, #NormalTok("span_id"); y #NormalTok("exception_stacktrace");.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Grafana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-5>
El propósito principal de este recurso es guiar el despliegue y uso de una #strong[arquitectura de centralización de logs] basada en el estándar OpenTelemetry, en un entorno local y reproducible mediante Docker Compose.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, centralización y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra cómo OpenTelemetry enriquece automáticamente los logs con atributos de trazabilidad (#NormalTok("trace_id");, #NormalTok("span_id");), contexto de código (#NormalTok("code_namespace");, #NormalTok("code_function");, #NormalTok("code_lineno");) y excepciones estructuradas (#NormalTok("exception_stacktrace");, #NormalTok("exception_message");).

El alcance del recurso se limita a la #strong[centralización y visualización de logs]. El stack LGTM también soporta métricas y trazas distribuidas, lo cual sienta bases para integraciones futuras.

== Observabilidad y centralización de logs con OpenTelemetry
<observabilidad-y-centralización-de-logs-con-opentelemetry>
En arquitecturas basadas en microservicios, la observabilidad permite comprender el comportamiento interno del sistema a partir de señales externas. Los #strong[logs] constituyen una fuente primaria de información debido a su riqueza semántica y contextual.

Todas las guías anteriores resolvían la observabilidad con herramientas concretas, cada una con su propio formato y su propio protocolo. Esto plantea un problema de fondo: si mañana quieres cambiar de herramienta de almacenamiento, tendrías que reinstrumentar tus aplicaciones. OpenTelemetry (OTel) nace precisamente para romper ese acoplamiento.

=== OpenTelemetry: el estándar que desacopla la instrumentación del backend
<opentelemetry-el-estándar-que-desacopla-la-instrumentación-del-backend>
OpenTelemetry no es una herramienta de almacenamiento ni un visualizador: es un #strong[estándar abierto y neutral respecto al proveedor] (#emph[vendor-neutral]). Define un conjunto de APIs, SDKs y herramientas para capturar y exportar las señales de observabilidad (#strong[logs, métricas y trazas], los tres pilares descritos en #ref(<sec-5-1>, supplement: [Sección]) del marco conceptual) y transmitirlas mediante un protocolo común, el #strong[OTLP (OpenTelemetry Protocol)].

¿Por qué es esto importante? Porque separa dos responsabilidades que antes estaban entrelazadas:

- #emph[cómo se instrumenta] una aplicación (responsabilidad de OTel, una sola vez);
- #emph[a dónde se envían] los datos (un simple detalle de configuración del backend).

Instrumentas una vez con OpenTelemetry y puedes cambiar de backend de almacenamiento sin tocar el código de tus servicios. Es el mismo principio de neutralidad tecnológica que defiende el marco conceptual de este recurso, llevado al plano de la instrumentación.

Una ventaja concreta de este enfoque es la #strong[correlación automática] entre señales: los logs generados durante una petición HTTP llevan automáticamente el #NormalTok("trace_id"); y el #NormalTok("span_id"); de la traza activa, lo que permite navegar desde un log hacia la traza distribuida correspondiente y viceversa. Recordarás del marco conceptual (#ref(<sec-5-3>, supplement: [Sección])) que la correlación de eventos era uno de los grandes problemas de la dispersión; OpenTelemetry lo resuelve de raíz, propagando el contexto de traza de forma transparente.

== Requisitos previos
<requisitos-previos-5>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-5>
El stack tiene un #strong[consumo estimado de \~3 GB de RAM en estado estable]. Para evitar que un contenedor agote la memoria del host, cada servicio define un límite explícito mediante #NormalTok("mem_limit");:

#figure([
#table(
  columns: (16.95%, 40.68%, 42.37%),
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("otel-lgtm");], [Imagen todo-en-uno: OTel Collector + Loki + Prometheus + Tempo + Grafana], [#NormalTok("2g");],
  [#NormalTok("logs.producer");], [Aplicación Quarkus que genera y exporta logs vía OTLP], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack LGTM, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-otel-1>


Estos límites son #strong[parametrizables mediante un archivo #NormalTok(".env");] ubicado junto al #NormalTok("docker-compose.yml");, lo que permite ajustarlos según los recursos disponibles del host:

#Skylighting(([#VariableTok("OTEL_LGTM_MEM_LIMIT");#OperatorTok("=");#NormalTok("2g");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
== Estructura del proyecto
<estructura-del-proyecto-5>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("└──");#NormalTok(" logs.producer/");],
[#NormalTok("    ");#ExtensionTok("├──");#NormalTok(" src/");],
[#NormalTok("    ");#ExtensionTok("└──");#NormalTok(" pom.xml");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-5>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("          |");],
[#NormalTok("          |  OTLP (gRPC :4317)");],
[#NormalTok("          v");],
[#NormalTok("[OTel Collector — grafana/otel-lgtm:0.27.1]");],
[#NormalTok("          |");],
[#NormalTok("     _____|_______________________________");],
[#NormalTok("     |            |           |          |");],
[#NormalTok("     v            v           v          v");],
[#NormalTok("  [Loki]    [Prometheus]  [Tempo]  [Grafana :3000]");],
[#NormalTok("(logs)       (métricas)   (trazas) (visualización)");],));
La arquitectura implementada se fundamenta en:

- #strong[OpenTelemetry Collector]: recibe señales de observabilidad vía OTLP (gRPC puerto 4317 / HTTP puerto 4318) y las distribuye a los backends correspondientes.
- #strong[Loki]: almacena los logs indexando solo etiquetas (labels). Los atributos OTel (#NormalTok("service_name");, #NormalTok("severity_text");, #NormalTok("trace_id");, etc.) se convierten en labels.
- #strong[Prometheus]: almacena métricas.
- #strong[Tempo]: almacena trazas distribuidas.
- #strong[Grafana]: capa de visualización unificada para las tres señales.
- #strong[#NormalTok("grafana/otel-lgtm");]: imagen todo-en-uno que empaqueta el Collector y el stack LGTM completo, pensada para entornos de desarrollo y laboratorio.

== Implementación de la arquitectura conceptual con OpenTelemetry
<implementación-de-la-arquitectura-conceptual-con-opentelemetry>
=== docker-compose.yml
<docker-compose.yml-5>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("OTEL_HOST");#KeywordTok(":");#AttributeTok(" otel-lgtm");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("otel-lgtm");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("otel-lgtm");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/otel-lgtm:0.27.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" otel-lgtm");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${OTEL_LGTM_MEM_LIMIT:-2g}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3000:3000\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3100:3100\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4317:4317\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4318:4318\"");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"test -f /tmp/ready || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 3s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("20");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 15s");],));
#block[
#callout(
body: 
[
#strong[El healthcheck:] La imagen #NormalTok("grafana/otel-lgtm"); no incluye #NormalTok("curl"); ni #NormalTok("wget");. Internamente crea el archivo #NormalTok("/tmp/ready"); cuando todos sus servicios están listos. El healthcheck verifica ese archivo.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Despliegue y validación
<despliegue-y-validación-5>
=== Inicialización de los servicios
<inicialización-de-los-servicios-4>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios-4>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
Salida esperada (referencial):

#Skylighting(([#NormalTok("NAME                      STATUS");],
[#NormalTok("otel-lgtm                 Up (healthy)");],
[#NormalTok("logs.producer-1           Up");],));
== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-5>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-5>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], utilizando la extensión #NormalTok("quarkus-opentelemetry"); que exporta logs directamente al OTel Collector mediante #strong[OTLP/gRPC].

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,opentelemetry' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados al OTel Collector. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.application.name=logs-producer");],
[],
[#NormalTok("# OpenTelemetry: exportar logs via OTLP gRPC");],
[#NormalTok("quarkus.otel.logs.enabled=true");],
[#NormalTok("# OTEL_HOST defaults to localhost (dev/IDE); docker compose overrides to \"otel-lgtm\"");],
[#NormalTok("quarkus.otel.exporter.otlp.endpoint=http://${OTEL_HOST:localhost}:4317");],));
#block[
#callout(
body: 
[
La propiedad #NormalTok("quarkus.otel.exporter.otlp.endpoint"); configura el endpoint para todas las señales (logs, métricas, trazas). Al habilitar #NormalTok("quarkus.otel.logs.enabled=true");, los logs del JBoss LogManager son interceptados y exportados vía OTLP. No se requiere ninguna otra extensión de logging.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (agente OpenTelemetry)
<otras-aplicaciones-java-agente-opentelemetry>
Para aplicaciones Java que no utilizan Quarkus, la forma más simple de integrar OpenTelemetry es mediante el #strong[agente de instrumentación automática], que intercepta los logs de Logback/Log4j2 sin modificar el código:

#Skylighting(([#CommentTok("# Descargar el agente");],
[#ExtensionTok("curl");#NormalTok(" ");#AttributeTok("-L");#NormalTok(" https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-o");#NormalTok(" opentelemetry-javaagent.jar");],
[],
[#CommentTok("# Ejecutar la aplicación con el agente");],
[#ExtensionTok("java");#NormalTok(" ");#AttributeTok("-javaagent:opentelemetry-javaagent.jar");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-Dotel.service.name");#OperatorTok("=");#NormalTok("mi-servicio ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-Dotel.exporter.otlp.endpoint");#OperatorTok("=");#NormalTok("http://localhost:4317 ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-Dotel.logs.exporter");#OperatorTok("=");#NormalTok("otlp ");#DataTypeTok("\\");],
[#NormalTok("     ");#AttributeTok("-jar");#NormalTok(" myapp.jar");],));
#quote(block: true)[
El agente intercepta automáticamente Logback, Log4j2, JUL y JBoss Logging, sin necesidad de modificar #NormalTok("logback.xml"); ni el código de la aplicación.
]

== Visualización en Grafana
<visualización-en-grafana-1>
Acceda a Grafana en #NormalTok("http://localhost:3000"); con usuario #NormalTok("admin"); y contraseña #NormalTok("admin");.

=== Ruta sugerida para logs
<ruta-sugerida-para-logs>
#strong[Drilldown → Logs]

Desde allí puede filtrar por #NormalTok("service_name");, nivel (#NormalTok("severity_text");) y buscar por contenido.

=== Consultas LogQL de ejemplo
<consultas-logql-de-ejemplo>
Todos los logs del servicio:

#Skylighting(([#NormalTok("{service_name=\"logs-producer\"}");],));
Filtrar solo errores:

#Skylighting(([#NormalTok("{service_name=\"logs-producer\", severity_text=\"ERROR\"}");],));
Buscar excepciones por contenido:

#Skylighting(([#NormalTok("{service_name=\"logs-producer\"} |= \"NullPointerException\"");],));
Ver mensajes formateados:

#Skylighting(([#NormalTok("{service_name=\"logs-producer\"} | logfmt");],));
=== La Trinidad de la Observabilidad en Acción (Correlación Cruzada)
<la-trinidad-de-la-observabilidad-en-acción-correlación-cruzada>
El protocolo #strong[OTLP (OpenTelemetry Protocol)] permite unificar el envío de logs, métricas y trazas distribuidas. En Grafana, esto habilita el flujo de diagnóstico definitivo: la #strong[correlación cruzada].

Usted puede rastrear un problema en caliente cruzando las tres señales de la siguiente manera:

#figure([
#block[
#box(image("guias/06-otel_files/figure-typst/mermaid-figure-1.png", height: 3.65in, width: 4.68in))

]
], caption: figure.caption(
position: bottom, 
[
Correlación de las tres señales de observabilidad para el diagnóstico de un problema.
]), 
kind: "quarto-float-fig", 
supplement: "Figura", 
)
<fig-otel-correlacion-senales>


==== Paso 1: Detección a través de logs (Loki)
<paso-1-detección-a-través-de-logs-loki>
+ Ingrese a #strong[Explore] en Grafana (#NormalTok("http://localhost:3000");) y seleccione el datasource #strong[Loki].
+ Ejecute la consulta LogQL #NormalTok("{service_name=\"logs-producer\", severity_text=\"ERROR\"}");.
+ Localice el log de error generado por el NPE al llamar a #NormalTok("GET http://localhost:8080/api/error");.
+ Al hacer clic sobre la línea del log para expandir sus metadatos estructurados, observará que OpenTelemetry inyectó automáticamente los campos #NormalTok("trace_id"); y #NormalTok("span_id"); en el contexto.

==== Paso 2: Navegación contextual a la traza (Tempo)
<paso-2-navegación-contextual-a-la-traza-tempo>
+ En el desglose del log expandido, Grafana reconocerá el valor del campo #NormalTok("trace_id"); y presentará un botón interactivo llamado #strong[#NormalTok("Tempo");] al lado del hash.
+ Al hacer clic en este botón, la pantalla se dividirá en dos (#emph[Split View]):
  - #strong[Panel Izquierdo]: El log de Loki detallando la excepción #NormalTok("NullPointerException");.
  - #strong[Panel Derecho]: La representación visual del ciclo de vida de la petición HTTP en #strong[Tempo] correspondiente a ese #NormalTok("trace_id"); exacto.
+ En el panel derecho de Tempo podrá observar de forma gráfica:
  - El #emph[span] raíz de la petición (#NormalTok("GET /api/error");).
  - El #emph[span] interno del microservicio Quarkus.
  - La duración exacta de la llamada en milisegundos y el estado de error (marcado en rojo).
  - Al expandir el span de la traza, verá los logs y los eventos de excepción incrustados en la línea de tiempo exacta donde ocurrieron.

==== Paso 3: Correlación temporal con el comportamiento del sistema (Prometheus)
<paso-3-correlación-temporal-con-el-comportamiento-del-sistema-prometheus>
+ La observabilidad unificada cobra verdadero sentido cuando cruzamos esta latencia o error con el rendimiento físico del hardware.
+ Desde la misma interfaz Explore de Grafana, configure un tercer panel con el datasource #strong[Prometheus].
+ Ingrese las siguientes consultas PromQL sobre la misma ventana de tiempo del incidente:
  - #strong[Tasa de errores por segundo]:

    #Skylighting(([#NormalTok("sum(rate(http_server_duration_milliseconds_count{status=~\"5..\"}[1m])) by (uri)");],));

  - #strong[Uso de CPU del proceso]:

    #Skylighting(([#NormalTok("process_cpu_usage{service_name=\"logs-producer\"}");],));

  - #strong[Consumo de Memoria Heap de la JVM]:

    #Skylighting(([#NormalTok("jvm_memory_used_bytes{area=\"heap\", service_name=\"logs-producer\"}");],));
+ Observe la coincidencia exacta: el pico en la gráfica de errores HTTP en Prometheus se alinea perfectamente a nivel de segundo con el timestamp del log en Loki y la duración anómala registrada en Tempo.

Este nivel de integración elimina la necesidad de adivinar qué causó un pico de CPU o qué petición provocó una fuga de memoria, materializando de forma práctica la arquitectura de observabilidad conceptual del laboratorio.

== Actividades de profundización
<actividades-de-profundización-5>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y localice en Grafana el evento de error. Observe el campo #NormalTok("exception_stacktrace"); exportado como atributo estructurado, así como el #NormalTok("trace_id"); que correlaciona el log con la traza HTTP.
- Comparar la riqueza semántica de los logs OTel (con #NormalTok("trace_id");, #NormalTok("span_id");, #NormalTok("code_namespace");) frente a los enfoques basados en texto plano o GELF.
- Explorar las métricas exportadas automáticamente por Quarkus (JVM, HTTP requests) en la sección de #strong[Prometheus] de Grafana.
- Desplegar dos instancias de #NormalTok("logs.producer"); con distintos #NormalTok("quarkus.application.name"); y distinguirlas por #NormalTok("service_name"); en LogQL.
- Analizar la diferencia entre #NormalTok("severity_text"); (nivel semántico OTel) y el nivel de log tradicional de Java.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-5>
+ OpenTelemetry enriquece automáticamente los logs con #NormalTok("trace_id"); y #NormalTok("span_id"); cuando se generan dentro de una petición HTTP activa. Explique el mecanismo por el cual Quarkus propaga este contexto de traza al logger sin que el desarrollador lo haga explícitamente.
+ La imagen #NormalTok("grafana/otel-lgtm"); empaqueta en un solo contenedor el OTel Collector, Loki, Prometheus, Tempo y Grafana. Analice las ventajas y limitaciones de esta decisión de diseño para entornos de laboratorio frente a un despliegue de componentes separados como en la guía PLG.
+ Evalúe la diferencia arquitectónica entre exportar logs mediante OTLP/gRPC (esta guía) y los enfoques basados en TCP JSON (ELK/OLO/Vector) o file tailing (PLG): ¿qué pilares de la observabilidad se habilitan o quedan incompletos con cada enfoque?

== Troubleshooting
<troubleshooting-5>
#strong[El contenedor #NormalTok("otel-lgtm"); queda en estado #NormalTok("unhealthy");.]

#strong[Explicación:] La imagen no incluye #NormalTok("curl"); ni #NormalTok("wget");, por lo que los healthchecks basados en HTTP fallan. El healthcheck correcto usa el archivo #NormalTok("/tmp/ready"); que el contenedor crea internamente cuando todos sus componentes están listos.

#strong[Solución:] Asegúrese de que el healthcheck en #NormalTok("docker-compose.yml"); sea:

#Skylighting(([#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"test -f /tmp/ready || exit 1\"");#KeywordTok("]");],));

#horizontalrule

#strong[Los logs no aparecen en Grafana aunque la aplicación está corriendo.]

#strong[Solución:] \
\1. Verifique que #NormalTok("quarkus.otel.logs.enabled=true"); esté en #NormalTok("application.properties");. \
\2. Asegúrese de que el endpoint OTLP apunte al host correcto (#NormalTok("otel-lgtm"); dentro de Docker Compose, #NormalTok("localhost"); en IDE). \
\3. Revise los logs de la aplicación: si hay errores de conexión al exportador OTLP, aparecerán en la consola (pero con delay por el backoff de reintentos).

#horizontalrule

#strong[La aplicación falla al iniciar con #NormalTok("Unable to export logs");.]

#strong[Solución:] Si #NormalTok("logs.producer"); arranca antes de que #NormalTok("otel-lgtm"); esté listo, el exportador OTLP intentará reconectarse automáticamente. El #NormalTok("depends_on"); con #NormalTok("condition: service_healthy"); previene este escenario garantizando que #NormalTok("otel-lgtm"); esté completamente listo antes de iniciar la aplicación.

== Referencias
<referencias-5>
- OpenTelemetry -- https:\/\/opentelemetry.io/docs/
- Grafana otel-lgtm -- https:\/\/github.com/grafana/docker-otel-lgtm
- Quarkus OpenTelemetry -- https:\/\/quarkus.io/guides/opentelemetry
- LogQL -- https:\/\/grafana.com/docs/loki/latest/query/
- OTel Java Instrumentation Agent -- https:\/\/opentelemetry.io/docs/zero-code/java/agent/

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Pipeline de Observabilidad con Vector, Loki y Grafana
<sec-guia-vector>
#quote(block: true)[
#emph[Guía práctica para implementar una solución de centralización de logs de alto rendimiento utilizando Vector como enrutador y transformador, conectado a Loki y Grafana, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-6>
Implementar y validar una arquitectura moderna de enrutamiento y centralización de logs mediante #strong[Docker Compose], usando #strong[Vector] (escrito en Rust) como recolector y transformador ligero, #strong[Loki] para el almacenamiento eficiente por etiquetas, y #strong[Grafana] para la exploración y análisis.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-7>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes de un pipeline de observabilidad basado en Vector, Loki y Grafana.
- Relacionar conceptos teóricos de observabilidad con una implementación práctica de alto rendimiento.
- Configurar Vector con el modelo #emph[Source → Transform → Sink] y el lenguaje #strong[VRL] (Vector Remap Language).
- Configurar aplicaciones Java para emitir logs estructurados en JSON vía TCP hacia Vector.
- Explorar y consultar logs centralizados desde Grafana usando #strong[LogQL].
- Comparar el enfoque Vector frente a alternativas como Logstash o Fluentd en términos de rendimiento y consumo de recursos.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Grafana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-6>
Esta guía representa el estado del arte en enrutamiento y procesamiento de telemetría. #strong[Vector] está diseñado para ser significativamente más eficiente que alternativas basadas en JVM (Logstash) o Ruby (Fluentd), al ser un ejecutable nativo compilado en Rust.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software, microservicios, DevOps y observabilidad.
- Un #strong[entorno de laboratorio reproducible], que permite experimentar con flujos reales de generación, transformación y análisis de logs.
- Un #strong[caso de estudio técnico], que ilustra el modelo de pipeline declarativo de Vector y el lenguaje VRL para la transformación de eventos.

El alcance del recurso se limita a la centralización y visualización de logs vía TCP JSON. Vector soporta docenas de fuentes y destinos adicionales (archivos, Docker, Kafka, S3, Elasticsearch, etc.).

== Observabilidad y rendimiento con Vector
<observabilidad-y-rendimiento-con-vector>
En arquitecturas donde el volumen de logs es masivo, el componente de recolección y procesamiento puede convertirse en el cuello de botella. #strong[Vector] soluciona esto al ser un ejecutable nativo (Rust) que:

- Consume una fracción de los recursos de CPU y RAM frente a Logstash o Fluentd.
- Permite transformar eventos #strong[en memoria] sin necesidad de plugins externos ni dependencias de runtime.
- Soporta múltiples fuentes (#emph[sources]) y destinos (#emph[sinks]) mediante un modelo de pipeline declarativo.
- Incluye #strong[VRL (Vector Remap Language)], un lenguaje de transformación seguro y tipado, específicamente diseñado para manipular eventos de observabilidad.

=== Vector y la etapa de procesamiento
<vector-y-la-etapa-de-procesamiento>
Conviene situar a Vector dentro de la arquitectura conceptual (marco conceptual, #ref(<sec-5-7>, supplement: [Sección])). Vector se concentra en las etapas de #strong[recolección y procesamiento], y su modelo #emph[source → transform → sink] es una materialización casi literal del pipeline de procesamiento descrito en el marco conceptual (#ref(<sec-5-7-2>, supplement: [Sección])):

- #strong[Source] (fuente): de dónde llegan los eventos (TCP, archivos, etc.).
- #strong[Transform] (transformación): donde se filtra, normaliza, enriquece y (de forma destacada) se #strong[sanitiza] la información sensible (marco conceptual, #ref(<sec-5-6>, supplement: [Sección])), todo mediante VRL.
- #strong[Sink] (destino): hacia dónde se envían los eventos ya procesados.

¿Por qué importa que Vector esté escrito en Rust? Porque el lenguaje le permite procesar eventos en memoria, sin un #emph[runtime] pesado (como la JVM de Logstash) ni el costo de plugins externos. En escenarios de alto volumen, donde el recolector puede convertirse en el cuello de botella (marco conceptual, #ref(<sec-5-7-1>, supplement: [Sección])), esta eficiencia deja de ser un detalle y pasa a ser un criterio de diseño decisivo.

Observa, además, que Vector puede desplegarse en dos roles: como #strong[agente] (#emph[agent]) junto a cada servicio, o como #strong[agregador] (#emph[aggregator]) centralizado que recibe de muchos agentes. Esta flexibilidad conecta directamente con los patrones de recolección (agente, #emph[sidecar]) discutidos en el marco conceptual (#ref(<sec-5-4>, supplement: [Sección])).

== Requisitos previos
<requisitos-previos-6>
- Docker instalado \
  https:\/\/docs.docker.com/engine/install/
- Docker Compose \
  https:\/\/docs.docker.com/compose/install/
- Al menos #strong[8 GB de RAM] libres (Vector es muy ligero; Loki y Grafana son los principales consumidores)

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-6>
#strong[Consumo estimado del stack:] \~2.5 GB de RAM en estado estable. Se trata de un stack ligero, apto para equipos con 4 GB de RAM.

Cada servicio declara un #NormalTok("mem_limit"); que acota su consumo máximo de memoria:

#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [Vector], [Recolección y transformación de eventos (Rust)], [512m],
  [Loki], [Almacenamiento e indexación por etiquetas], [512m],
  [Grafana], [Visualización y exploración (LogQL)], [512m],
  [logs.producer (Quarkus)], [Aplicación productora de logs], [512m],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack Vector, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-vector-1>


Los límites son parametrizables vía variables de entorno definidas en el archivo #NormalTok(".env"); (junto al #NormalTok("docker-compose.yml");):

#Skylighting(([#VariableTok("VECTOR_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("LOKI_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("GRAFANA_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
== Estructura del proyecto
<estructura-del-proyecto-6>
#Skylighting(([#ExtensionTok("logs-centralizados/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("├──");#NormalTok(" vector/");],
[#ExtensionTok("│");#NormalTok("   └── vector.toml");],
[#ExtensionTok("└──");#NormalTok(" grafana/");],
[#NormalTok("    ");#ExtensionTok("└──");#NormalTok(" provisioning/");],
[#NormalTok("        ");#ExtensionTok("└──");#NormalTok(" datasources/");],
[#NormalTok("            ");#ExtensionTok("└──");#NormalTok(" loki.yaml");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-6>
#Skylighting(([#NormalTok("[Aplicaciones Java / Quarkus]");],
[#NormalTok("         |");],
[#NormalTok("     (TCP JSON :4560)");],
[#NormalTok("         v");],
[#NormalTok("      [Vector 0.55]");],
[#NormalTok("      Source → Transform (VRL) → Sink");],
[#NormalTok("         |");],
[#NormalTok("     (HTTP API push)");],
[#NormalTok("         v");],
[#NormalTok("       [Loki 3.0] ──→ [Grafana 13.0]");],));
La arquitectura implementada se fundamenta en cuatro componentes:

- #strong[Vector]: recolector y transformador de logs. Recibe eventos JSON vía TCP, aplica transformaciones con VRL y los envía a Loki.
- #strong[VRL (Vector Remap Language)]: lenguaje declarativo para manipular eventos dentro del pipeline (extracción de campos, enriquecimiento, censura de datos).
- #strong[Loki]: motor de almacenamiento ligero que indexa solo etiquetas (#emph[labels]), no el contenido textual.
- #strong[Grafana]: capa de visualización y exploración mediante #strong[LogQL].

== Implementación de la arquitectura conceptual
<implementación-de-la-arquitectura-conceptual-1>
=== docker-compose.yml
<docker-compose.yml-6>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("VECTOR_HOST");#KeywordTok(":");#AttributeTok(" vector");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("vector");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("vector");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" timberio/vector:0.55.0-alpine");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" vector");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${VECTOR_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"--config\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"/etc/vector/vector.toml\"");#KeywordTok("]");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./vector/vector.toml");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /etc/vector/vector.toml");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"4560:4560\"");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8686:8686\"");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"wget -q -O /dev/null http://127.0.0.1:8686/health || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 3s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("10");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/loki:3.0.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" loki");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${LOKI_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3100:3100\"");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");#AttributeTok(" -config.file=/etc/loki/local-config.yaml");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"wget -q --spider http://localhost:3100/ready || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 15s");],
[],
[#AttributeTok("  ");#FunctionTok("grafana");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/grafana:13.0.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" grafana");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${GRAFANA_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ENABLED=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ORG_ROLE=Admin");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_DISABLE_LOGIN_FORM=true");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3000:3000\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /etc/grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],));
#block[
#callout(
body: 
[
#strong[El comando de Vector:] La imagen #NormalTok("timberio/vector"); carga por defecto #NormalTok("/etc/vector/vector.yaml");. Al usar un archivo #NormalTok(".toml");, es necesario especificarlo explícitamente con #NormalTok("command: [\"--config\", \"/etc/vector/vector.toml\"]");.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#strong[El healthcheck de Vector:] La imagen Alpine de Vector usa busybox #NormalTok("wget");, que no soporta la opción #NormalTok("--spider");. Se usa #NormalTok("-O /dev/null"); en su lugar. Además, se usa #NormalTok("127.0.0.1"); en vez de #NormalTok("localhost"); para evitar inconsistencias con la resolución de la interfaz de loopback en busybox.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Configuración del pipeline Vector (#NormalTok("vector/vector.toml");)
<configuración-del-pipeline-vector-vectorvector.toml>
#Skylighting(([#CommentTok("# Habilita la API interna de Vector (requerida para el healthcheck)");],
[#KeywordTok("[api]");],
[#DataTypeTok("enabled");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#ConstantTok("true");],
[#DataTypeTok("address");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"0.0.0.0:8686\"");],
[],
[#CommentTok("# 1. ORIGEN: recibe logs JSON delimitados por newline via TCP");],
[#KeywordTok("[sources.java_app]");],
[#DataTypeTok("type");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"socket\"");],
[#DataTypeTok("address");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"0.0.0.0:4560\"");],
[#DataTypeTok("mode");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"tcp\"");],
[#DataTypeTok("framing.method");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"newline_delimited\"");],
[#DataTypeTok("decoding.codec");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"json\"");],
[],
[#CommentTok("# 2. TRANSFORMACIÓN: extrae el nivel de log desde la clave plana \"log.level\" (formato ECS)");],
[#KeywordTok("[transforms.enrich]");],
[#DataTypeTok("type");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"remap\"");],
[#DataTypeTok("inputs");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"java_app\"");#OperatorTok("]");],
[#DataTypeTok("source");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("'''");],
[#VerbatimStringTok(".level = .\"log.level\" || \"unknown\"");],
[#StringTok("'''");],
[],
[#CommentTok("# 3. DESTINO: envía los eventos enriquecidos a Loki");],
[#KeywordTok("[sinks.loki_out]");],
[#DataTypeTok("type");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"loki\"");],
[#DataTypeTok("inputs");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"enrich\"");#OperatorTok("]");],
[#DataTypeTok("endpoint");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"http://loki:3100\"");],
[#DataTypeTok("encoding.codec");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"json\"");],
[],
[#NormalTok("  ");#KeywordTok("[sinks.loki_out.labels]");],
[#NormalTok("  ");#DataTypeTok("job");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"vector_app_logs\"");],
[#NormalTok("  ");#DataTypeTok("level");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"{{ level }}\"");],));
#block[
#callout(
body: 
[
#strong[VRL y claves con punto:] En el formato ECS, el nivel de log se serializa como la clave plana #NormalTok("\"log.level\""); (no como objeto anidado). En VRL, para acceder a esta clave sin que sea interpretada como ruta anidada, se usa la sintaxis #NormalTok(".\"log.level\""); (entre comillas). El operador #NormalTok("||"); realiza null-coalescing: si el campo no existe o es nulo, usa el valor por defecto #NormalTok("\"unknown\"");. No se usa el operador #NormalTok("??"); (que es para error-coalescing, no para null).

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Aprovisionamiento de Grafana (#NormalTok("grafana/provisioning/datasources/loki.yaml");)
<aprovisionamiento-de-grafana-grafanaprovisioningdatasourcesloki.yaml-1>
#Skylighting(([#FunctionTok("apiVersion");#KeywordTok(":");#AttributeTok(" ");#DecValTok("1");],
[],
[#FunctionTok("datasources");#KeywordTok(":");],
[#AttributeTok("  ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("name");#KeywordTok(":");#AttributeTok(" Loki");],
[#AttributeTok("    ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" loki");],
[#AttributeTok("    ");#FunctionTok("access");#KeywordTok(":");#AttributeTok(" proxy");],
[#AttributeTok("    ");#FunctionTok("url");#KeywordTok(":");#AttributeTok(" http://loki:3100");],
[#AttributeTok("    ");#FunctionTok("isDefault");#KeywordTok(":");#AttributeTok(" ");#CharTok("true");],));
== Despliegue y validación
<despliegue-y-validación-6>
=== Inicialización de los servicios
<inicialización-de-los-servicios-5>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");],));
=== Validación de los servicios
<validación-de-los-servicios-5>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
Salida esperada (referencial):

#Skylighting(([#NormalTok("NAME                STATUS");],
[#NormalTok("loki                Up (healthy)");],
[#NormalTok("vector              Up (healthy)");],
[#NormalTok("grafana             Up");],
[#NormalTok("logs.producer-1     Up");],));
== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-6>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-6>
El recurso contempla un ejemplo de integración con aplicaciones desarrolladas en #strong[Quarkus], usando el socket handler JSON para enviar logs estructurados directamente al socket TCP de Vector.

- En caso de no tener una aplicación puede crear con el siguiente comando.

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
- Configure su aplicación para que los logs sean enviados a Vector. (#strong[#NormalTok("application.properties");])

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[],
[#NormalTok("# Enviar logs estructurados en JSON via TCP a Vector");],
[#NormalTok("quarkus.log.socket.enable=true");],
[#NormalTok("quarkus.log.socket.json=true");],
[#NormalTok("# VECTOR_HOST defaults to localhost (dev/IDE); docker compose overrides to \"vector\"");],
[#NormalTok("quarkus.log.socket.endpoint=${VECTOR_HOST:localhost}:4560");],
[#NormalTok("quarkus.log.socket.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.socket.json.log-format=ECS");],));
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
=== Otras aplicaciones Java (Logback)
<otras-aplicaciones-java-logback-4>
Para aplicaciones Java que no utilizan Quarkus, se puede usar el #NormalTok("LogstashTcpSocketAppender");, 100% compatible con la entrada TCP de Vector.

#Skylighting(([#NormalTok("<");#KeywordTok("dependency");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("groupId");#NormalTok(">net.logstash.logback</");#KeywordTok("groupId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("artifactId");#NormalTok(">logstash-logback-encoder</");#KeywordTok("artifactId");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("version");#NormalTok(">8.1</");#KeywordTok("version");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("dependency");#NormalTok(">");],));
#NormalTok("logback.xml");:

#Skylighting(([#NormalTok("<");#KeywordTok("configuration");#NormalTok(">");],
[#NormalTok("  <");#KeywordTok("appender");#NormalTok(" ");#OtherTok("name=");#StringTok("\"VECTOR\"");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.appender.LogstashTcpSocketAppender\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("destination");#NormalTok(">vector:4560</");#KeywordTok("destination");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("encoder");#NormalTok(" ");#OtherTok("class=");#StringTok("\"net.logstash.logback.encoder.LogstashEncoder\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("appender");#NormalTok(">");],
[],
[#NormalTok("  <");#KeywordTok("root");#NormalTok(" ");#OtherTok("level=");#StringTok("\"INFO\"");#NormalTok(">");],
[#NormalTok("    <");#KeywordTok("appender-ref");#NormalTok(" ");#OtherTok("ref=");#StringTok("\"VECTOR\"");#NormalTok(" />");],
[#NormalTok("  </");#KeywordTok("root");#NormalTok(">");],
[#NormalTok("</");#KeywordTok("configuration");#NormalTok(">");],));
== Visualización en Grafana
<visualización-en-grafana-2>
Acceda a Grafana en #NormalTok("http://localhost:3000");. La fuente de datos Loki ya está preconfigurada.

Navegue a #strong[Explore] y seleccione #strong[Loki] como fuente de datos.

#strong[Consultas LogQL de ejemplo:]

Todos los logs del pipeline Vector:

#Skylighting(([#NormalTok("{job=\"vector_app_logs\"}");],));
Filtrar por nivel:

#Skylighting(([#NormalTok("{job=\"vector_app_logs\", level=\"ERROR\"}");],));
Buscar excepciones por contenido:

#Skylighting(([#NormalTok("{job=\"vector_app_logs\"} |= \"NullPointerException\"");],));
Analizar los campos ECS y mostrar solo el mensaje:

#Skylighting(([#NormalTok("{job=\"vector_app_logs\"} | json | line_format \"{{.message}}\"");],));
== Actividades de profundización
<actividades-de-profundización-6>
- #strong[Simular fallos y rastrear su origen:] El endpoint #NormalTok("GET /api/error"); genera intencionalmente una #NormalTok("NullPointerException");. Ejecútelo y use la consulta #NormalTok("{job=\"vector_app_logs\"} |= \"NullPointerException\""); en Grafana para localizarlo.
- #strong[Enriquecimiento con VRL:] Modifique la sección #NormalTok("[transforms.enrich]"); en #NormalTok("vector.toml"); para agregar un campo estático al evento (ej. #NormalTok(".environment = \"dev\"");). Verifique que el campo aparece en los logs de Loki.
- #strong[Censura de datos sensibles:] Añada una transformación VRL que elimine un campo del evento antes de enviarlo a Loki (ej. #NormalTok("del(.\"process.thread.name\")");).
- #strong[Múltiples destinos:] Configure un segundo sink en #NormalTok("vector.toml"); que además de Loki escriba los eventos en un archivo local (type = "file"). Esto ilustra el enrutamiento a múltiples backends simultáneamente.
- #strong[Comparar recursos:] Ejecute #NormalTok("docker stats"); con el stack Vector activo y compare el consumo de memoria del contenedor #NormalTok("vector"); frente al de #NormalTok("fluentd"); o #NormalTok("logstash"); en las guías anteriores.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-6>
+ En el pipeline de Vector de esta guía, la transformación VRL accede al campo #NormalTok("\"log.level\""); con la sintaxis #NormalTok(".\"log.level\""); (entre comillas). Explique por qué es necesaria esa sintaxis y qué diferencia introduce respecto a acceder a un campo ordinario como #NormalTok(".message");.
+ El modelo de pipeline de Vector (Source → Transform → Sink) es declarativo y tipado. Analice cómo este diseño facilita o dificulta la implementación de enrutamiento condicional (enviar logs de nivel ERROR a un destino distinto que los de nivel INFO) en comparación con el modelo de Fluentd o Logstash.
+ Vector está implementado en Rust y opera sin JVM ni runtime de Ruby. Evalúe en qué escenarios de producción esta diferencia de implementación justifica migrar desde Logstash o Fluentd, y en cuáles el ecosistema de plugins de esas herramientas sería un factor determinante para no hacerlo.

== Troubleshooting
<troubleshooting-6>
#strong[Error común:] Vector no arranca y reporta #NormalTok("no such file or directory: /etc/vector/vector.yaml");.

#strong[Solución:] La imagen #NormalTok("timberio/vector"); busca #NormalTok("/etc/vector/vector.yaml"); por defecto. Asegúrese de incluir #NormalTok("command: [\"--config\", \"/etc/vector/vector.toml\"]"); en el servicio para apuntar al archivo TOML correcto.

#horizontalrule

#strong[Error común:] El healthcheck de Vector falla con #NormalTok("wget: can't connect to remote host");.

#strong[Causa:] Dos posibles razones: (1) el bloque #NormalTok("[api]"); no está habilitado en #NormalTok("vector.toml");, o (2) busybox #NormalTok("wget"); no soporta #NormalTok("--spider");.

#strong[Solución:] Verifique que #NormalTok("vector.toml"); incluya #NormalTok("[api]"); con #NormalTok("enabled = true");, y use #NormalTok("wget -q -O /dev/null http://127.0.0.1:8686/health"); en el healthcheck (no #NormalTok("--spider"); y con #NormalTok("127.0.0.1"); explícito).

#horizontalrule

#strong[Error común:] Error de VRL #NormalTok("unnecessary error coalescing operation"); al usar #NormalTok(".\"log.level\" ?? \"unknown\"");.

#strong[Solución:] En VRL, el operador #NormalTok("??"); es para #emph[error-coalescing] (cuando una expresión puede fallar). El acceso a un campo (#NormalTok(".\"log.level\"");) no falla: devuelve #NormalTok("null"); si el campo no existe. Para null-coalescing, use el operador lógico #NormalTok("||");: #NormalTok(".level = .\"log.level\" || \"unknown\"");.

#horizontalrule

#strong[Error común:] Los logs no aparecen en Grafana aunque Vector está corriendo.

#strong[Solución:] Verifique que la datasource Loki esté aprovisionada en Grafana (carpeta #NormalTok("grafana/provisioning/datasources/");). Confirme que el pipeline Vector recibe datos consultando la API: #NormalTok("curl http://localhost:8686/graphql"); (responde con el esquema GraphQL si está activo). Revise los logs de Vector con #NormalTok("docker compose logs vector");.

== Referencias
<referencias-6>
- Vector -- https:\/\/vector.dev/docs/
- Vector Remap Language (VRL) -- https:\/\/vrl.dev
- Loki + Vector -- https:\/\/grafana.com/docs/loki/latest/send-data/vector/
- Grafana -- https:\/\/grafana.com/docs/grafana/latest/

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Plataforma Unificada de Observabilidad con SigNoz y ClickHouse
<sec-guia-signoz>
#quote(block: true)[
#emph[Guía práctica para desplegar y configurar SigNoz, una plataforma moderna "Todo en Uno" basada nativamente en OpenTelemetry y soportada por la base de datos columnar ClickHouse, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

== Objetivo de la guía
<objetivo-de-la-guía-7>
Implementar y validar una plataforma unificada de observabilidad mediante #strong[Docker Compose], usando #strong[SigNoz] como solución integral que integra colector (OTel Collector), almacenamiento analítico (ClickHouse) e interfaz de exploración en un único despliegue.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-8>
Al finalizar esta guía, el estudiante será capaz de:

- Identificar los componentes internos de SigNoz y el rol de cada uno (colector, ClickHouse, Zookeeper, backend, frontend).
- Comprender las ventajas del almacenamiento columnar (ClickHouse) frente a la indexación completa (Elasticsearch) para ingestión masiva de logs.
- Configurar aplicaciones Quarkus para emitir telemetría nativa OTLP hacia SigNoz.
- Explorar y correlacionar logs con trazas distribuidas desde la interfaz de SigNoz.
- Comprender el patrón de #emph[override] de Docker Compose como técnica para extender stacks de terceros sin modificar sus archivos.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en SigNoz que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-7>
#strong[SigNoz] se posiciona como el "estado del arte" de la observabilidad open source: una alternativa libre a plataformas comerciales como DataDog o New Relic. A diferencia de los stacks ensamblados de guías anteriores (ELK, PLG, Vector+Loki), SigNoz integra en un único despliegue:

- Un colector OTel nativo.
- Un motor analítico columnar (ClickHouse) para ingestión de alta velocidad.
- Una interfaz unificada con logs, métricas y trazas en un solo lugar.

El material está concebido como:

- Un #strong[recurso educativo aplicado], orientado a cursos de arquitectura de software y observabilidad.
- Un #strong[entorno de laboratorio reproducible]: se clona el repositorio oficial de SigNoz a una versión fija y se extiende con un compose de #emph[override] mínimo.
- Un #strong[caso de estudio técnico], que ilustra las diferencias entre un stack ensamblado y una plataforma integrada, y la técnica de composición de múltiples archivos de #NormalTok("docker compose");.

El alcance del recurso cubre logs, métricas y trazas distribuidas (los tres pilares de la observabilidad), aunque el énfasis educativo está en los logs.

== Observabilidad Nativa y Almacenamiento Columnar
<observabilidad-nativa-y-almacenamiento-columnar>
Esta guía cierra el recorrido por los paradigmas de almacenamiento del marco conceptual (#ref(<sec-5-7-3>, supplement: [Sección])) con el tercero y más orientado al análisis a gran escala: el #strong[almacén columnar].

=== Filas vs.~columnas: el paradigma OLAP
<filas-vs.-columnas-el-paradigma-olap>
Imagina una tabla de logs con millones de filas y columnas como #NormalTok("timestamp");, #NormalTok("nivel");, #NormalTok("servicio"); y #NormalTok("mensaje");. Una base de datos tradicional (orientada a filas, u OLTP) guarda cada registro completo, uno tras otro (ideal para "tráeme el log \#4827 entero"). Una base de datos #strong[columnar (OLAP)], en cambio, guarda juntos todos los valores de una misma columna.

¿Qué se gana con esto? Fundamentalmente dos cosas:

- #strong[Compresión muy alta:] los valores similares quedan contiguos (todos los #NormalTok("nivel"); juntos: #NormalTok("INFO, INFO, ERROR, INFO...");), y los datos repetitivos se comprimen extraordinariamente bien.
- #strong[Análisis veloz:] una consulta como "¿cuántos errores por minuto en la última hora?" solo necesita leer las columnas #NormalTok("nivel"); y #NormalTok("timestamp");, no los millones de mensajes completos.

#strong[ClickHouse] es la base de datos columnar que materializa este paradigma. A diferencia del índice invertido de Elasticsearch (optimizado para la búsqueda de texto), ClickHouse está optimizado para #emph[agregar] y #emph[analizar] grandes volúmenes, lo que le permite ingestar millones de logs por segundo usando una fracción del disco y la RAM.

=== SigNoz: una plataforma nativa de OpenTelemetry
<signoz-una-plataforma-nativa-de-opentelemetry>
#strong[SigNoz] es la plataforma que integra ClickHouse como motor de almacenamiento con un colector #strong[OTel nativo]. Esto significa que adopta de fábrica el estándar OTLP que estudiaste en la guía de OpenTelemetry: recibe logs, métricas y trazas (los tres pilares) de cualquier aplicación instrumentada con OpenTelemetry, sin formatos propietarios. Es, en cierto modo, la convergencia de los dos últimos grandes temas del recurso: el estándar unificado (OTel) operando sobre el almacenamiento analítico (columnar).

== Requisitos previos
<requisitos-previos-7>
- Docker instalado (https:\/\/docs.docker.com/engine/install/)
- Docker Compose (https:\/\/docs.docker.com/compose/install/)
- Git instalado
- Al menos #strong[8 GB de RAM] libres.
- Conexión a Internet (el primer arranque descarga binarios UDF de ClickHouse).

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-7>
#strong[Consumo estimado del stack:] \~5 GB de RAM en estado estable, incluyendo ClickHouse y los servicios del core de SigNoz (colector, query-service y frontend).

Este recurso se despliega como un #emph[override] sobre el #NormalTok("docker-compose.yaml"); oficial de SigNoz, por lo que #strong[solo controla los componentes propios] del laboratorio. La siguiente tabla muestra los servicios definidos por este override y su #NormalTok("mem_limit");:

#figure([
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Servicio], [#NormalTok("mem_limit");], [Variable],),
  table.hline(),
  [#NormalTok("logs.producer"); (aplicación Quarkus)], [#NormalTok("512m");], [#NormalTok("PRODUCER_MEM_LIMIT");],
)
], caption: figure.caption(
position: top, 
[
Límites de memoria controlados por el archivo de override de Docker Compose.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-signoz-1>


#block[
#callout(
body: 
[
Los límites de memoria de los servicios del #strong[core de SigNoz] (ClickHouse, colector, query-service y frontend) los gobierna el #NormalTok("docker-compose.yaml"); oficial del repositorio de SigNoz. El override de esta guía no los redefine: parametriza únicamente los componentes propios del recurso. El servicio #NormalTok("otel-collector"); que aparece en el override solo ajusta el #NormalTok("command"); del colector oficial, no su límite de memoria.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Las variables están centralizadas en el archivo #NormalTok(".env"); del override:

#Skylighting(([#CommentTok("# Límite de memoria del único componente propio de este override.");],
[#CommentTok("# Los servicios del core de SigNoz (ClickHouse, otel-collector, query-service,");],
[#CommentTok("# frontend) los gobierna el docker-compose.yaml oficial del repositorio de SigNoz.");],
[#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
== Estructura del proyecto
<estructura-del-proyecto-7>
#Skylighting(([#ExtensionTok("08-SigNoz/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml          ");#OperatorTok("<");#NormalTok("-- Override mínimo ");#ErrorTok("(");#ExtensionTok("otel-collector");#NormalTok(" + logs.producer");#KeywordTok(")");],
[#ExtensionTok("├──");#NormalTok(" logs.producer/");],
[#ExtensionTok("│");#NormalTok("   ├── src/");],
[#ExtensionTok("│");#NormalTok("   └── pom.xml");],
[#ExtensionTok("└──");#NormalTok(" signoz/                     ");#OperatorTok("<");#NormalTok("-- Repositorio oficial clonado ");#ErrorTok("(");#ExtensionTok("no");#NormalTok(" se edita");#KeywordTok(")");],
[#NormalTok("    ");#ExtensionTok("└──");#NormalTok(" deploy/docker/");],
[#NormalTok("        ");#ExtensionTok("├──");#NormalTok(" docker-compose.yaml");],
[#NormalTok("        ");#ExtensionTok("└──");#NormalTok(" otel-collector-config.yaml");],));
El directorio #NormalTok("signoz/"); se obtiene clonando el repositorio oficial a una versión fija. #strong[No se edita ningún archivo] de ese directorio: toda la personalización vive en el #NormalTok("docker-compose.yml"); de #emph[override].

== Arquitectura de la solución
<arquitectura-de-la-solución-7>
#Skylighting(([#NormalTok("[Aplicación Quarkus / logs.producer]");],
[#NormalTok("         |");],
[#NormalTok("    (OTLP gRPC :4317)");],
[#NormalTok("         v");],
[#NormalTok(" [SigNoz OTel Collector]");],
[#NormalTok("         |");],
[#NormalTok("   (Exportador nativo)");],
[#NormalTok("         v");],
[#NormalTok("     [ClickHouse]");],
[#NormalTok("         |");],
[#NormalTok("         v");],
[#NormalTok("  [SigNoz Backend] ---> [SigNoz UI :8080]");],));
Los componentes internos del stack SigNoz son:

#figure([
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Contenedor], [Rol],),
  table.hline(),
  [#NormalTok("signoz-otel-collector");], [Recibe telemetría OTLP (gRPC :4317, HTTP :4318)],
  [#NormalTok("signoz-clickhouse");], [Almacenamiento columnar OLAP para logs, trazas y métricas],
  [#NormalTok("signoz-zookeeper-1");], [Coordinación de clúster ClickHouse],
  [#NormalTok("signoz");], [Backend API + Frontend (UI web en :8080)],
)
], caption: figure.caption(
position: top, 
[
Componentes internos del stack SigNoz y su rol.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-signoz-2>


== Implementación de la arquitectura
<implementación-de-la-arquitectura>
=== Paso 1: Descargar el repositorio de SigNoz
<paso-1-descargar-el-repositorio-de-signoz>
El repositorio oficial de SigNoz no se incluye en este repositorio (167 MB, más de 7000 archivos). Desde el directorio #NormalTok("08-SigNoz/");, ejecute el script de setup incluido:

#Skylighting(([#ExtensionTok("./setup.sh");],));
El script equivale a:

#Skylighting(([#FunctionTok("git");#NormalTok(" clone ");#AttributeTok("--depth");#NormalTok(" 1 ");#AttributeTok("--branch");#NormalTok(" v0.122.0 https://github.com/SigNoz/signoz.git");],));
#block[
#callout(
body: 
[
#NormalTok("--depth 1"); descarga solo el último commit (sin historia), reduciendo el tamaño. #NormalTok("--branch v0.122.0"); fija la versión para reproducibilidad. El directorio #NormalTok("signoz/"); está en #NormalTok(".gitignore"); y no se versiona.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Paso 2: El override #NormalTok("docker-compose.yml");
<paso-2-el-override-docker-compose.yml>
El archivo de #emph[override] que acompaña esta guía tiene dos responsabilidades:

+ #strong[Corregir el comando del colector]: el compose oficial inicia el colector con #NormalTok("--manager-config");, que activa el protocolo opAMP para configuración dinámica desde SigNoz. En un entorno de laboratorio esto impide que los receptores OTLP (puerto 4317) se activen hasta que el usuario cree una cuenta y un agente vinculado. El override elimina ese flag para que los receptores arranquen con la configuración estática.

+ #strong[Agregar la aplicación de demostración]: el servicio #NormalTok("logs.producer"); se une a la red #NormalTok("signoz-net"); que crea el compose oficial.

#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#CommentTok("  # Override: remove --manager-config so OTLP receivers (port 4317) activate without");],
[#CommentTok("  # needing a live SigNoz account / opamp connection.");],
[#AttributeTok("  ");#FunctionTok("otel-collector");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" -c");],
[#KeywordTok("      - ");#CharTok("|");],
[#NormalTok("        /signoz-otel-collector migrate sync check &&");],
[#NormalTok("        /signoz-otel-collector --config=/etc/otel-collector-config.yaml");],
[],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" ../../../logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8090:8080\"");#CommentTok("        # 8080 ya lo usa el frontend de SigNoz");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("SIGNOZ_HOST");#KeywordTok(":");#AttributeTok(" signoz-otel-collector");],
[#AttributeTok("    ");#FunctionTok("networks");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" signoz-net");],
[#AttributeTok("    ");#FunctionTok("restart");#KeywordTok(":");#AttributeTok(" unless-stopped");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");#CommentTok("   # único componente propio que limitamos");],));
#block[
#callout(
body: 
[
El #NormalTok("context"); del build usa una ruta relativa desde el directorio del primer #NormalTok("-f"); (#NormalTok("signoz/deploy/docker/");), por eso el path #NormalTok("../../../logs.producer"); apunta al directorio correcto.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Configuración de la aplicación (#NormalTok("application.properties");)
<configuración-de-la-aplicación-application.properties>
#Skylighting(([#NormalTok("quarkus.application.name=logs-producer");],
[],
[#NormalTok("# OpenTelemetry: exportar logs via OTLP gRPC al colector de SigNoz");],
[#NormalTok("quarkus.otel.logs.enabled=true");],
[#NormalTok("# SIGNOZ_HOST defaults to localhost (dev/IDE); docker compose overrides to \"signoz-otel-collector\"");],
[#NormalTok("quarkus.otel.exporter.otlp.endpoint=http://${SIGNOZ_HOST:localhost}:4317");],));
La extensión #NormalTok("quarkus-opentelemetry"); envía logs, trazas y métricas automáticamente en formato OTLP. No se requiere ningún agente externo ni appender adicional.

== Despliegue y validación
<despliegue-y-validación-7>
=== Levantar el stack
<levantar-el-stack>
Desde el directorio #NormalTok("08-SigNoz/");, ejecute:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" signoz/deploy/docker/docker-compose.yaml ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" docker-compose.yml ");#DataTypeTok("\\");],
[#NormalTok("  up ");#AttributeTok("-d");#NormalTok(" ");#AttributeTok("--build");],));
Docker Compose fusiona los dos archivos: el oficial define la infraestructura (ClickHouse, Zookeeper, colector, backend/frontend) y el override corrige el comando del colector y agrega #NormalTok("logs.producer");.

Verifique que todos los contenedores están activos y saludables:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" signoz/deploy/docker/docker-compose.yaml ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" docker-compose.yml ");#DataTypeTok("\\");],
[#NormalTok("  ps");],));
El colector puede tardar hasta 60 segundos en completar la migración de esquemas de ClickHouse en el primer arranque.

=== Detener el stack
<detener-el-stack>
#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" signoz/deploy/docker/docker-compose.yaml ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-f");#NormalTok(" docker-compose.yml ");#DataTypeTok("\\");],
[#NormalTok("  down");],));
#block[
#callout(
body: 
[
Para eliminar también los volúmenes (ClickHouse, Zookeeper, SQLite), agregue #NormalTok("--volumes");. Esto borra todos los datos almacenados.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Emisión de logs desde aplicaciones
<emisión-de-logs-desde-aplicaciones-7>
=== Aplicaciones Quarkus
<aplicaciones-quarkus-7>
- En caso de no tener una aplicación, créela con:

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,opentelemetry' \\");],
[#NormalTok("    -DnoCode");],));
- Configure el exportador OTLP en #NormalTok("application.properties");:

#Skylighting(([#NormalTok("quarkus.application.name=logs-producer");],
[#NormalTok("quarkus.otel.logs.enabled=true");],
[#NormalTok("quarkus.otel.exporter.otlp.endpoint=http://${SIGNOZ_HOST:localhost}:4317");],));
#strong[Uso del logger:]

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#DataTypeTok("static");#NormalTok(" ");#DataTypeTok("final");#NormalTok(" ");#BuiltInTok("Logger");#NormalTok(" LOG ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("Logger");#OperatorTok(".");#FunctionTok("getLogger");#OperatorTok("(");#NormalTok("MiClase");#OperatorTok(".");#FunctionTok("class");#OperatorTok(");");],));
#block[
#callout(
body: 
[
A diferencia de otras guías, aquí no se escribe en archivos ni se configura un socket. El OTel SDK envía los logs directamente al colector por red en formato OTLP. Las trazas HTTP se correlacionan automáticamente con los logs mediante #NormalTok("trace_id"); y #NormalTok("span_id");.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Visualización en SigNoz
<visualización-en-signoz>
Acceda a SigNoz en #NormalTok("http://localhost:8080");.

#quote(block: true)[
#strong[Primer acceso:] SigNoz le pedirá crear una cuenta de administrador (correo y contraseña). Esto es local, no requiere ningún servicio externo.
]

=== Explorar logs
<explorar-logs>
Navegue a #strong[Logs → Logs Explorer] en el menú lateral.

#strong[Filtros útiles:]

#Skylighting(([#NormalTok("service.name = logs-producer");],));
#Skylighting(([#NormalTok("severity_text = ERROR");],));
#Skylighting(([#NormalTok("body contains NullPointerException");],));
=== Correlación con trazas
<correlación-con-trazas>
En la vista de detalle de un log, el campo #NormalTok("trace_id"); actúa como enlace directo a la traza distribuida correspondiente. Esto permite ver el contexto completo de una petición HTTP (latencia, spans) desde un mensaje de log.

=== Generar tráfico de prueba
<generar-tráfico-de-prueba>
La aplicación expone los siguientes endpoints:

#figure([
#table(
  columns: (29.63%, 22.22%, 48.15%),
  align: (auto,auto,auto,),
  table.header([Método], [Path], [Descripción],),
  table.hline(),
  [#NormalTok("POST");], [#NormalTok("/logs");], [Emite un log al nivel y con el mensaje indicados],
  [#NormalTok("GET");], [#NormalTok("/api/error");], [Genera una #NormalTok("NullPointerException"); intencional],
)
], caption: figure.caption(
position: top, 
[
Endpoints expuestos por la aplicación de ejemplo.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-signoz-3>


#Skylighting(([#CommentTok("# Emitir logs de prueba");],
[#ExtensionTok("curl");#NormalTok(" ");#AttributeTok("-X");#NormalTok(" POST http://localhost:8090/logs ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-H");#NormalTok(" ");#StringTok("\"Content-Type: application/json\"");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-d");#NormalTok(" ");#StringTok("'{\"level\":\"INFO\",\"message\":\"Hola desde el laboratorio SigNoz\"}'");],
[],
[#CommentTok("# Generar un error");],
[#ExtensionTok("curl");#NormalTok(" http://localhost:8090/api/error");],));
== Actividades de profundización
<actividades-de-profundización-7>
- #strong[Correlación logs--trazas:] Genere errores con #NormalTok("GET /api/error"); y siga el enlace #NormalTok("trace_id"); desde el log hasta la traza completa en SigNoz Traces.
- #strong[Comparar modelos de indexación:] Contraste el enfoque columnar de ClickHouse (sin índice de texto completo) con la indexación invertida de Elasticsearch. ¿Cómo afecta esto al costo de almacenamiento y a la velocidad de ingesta?
- #strong[Analizar el override de Docker Compose:] Inspeccione el #NormalTok("docker-compose.yml"); de override y explique por qué basta cambiar #NormalTok("command"); sin copiar toda la definición del servicio.
- #strong[Explorar el protocolo opAMP:] Investigue qué es el protocolo opAMP (#emph[Open Agent Management Protocol]) y por qué SigNoz lo usa para la configuración dinámica del colector en producción.
- #strong[Desplegar una segunda aplicación:] Agregue un segundo servicio al override, asígnele un #NormalTok("quarkus.application.name"); diferente y filtre por él en el Logs Explorer.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-7>
+ ClickHouse almacena datos en formato columnar (OLAP), mientras que Elasticsearch usa índices invertidos orientados a búsqueda de texto. Explique por qué el almacenamiento columnar ofrece ventajas de compresión y velocidad de ingesta para logs de alta frecuencia, y qué tipo de consultas se vuelven más eficientes con cada motor.
+ El override de Docker Compose de esta guía solo redefine el campo #NormalTok("command"); del servicio #NormalTok("otel-collector"); sin duplicar el resto de su definición. Analice el mecanismo de fusión de archivos que usa Docker Compose para entender cómo se combinan las claves del compose oficial con las del override, y qué ocurriría si se omitiera el override al levantar el stack.
+ El protocolo opAMP (#emph[Open Agent Management Protocol]) permite la configuración dinámica del OTel Collector desde SigNoz sin reiniciar el contenedor. Evalúe las implicaciones de seguridad y operativas de habilitar opAMP en producción frente al enfoque de configuración estática usado en esta guía de laboratorio.

== Troubleshooting
<troubleshooting-7>
#strong[El puerto 4317 no responde (conexión rechazada desde #NormalTok("logs.producer");).]

#strong[Causa:] El colector arrancó con #NormalTok("--manager-config"); (si se usa el compose oficial sin el override) y los receptores OTLP esperan que el servidor opAMP les entregue la configuración de forma dinámica.

#strong[Solución:] Asegúrese de lanzar #strong[siempre] los dos compose con #NormalTok("-f signoz/deploy/docker/docker-compose.yaml -f docker-compose.yml");. El override elimina #NormalTok("--manager-config"); para que los receptores usen la configuración estática.

#horizontalrule

#strong[El colector tarda en arrancar y #NormalTok("logs.producer"); reporta errores de conexión al inicio.]

#strong[Causa:] El colector ejecuta migraciones de esquema en ClickHouse antes de abrir el puerto 4317. En el primer arranque puede tardar hasta 60 segundos.

#strong[Solución:] Espere hasta que #NormalTok("docker compose ps"); muestre el colector #NormalTok("Up"); (sin estado de salud explícito). La aplicación reintentará la conexión automáticamente gracias a #NormalTok("restart: unless-stopped");.

#horizontalrule

#strong[El primer arranque tarda mucho tiempo.]

#strong[Causa:] #NormalTok("init-clickhouse"); descarga un binario de funciones UDF (histogramQuantile) desde GitHub al primer inicio.

#strong[Solución:] Espere a que el contenedor #NormalTok("signoz-init-clickhouse"); finalice (#NormalTok("Exited (0)");). Este paso solo ocurre la primera vez; los reinicios posteriores son rápidos porque los volúmenes persisten los datos.

#horizontalrule

#strong[#NormalTok("docker compose up"); falla con "port is already allocated" en el puerto 8080.]

#strong[Causa:] Hay otro servicio (por ejemplo, otra guía del laboratorio) usando el puerto 8080 en el host.

#strong[Solución:] Detenga el servicio conflictivo antes de levantar este stack. El frontend de SigNoz necesita el puerto 8080 en el host.

== Referencias
<referencias-7>
- SigNoz Documentation: https:\/\/signoz.io/docs/
- SigNoz GitHub: https:\/\/github.com/SigNoz/signoz
- ClickHouse Documentation: https:\/\/clickhouse.com/docs/
- OpenTelemetry Protocol (OTLP): https:\/\/opentelemetry.io/docs/specs/otlp/
- opAMP (Open Agent Management Protocol): https:\/\/opentelemetry.io/docs/collector/management/
- Quarkus OpenTelemetry Guide: https:\/\/quarkus.io/guides/opentelemetry

#horizontalrule

#emph[Esta guía complementa el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

= Centralización de Logs con Grafana Alloy y Loki
<sec-guia-alloy>
#quote(block: true)[
#emph[Guía práctica complementaria a la guía Promtail. Implementa la misma arquitectura de centralización por archivo (]file tailing#emph[) utilizando #strong[Grafana Alloy], el sucesor oficial de Promtail, como instanciación concreta de la arquitectura conceptual de observabilidad presentada en el documento central.]
]

#quote(block: true)[
#strong[Prerequisito recomendado:] Completar primero la guía Promtail. Esta guía asume familiaridad con Loki, LogQL y el modelo de indexación por etiquetas. El foco está en las diferencias de configuración entre Promtail y Alloy, no en los conceptos base.
]

== Objetivo de la guía
<objetivo-de-la-guía-8>
Implementar y validar una arquitectura de centralización de logs mediante #strong[Docker Compose], migrando el agente de recolección de #strong[Promtail] a #strong[Grafana Alloy], y comprendiendo el nuevo modelo de configuración orientado a componentes (#emph[dataflow]) que introduce Alloy.

== Resultados de aprendizaje esperados
<resultados-de-aprendizaje-esperados-9>
Al finalizar esta guía, el estudiante será capaz de:

- Explicar por qué Grafana Labs puso Promtail en modo mantenimiento y qué ventajas aporta Alloy como sucesor.
- Distinguir el modelo de configuración declarativo-dataflow de Alloy frente al modelo implícito de Promtail.
- Configurar los componentes #NormalTok("local.file_match");, #NormalTok("loki.source.file");, #NormalTok("loki.process"); y #NormalTok("loki.write"); para construir un pipeline de #emph[file tailing] hacia Loki.
- Utilizar la interfaz web integrada de Alloy para inspeccionar el estado de los componentes en tiempo real.
- Migrar conceptualmente una configuración Promtail existente a Alloy.

#strong[Tiempo estimado:] 2 horas de laboratorio acompañado y 2 horas de trabajo independiente (despliegue, validación y desarrollo del cuestionario de análisis crítico).

#strong[Evidencias esperadas:] al finalizar la guía, el estudiante debe contar con (a) el archivo #NormalTok("docker-compose.yml"); y las configuraciones del stack funcionales, (b) una captura de la consulta de logs en Grafana que muestre los eventos emitidos por la aplicación de prueba, (c) la salida exitosa del script #NormalTok("smoke_test.sh"); de la solución correspondiente y (d) las respuestas al cuestionario de análisis crítico. Los entregables exigibles y la rúbrica de evaluación se definen de forma homogénea en la guía docente del recurso.

== Propósito y alcance del recurso
<propósito-y-alcance-del-recurso-8>
#strong[Grafana Alloy] (v1.x) es el sucesor unificado de Promtail y del Grafana Agent. A diferencia de Promtail, que es un agente especializado en #emph[file tailing] hacia Loki, Alloy es una plataforma de telemetría genérica que puede recolectar logs, métricas y trazas desde múltiples fuentes y enviarlos a múltiples destinos.

El modelo de configuración de Alloy es explícitamente #strong[orientado al flujo de datos]: los componentes se declaran por separado y se conectan entre sí mediante referencias explícitas (#NormalTok("forward_to");). Esto lo hace más verboso para casos simples, pero significativamente más claro y flexible para pipelines complejos.

Esta guía se limita al caso de uso equivalente a Promtail: #emph[file tailing] de logs estructurados en JSON hacia Loki.

== Promtail vs Grafana Alloy
<promtail-vs-grafana-alloy>
En la guía de Promtail aprendiste a recolectar logs hacia Loki. Pero Promtail tiene un alcance deliberadamente estrecho: solo logs, y solo hacia Loki. ¿Qué ocurre cuando un mismo equipo necesita recolectar también métricas y trazas? Durante años, la respuesta fue instalar varios agentes distintos (Promtail para logs, otro agente para métricas…), cada uno con su propia configuración. #strong[Grafana Alloy] nace para unificar todo eso en un único recolector de telemetría.

=== Del agente de propósito único al modelo de flujo de datos
<del-agente-de-propósito-único-al-modelo-de-flujo-de-datos>
La diferencia de fondo entre Promtail y Alloy no es de sintaxis, sino de #strong[modelo mental]. Promtail usa una configuración declarativa estática: defines #emph[trabajos] (#emph[jobs]) y, dentro de ellos, una cadena de etapas. Alloy adopta un #strong[modelo de componentes y flujo de datos] (#emph[dataflow]), heredado del proyecto Grafana Agent Flow: cada pieza del pipeline es un componente con entradas y salidas explícitas, que conectas entre sí declarando hacia dónde reenvía sus datos (#NormalTok("forward_to");).

Piénsalo como la diferencia entre una receta lineal ("haz esto, luego esto otro") y un diagrama de tuberías donde conectas explícitamente cada tramo. El segundo modelo es más verboso, pero también más expresivo y depurable: puedes ramificar flujos, reutilizar componentes y observar el recorrido de los datos en una interfaz gráfica (sección 7).

¿Por qué ocurrió esta transición en el ecosistema de Grafana? Como se anticipó en la guía de Promtail, este último entró en #strong[modo mantenimiento] en 2023. Grafana consolidó sus múltiples agentes (Promtail, Grafana Agent) en una sola herramienta (Alloy) capaz de manejar los tres pilares de la observabilidad (marco conceptual, #ref(<sec-5-1>, supplement: [Sección])) bajo un único modelo de configuración.

La siguiente tabla resume las equivalencias concretas entre ambos, útil si llegas desde la guía de Promtail:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Concepto], [Promtail (YAML)], [Grafana Alloy (Alloy syntax)],),
  table.hline(),
  [Formato de config], [YAML (#NormalTok("promtail-config.yaml");)], [HCL-like (#NormalTok(".alloy");)],
  [Descubrimiento de archivos], [#NormalTok("scrape_configs[].file_sd_configs");], [Componente #NormalTok("local.file_match");],
  [Lectura del archivo], [Implícito en el job de scrape], [Componente explícito #NormalTok("loki.source.file");],
  [Pipeline de procesamiento], [Array #NormalTok("pipeline_stages"); dentro del job], [Componente #NormalTok("loki.process"); con bloques #NormalTok("stage.*");],
  [Extracción de campos JSON], [#NormalTok("stage.json"); o #NormalTok("stage.regex");], [#NormalTok("stage.json"); o #NormalTok("stage.regex"); (mismo modelo)],
  [Promoción a etiquetas], [#NormalTok("stage.labels");], [#NormalTok("stage.labels");],
  [Destino Loki], [#NormalTok("clients: [url: ...]"); (top-level)], [Componente #NormalTok("loki.write"); con bloque #NormalTok("endpoint");],
  [Flujo de datos], [#strong[Implícito] (stages en cadena por job)], [#strong[Explícito] (wiring con #NormalTok("forward_to");)],
  [Archivo de posiciones], [#NormalTok("positions.filename"); en config], [Gestionado automáticamente en #NormalTok("--storage.path");],
  [Recarga en caliente], [SIGHUP o #NormalTok("/-/reload");], [#NormalTok("/-/reload"); HTTP o SIGHUP],
  [Interfaz de inspección], [Ninguna], [UI web en #NormalTok(":12345"); con grafo de componentes],
)
], caption: figure.caption(
position: top, 
[
Equivalencias de configuración entre Promtail y Grafana Alloy.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-alloy-1>


== Requisitos previos
<requisitos-previos-8>
- Docker instalado https:\/\/docs.docker.com/engine/install/
- Docker Compose https:\/\/docs.docker.com/compose/install/
- Al menos #strong[4 GB de RAM] libres (este stack no incluye Elasticsearch ni OpenSearch; Alloy, Loki y Grafana tienen una huella de memoria significativamente menor que los stacks ELK/OLO). Este requisito reducido es, en sí mismo, un punto de comparación pedagógico con las guías anteriores.

=== Dimensionamiento de recursos
<dimensionamiento-de-recursos-8>
#strong[Consumo estimado del stack:] \~2.5 GB de RAM en estado estable. Se trata de un stack ligero, apto para equipos con tan solo 4 GB de RAM disponibles.

Cada servicio declara un #NormalTok("mem_limit"); que acota su consumo de memoria. La siguiente tabla resume el rol de cada contenedor en el pipeline y su límite por defecto:

#figure([
#table(
  columns: (16.95%, 40.68%, 42.37%),
  align: (auto,auto,auto,),
  table.header([Servicio], [Función en el pipeline], [#NormalTok("mem_limit"); por defecto],),
  table.hline(),
  [#NormalTok("logs.producer");], [Aplicación Quarkus que genera los logs (fuente de datos)], [#NormalTok("512m");],
  [#NormalTok("alloy");], [Recolector y procesador del pipeline (lee, transforma y envía)], [#NormalTok("512m");],
  [#NormalTok("loki");], [Almacenamiento e indexación por etiquetas de los logs], [#NormalTok("512m");],
  [#NormalTok("grafana");], [Visualización y consulta de los logs], [#NormalTok("512m");],
)
], caption: figure.caption(
position: top, 
[
Servicios del stack, su función en el pipeline y límites de memoria por defecto.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-alloy-2>


Los límites son parametrizables mediante variables de entorno definidas en un archivo #NormalTok(".env"); junto al #NormalTok("docker-compose.yml");, lo que permite ajustarlos sin editar el compose:

#Skylighting(([#VariableTok("PRODUCER_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("ALLOY_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("LOKI_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],
[#VariableTok("GRAFANA_MEM_LIMIT");#OperatorTok("=");#NormalTok("512m");],));
== Estructura del proyecto
<estructura-del-proyecto-8>
#Skylighting(([#ExtensionTok("09-Alloy/");],
[#ExtensionTok("├──");#NormalTok(" docker-compose.yml");],
[#ExtensionTok("├──");#NormalTok(" alloy/");],
[#ExtensionTok("│");#NormalTok("   └── config.alloy          ");#OperatorTok("<");#NormalTok("-- Configuración del pipeline Alloy");],
[#ExtensionTok("├──");#NormalTok(" grafana/");],
[#ExtensionTok("│");#NormalTok("   └── provisioning/");],
[#ExtensionTok("│");#NormalTok("       └── datasources/");],
[#ExtensionTok("│");#NormalTok("           └── loki.yaml");],
[#ExtensionTok("├──");#NormalTok(" logs/                      ");#OperatorTok("<");#NormalTok("-- Volumen compartido: producer escribe, Alloy lee");],
[#ExtensionTok("└──");#NormalTok(" logs.producer/");],
[#NormalTok("    ");#ExtensionTok("├──");#NormalTok(" src/");],
[#NormalTok("    ");#ExtensionTok("└──");#NormalTok(" pom.xml");],));
== Arquitectura de la solución
<arquitectura-de-la-solución-8>
#Skylighting(([#NormalTok("[Aplicación Quarkus / logs.producer]");],
[#NormalTok("         |");],
[#NormalTok("   (Escribe JSON en archivo)");],
[#NormalTok("         v");],
[#NormalTok("  [Volumen compartido ./logs]");],
[#NormalTok("         |");],
[#NormalTok("   (local.file_match → loki.source.file)");],
[#NormalTok("         v");],
[#NormalTok("  [Grafana Alloy :12345]");],
[#NormalTok("   loki.process (regex + labels)");],
[#NormalTok("         |");],
[#NormalTok("   (loki.write / HTTP push)");],
[#NormalTok("         v");],
[#NormalTok("     [Loki 3.0] ──→ [Grafana 13.0]");],));
La arquitectura es funcionalmente idéntica a la de la guía Promtail. La diferencia es interna: el pipeline de Alloy es un #strong[grafo de componentes] con conexiones explícitas en lugar de una lista de etapas implícitas.

== Implementación
<implementación>
=== #NormalTok("docker-compose.yml");
<docker-compose.yml-7>
#Skylighting(([#FunctionTok("services");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("logs.producer");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("build");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("context");#KeywordTok(":");#AttributeTok(" logs.producer");],
[#AttributeTok("      ");#FunctionTok("dockerfile");#KeywordTok(":");#AttributeTok(" src/main/docker/Dockerfile.compose");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${PRODUCER_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"8080:8080\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ./logs:/deployments/logs");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("alloy");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("alloy");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/alloy:v1.16.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" alloy");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${ALLOY_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" run");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" --server.http.listen-addr=0.0.0.0:12345");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" --storage.path=/var/lib/alloy/data");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" /etc/alloy/config.alloy");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ./alloy/config.alloy:/etc/alloy/config.alloy:ro");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ./logs:/var/log/app:ro");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" alloy_data:/var/lib/alloy/data");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"12345:12345\"");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#CommentTok("      # La imagen de Alloy no incluye wget ni curl.");],
[#CommentTok("      # Verificamos que el puerto 12345 esté en estado LISTEN vía /proc/net/tcp6.");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"grep -q '3039' /proc/net/tcp6 || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("6");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 20s");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#AttributeTok("  ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/loki:3.0.0");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" loki");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${LOKI_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3100:3100\"");],
[#AttributeTok("    ");#FunctionTok("command");#KeywordTok(":");#AttributeTok(" -config.file=/etc/loki/local-config.yaml");],
[#AttributeTok("    ");#FunctionTok("healthcheck");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("test");#KeywordTok(":");#AttributeTok(" ");#KeywordTok("[");#StringTok("\"CMD-SHELL\"");#KeywordTok(",");#AttributeTok(" ");#StringTok("\"wget -q --spider http://localhost:3100/ready || exit 1\"");#KeywordTok("]");],
[#AttributeTok("      ");#FunctionTok("interval");#KeywordTok(":");#AttributeTok(" 10s");],
[#AttributeTok("      ");#FunctionTok("timeout");#KeywordTok(":");#AttributeTok(" 5s");],
[#AttributeTok("      ");#FunctionTok("retries");#KeywordTok(":");#AttributeTok(" ");#DecValTok("12");],
[#AttributeTok("      ");#FunctionTok("start_period");#KeywordTok(":");#AttributeTok(" 15s");],
[],
[#AttributeTok("  ");#FunctionTok("grafana");#KeywordTok(":");],
[#AttributeTok("    ");#FunctionTok("image");#KeywordTok(":");#AttributeTok(" grafana/grafana:13.0.1");],
[#AttributeTok("    ");#FunctionTok("container_name");#KeywordTok(":");#AttributeTok(" grafana");],
[#AttributeTok("    ");#FunctionTok("mem_limit");#KeywordTok(":");#AttributeTok(" ${GRAFANA_MEM_LIMIT:-512m}");],
[#AttributeTok("    ");#FunctionTok("environment");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ENABLED=true");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_ANONYMOUS_ORG_ROLE=Admin");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" GF_AUTH_DISABLE_LOGIN_FORM=true");],
[#AttributeTok("    ");#FunctionTok("ports");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#StringTok("\"3000:3000\"");],
[#AttributeTok("    ");#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("      ");#KeywordTok("-");#AttributeTok(" ");#FunctionTok("source");#KeywordTok(":");#AttributeTok(" ./grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("target");#KeywordTok(":");#AttributeTok(" /etc/grafana/provisioning");],
[#AttributeTok("        ");#FunctionTok("type");#KeywordTok(":");#AttributeTok(" bind");],
[#AttributeTok("    ");#FunctionTok("depends_on");#KeywordTok(":");],
[#AttributeTok("      ");#FunctionTok("loki");#KeywordTok(":");],
[#AttributeTok("        ");#FunctionTok("condition");#KeywordTok(":");#AttributeTok(" service_healthy");],
[],
[#FunctionTok("volumes");#KeywordTok(":");],
[#AttributeTok("  ");#FunctionTok("alloy_data");#KeywordTok(":");],));
#block[
#callout(
body: 
[
#strong[El comando de Alloy:] A diferencia de Promtail, que usa #NormalTok("--config.file=");, Alloy recibe la ruta del archivo de configuración como #strong[argumento posicional] al final del comando #NormalTok("alloy run");. El flag #NormalTok("--server.http.listen-addr"); es obligatorio para exponer la UI y los endpoints de salud.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#strong[El healthcheck:] La imagen de Alloy no incluye #NormalTok("wget"); ni #NormalTok("curl");. El puerto 12345 en hexadecimal es #NormalTok("0x3039");\; verificamos su presencia en #NormalTok("/proc/net/tcp6"); como alternativa portable.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Pipeline de Alloy (#NormalTok("alloy/config.alloy");)
<pipeline-de-alloy-alloyconfig.alloy>
#Skylighting(([#NormalTok("// ─── 1. Descubrir el archivo de log ─────────────────────────────────────────");],
[#NormalTok("local.file_match \"quarkus_logs\" {");],
[#NormalTok("  path_targets = [{\"__path__\" = \"/var/log/app/*.log\"}]");],
[#NormalTok("  sync_period  = \"5s\"");],
[#NormalTok("}");],
[],
[#NormalTok("// ─── 2. Leer el archivo (file tailing) ──────────────────────────────────────");],
[#NormalTok("loki.source.file \"quarkus_tail\" {");],
[#NormalTok("  targets    = local.file_match.quarkus_logs.targets");],
[#NormalTok("  forward_to = [loki.process.enrich.receiver]");],
[#NormalTok("}");],
[],
[#NormalTok("// ─── 3. Extraer el nivel de log y enriquecer con etiquetas ──────────────────");],
[#NormalTok("// El formato ECS de Quarkus produce claves planas con punto: {\"log.level\":\"INFO\",...}");],
[#NormalTok("// stage.regex extrae el nivel con la misma expresión validada en la guía Promtail.");],
[#NormalTok("loki.process \"enrich\" {");],
[#NormalTok("  stage.regex {");],
[#NormalTok("    expression = \"\\\"log\\\\.level\\\":\\\"(?P<level>[^\\\"]+)\\\"\"");],
[#NormalTok("  }");],
[],
[#NormalTok("  stage.labels {");],
[#NormalTok("    values = {");],
[#NormalTok("      \"level\" = \"\",");],
[#NormalTok("    }");],
[#NormalTok("  }");],
[],
[#NormalTok("  stage.static_labels {");],
[#NormalTok("    values = {");],
[#NormalTok("      \"job\"         = \"alloy_app_logs\",");],
[#NormalTok("      \"environment\" = \"dev\",");],
[#NormalTok("    }");],
[#NormalTok("  }");],
[],
[#NormalTok("  forward_to = [loki.write.loki_backend.receiver]");],
[#NormalTok("}");],
[],
[#NormalTok("// ─── 4. Enviar a Loki ────────────────────────────────────────────────────────");],
[#NormalTok("loki.write \"loki_backend\" {");],
[#NormalTok("  endpoint {");],
[#NormalTok("    url = \"http://loki:3100/loki/api/v1/push\"");],
[#NormalTok("  }");],
[#NormalTok("}");],));
#block[
#callout(
body: 
[
#strong[#NormalTok("log.level"); en ECS:] El formato ECS de Quarkus produce la clave con el punto como parte del nombre (#NormalTok("\"log.level\"");), no como estructura anidada. #NormalTok("stage.json"); de Alloy interpreta el punto como separador de ruta (igual que Promtail), por lo que se usa #NormalTok("stage.regex"); con la expresión #NormalTok("\"log\\\\.level\"");, la misma estrategia validada en la guía Promtail.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#strong[#NormalTok("forward_to");:] El wiring explícito es la diferencia conceptual central de Alloy. #NormalTok("loki.source.file.quarkus_tail"); envía a #NormalTok("loki.process.enrich.receiver");\; este a su vez envía a #NormalTok("loki.write.loki_backend.receiver");. Este grafo es visible en la UI de Alloy en #NormalTok("http://localhost:12345");.

]
, 
title: 
[
Nota
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
=== Configuración de la aplicación (#NormalTok("application.properties");)
<configuración-de-la-aplicación-application.properties-1>
Idéntica a la guía Promtail: la aplicación escribe en archivo JSON, sin conocimiento del agente que la lee.

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[],
[#NormalTok("# Escribir logs estructurados en formato JSON al archivo compartido con Alloy");],
[#NormalTok("quarkus.log.file.enable=true");],
[#NormalTok("quarkus.log.file.json=true");],
[#NormalTok("quarkus.log.file.path=/deployments/logs/application.log");],
[#NormalTok("quarkus.log.file.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.file.json.log-format=ECS");],));
== Despliegue y validación
<despliegue-y-validación-8>
Antes de levantar el stack, cree el directorio compartido para los logs:

#Skylighting(([#FunctionTok("mkdir");#NormalTok(" ");#AttributeTok("-p");#NormalTok(" logs");],));
Luego ejecute:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose up ");#AttributeTok("-d");#NormalTok(" ");#AttributeTok("--build");],));
Verifique que los servicios estén activos:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" compose ps");],));
== Interfaz de Alloy
<interfaz-de-alloy>
Acceda a #NormalTok("http://localhost:12345"); para ver la #strong[UI de Alloy]. Desde allí puede:

- Ver el #strong[grafo de componentes] con el estado de cada uno (verde = saludable).
- Inspeccionar los datos que fluyen por cada conexión en tiempo real (#emph[Live Debugging]).
- Consultar las métricas internas de Alloy (#NormalTok("/metrics");).
- Recargar la configuración sin reiniciar (#NormalTok("/-/reload");).

Esta interfaz no existe en Promtail y es una de las ventajas operativas más importantes de Alloy.

== Emisión de logs desde la aplicación
<emisión-de-logs-desde-la-aplicación>
#quote(block: true)[
#strong[Reutilización de la aplicación:] Si ya completó la guía Promtail, puede reutilizar la misma aplicación #NormalTok("logs.producer");. La configuración de escritura a archivo JSON (#NormalTok("application.properties");) es idéntica. Si aún no la tiene, créela con el siguiente comando:
]

#Skylighting(([#NormalTok("mvn io.quarkus.platform:quarkus-maven-plugin:3.18.4:create \\");],
[#NormalTok("    -DprojectGroupId=co.uniquindio.ingesis.logs \\");],
[#NormalTok("    -DprojectArtifactId=logs.producer \\");],
[#NormalTok("    -Dextensions='rest,logging-json' \\");],
[#NormalTok("    -DnoCode");],));
Configure la escritura a archivo JSON en #NormalTok("application.properties");:

#Skylighting(([#NormalTok("quarkus.log.console.json=false");],
[],
[#NormalTok("# Escribir logs estructurados en formato JSON al archivo compartido con Alloy");],
[#NormalTok("quarkus.log.file.enable=true");],
[#NormalTok("quarkus.log.file.json=true");],
[#NormalTok("quarkus.log.file.path=/deployments/logs/application.log");],
[#NormalTok("quarkus.log.file.json.exception-output-type=formatted");],
[#NormalTok("quarkus.log.file.json.log-format=ECS");],));
La aplicación expone los mismos endpoints que en las guías anteriores:

#figure([
#table(
  columns: (29.63%, 22.22%, 48.15%),
  align: (auto,auto,auto,),
  table.header([Método], [Path], [Descripción],),
  table.hline(),
  [#NormalTok("POST");], [#NormalTok("/logs");], [Emite un log al nivel indicado],
  [#NormalTok("GET");], [#NormalTok("/api/error");], [Genera una #NormalTok("NullPointerException"); intencional],
)
], caption: figure.caption(
position: top, 
[
Endpoints expuestos por la aplicación de ejemplo.
]), 
kind: "quarto-float-tbl", 
supplement: "Tabla", 
)
<tbl-alloy-3>


#Skylighting(([#CommentTok("# Emitir logs de prueba");],
[#ExtensionTok("curl");#NormalTok(" ");#AttributeTok("-X");#NormalTok(" POST http://localhost:8080/logs ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-H");#NormalTok(" ");#StringTok("\"Content-Type: application/json\"");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-d");#NormalTok(" ");#StringTok("'{\"level\":\"INFO\",\"message\":\"Hola desde Alloy\"}'");],
[],
[#CommentTok("# Generar un error");],
[#ExtensionTok("curl");#NormalTok(" http://localhost:8080/api/error");],));
== Visualización en Grafana
<visualización-en-grafana-3>
Acceda a Grafana en #NormalTok("http://localhost:3000");. La fuente de datos Loki está preconfigurada.

#strong[Consultas LogQL de ejemplo:]

Todos los logs del pipeline Alloy:

#Skylighting(([#NormalTok("{job=\"alloy_app_logs\"}");],));
Filtrar por nivel:

#Skylighting(([#NormalTok("{job=\"alloy_app_logs\", level=\"ERROR\"}");],));
Analizar el JSON y mostrar solo el mensaje:

#Skylighting(([#NormalTok("{job=\"alloy_app_logs\"} | json | line_format \"{{.message}}\"");],));
== Actividades de profundización
<actividades-de-profundización-8>
- #strong[Comparar el grafo de componentes con la guía Promtail:] Dibuje o esquematice el pipeline equivalente en Promtail y compare la verbosidad y claridad de ambas configuraciones. ¿Cuándo es preferible cada modelo?
- #strong[Usar la migración automática:] Ejecute #NormalTok("alloy convert --source-format=promtail --config.file=promtail-config.yaml"); con la configuración de la guía anterior. Compare la salida con #NormalTok("config.alloy"); de esta guía.
- #strong[Añadir una segunda fuente:] Modifique #NormalTok("config.alloy"); para leer también #NormalTok("/var/log/app/*.json"); (un segundo glob) y etiquetarlo con #NormalTok("source=\"json\"");. ¿Cómo se haría en Promtail?
- #strong[Inspeccionar el #emph[live debugging]:] Desde la UI de Alloy (#NormalTok("http://localhost:12345");), active la depuración en vivo del componente #NormalTok("loki.process.enrich"); y observe los eventos que atraviesan el pipeline mientras genera carga.
- #strong[Evaluar el estado de mantenimiento:] Investigue qué funcionalidades tiene Grafana Alloy que Promtail no tendrá jamás (soporte OTLP, Pyroscope, integración con Kubernetes, etc.) y analice las implicaciones para la decisión de migración en un proyecto real.

=== Cuestionario de análisis crítico
<cuestionario-de-análisis-crítico-8>
+ ¿Por qué no es posible usar #NormalTok("stage.json"); con la expresión #NormalTok("\"log.level\""); para extraer el nivel de los logs ECS de Quarkus en Alloy, y cuál es la diferencia entre un campo con punto en el nombre y un campo anidado?
+ El healthcheck de Alloy usa #NormalTok("/proc/net/tcp6"); en lugar de #NormalTok("wget"); o #NormalTok("curl");. Explique qué limitación de la imagen impone esta solución y proponga una alternativa basada en un Dockerfile personalizado.
+ Compare el modelo de configuración de Alloy (#emph[dataflow] explícito con #NormalTok("forward_to");) con el de Promtail (#emph[stages] implícitas en cadena). ¿En qué escenario de producción el modelo de Alloy ofrece una ventaja clara?

== Troubleshooting
<troubleshooting-8>
#strong[Alloy queda en estado #NormalTok("unhealthy"); al arrancar.]

#strong[Causa:] La imagen de Alloy no incluye #NormalTok("wget"); ni #NormalTok("curl");. El healthcheck de esta guía usa #NormalTok("/proc/net/tcp6");, que requiere que el puerto 12345 esté en estado LISTEN. Si Alloy tarda en abrir el puerto, el #NormalTok("start_period"); de 20 segundos debería ser suficiente.

#strong[Solución:] Verifique los logs con #NormalTok("docker compose logs alloy");. Si hay errores de sintaxis en #NormalTok("config.alloy");, Alloy no arrancará y el puerto nunca se abrirá. Valide la sintaxis localmente con #NormalTok("docker run --rm -v $(pwd)/alloy:/etc/alloy grafana/alloy:v1.16.1 fmt /etc/alloy/config.alloy");.

#horizontalrule

#strong[Los logs no aparecen en Loki / Grafana.]

#strong[Causas posibles:] 1. El directorio #NormalTok("./logs"); no existe o está vacío: #NormalTok("logs.producer"); no ha podido escribir el archivo. 2. El componente #NormalTok("loki.source.file"); no encuentra el glob #NormalTok("/var/log/app/*.log"); porque el archivo no se ha creado aún.

#strong[Solución:] Verifique que #NormalTok("./logs/application.log"); exista tras el arranque de #NormalTok("logs.producer");:

#Skylighting(([#FunctionTok("ls");#NormalTok(" ");#AttributeTok("-la");#NormalTok(" logs/");],
[#ExtensionTok("docker");#NormalTok(" compose logs logs.producer ");#KeywordTok("|");#NormalTok(" ");#FunctionTok("tail");#NormalTok(" ");#AttributeTok("-10");],));
Luego inspeccione el estado de los componentes en la UI de Alloy (#NormalTok("http://localhost:12345");).

#horizontalrule

#strong[Error de sintaxis en #NormalTok("config.alloy");.]

#strong[Solución:] Alloy incluye un formateador y validador:

#Skylighting(([#ExtensionTok("docker");#NormalTok(" run ");#AttributeTok("--rm");#NormalTok(" ");#DataTypeTok("\\");],
[#NormalTok("  ");#AttributeTok("-v");#NormalTok(" ");#VariableTok("$(");#BuiltInTok("pwd");#VariableTok(")");#NormalTok("/alloy:/etc/alloy ");#DataTypeTok("\\");],
[#NormalTok("  grafana/alloy:v1.16.1 ");#DataTypeTok("\\");],
[#NormalTok("  fmt /etc/alloy/config.alloy");],));
Si hay errores de sintaxis, el comando los reporta con la línea exacta.

== Referencias
<referencias-8>
- Grafana Alloy Documentation: https:\/\/grafana.com/docs/alloy/latest/
- Migrate from Promtail to Alloy: https:\/\/grafana.com/docs/alloy/latest/set-up/migrate/from-promtail/
- loki.source.file: https:\/\/grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/
- loki.process: https:\/\/grafana.com/docs/alloy/latest/reference/components/loki/loki.process/
- Alloy configuration syntax: https:\/\/grafana.com/docs/alloy/latest/get-started/configuration-syntax/
- LogQL (Loki Query Language): https:\/\/grafana.com/docs/loki/latest/query/
- Grafana Documentation: https:\/\/grafana.com/docs/grafana/latest/

#horizontalrule

#emph[Esta guía complementa la guía Promtail y el marco teórico de observabilidad y centralización de logs desarrollado en el documento central.]

#heading(level: 1, numbering: none)[Referencias bibliográficas]
<referencias-bibliográficas>
#block[
#block[
Abadi, D. J., Madden, S. R., & Hachem, N. (2008). Column-stores vs. row-stores: How different are they really? #emph[Proceedings of the 2008 ACM SIGMOD International Conference on Management of Data], 967-980. #link("https://doi.org/10.1145/1376616.1376712")

] <ref-abadi-2008>
#block[
Aghili, R., Li, H., & Khomh, F. (2025). Protecting privacy in software logs: What should be anonymized? #emph[Proceedings of the ACM on Software Engineering], #emph[2]\(FSE). #link("https://doi.org/10.1145/3715779")

] <ref-aghili-2025>
#block[
Beyer, B., Jones, C., Petoff, J., & Murphy, N. R. (2016). #emph[Site Reliability Engineering: How Google Runs Production Systems]. O'Reilly Media.

] <ref-beyer-2016>
#block[
Biggs, J., & Tang, C. (2011). #emph[Teaching for Quality Learning at University] (4th ed.). Open University Press.

] <ref-biggs-2011>
#block[
Bosch, J. (2016). Speed, data, and ecosystems: The future of software engineering. #emph[IEEE Software], #emph[33]\(1), 82-88. #link("https://doi.org/10.1109/MS.2016.14")

] <ref-bosch-2016>
#block[
Branch, R. M. (2009). #emph[Instructional Design: The ADDIE Approach]. Springer. #link("https://doi.org/10.1007/978-0-387-09506-6")

] <ref-branch-2009>
#block[
Burns, B., Grant, B., Oppenheimer, D., Brewer, E., & Wilkes, J. (2016). Borg, Omega, and Kubernetes: Lessons learned from three container-management systems over a decade. #emph[ACM Queue], #emph[14]\(1), 70-93. #link("https://doi.org/10.1145/2898442.2898444")

] <ref-burns-2016>
#block[
Chuvakin, A., Schmidt, K., & Phillips, C. (2012). #emph[Logging and Log Management: The Authoritative Guide to Understanding the Concepts Surrounding Logging and Log Management]. Syngress.

] <ref-chuvakin-2012>
#block[
Cito, J., Leitner, P., Fritz, T., & Gall, H. C. (2015). The making of cloud applications: An empirical study on software development for the cloud. #emph[Proceedings of the 10th Joint Meeting on Foundations of Software Engineering], 393-403. #link("https://doi.org/10.1145/2786805.2786826")

] <ref-cito-2015>
#block[
Design-Based Research Collective. (2003). Design-based research: An emerging paradigm for educational inquiry. #emph[Educational Researcher], #emph[32]\(1), 5-8. #link("https://doi.org/10.3102/0013189X032001005")

] <ref-design-2003>
#block[
He, P., Zhu, J., Zheng, Z., & Lyu, M. R. (2017). Drain: An online log parsing approach with fixed depth tree. #emph[2017 IEEE International Conference on Web Services], 33-40. #link("https://doi.org/10.1109/ICWS.2017.13")

] <ref-he-2017>
#block[
He, S., He, P., Chen, Z., Yang, T., Su, Y., & Lyu, M. R. (2021). A survey on automated log analysis for reliability engineering. #emph[ACM Computing Surveys], #emph[54]\(6), 1-37. #link("https://doi.org/10.1145/3460345")

] <ref-he-2021>
#block[
Hevner, A. R., March, S. T., Park, J., & Ram, S. (2004). Design science in information systems research. #emph[MIS Quarterly], #emph[28]\(1), 75-105. #link("https://doi.org/10.2307/25148625")

] <ref-hevner-2004>
#block[
Kalman, R. E. (1960). On the general theory of control systems. #emph[Proceedings of the First International Congress of the International Federation of Automatic Control (IFAC)], #emph[1], 481-492.

] <ref-kalman-1960>
#block[
Kitchin, R. (2014). #emph[The Data Revolution: Big Data, Open Data, Data Infrastructures and Their Consequences]. Sage Publications.

] <ref-kitchin-2014>
#block[
Kleppmann, M. (2017). #emph[Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems]. O'Reilly Media.

] <ref-kleppmann-2017>
#block[
Kolb, D. A. (1984). #emph[Experiential Learning: Experience as the Source of Learning and Development]. Prentice-Hall.

] <ref-kolb-1984>
#block[
Lamport, L. (1978). Time, clocks, and the ordering of events in a distributed system. #emph[Communications of the ACM], #emph[21]\(7), 558-565. #link("https://doi.org/10.1145/359545.359563")

] <ref-lamport-1978>
#block[
Majors, C., Fong-Jones, L., & Miranda, G. (2022). #emph[Observability Engineering: Achieving Production Excellence]. O'Reilly Media.

] <ref-majors-2022>
#block[
Manning, C. D., Raghavan, P., & Schütze, H. (2008). #emph[Introduction to Information Retrieval]. Cambridge University Press.

] <ref-manning-2008>
#block[
McKenney, S., & Reeves, T. C. (2018). #emph[Conducting Educational Design Research] (2nd ed.). Routledge. #link("https://doi.org/10.4324/9781315105642")

] <ref-mckenney-2018>
#block[
Newman, S. (2015). #emph[Building Microservices: Designing Fine-Grained Systems]. O'Reilly Media.

] <ref-newman-2015>
#block[
Oliner, A. J., Ganapathi, A., & Xu, W. (2012). Advances and challenges in log analysis. #emph[Communications of the ACM], #emph[55]\(2), 55-61. #link("https://doi.org/10.1145/2076450.2076466")

] <ref-oliner-2012>
#block[
Peffers, K., Tuunanen, T., Rothenberg, M. A., & Chatterjee, R. (2007). A design science research methodology for information systems research. #emph[Journal of Management Information Systems], #emph[24]\(3), 45-77. #link("https://doi.org/10.2753/MIS0742-1222240302")

] <ref-peffers-2007>
#block[
Richardson, C. (2018). #emph[Microservices Patterns: With Examples in Java]. Manning Publications.

] <ref-richardson-2018>
#block[
Sigelman, B. H., Barroso, L. A., Burrows, M., Stephenson, P., Plakal, M., Beaver, D., Jaspan, S., & Shanbhag, C. (2010). #emph[Dapper, a Large-Scale Distributed Systems Tracing Infrastructure] (Dapper-2010-1). Google.

] <ref-sigelman-2010>
#block[
Sridharan, C. (2018). #emph[Distributed Systems Observability: A Guide to Building Robust Systems]. O'Reilly Media.

] <ref-sridharan-2018>
#block[
Turnbull, J. (2016). #emph[The Art of Monitoring]. Turnbull Press.

] <ref-turnbull-2016>
#block[
Usman, M., Ferlin, S., Brunstrom, A., & Taheri, J. (2022). A survey on observability of distributed edge & container-based microservices. #emph[IEEE Access], #emph[10], 86904-86919. #link("https://doi.org/10.1109/ACCESS.2022.3193102")

] <ref-usman-2022>
#block[
Xu, W., Huang, L., Fox, A., Patterson, D., & Jordan, M. I. (2009). Detecting large-scale system problems by mining console logs. #emph[Proceedings of the ACM SIGOPS 22nd Symposium on Operating Systems Principles], 117-132. #link("https://doi.org/10.1145/1629575.1629587")

] <ref-xu-2009>
#block[
Zhu, J., He, S., Liu, J., He, P., Xie, Q., Zheng, Z., & Lyu, M. R. (2019). Tools and benchmarks for automated log parsing. #emph[Proceedings of the 41st International Conference on Software Engineering: Software Engineering in Practice], 121-130. #link("https://doi.org/10.1109/ICSE-SEIP.2019.00021")

] <ref-zhu-2019>
] <refs>



