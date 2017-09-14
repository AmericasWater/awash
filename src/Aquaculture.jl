# The Freshwater Aquaculture component.
#
# It uses aquaculture production data as a baseline, which is then allowed to change with temperature and production.

using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp Aquaculture begin
    regions = Index()

    # The basic pattern of aquaculture (could vary in time)
    demand_baseline = Parameter(index=[regions, time], unit="1000 m^3")

    # The effect of production on demand
    production_baseline = Parameter(index=[time], unit="MT") # 299,396
    production = Parameter(index=[time], unit="MT")

    production_adjusted = Variable(index=[regions, time], unit="1000 m^3")

    entrant_demandpermt = Parameter(unit="1000 m^3 / MT") # water demand per additional MT
    entrant_demand = Variable(index=[regions, time], unit="1000 m^3")

    # The effect of temperature on evaporation
    temperature_baseline = Parameter(index=[regions, time], unit="degreeC")
    temperature = Parameter(index=[regions, time], unit="degreeC")

    temperature_demandperdeg = Parameter(unit="1000 m^3 / degreeC") # water demand per addition C
    temperature_anomaly = Variable(index=[regions, time], unit="1000 m^3")

    # Demand combining the two effects
    demand = Variable(index=[regions, time], unit="1000 m^3")
end

function run_timestep(c::Aquaculture, tt::Int)
    v, p, d = getvpd(c)

    # Production effect
    v.production_adjusted[:, tt] = (p.production[tt] / p.production_baseline[tt]) * p.demand_baseline[:, tt]

    if tt > 1 && p.production[tt] > p.production[tt-1]
        mygrowth = p.production[tt] - p.production[tt-1]
        theirgrowth = p.production_baseline[tt] - p.production_baseline[tt-1]
        # Only include this if we have more entrants than they estimate fewer than me
        if mygrowth > theirgrowth
            # Pattern according to v.production_anomaly[:, tt]
            v.entrant_demand[:, tt] = (mygrowth - theirgrowth) * entrant_demandpermt * v.production_anomaly[:, tt] / sum(v.production_anomaly[:, tt])
        end
    else
        v.entrant_demand[:, tt] = 0
    end

    # Temperature effect
    v.temperature_anomaly[:, tt] = (p.temperature[:, tt] - p.temperature_baseline[:, tt]) * p.temperature_demandperdeg

    # Combine all effects
    v.demand[:, tt] = v.production_adjusted[:, tt] + v.entrant_demand[:, tt] + v.temperature_anomaly[:, tt]
end

function initaquaculture(m::Model)
    aquaculture = addcomponent(m, Aquaculture);

    scaling = config["timestep"] / 12.

    # Baseline from USGS
    demand_baseline = repeat(convert(Vector{Float64}, readtable(datapath("aquaculture/usgsextract.csv"))[:AQ_WFrTo]) * scaling, outer=[1, m.indices_counts[:time]])
    aquaculture[:demand_baseline] = demand_baseline

    # Production data from Fisheries of the United States
    production = readtable(datapath("aquaculture/production.csv"))
    production_baseline = repeat(production[production[:year] .== 2010, :production] * scaling, outer=[numsteps])
    aquaculture[:production_baseline] = production_baseline
    aquaculture[:production] = repeat(production[production[:year] .>= 2010, :production] * scaling, inner=[round.(Int64, 1. / scaling)])

    # Demand per entrant as average demand
    aquaculture[:entrant_demandpermt] = sum(demand_baseline) / mean(production_baseline)

    # We don't have temperature data in the model yet!
    aquaculture[:temperature_baseline] = zeros(numcounties, numsteps)
    aquaculture[:temperature] = zeros(numcounties, numsteps)
    aquaculture[:temperature_demandperdeg] = 0.

    aquaculture
end
