"""
    ShapefileToGmsh

Convert ESRI Shapefiles to Gmsh geometry (`.geo`) and mesh (`.msh`) files.

## Typical workflow

```julia
using ShapefileToGmsh

# 1. Inspect the shapefile's attribute table.
list_components("regions.shp")

# 2. Generate a mesh for a single region (already in metres).
shapefile_to_msh("regions.shp", "output/my_region";
  select            = row -> row.NAME == "Catalonia",
  proj_method       = nothing,
  edge_length_range = (5_000.0, Inf),
  bbox_size         = 100.0,
  mesh_size         = 2.0,
)
```

## Pipeline

`shapefile_to_geo` / `shapefile_to_msh` run these steps in order:

1. [`read_shapefile`](@ref) — parse the `.shp` geometry, optionally filtered
   by [`select`](@ref read_shapefile).
2. [`project_to_meters`](@ref) — reproject coordinates with the PROJ library.
3. [`coarsen_edges`](@ref) / [`refine_edges`](@ref) — adjust edge resolution.
4. [`filter_components`](@ref) — drop degenerate rings produced by coarsening.
5. [`rescale`](@ref) — normalise geometry into an `L × L` bounding box.
6. [`write_geo`](@ref) or [`generate_mesh`](@ref) — write output.
"""
module ShapefileToGmsh

using Shapefile
using Printf
import Proj
import Tables

include("geometry.jl")
include("shapefiles.jl")
include("projection.jl")
include("adaptivity.jl")
include("verbose.jl")
include("gmsh.jl")
include("pipeline.jl")

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

export ShapeGeometry, Contour, npoints, nedges

export read_shapefile, list_components

export project_to_meters, rescale

export coarsen_edges, refine_edges, filter_components

export write_geo
export generate_mesh

export shapefile_to_geo
export shapefile_to_msh

end
