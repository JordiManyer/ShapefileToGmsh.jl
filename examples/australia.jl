# # Australia (2D)
#
# This example loads the ABS ASGS 2021 continental boundary for Australia
# directly from a ZIP archive hosted by the Australian Bureau of Statistics,
# without extracting any files to disk.
#
# **Features highlighted:**
# - Reading from a ZIP archive via GDAL's `/vsizip/` virtual filesystem
# - `list_components` to inspect the file before deciding what to select
# - `ring == 1` to select the mainland and exclude offshore islands
# - Producing both a `.geo` script and a `.msh` file in one pass
#
# | Geometry | Mesh |
# |:--------:|:----:|
# | ![Australia geometry](../assets/australia_geo.png) | ![Australia mesh](../assets/australia_mesh.png) |

using GeoGmsh
using Downloads

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ## Download
#
# The ABS distributes the continental boundary as a zipped Shapefile.
# We download it once and cache it locally.

zip_url  = "https://www.abs.gov.au/statistics/standards/" *
           "australian-statistical-geography-standard-asgs-edition-3/" *
           "jul2021-jun2026/access-and-downloads/digital-boundary-files/" *
           "AUS_2021_AUST_SHP_GDA2020.zip"
zip_path = joinpath(data_dir, "AUS_2021_AUST_SHP_GDA2020.zip")

if !isfile(zip_path)
  println("Downloading ABS ASGS boundary file…")
  Downloads.download(zip_url, zip_path)
  println("  Saved: ", zip_path)
end

# ## Inspect
#
# GDAL's `/vsizip/` virtual filesystem lets us read directly from the ZIP.
# `list_components` prints the attribute table augmented with per-ring
# statistics (area, bounding box, point count) — useful for deciding which
# rows and rings to select.

input  = "/vsizip/$zip_path/AUS_2021_AUST_GDA2020.shp"
output = joinpath(data_dir, "australia")

comps = list_components(input)
sort!(comps, :area, rev = true)
println(first(comps, 5))

# ## 2D geometry and mesh
#
# `AUS_CODE21 == "AUS"` selects the continental polygon.
# `ring == 1` picks the mainland (largest component); outer islands such as
# Tasmania have `ring ≥ 2`.
# The 100 km simplification tolerance is appropriate for a continent-scale mesh.

geoms_to_geo(
  input, output;
  select       = row -> row.AUS_CODE21 == "AUS" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 100_000.0),
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  input, output;
  select       = row -> row.AUS_CODE21 == "AUS" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 100_000.0),
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
