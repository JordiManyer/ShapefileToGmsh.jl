module PipelineTests

using GeoGmsh
import ArchGDAL
import GeoInterface as GI
using Test

const FIXTURE_SHP = joinpath(@__DIR__, "meshes", "fixture.shp")
const TMP_NAME    = joinpath(tempdir(), "test_geogmsh_pipeline")

# Write a tiny synthetic GeoTIFF (5×6 pixels, constant 100 m elevation)
# covering the unit square [0,1]×[0,1] with padding, for 3D volume tests.
function _write_test_dem(path)
  ArchGDAL.create(path;
    driver = ArchGDAL.getdriver("GTiff"),
    width  = 5,
    height = 6,
    nbands = 1,
    dtype  = Float64,
  ) do ds
    ArchGDAL.setgeotransform!(ds, [-0.5, 0.5, 0.0, 2.0, 0.0, -0.5])
    ArchGDAL.write!(ds, fill(100.0, 5, 6), 1)
  end
end

function run()
  # geoms_to_geo from a DataFrame: reproject + simplify + rescale
  df = read_geodata(FIXTURE_SHP)
  geoms_to_geo(df, TMP_NAME;
    target_crs   = "EPSG:3857",
    simplify_alg = MinEdgeLength(tol = 50_000.0),
    bbox_size    = 100.0,
    mesh_size    = 5.0,
  )
  @test isfile(TMP_NAME * ".geo")
  rm(TMP_NAME * ".geo")

  # Skip reprojection
  geoms_to_geo(df, TMP_NAME; target_crs = nothing, mesh_size = 1.0)
  @test isfile(TMP_NAME * ".geo")
  rm(TMP_NAME * ".geo")

  # select kwarg filters rows before processing
  geoms_to_geo(df, TMP_NAME;
    target_crs = nothing,
    select     = row -> string(row.NAME) == "Alpha",
    mesh_size  = 1.0,
  )
  @test isfile(TMP_NAME * ".geo")
  rm(TMP_NAME * ".geo")

  # backward-compat wrapper
  shapefile_to_geo(FIXTURE_SHP, TMP_NAME;
    target_crs = nothing, mesh_size = 1.0, verbose = false)
  @test isfile(TMP_NAME * ".geo")
  rm(TMP_NAME * ".geo")

  # geoms_to_geo from raw GeoInterface geometry (no CRS)
  poly = GI.Polygon([GI.LinearRing([(0.,0.),(1.,0.),(1.,1.),(0.,1.),(0.,0.)])])
  geoms_to_geo(poly, TMP_NAME; target_crs = nothing, mesh_size = 0.1)
  @test isfile(TMP_NAME * ".geo")
  rm(TMP_NAME * ".geo")

  # geoms_to_msh_3d_volume: depth kwarg
  tmpdem = tempname() * ".tif"
  _write_test_dem(tmpdem)
  geoms_to_msh_3d_volume(poly, tmpdem, TMP_NAME;
    target_crs = nothing,
    mesh_size  = 0.1,
    depth      = 0.5,
    verbose    = false,
  )
  @test isfile(TMP_NAME * ".msh")
  content = read(TMP_NAME * ".msh", String)
  @test occursin("\$PhysicalNames", content)
  rm(TMP_NAME * ".msh")

  # geoms_to_msh_3d_volume: z_bottom kwarg
  geoms_to_msh_3d_volume(poly, tmpdem, TMP_NAME;
    target_crs = nothing,
    mesh_size  = 0.1,
    z_bottom   = -1.0,
    verbose    = false,
  )
  @test isfile(TMP_NAME * ".msh")
  rm(TMP_NAME * ".msh")
  rm(tmpdem)
end

end # module
