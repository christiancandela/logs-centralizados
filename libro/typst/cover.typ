// Portada: imagen a página completa con logo UniQuindío y año

#let cover(title, subtitle, authors, year) = {


  // Fondo: imagen de portada a sangre completa
  image("../images/cover.png", width: 100%, height: 100%, fit: "cover")

  // Logo de la Universidad del Quindío (parte superior centrada)
  place(top + center, dy: 2cm)[
    #image("../images/logo_uq_gris.png", width: 4.5cm)
  ]

// Título sobre la imagen
  place(
    top + center,
    dy: 10cm,
    [
      #block(
        width: 17cm,
        fill: rgb(8, 26, 43).transparentize(20%),
        inset: 18pt,
        stroke: rgb(74, 144, 194),
        radius: 6pt,
      )[
        #align(center)[
          #set text(fill: white)
          #text(
            size: 26pt,
            weight: "bold",
          )[
            #title
          ]
          #v(0.8em)
          #text(size: 18pt)[
            #subtitle
          ]
          #v(1.6em)
          #set text(size: 13pt)
          #authors
        ]
      ]
    ]
  )

  // Año en la parte inferior
  place(bottom + center, dy: -2cm)[
    #text(
      size: 13pt,
      weight: "bold",
      fill: white,
      tracking: 0.25em,
    )[#year]
  ]

}