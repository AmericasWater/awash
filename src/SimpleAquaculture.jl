# The Freshwater Aquaculture component.
#
# It uses aquaculture production data as a baseline, with aggregate production.

using CSV
using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp Aquaculture begin
    regions = Index()

    # The basic pattern of aquaculture (could vary in time)
    demand_baseline = Parameter(index=[regions, time], unit="1000 m^3")

    # The effect of production on demand
    production_baseline = Parameter(index=[time], unit="MT") # 299,396 in 2010
    production = Parameter(index=[time], unit="MT")

    # Demand combining the two effects
    demand = Variable(index=[regions, time], unit="1000 m^3")
end

function run_timestep(c::Aquaculture, tt::Int)
    v, p, d = getvpd(c)

    # Scale with production
    v.demand[:, tt] = (p.production[tt] / p.production_baseline[tt]) * p.demand_baseline[:, tt]
end

function initaquaculture(m::Model)
    aquaculture = addcomponent(m, Aquaculture);

    scaling = config["timestep"] / 12.

    # Baseline from USGS
    aquaculture[:demand_baseline] = repeat(convert(Vector{Float64}, CSV.read(datapath("aquaculture/usgsextract.csv"))[:AQ_WFrTo]) * scaling, outer=[1, m.indices_counts[:time]])

    # Production data from Fisheries of the United States
    production = CSV.read(datapath("aquaculture/production.csv"))

    aquaculture[:production_baseline] = repeat(production[production[:year] .== 2010, :production] * scaling, outer=[numsteps])
    aquaculture[:production] = repeat(production[production[:year] .>= 2010, :production] * scaling, inner=[round.(Int64, 1. / scaling)])

    aquaculture
end
