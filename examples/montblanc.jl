"""
Mont Blanc terrain mesh example.

Meshes the terrain around Mont Blanc using a bounding box defined directly
in geographic coordinates (EPSG:4326), reprojected to UTM zone 32N
(EPSG:32632, metres) for physically consistent distances and elevations.

DEM tiles used (1°×1° each, GLO-30 convention):
  N45_00_E006_00 and N45_00_E007_00 — covers 45–46°N, 6–8°E.

Bounding box of interest (EPSG:4326):
  6.785431, 45.785243, 7.044296, 45.956878
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

lon_min, lat_min = 6.73, 45.75
lon_max, lat_max = 7.10, 45.99

bbox_path = joinpath(data_dir, "montblanc_bbox.geojson")
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

tiles = [("N45_00", "E006_00"), ("N45_00", "E007_00")]

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

dem_vrt_4326 = joinpath(data_dir, "montblanc_dem_4326.vrt")
GDAL_jll.gdalbuildvrt_exe() do exe
  run(`$exe $dem_vrt_4326 $tile_paths`)
end
println("Mosaic (EPSG:4326): ", dem_vrt_4326)

# ---------------------------------------------------------------------------
# 4. Reproject DEM to UTM zone 32N (EPSG:32632, metres)
# ---------------------------------------------------------------------------

dem_tif_utm = joinpath(data_dir, "montblanc_dem_32632.tif")
if !isfile(dem_tif_utm)
  println("Reprojecting DEM to EPSG:32632…")
  GDAL_jll.gdalwarp_exe() do exe
    run(`$exe -t_srs EPSG:32632 -tr 30 30 -r bilinear
             -co COMPRESS=DEFLATE
             $dem_vrt_4326 $dem_tif_utm`)
  end
  println("  Saved: ", dem_tif_utm)
end

# ---------------------------------------------------------------------------
# 5. Terrain mesh
# ---------------------------------------------------------------------------

output = joinpath(data_dir, "montblanc")

geoms_to_msh_3d(
  bbox_path, dem_tif_utm, output;
  target_crs   = "EPSG:32632",
  simplify_alg = MinEdgeLength(tol = 500.0),
  mesh_size    = 500.0,
  nodata_fill  = 0.0,
  verbose      = true,
)
