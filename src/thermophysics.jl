

# ****************************************************************
#                   Thermophysical properties
# ****************************************************************

"""
- `A_B`   : Bond albedo
- `A_TH`  : Albedo at thermal radiation wavelength
- `k`     : Thermal conductivity
- `ρ`     : Density [kg/m³]
- `Cp`    : Heat capacity [J/kg/K]
- `ϵ`     : Emissivity
- `P`     : Rotation period [s]
- `l`     : Thermal skin depth
- `Γ`     : Thermal inertia
- `Δt`    : Time step
- `t_bgn` : Start time of the simulation
- `t_end` : End time of the simulation
- `Nt`    : Number of time step
- `Δz`    : Depth step
- `z_max` : Maximum depth for themal simualtion
- `Nz`    : Number of depth step
- `λ`     : Non-dimensional coefficient for heat diffusion equation
"""
struct ParamsThermo{T1, T2}
    A_B  ::T1
    A_TH ::T1
    k    ::T1
    ρ    ::T1
    Cp   ::T1
    ϵ    ::T1
    P    ::T1
    l    ::T1
    Γ    ::T1
    Δt   ::T1
    t_bgn::T1
    t_end::T1
    Nt   ::T2
    Δz   ::T1
    z_max::T1
    Nz   ::T2
    λ    ::T1
end


function ParamsThermo(; A_B, A_TH, k, ρ, Cp, ϵ, P, Δt, t_bgn, t_end, Δz, z_max)
    l = thermal_skin_depth(P, k, ρ, Cp)
    Γ = thermal_inertia(k, ρ, Cp)
    
    Δt /= P
    t_bgn /= P
    t_end /= P
    Nt = length(t_bgn:Δt:t_end)
    
    Δz /= l
    z_max /= l
    Nz = length(0:Δz:z_max)
    
    λ = 1/4π * (Δt/Δz^2)
    λ > 0.5 && println("λ should be smaller than 0.5 for convergence.")
    
    ParamsThermo(A_B, A_TH, k, ρ, Cp, ϵ, P, l, Γ, Δt, t_bgn, t_end, Nt, Δz, z_max, Nz, λ)
end


function Base.show(io::IO, params::ParamsThermo)
    @unpack A_B, A_TH, k, ρ, Cp, ϵ, P, l, Γ, Δt, t_bgn, t_end, Nt, Δz, z_max, Nz, λ = params
    
    println(io, "Thermophysical parameters")
    println("-------------------------")
    
    println("A_B   : ", A_B)
    println("A_TH  : ", A_TH)
    println("k     : ", k)
    println("ρ     : ", ρ)
    println("Cp    : ", Cp)
    println("ϵ     : ", ϵ)
    println("P     : ", P)
    println("l     : ", l)
    println("Γ     : ", Γ)
    println("Δt    : ", Δt)
    println("t_bgn : ", t_bgn)
    println("t_end : ", t_end)
    println("Nt    : ", Nt)
    println("Δz    : ", Δz)
    println("z_max : ", z_max)
    println("Nz    : ", Nz)
    println("λ     : ", λ)
end


"""
    thermal_skin_depth(P, k, ρ, Cp) -> l_2π

# Arguments
- `P`  :
- `k`  :
- `ρ`  :
- `Cₚ` :

# Return
`l_2π` : Thermal skin depth
"""
thermal_skin_depth(P, k, ρ, Cp) = √(4π * P * k / (ρ * Cp))
thermal_skin_depth(params) = thermal_skin_depth(params.P, params.k, params.ρ, params.Cp)


"""
    thermal_inertia(k, ρ, Cp) -> Γ

# Arguments
- `k`  :
- `ρ`  :
- `Cp` :

# Return
`Γ` : Thermal inertia
"""
thermal_inertia(k, ρ, Cp) = √(k * ρ * Cp)
thermal_inertia(params) = thermal_inertia(params.k, params.ρ, params.Cp)


# ****************************************************************
#                      1D heat conduction
# ****************************************************************

"""
    update_temps!(Tⱼ, Tⱼ₊₁, F, params)

Update temerature profie based on 1-D heat diffusion

# Arguments
- `Tⱼ`     : Temperatures
- `Tⱼ₊₁`   : Temperatures at the next time step
- `F`      : Energy flux to the surface 
- `params` : Thermophysical parameters

i : index of depth
j : index of time step

for i in 2:length(Tⱼ)-1
    Tⱼ₊₁[i] = (1-2λ)*Tⱼ[i] + λ*(Tⱼ[i+1] + Tⱼ[i-1])
end
"""



function update_temps!(shape, params)
    @unpack A_B, A_TH, λ, Δz, Γ, P, ϵ = params

    for facet in shape.facets
        update_temps!(facet::Facet, A_B, A_TH, λ, Δz, Γ, P, ϵ)
    end
end

function update_temps!(facet::Facet, A_B, A_TH, λ, Δz, Γ, P, ϵ)
    F_total = flux_total(facet, A_B, A_TH)

    Tⱼ   = facet.temps
    Tⱼ₊₁ = facet._temps_

    @. Tⱼ₊₁[begin+1:end-1] = @views (1-2λ)*Tⱼ[begin+1:end-1] + λ*(Tⱼ[begin+2:end] + Tⱼ[begin:end-2])

    update_surf_temp!(Tⱼ₊₁, F_total, Δz, Γ, P, ϵ)  # Surface boundary condition (Radiation)
    Tⱼ₊₁[end] = Tⱼ₊₁[end-1]                        # Internal boundary condition (Insulation)
        
    Tⱼ .= Tⱼ₊₁
end

"""
    update_surf_temp!(T, F_total, Δz, Γ, P, ϵ)

# Arguments
- `T`       : 1-D array of temperatures
- `F_total` : Total energy flux to the surface facet 
- `Δz`      : 
- `Γ`       : Thermal inertia
- `P`       : Rotation period
- `ϵ`       : Emissivity

Update surface temperature under radiative boundary condition using Newton's method
"""
function update_surf_temp!(T, F_total, Δz, Γ, P, ϵ)
    for _ in 1:20
        T_pri = T[begin]

        f = F_total + Γ / √(4π * P) * (T[begin+1] - T[begin]) / Δz - ϵ*σ_SB*T[begin]^4
        df = - Γ / √(4π * P) / Δz - 4*ϵ*σ_SB*T[begin]^3             
        T[begin] -= f / df

        err = abs(1 - T_pri / T[begin])
        err < 1e-10 && return
    end
end

"""
    flux_total(facet::Facet, A_B::Real, A_TH::Real) -> F_total

# Arguments
- `facet` : surface facet (`Facet`)
- `A_B`   : Bond albedo
- `A_TH`  : Albedo in thermal infrared wavelength

Total energy absorbed by the facet
"""
function flux_total(facet::Facet, A_B::Real, A_TH::Real)
    F_sun  = facet.flux.sun
    F_scat = facet.flux.scat
    F_rad  = facet.flux.rad
    
    F_total = (1 - A_B)*(F_sun + F_scat) + (1 - A_TH)*F_rad
end


# ****************************************************************
#
# ****************************************************************


"""
    intensity(λ, T) -> I

Intensity of radiation at a wavelength λ and tempertature T
according to the Planck function
"""
function intensity(λ, T)
    h = 6.62607015e-34  # Planck constant [J⋅s]
    k = 1.380649e-23    # Boltzmann's constant [J/K]

    I = 2 * h * c^2 / λ^5 / (exp(h * c₀ / (λ * k * T)) - 1)
end


ν2λ(ν) = c₀ / ν
λ2ν(λ) = c₀ / λ

