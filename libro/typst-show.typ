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
  [$title$],
  [$subtitle$],
  [
    $for(book.author)$
    $it.name$$if(it.degree)$, $it.degree$$endif$\
    $endfor$
  ],
  [$book.date$],
)
]


#show: book.with(
  image-index: image("images/chapter_header.png"),
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$

$if(book.author)$
  author: "$for(book.author)$$it.name$, $it.degree$$sep$\n$endfor$",
$endif$
$if(date)$
  date: "$date$",
$endif$
$if(lang)$
  lang: "$lang$",
$endif$

  supplement-chapter: "Capítulo",
  copyright: [
    #set text(size: 9pt)

    *$title$* \
    _$subtitle$_

    #v(0.3em)
    *Autores* \
        $for(book.author)$

        $it.name$, $it.degree$\

        $endfor$



    #v(0.3em)
    Universidad del Quindío — Facultad de Ingeniería \
    Programa de Ingeniería de Sistemas y Computación \
    Armenia, Quindío, Colombia — $book.date$

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
    © $book.date$ $for(book.author)$ $it.name$$sep$,$endfor$

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
$if(toc-depth)$
  outline-depth: $toc-depth$,
$endif$
  outline-small-depth: 1,
$if(lof)$
  list-of-figure-title: "$if(crossref.lof-title)$$crossref.lof-title$$else$$crossref-lof-title$$endif$",
$endif$
$if(lot)$
  list-of-table-title: "$if(crossref.lot-title)$$crossref.lot-title$$else$$crossref-lot-title$$endif$",
$endif$
$if(margin-geometry)$
  padded-heading-number: false,
$endif$
$if(fontsize)$
  font-size: $fontsize$,
$endif$
)

$if(margin-geometry)$
// Configure marginalia page geometry for book context
// Geometry computed by Quarto's meta.lua filter (typstGeometryFromPaperWidth)
// IMPORTANT: This must come AFTER book.with() to override the book format's margin settings
#import "@preview/marginalia:0.3.1" as marginalia

#show: marginalia.setup.with(
  inner: (
    far: $margin-geometry.inner.far$,
    width: $margin-geometry.inner.width$,
    sep: $margin-geometry.inner.separation$,
  ),
  outer: (
    far: $margin-geometry.outer.far$,
    width: $margin-geometry.outer.width$,
    sep: $margin-geometry.outer.separation$,
  ),
  top: $if(margin.top)$$margin.top$$else$1.25in$endif$,
  bottom: $if(margin.bottom)$$margin.bottom$$else$1.25in$endif$,
  // CRITICAL: Enable book mode for recto/verso awareness
  book: true,
  clearance: $margin-geometry.clearance$,
)
$endif$
