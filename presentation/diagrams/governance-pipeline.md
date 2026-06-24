```d2 +render +width:95%
direction: right

contract: "OpenAPI\nin Git" {
  shape: document
}

pr: "PR triggers\nCI" {
  shape: step
}

spectral: "Spectral\ndesign gate" {
  shape: rectangle
}

oasdiff: "oasdiff\ncompatibility" {
  shape: rectangle
}

microcks: "Microcks\ncontract test" {
  shape: rectangle
}

merge: Merge {
  shape: diamond
}

catalog: "Backstage\ncatalog" {
  shape: cylinder
}

contract -> pr -> spectral -> oasdiff -> microcks -> merge -> catalog
```
