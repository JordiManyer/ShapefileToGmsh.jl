"""
Australia mesh example.

Downloads the ABS ASGS 2021 boundary file for the whole continent,
reprojects to Web Mercator, simplifies, and produces both a .geo
script and a split .msh file (one mesh per island component).

Data source: Australian Bureau of Statistics (ABS)
  Australian Statistical Geography Standard (ASGS) Edition 3
  https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs-edition-3
  File: AUS_2021_AUST_GDA2020_SHP.zip
"""

using GeoGmsh
using Downloads

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

zip_url  = "https://www.abs.gov.au/statistics/standards/" *
           "australian-statistical-geography-standard-asgs-edition-3/" *
           "jul2021-jun2026/access-and-downloads/digital-boundary-files/" *
           "AUS_2021_AUST_SHP_GDA2020.zip"
zip_path = joinpath(data_dir, "AUS_2021_AUST_GDA2020_SHP.zip")

if !isfile(zip_path)
  println("Downloading ABS ASGS boundary file…")
  Downloads.download(zip_url, zip_path)
  println("  Saved: ", zip_path)
end

# ArchGDAL (and therefore GeoGmsh) can read directly from a ZIP via the
# GDAL /vsizip/ virtual filesystem — no extraction needed.
input = "/vsizip/$zip_path/AUS_2021_AUST_GDA2020.shp"

# ---------------------------------------------------------------------------
# Inspect
# ---------------------------------------------------------------------------

println("\nComponents in the file:")
comps = list_components(input)
sort!(comps, :area, rev = true)
println(first(comps, 10))

# ---------------------------------------------------------------------------
# 2D geo + mesh
# ---------------------------------------------------------------------------

# Select the whole-of-Australia row (AUS_CODE21 == "AUS") which contains
# the full coastline polygon with all islands as separate components.
output = joinpath(data_dir, "australia")

geoms_to_geo(
  input, output;
  select           = row -> row.AUS_CODE21 == "AUS",
  target_crs       = "EPSG:3857",        # Web Mercator, metres
  simplify_tol     = 100_000.0,          # ≥ 100 km minimum edge
  bbox_size        = 100.0,              # normalise into a 100×100 box
  split_components = true,
  verbose          = true,
)

geoms_to_msh(
  input, output;
  select           = row -> row.AUS_CODE21 == "AUS",
  target_crs       = "EPSG:3857",
  simplify_tol     = 100_000.0,
  bbox_size        = 100.0,
  mesh_size        = 2.0,
  split_components = true,
  verbose          = true,
)
