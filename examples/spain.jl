"""
Spain NUTS-2 mesh example.

Downloads the Eurostat NUTS-2 boundaries for 2024 (all of Europe) from the
GISCO distribution service and produces two meshes:

1. spain     — all Spanish NUTS-2 regions in a single mesh.
2. catalonia — Catalonia (ES51) only.

Data source: Eurostat GISCO
  NUTS 2024 – 1:1 Million, EPSG:4326, Level 2
  https://gisco-services.ec.europa.eu/distribution/v2/nuts/
"""

using GeoGmsh
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

println("\nSpanish NUTS-2 regions (largest first):")
comps = list_components(nuts_path)
comps = filter(row -> startswith(row.NUTS_ID, "ES") && length(row.NUTS_ID) == 4, comps)
sort!(comps, :area, rev = true)
println(comps)

# ---------------------------------------------------------------------------
# 1. Whole Spain — all NUTS-2 regions in one mesh
# ---------------------------------------------------------------------------

println("\n=== Spain (all NUTS-2) ===")

is_spain = row -> startswith(row.NUTS_ID, "ES") && length(row.NUTS_ID) == 4

geoms_to_geo(
  nuts_path, joinpath(data_dir, "spain");
  select       = is_spain,
  target_crs   = "EPSG:3035",    # ETRS89 LAEA — equal-area, metres
  simplify_tol = 10_000.0,       # ≥ 10 km minimum edge
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  nuts_path, joinpath(data_dir, "spain");
  select       = is_spain,
  target_crs   = "EPSG:3035",
  simplify_tol = 10_000.0,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)

# ---------------------------------------------------------------------------
# 2. Catalonia (ES51) only
# ---------------------------------------------------------------------------

println("\n=== Catalonia (ES51) ===")

geoms_to_geo(
  nuts_path, joinpath(data_dir, "catalonia");
  select       = row -> row.NUTS_ID == "ES51",
  target_crs   = "EPSG:3035",
  simplify_tol = 10_000.0,
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  nuts_path, joinpath(data_dir, "catalonia");
  select       = row -> row.NUTS_ID == "ES51",
  target_crs   = "EPSG:3035",
  simplify_tol = 10_000.0,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
