## Population Water Demand Component
#
# Determines domestic water demands, as a function of the population.

using CSV
using Mimi
using DataFrames
include("lib/readconfig.jl")
include("lib/datastore.jl")

if config["dataset"] == "counties"
    populations = CSV.read(loadpath("county-pops.csv"), missingstring="NA")
else
    populations = CSV.read(loadpath("county-pops.csv"));
end

function getpopulation(fips, year)
    if typeof(fips) <: Int
        pop = populations[(populations[:FIPS] .== fips) .& (populations[:year] .== year), :population]
    else
        pop = populations[(populations[:FIPS] .== parse(Int64, fips)) .& (populations[:year] .== year), :population]
    end
    if length(pop) != 1
        NA
    else
        pop[1]
    end
end

function getpopulation_yeardata(year)
    populations[populations[:year] .== year, :]
end

function getpopulation_withinyear(fips, yeardata)
    if typeof(fips) <: Int
        pop = yeardata[yeardata[:FIPS] .== fips, :population]
    else
        pop = yeardata[yeardata[:FIPS] .== parse(Int64, fips), :population]
    end
    if length(pop) != 1
        NA
    else
        pop[1]
    end
end

population_2010data = getpopulation_yeardata(2010)
configtransforms["repcap"] = (fips, x) -> getpopulation_withinyear(fips, population_2010data) * x

@defcomp PopulationDemand begin
    regions = Index()
    allcrops = Index()

    # Internal
    # Resource demands
    population = Parameter(index=[regions, time], unit="person")

    cropinterestperperson = Parameter(index=[allcrops], unit="lborbu/person")

    # Amount of crops that would buy
    cropinterest = Variable(index=[regions, allcrops, time], unit="lborbu")

    """
    Compute the `surplus` as `available` - `demand`.
    """
    function run_timestep(p, v, d, t)
        for rr in d.regions
            for cc in d.allcrops
                v.cropinterest[rr, cc, tt] = p.population[rr, tt] * p.cropinterestperperson[cc]
            end
        end
    end
end

"""
Add a populationdemand component to the model.
"""
function initpopulationdemand(m::Model, years)
    populationdemand = add_comp!(m, PopulationDemand)

    # How much of each crop will people buy per year?
    populationdemand[:cropinterestperperson] = (365.25/12 * config["timestep"]) * [crop_interest[crop] for crop in allcrops]

    allpops = Matrix{Float64}(m.indices_counts[:regions], length(years))
    totalpop = 0
    for tt in 1:length(years)
        year = years[tt]
        population_yeardata = getpopulation_yeardata(year)
        population_before = getpopulation_yeardata(div(year, 10) * 10)
        population_after = getpopulation_yeardata((div(year, 10) + 1) * 10)
        for ii in 1:m.indices_counts[:regions]
            fips = m.indices_values[:regions][ii]
            pop = getpopulation_withinyear(fips, population_yeardata)
            if isna.(pop) && mod(year, 10) != 0
                # Estimate from decade
                pop0 = getpopulation_withinyear(fips, population_before)
                pop1 = getpopulation_withinyear(fips, population_after)
                if isna.(pop1)
                    pop = pop0
                else
                    pop = pop0 * (1 - mod(year, 10) / 10) + pop1 * mod(year, 10) / 10
                end
            end
            if isna.(pop)
                pop = 0.
            end
            allpops[ii, tt] = pop
            totalpop += pop
        end
    end

    populationdemand[:population] = allpops

    populationdemand
end

function constraintoffset_populationdemand_cropinterest(m::Model)
    gen(rr, cc, tt) = -m.md.external_params[:population].values[rr, tt] * m.md.external_params[:cropinterestperperson].values[cc]
    hallsingle(m, :PopulationDemand, :cropinterest, gen)
end
