# GeoGmsh.jl

```@docs
GeoGmsh
```

A Julia package that converts geospatial data into Gmsh geometry (`.geo`) and
mesh (`.msh`) files. Accepts any
[GeoInterface](https://github.com/JuliaGeo/GeoInterface.jl)-compatible source:
Shapefiles, GeoJSON, GeoPackage, GeoParquet, NaturalEarth data, or raw
GeoInterface geometries.

---

| | |
|:---:|:---:|
| ![Australia geometry](assets/australia_geo.png) | ![Australia mesh](assets/australia_mesh.png) |
| **Australia — geometry** | **Australia — mesh** |
| ![Spain mesh](assets/spain.png) | ![Catalonia mesh](assets/catalonia.png) |
| **Spain** | **Catalonia** |

---

## Features

- **Universal reader** — load any geospatial format (Shapefile, GeoJSON, GeoPackage, GeoParquet, …) through a single [`read_geodata`](@ref) call backed by GDAL.
- **Reproject** — convert between coordinate systems via [GeometryOps.jl](https://github.com/JuliaGeo/GeometryOps.jl) / Proj.jl (e.g. geographic degrees → Web Mercator metres).
- **Simplify** — remove short edges with [`MinEdgeLength`](@ref), a custom `SimplifyAlg` that guarantees no boundary edge shorter than the threshold remains.
- **Segmentize** — subdivide long edges via `GeometryOps.segmentize`.
- **Rescale** — normalise geometry into a dimensionless bounding box so `mesh_size` stays consistent across datasets.
- **Output** — write a human-readable `.geo` script or call the Gmsh API to produce a `.msh` file directly; supports linear/quadratic elements and quad recombination.
- **Split components** — one file per polygon ring.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/JordiManyer/GeoGmsh.jl")
```

## Quick start

### From NaturalEarth (no files needed)

```julia
using GeoGmsh
using NaturalEarth

fc = naturalearth("admin_0_countries", 110)   # GeoInterface FeatureCollection
geoms_to_geo(fc, "countries";
  target_crs   = "EPSG:3857",
  simplify_tol = 5_000.0,
  mesh_size    = 2.0,
)
# → countries.geo
```

### From a file

```julia
using GeoGmsh

# Inspect the file first
list_components("NUTS_RG_01M_2024_3035.shp")

# Generate a mesh
df = read_geodata("NUTS_RG_01M_2024_3035.shp";
  select = row -> row.CNTR_CODE == "DE" && row.LEVL_CODE == 0)

geoms_to_msh(df, "germany";
  target_crs   = "EPSG:3857",
  simplify_tol = 50_000.0,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
)
# → germany.msh
```

## Pipeline overview

| Step | Tool | Purpose |
|------|------|---------|
| Read | [`read_geodata`](@ref) | Parse any geospatial format; filter by attribute |
| Reproject | `GeometryOps.reproject` | Convert coordinates via PROJ |
| Simplify | [`MinEdgeLength`](@ref) via `GO.simplify` | Remove short-edge redundancy |
| Segmentize | `GeometryOps.segmentize` | Subdivide long edges |
| Ingest | [`ingest`](@ref) | Normalise ring orientation for Gmsh |
| Filter | [`filter_components`](@ref) | Drop degenerate rings |
| Rescale | [`rescale`](@ref) | Normalise into an L × L bounding box |
| Output | [`write_geo`](@ref) / [`generate_mesh`](@ref) | Write `.geo` or `.msh` |

See the [Pipeline guide](@ref pipeline) and [API reference](@ref api) for details.

## Data sources

The example meshes above were generated from the following open datasets:

- **NUTS — Territorial units statistics** (Spain, Catalonia): Eurostat / GISCO, © European Union.
  [https://ec.europa.eu/eurostat/web/gisco/geodata/statistical-units/territorial-units-statistics](https://ec.europa.eu/eurostat/web/gisco/geodata/statistical-units/territorial-units-statistics)
- **ASGS Edition 3** (Australia): Australian Bureau of Statistics.
  [https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3](https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3)
