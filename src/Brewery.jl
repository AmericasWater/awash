# The Brewery Component
# This is how we make beer

using Mimi

@defcomp Brewery begin
    region = Index()

    production = Parameter(index=[region, time], unit="liter")

    hopsdemand = Variable(index=[region, time], unit="MT")
    waterdemand = Variable(index=[region, time], unit="1000 m^3")
end

function run_timestep(c::Brewery, tt::Int64)
    v, p, d = getvpd(c)

    v.hopsdemand[:, tt] = .07 * p.production[:, tt]
    v.waterdemand[:, tt] = 2 * p.production[:, tt] / 1e6
end

function initbrewer(m::Model)
    brewery = addcomponent(m, Brewery)

    production = readtable("../data/county-info.csv")[:, :LandArea_sqmi]

    brewery[:production] = repeat(convert(Vector{Float64}, dropna(production)), outer=[1, numsteps])
end
