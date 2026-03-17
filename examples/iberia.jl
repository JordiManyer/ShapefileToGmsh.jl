"""
Iberian Peninsula mesh example.

Downloads the Eurostat NUTS-2 boundaries, filters mainland Spain and
mainland Portugal (excluding islands and autonomous cities), unions all
regions into a single polygon, and produces one combined mesh.

Data source: Eurostat GISCO
  NUTS 2024 – 1:1 Million, EPSG:4326, Level 2
  https://gisco-services.ec.europa.eu/distribution/v2/nuts/
"""

using GeoGmsh
import GeoInterface as GI
import GeometryOps as GO
using LibGEOS          # loads the GeometryOps ↔ GEOS extension
using Downloads

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

nuts_url  = "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/" *
            "NUTS_RG_01M_2024_4326_LEVL_2.geojson"
nuts_path = joinpath(data_dir, "NUTS_RG_01M_2024_4326_LEVL_2.geojson")

if !isfile(nuts_path)
  println("Downloading NUTS-2 boundaries (~16 MB)…")
  Downloads.download(nuts_url, nuts_path)
  println("  Saved: ", nuts_path)
end

# ---------------------------------------------------------------------------
# Inspect
# ---------------------------------------------------------------------------

# Regions excluded from "mainland":
#   ES53 Illes Balears, ES63 Ceuta, ES64 Melilla, ES70 Canarias
#   PT20 Açores, PT30 Madeira
const EXCLUDE = ("ES53", "ES63", "ES64", "ES70", "PT20", "PT30")

is_mainland = row -> length(row.NUTS_ID) == 4 &&
                     (startswith(row.NUTS_ID, "ES") || startswith(row.NUTS_ID, "PT")) &&
                     row.NUTS_ID ∉ EXCLUDE

println("\nMainland Iberian Peninsula NUTS-2 regions (largest first):")
comps = list_components(nuts_path)
comps = filter(is_mainland, comps)
sort!(comps, :area, rev = true)
println(comps)

# ---------------------------------------------------------------------------
# Union all mainland regions into one polygon
# ---------------------------------------------------------------------------

iberia_df = read_geodata(nuts_path; select = is_mainland)
col       = first(GI.geometrycolumns(iberia_df))
geom_list = collect(skipmissing(iberia_df[!, col]))

println("\nUnioning $(length(geom_list)) NUTS-2 regions into one polygon…")

iberia_geom = foldl((a, b) -> GO.union(GO.GEOS(), a, b), geom_list)

println("  Done.  Result trait: ", GI.geomtrait(iberia_geom))

# ---------------------------------------------------------------------------
# 2D geo + mesh
# ---------------------------------------------------------------------------

output = joinpath(data_dir, "iberia")

geoms_to_geo(
  iberia_geom, output;
  target_crs   = "EPSG:3035",    # ETRS89 LAEA — equal-area, metres
  simplify_tol = 10_000.0,       # ≥ 10 km minimum edge
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  iberia_geom, output;
  target_crs   = "EPSG:3035",
  simplify_tol = 10_000.0,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
