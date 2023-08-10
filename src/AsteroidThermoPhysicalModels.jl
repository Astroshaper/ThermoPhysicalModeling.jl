module AsteroidThermoPhysicalModels

using LinearAlgebra
using StaticArrays
using Statistics

import SPICE

using DataFrames
using ProgressMeter

using FileIO
using JLD2


include("constants.jl")
export AU, G, GM☉, M☉, SOLAR_CONST, c₀, σ_SB
export MERCURY, VENUS, EARTH, MARS, JUPITER, SATURN, URANUS, NEPTUNE
export CERES, PLUTO, ERIS
export MOON
export RYUGU, DIDYMOS, DIMORPHOS

include("obj.jl")
include("shape.jl")
include("facet.jl")
export ShapeModel

include("thermophysics.jl")
include("TPM.jl")
include("energy_flux.jl")
include("non_grav.jl")
export init_temperature!, run_TPM!

include("roughness.jl")

end # module AsteroidThermoPhysicalModels
