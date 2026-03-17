"""
Everest terrain mesh example.

Meshes the terrain around Mount Everest using a bounding box defined in
geographic coordinates (EPSG:4326), reprojected to UTM zone 45N
(EPSG:32645, metres) for physically consistent distances and elevations.

DEM tiles used (1°×1° each, GLO-30 convention):
  N27_00_E086_00, N27_00_E087_00,
  N28_00_E086_00, N28_00_E087_00

Bounding box of interest (EPSG:4326):
  86.551666, 27.712710, 87.301483, 28.214870
  (small padding added to avoid edge effects)
"""

using GeoGmsh
using Downloads
import GDAL_jll

data_dir = joinpath(@__DIR__, "..", "data")
mkpath(data_dir)

# ---------------------------------------------------------------------------
# 1. Write bounding-box polygon as GeoJSON (EPSG:4326)
# ---------------------------------------------------------------------------

lon_min, lat_min = 86.50, 27.66
lon_max, lat_max = 87.35, 28.26

bbox_path = joinpath(data_dir, "everest_bbox.geojson")
open(bbox_path, "w") do io
  write(io, """
{
  "type": "FeatureCollection",
  "features": [{
    "type": "Feature",
    "geometry": {
      "type": "Polygon",
      "coordinates": [[[$(lon_min),$(lat_min)],[$(lon_max),$(lat_min)],
                        [$(lon_max),$(lat_max)],[$(lon_min),$(lat_max)],
                        [$(lon_min),$(lat_min)]]]
    },
    "properties": {}
  }]
}
""")
end

# ---------------------------------------------------------------------------
# 2. Download Copernicus GLO-30 DEM tiles
# ---------------------------------------------------------------------------

tiles = [
  ("N27_00", "E086_00"), ("N27_00", "E087_00"),
  ("N28_00", "E086_00"), ("N28_00", "E087_00"),
]

const DEM_BASE = "https://copernicus-dem-30m.s3.amazonaws.com"

println("Downloading DEM tiles…")
tile_paths = String[]
for (lat, lon) in tiles
  name = "Copernicus_DSM_COG_10_$(lat)_$(lon)_DEM"
  url  = "$DEM_BASE/$name/$name.tif"
  dest = joinpath(data_dir, "$name.tif")
  if isfile(dest)
    print("  $name  (cached)\n")
  else
    print("  $name  downloading… ")
    try
      Downloads.download(url, dest)
      println("ok")
    catch e
      println("FAILED: $e")
      continue
    end
  end
  push!(tile_paths, dest)
end
println("$(length(tile_paths)) tile(s) ready.")

# ---------------------------------------------------------------------------
# 3. Mosaic DEM tiles into a single VRT (EPSG:4326)
# ---------------------------------------------------------------------------

dem_vrt_4326 = joinpath(data_dir, "everest_dem_4326.vrt")
GDAL_jll.gdalbuildvrt_exe() do exe
  run(`$exe $dem_vrt_4326 $tile_paths`)
end
println("Mosaic (EPSG:4326): ", dem_vrt_4326)

# ---------------------------------------------------------------------------
# 4. Reproject DEM to UTM zone 45N (EPSG:32645, metres)
# ---------------------------------------------------------------------------

dem_tif_utm = joinpath(data_dir, "everest_dem_32645.tif")
if !isfile(dem_tif_utm)
  println("Reprojecting DEM to EPSG:32645…")
  GDAL_jll.gdalwarp_exe() do exe
    run(`$exe -t_srs EPSG:32645 -tr 30 30 -r bilinear
             -co COMPRESS=DEFLATE
             $dem_vrt_4326 $dem_tif_utm`)
  end
  println("  Saved: ", dem_tif_utm)
end

# ---------------------------------------------------------------------------
# 5. Terrain mesh
# ---------------------------------------------------------------------------

output = joinpath(data_dir, "everest")

geoms_to_msh_3d(
  bbox_path, dem_tif_utm, output;
  target_crs   = "EPSG:32645",
  simplify_alg = MinEdgeLength(tol = 500.0),
  mesh_size    = 500.0,
  nodata_fill  = 0.0,
  verbose      = true,
)
