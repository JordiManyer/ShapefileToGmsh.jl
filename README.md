# GeoGmsh.jl

[![Build Status](https://github.com/JordiManyer/GeoGmsh.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JordiManyer/GeoGmsh.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://JordiManyer.github.io/GeoGmsh.jl/dev/)

A Julia package that converts geospatial data into Gmsh geometry (`.geo`) and
mesh (`.msh`) files. Accepts any GeoInterface-compatible source: Shapefiles,
GeoJSON, GeoPackage, GeoParquet, NaturalEarth data, or raw geometries.

<table>
  <tr>
    <td align="center"><b>France</b></td>
    <td align="center"><b>Iberian Peninsula</b></td>
    <td align="center"><b>Spain</b></td>
    <td align="center"><b>Catalonia</b></td>
  </tr>
  <tr>
    <td><img src="docs/src/assets/france.png" alt="France" width="100%"/></td>
    <td><img src="docs/src/assets/iberia.png" alt="Iberia" width="100%"/></td>
    <td><img src="docs/src/assets/spain.png" alt="Spain" width="100%"/></td>
    <td><img src="docs/src/assets/catalonia.png" alt="Catalonia" width="100%"/></td>
  </tr>
  <tr>
    <td align="center"><b>Australia — geometry</b></td>
    <td align="center"><b>Australia — mesh</b></td>
    <td align="center"><b>Mont Blanc (3D terrain)</b></td>
    <td align="center"><b>Everest (3D terrain)</b></td>
  </tr>
  <tr>
    <td><img src="docs/src/assets/australia_geo.png" alt="Australia geometry" width="100%"/></td>
    <td><img src="docs/src/assets/australia_mesh.png" alt="Australia mesh" width="100%"/></td>
    <td><img src="docs/src/assets/montblanc.png" alt="Mont Blanc" width="100%"/></td>
    <td><img src="docs/src/assets/everest.png" alt="Everest" width="100%"/></td>
  </tr>
</table>

## Features

- **Universal reader** — load any geospatial format through a single `read_geodata` call backed by GDAL. Read directly from ZIP archives via `/vsizip/`.
- **Reproject** — convert between coordinate systems via Proj.jl (e.g. geographic degrees → UTM metres).
- **Simplify** — `MinEdgeLength` removes short edges; `AngleFilter` suppresses zig-zag spikes; compose algorithms with `∘`.
- **Segmentize** — subdivide long edges to control maximum element size.
- **Rescale** — normalise geometry into a dimensionless bounding box so `mesh_size` is consistent.
- **3D terrain** — lift a 2D mesh to terrain elevation by sampling a DEM raster at every node.
- **Output** — `.geo` script or `.msh` file via the Gmsh API; linear/quadratic elements, triangle or quad recombination.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/JordiManyer/GeoGmsh.jl")
```

## Quick start

```julia
using GeoGmsh, NaturalEarth

# No files needed — NaturalEarth.jl provides built-in country boundaries
countries = naturalearth("admin_0_countries", 110)

geoms_to_msh(countries, "france";
  select       = row -> get(row, :NAME, "") == "France" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 5_000.0),
  bbox_size    = 100.0,
  mesh_size    = 2.0,
)
# → france.msh
```

```julia
using GeoGmsh

# From any file — Shapefile, GeoJSON, GeoPackage, ZIP, …
geoms_to_msh("NUTS_RG_01M_2024_4326_LEVL_0.geojson", "germany";
  select       = row -> row.NUTS_ID == "DE" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 10_000.0),
  bbox_size    = 100.0,
  mesh_size    = 2.0,
)
# → germany.msh
```

```julia
# 3D terrain mesh from a bounding box + DEM
geoms_to_msh_3d("bbox.geojson", "dem_utm.tif", "terrain";
  target_crs   = "EPSG:32632",
  simplify_alg = MinEdgeLength(tol = 500.0),
  mesh_size    = 500.0,
)
# → terrain.msh  (node z-coordinates sampled from DEM)
```

See the [documentation](https://JordiManyer.github.io/GeoGmsh.jl/dev/) for the
full pipeline guide, API reference, and worked examples.

## Data sources

- **NUTS** (Spain, Catalonia, Navarre, Iberia): Eurostat / GISCO, © European Union.
- **ASGS Edition 3** (Australia): Australian Bureau of Statistics.
- **Copernicus GLO-30 DEM** (Mont Blanc, Everest, Pyrenees): © DLR / Airbus.
