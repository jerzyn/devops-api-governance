// Shared typographic styles (presenterm renders these as images).
// Use rgb(r, g, b) — hex strings like rgb("#ee9322") break typst parsing (# = markup).
#let content-title(body) = {
  block(
    width: 100%,
    align(center)[
      text(size: 32pt, weight: "bold", fill: rgb(238, 146, 34))[#body]
    ],
  )
}

#let title-slide() = {
  set page(fill: rgb(4, 3, 18), margin: 0pt)
  align(center + horizon)[
    block[
      text(size: 48pt, weight: "bold", fill: rgb(180, 204, 255))[DevOps-Driven API Governance]
      v(2em)
      text(size: 32pt, fill: rgb(165, 215, 232))[API Days Munich 2026]
      v(6em)
      text(size: 20pt, fill: rgb(182, 234, 218))[
        Andrzej Jarzyna \
        Krzysztof Madeński
      ]
    ],
  ]
}
