# # Iberian Peninsula (2D)
#
# This example builds a single mesh for the whole Iberian Peninsula by
# downloading the Eurostat NUTS-0 boundaries, selecting mainland Spain and
# mainland Portugal separately, and **unioning** them into one polygon before
# meshing.
#
# **Features highlighted:**
# - Multi-country polygon union via `GeometryOps.union` (LibGEOS backend)
# - Passing a raw GeoInterface geometry directly to `geoms_to_geo` / `geoms_to_msh`
# - Composed simplification: `AngleFilter ∘ MinEdgeLength`
#
# | Iberian Peninsula |
# |:-----------------:|
# | ![Iberia mesh](../assets/iberia.png) |

using GeoGmsh
import GeoInterface as GI
import GeometryOps as GO
using LibGEOS          # activates the GeometryOps ↔ GEOS extension
using Downloads

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ## Download
#
# NUTS-0 contains one feature per country; a single file covers all of Europe.

nuts0_url  = "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/" *
             "NUTS_RG_01M_2024_4326_LEVL_0.geojson"
nuts0_path = joinpath(data_dir, "NUTS_RG_01M_2024_4326_LEVL_0.geojson")

if !isfile(nuts0_path)
  println("Downloading NUTS-0 boundaries…")
  Downloads.download(nuts0_url, nuts0_path)
  println("  Saved: ", nuts0_path)
end

# ## Select mainland polygons
#
# `list_components` expands MultiPolygons and sorts rings by area, so
# `ring == 1` always refers to the largest (mainland) component.

println("\nNUTS-0 Spain + Portugal components (sorted by area):")
comps = list_components(nuts0_path)
comps = filter(row -> row.NUTS_ID ∈ ("ES", "PT"), comps)
sort!(comps, :area, rev = true)
println(comps)

geom_col = first(GI.geometrycolumns(comps))

spain_rows    = filter(row -> row.NUTS_ID == "ES" && row.ring == 1, comps)
portugal_rows = filter(row -> row.NUTS_ID == "PT" && row.ring == 1, comps)

spain_geom    = spain_rows[1, geom_col]
portugal_geom = portugal_rows[1, geom_col]

# ## Union
#
# `GO.union(GO.GEOS(), a, b)` calls LibGEOS to compute the polygon union.
# The result is a single GeoInterface-compatible polygon that GeoGmsh can
# ingest directly — no DataFrame or file required.

println("\nUnioning mainland Spain + Portugal…")
iberia_geom = GO.union(GO.GEOS(), spain_geom, portugal_geom)
println("  Done.  Result trait: ", GI.geomtrait(iberia_geom))

# ## 2D geometry and mesh

output    = joinpath(data_dir, "iberia")
iberia_alg = AngleFilter(tol = 20.0) ∘ MinEdgeLength(tol = 10_000.0)

geoms_to_geo(
  iberia_geom, output;
  target_crs   = "EPSG:3857",
  simplify_alg = iberia_alg,
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  iberia_geom, output;
  target_crs   = "EPSG:3857",
  simplify_alg = iberia_alg,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
