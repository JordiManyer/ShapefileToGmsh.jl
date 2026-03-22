using Documenter
using Literate
using GeoGmsh

# ---------------------------------------------------------------------------
# Generate example pages from examples/*.jl using Literate.jl
# ---------------------------------------------------------------------------

examples_src = joinpath(@__DIR__, "..", "examples")
examples_out = joinpath(@__DIR__, "src", "examples")
mkpath(examples_out)

# Map filenames → sidebar titles (order controls page order)
example_titles = [
  "naturalearth" => "NaturalEarth (2D)",
  "australia"    => "Australia (2D)",
  "spain"        => "Spain & Catalonia (2D)",
  "iberia"       => "Iberian Peninsula (2D)",
  "montblanc"    => "Mont Blanc (3D terrain)",
  "everest"      => "Everest (3D terrain)",
]

for f in sort(readdir(examples_src))
  endswith(f, ".jl") || continue
  Literate.markdown(joinpath(examples_src, f), examples_out;
    execute = false,
    flavor  = Literate.CommonMarkFlavor(),
  )
end

example_pages = [
  title => "examples/$stem.md"
  for (stem, title) in example_titles
]

# ---------------------------------------------------------------------------
# Generate documentation with Documenter.jl
# ---------------------------------------------------------------------------

makedocs(
  sitename = "GeoGmsh.jl",
  format   = Documenter.HTML(
    prettyurls = get(ENV, "CI", nothing) == "true",
  ),
  modules  = [GeoGmsh],
  pages    = [
    "Home"           => "index.md",
    "Pipeline guide" => "pipeline.md",
    "Examples"       => example_pages,
    "API reference"  => "api.md",
  ],
  checkdocs = :exports,
  warnonly  = true,
)

deploydocs(
  repo         = "github.com/JordiManyer/GeoGmsh.jl.git",
  devbranch    = "master",
  push_preview = true,
)
