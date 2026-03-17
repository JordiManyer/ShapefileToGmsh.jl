# # Spain and Catalonia (2D)
#
# This example downloads NUTS administrative boundaries from Eurostat GISCO
# and produces two separate meshes: mainland Spain (country level, NUTS-0)
# and Catalonia (region level, NUTS-2).
#
# **Features highlighted:**
# - Downloading and reading GeoJSON files from Eurostat GISCO
# - Selecting features by NUTS ID and ring index
# - Composing simplification algorithms with `∘`: `AngleFilter ∘ MinEdgeLength`
#   applies minimum-edge-length first, then removes zig-zag spikes by angle
# - Using different NUTS levels (NUTS-0 vs NUTS-2) for country vs. region
#
# !!! note "NUTS levels"
#     NUTS-0 = countries (e.g. `"ES"` for Spain).
#     NUTS-2 = regions (e.g. `"ES51"` for Catalonia).
#     They are distributed in separate files.
#
# | Spain | Catalonia |
# |:-----:|:---------:|
# | ![Spain mesh](../assets/spain.png) | ![Catalonia mesh](../assets/catalonia.png) |

using GeoGmsh
using Downloads
import GeometryOps as GO

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ## Download
#
# Two NUTS files are needed: NUTS-0 for the country outline and NUTS-2 for
# the regional breakdown.

base_url = "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/"

nuts0_url  = base_url * "NUTS_RG_01M_2024_4326_LEVL_0.geojson"
nuts0_path = joinpath(data_dir, "NUTS_RG_01M_2024_4326_LEVL_0.geojson")

nuts2_url  = base_url * "NUTS_RG_01M_2024_4326_LEVL_2.geojson"
nuts2_path = joinpath(data_dir, "NUTS_RG_01M_2024_4326_LEVL_2.geojson")

if !isfile(nuts0_path)
  println("Downloading NUTS-0 boundaries…")
  Downloads.download(nuts0_url, nuts0_path)
  println("  Saved: ", nuts0_path)
end

if !isfile(nuts2_path)
  println("Downloading NUTS-2 boundaries (~16 MB)…")
  Downloads.download(nuts2_url, nuts2_path)
  println("  Saved: ", nuts2_path)
end

# ## Mainland Spain
#
# The NUTS-0 `"ES"` feature is a MultiPolygon whose largest component
# (`ring == 1`) is the Iberian mainland.
#
# The composed algorithm `AngleFilter(tol=20°) ∘ MinEdgeLength(tol=10 km)`
# first removes short edges (≤ 10 km), then iteratively removes vertices
# where the interior angle is shallower than 20°, eliminating zig-zag spikes
# along the coastline.

println("\n=== Spain (mainland) ===")

println("\nNUTS-0 Spain components (sorted by area):")
comps = list_components(nuts0_path)
comps = filter(row -> row.NUTS_ID == "ES", comps)
sort!(comps, :area, rev = true)
println(comps)

spain_alg = AngleFilter(tol = 20.0) ∘ MinEdgeLength(tol = 10_000.0)

geoms_to_geo(
  nuts0_path, joinpath(data_dir, "spain");
  select       = row -> row.NUTS_ID == "ES" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = spain_alg,
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  nuts0_path, joinpath(data_dir, "spain");
  select       = row -> row.NUTS_ID == "ES" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = spain_alg,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)

# ## Catalonia
#
# Catalonia (`"ES51"`) is a NUTS-2 region on the north-east coast of Spain.
# We use the finer NUTS-2 file, with `MinEdgeLength` only (the boundary is
# smoother at this scale so angle filtering is not needed).

println("\n=== Catalonia (ES51) ===")

println("\nNUTS-2 Catalonia components (sorted by area):")
comps2 = list_components(nuts2_path)
comps2 = filter(row -> row.NUTS_ID == "ES51", comps2)
sort!(comps2, :area, rev = true)
println(comps2)

geoms_to_geo(
  nuts2_path, joinpath(data_dir, "catalonia");
  select       = row -> row.NUTS_ID == "ES51" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 10_000.0),
  bbox_size    = 100.0,
  verbose      = true,
)

geoms_to_msh(
  nuts2_path, joinpath(data_dir, "catalonia");
  select       = row -> row.NUTS_ID == "ES51" && row.ring == 1,
  target_crs   = "EPSG:3857",
  simplify_alg = MinEdgeLength(tol = 10_000.0),
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
