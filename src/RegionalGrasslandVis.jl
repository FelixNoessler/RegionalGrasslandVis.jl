module RegionalGrasslandVis

using Statistics
using GLMakie
using Unitful

greet() = print("Hello, here is RegionalGrasslandVis! :)")

include("dashboard.jl")
include("plotting_functions.jl")

end # module RegionalGrasslandVis
