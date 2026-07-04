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

