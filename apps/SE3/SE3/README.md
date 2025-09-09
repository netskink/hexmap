
# call map

flowchart LR
  %% Layout
  classDef entry fill:#cfe8ff,stroke:#2b6cb0,color:#000,stroke-width:1px
  classDef helper fill:#fff,stroke:#555,color:#000,stroke-width:1px
  classDef neigh fill:#fff,stroke:#888,color:#000,stroke-dasharray:3 3,stroke-width:1px

  subgraph Lifecycle & Input
    didMove["didMove(to:)"]:::entry
    didChange["didChangeSize(_:)"]:::entry
    touchesEnded["touchesEnded(_:with:)"]:::entry
  end

  subgraph Camera Setup
    fitCamera["fitCamera()"]:::helper
    computeScale["computeScale()"]:::helper
    clampCamera["clampCameraToMap()"]:::helper
  end

  subgraph Highlights Pipeline
    showFromUnit["showMoveHighlightsFromUnit()"]:::helper
    showHighlights["showMoveHighlights(from:range:)"]:::helper
    paintReachable["paintReachable(from:range:)"]:::helper
    clearHighlights["clearHighlights()"]:::helper
  end

  subgraph Neighbor/Bounds
    nearest["nearestSixNeighbors(c:r:)"]:::neigh
    evenR["evenRNeighbors(c:r:)"]:::neigh
    oddR["oddRNeighbors(c:r:)"]:::neigh
    inBounds["isInBounds(c:r:)"]:::neigh
  end

  %% Edges
  didMove --> fitCamera
  didMove --> clampCamera
  didChange --> fitCamera
  didChange --> clampCamera
  fitCamera --> computeScale

  touchesEnded --> showFromUnit
  touchesEnded --> clearHighlights
  showFromUnit --> showHighlights
  showHighlights --> paintReachable

  paintReachable --> nearest
  paintReachable --> evenR
  paintReachable --> oddR
  paintReachable --> inBounds
