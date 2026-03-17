# [Pipeline guide](@id pipeline)

This page walks through the full conversion pipeline step by step.
All steps are also available individually so you can mix and match.

## 1. Read geospatial data

[`read_geodata`](@ref) reads any GDAL-supported format — Shapefile, GeoJSON,
GeoPackage, GeoParquet, GeoArrow, FlatGeobuf — and returns a standard
`DataFrame` with a `:geometry` column and CRS metadata attached.

```julia
df = read_geodata("regions.shp")
df = read_geodata("countries.geojson")
df = read_geodata("data.gpkg"; layer = "admin")
```

Pass `select` to load only a subset of records:

```julia
df = read_geodata("NUTS.shp";
  select = row -> row.CNTR_CODE == "DE" && row.LEVL_CODE == 0)
```

Call [`list_components`](@ref) to inspect what is in a file before deciding
which records to select:

```julia
list_components("NUTS_RG_01M_2024_3035.shp")
```

### NaturalEarth data

NaturalEarth.jl returns GeoInterface-compatible `FeatureCollection` objects
that `geoms_to_geo` accepts directly — no file reading needed:

```julia
using NaturalEarth
fc = naturalearth("admin_0_countries", 110)
geoms_to_geo(fc, "countries"; target_crs = "EPSG:3857", mesh_size = 2.0)
```

## 2. Reproject coordinates

Geographic data is often stored in decimal degrees (lon/lat, EPSG:4326).
Gmsh works in a flat Cartesian plane, so reprojection to metres is needed
before edge-length operations or meshing.

`geoms_to_geo` handles this automatically via `target_crs`:

```julia
geoms_to_geo(df, "output"; target_crs = "EPSG:3857")   # Web Mercator
geoms_to_geo(df, "output"; target_crs = "EPSG:3035")   # ETRS89 / LAEA Europe
```

Pass `target_crs = nothing` to skip reprojection (e.g. data already in metres).

Reprojection is done by `GeometryOps.reproject` (via Proj.jl) on the raw
GeoInterface geometry, before ingestion.

## 3. Simplify edges

Large shapefiles and NaturalEarth data contain far more boundary points than a
coarse mesh needs. [`MinEdgeLength`](@ref) removes vertices that are closer
than `simplify_tol` to the last *retained* vertex — guaranteeing no boundary
edge shorter than the threshold remains in the output.

```julia
geoms_to_geo(df, "output";
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 5_000.0),   # no edge shorter than 5 km
)
```

You can also call it directly on any GeoInterface geometry:

```julia
import GeometryOps as GO
simplified = GO.simplify(MinEdgeLength(tol = 5_000.0), polygon)
```

!!! note "Why not `RadialDistance`?"
    `RadialDistance` (built into GeometryOps) measures distance to the last
    *visited* point, not the last *kept* one. This means short edges can still
    appear after simplification. `MinEdgeLength` measures to the last kept
    point, giving a strict guarantee.

## 4. Segmentize edges

To ensure no edge is *longer* than a threshold — useful when boundaries span
large distances and linear interpolation becomes inaccurate — use
`GeometryOps.segmentize` via the `max_edge_length` keyword:

```julia
geoms_to_geo(df, "output";
  target_crs   = "EPSG:3857",
  max_distance = 50_000.0,   # no edge longer than 50 km
)
```

For large geographic regions, geodesic segmentization is more accurate than
planar; call it directly before passing data to the pipeline:

```julia
import GeometryOps as GO
geom = GO.segmentize(GO.Geodesic(), feature_collection; max_distance = 50_000.0)
geoms_to_geo(geom, "output"; target_crs = "EPSG:3857")
```

## 5. Rescale geometry

When mesh parameters are easier to express in normalised units (e.g. for an
FEM solver that expects an O(1) domain), rescale the geometry so its largest
bounding-box dimension equals `L`:

```julia
geoms_to_geo(df, "output"; bbox_size = 100.0)
```

After rescaling, set `mesh_size` in the same normalised units (e.g. `2.0`
gives roughly 50 elements across the domain).

## 6. Write output

### `.geo` script

Produces a human-readable Gmsh geometry script that you can open in the GUI,
edit manually, or mesh with `gmsh file.geo -2`:

```julia
write_geo(geoms, "output/germany"; mesh_size = 2.0)
# → output/germany.geo
```

### `.msh` file (via Gmsh API)

Generates the mesh immediately without any intermediate file:

```julia
generate_mesh(geoms, "output/germany";
  mesh_size = 2.0,
  order     = 2,        # quadratic elements
  recombine = true,     # triangles → quads
)
# → output/germany.msh
```

### Split components

Both output functions accept `split_components = true` to write one file per
`ShapeGeometry` into a directory:

```julia
generate_mesh(geoms, "output/australia"; mesh_size = 2.0, split_components = true)
# → output/australia/1.msh, 2.msh, …
```

## One-call pipeline

For most use cases `geoms_to_geo` or `geoms_to_msh` compose the entire pipeline:

```julia
geoms_to_msh(
  read_geodata("NUTS_RG_01M_2024_3035.shp";
    select = row -> row.CNTR_CODE == "DE" && row.LEVL_CODE == 0),
  "germany";
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 50_000.0),
  bbox_size    = 100.0,
  mesh_size    = 2.0,
)
```

Or directly from a file path:

```julia
shapefile_to_msh("regions.shp", "output";
  target_crs = "EPSG:3857",
  mesh_size  = 1.0,
)
```

## 3D terrain meshing

For terrain-following meshes, the pipeline branches after step 2 (reprojection)
and does **not** use `bbox_size` — the geometry must stay in the DEM's native
CRS units (metres) so that elevation sampling is consistent.

### Surface mesh

[`geoms_to_msh_3d`](@ref) generates a flat 2D triangle mesh and then lifts
every node's z-coordinate by bilinearly sampling a DEM:

```julia
geoms_to_msh_3d("region.geojson", "dem_utm.tif", "terrain";
  target_crs   = "EPSG:32632",          # must match the DEM CRS
  simplify_alg = MinEdgeLength(tol = 500.0),
  mesh_size    = 500.0,                 # metres
)
# → terrain.msh  (triangulated surface)
```

The DEM file can be any GDAL-supported raster (GeoTIFF, SRTM `.hgt`, NetCDF, …).
It must already be reprojected to the same CRS as `target_crs`.  See the
Mont Blanc and Everest examples for a full GDAL download + mosaic + reproject
workflow.

### Volumetric mesh

[`geoms_to_msh_3d_volume`](@ref) extends the surface pipeline to produce a
solid tetrahedral mesh by extruding the terrain surface downward by `depth`
(in the same units as the CRS) to a flat bottom plane:

```julia
geoms_to_msh_3d_volume("region.geojson", "dem_utm.tif", "terrain_vol";
  target_crs   = "EPSG:32632",
  simplify_alg = MinEdgeLength(tol = 500.0),
  mesh_size    = 500.0,
  depth        = 1_000.0,              # 1 km pedestal below terrain minimum
)
# → terrain_vol.msh  (tetrahedral volume)
```

Each surface triangle is extruded into a triangular prism which is then split
into three tetrahedra, so the volume mesh has exactly 3× as many elements as
the surface mesh and twice as many nodes.

## Ring orientation

Gmsh requires:

- Exterior rings → **CCW** (counter-clockwise, positive signed area)
- Hole rings → **CW** (clockwise, negative signed area)

[`ingest`](@ref) enforces this convention automatically on all input geometries,
regardless of the source winding order (ESRI Shapefiles use the opposite
convention, for example).
