"""
NaturalEarth example — no download required.

Uses NaturalEarth.jl to load world country boundaries directly into Julia
(no shapefiles to manage) and produces meshes for two cases:

1. All world countries at 110 m scale — coarse global mesh.
2. European countries at 10 m scale — finer regional mesh.

NaturalEarth.jl returns GeoInterface-compatible data, so it can be passed
directly to geoms_to_geo / geoms_to_msh without any file I/O.
"""

using GeoGmsh
using NaturalEarth

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ---------------------------------------------------------------------------
# 1. World — 110 m scale (coarse, fast)
# ---------------------------------------------------------------------------

println("=== World (110 m) ===")
world = naturalearth("admin_0_countries", 110)

geoms_to_geo(
  world, joinpath(data_dir, "world");
  target_crs   = "EPSG:3857",
  simplify_tol = 50_000.0,    # ≥ 50 km
  bbox_size    = 200.0,
  mesh_size    = 5.0,
  verbose      = true,
)

geoms_to_msh(
  world, joinpath(data_dir, "world");
  target_crs   = "EPSG:3857",
  simplify_tol = 50_000.0,
  bbox_size    = 200.0,
  mesh_size    = 5.0,
  verbose      = true,
)

# ---------------------------------------------------------------------------
# 2. Europe — 10 m scale (finer)
# ---------------------------------------------------------------------------

println("\n=== Europe (10 m) ===")
europe_raw = naturalearth("admin_0_countries", 10)

# Filter: rows where the CONTINENT column is "Europe", excluding Russia
# (which spans Eurasia and dominates the bounding box).
is_europe = row -> get(row, :CONTINENT, "") == "Europe" &&
                   get(row, :NAME, "")      != "Russia"

geoms_to_geo(
  europe_raw, joinpath(data_dir, "europe");
  select       = is_europe,
  target_crs   = "EPSG:3035",   # ETRS89 LAEA — equal-area, metres
  simplify_tol = 10_000.0,      # ≥ 10 km
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)

geoms_to_msh(
  europe_raw, joinpath(data_dir, "europe");
  select       = is_europe,
  target_crs   = "EPSG:3035",
  simplify_tol = 10_000.0,
  bbox_size    = 100.0,
  mesh_size    = 2.0,
  verbose      = true,
)
