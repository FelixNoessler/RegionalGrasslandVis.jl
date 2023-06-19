module RegionalGrasslandVis

using Statistics
using GLMakie
using Unitful
import Dates


makie_theme = Theme(
    fontsize=18,
    Axis=(xgridvisible=false, ygridvisible=false,
        topspinevisible=false, rightspinevisible=false),
    GLMakie=(title="Grassland Simulation",
             focus_on_show=true)
)

function set_global_theme(; theme=makie_theme)
    set_theme!(makie_theme)
end


include("dashboard.jl")
include("dashboard_plotting.jl")
include("functional_response.jl")
include("reducer_functions.jl")
include("abiotic.jl")
include("landuse.jl")
include("helper_functions.jl")

end # module RegionalGrasslandVis
