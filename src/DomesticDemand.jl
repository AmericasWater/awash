# The domestic demand component

using Mimi
using DataFrames

populations = readtable("../data/county-pops.csv", eltypes=[Int64, UTF8String, UTF8String, Int64, Float64]);

function getpopulation(fips, year)
    pop = populations[(populations[:FIPS] .== parse(Int64, fips)) & (populations[:year] .== year), :population]
    if length(pop) != 1
        NA
    else
        pop[1]
    end
end

@defcomp DomesticDemand begin
    regions = Index()
    crops = Index()

    # Internal
    # Resource demands
    population = Parameter(index=[regions, time])

    waterdemandperperson = Parameter()
    cropinterestperperson = Parameter(index=[crops])

    # Demanded water
    waterdemand = Variable(index=[regions, time])
    # Amount of crops that would buy
    cropinterest = Variable(index=[regions, crops, time])
end

"""
Compute the `surplus` as `available` - `demand`.
"""
function timestep(c::DomesticDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.waterdemand[rr, tt] = p.population[rr, tt] * p.waterdemandperperson
        for cc in d.crops
            v.cropinterest[rr, cc, tt] = p.population[rr, tt] * p.cropinterestperperson[cc]
        end
    end
end

"""
Add a domesticdemand component to the model.
"""
function initdomesticdemand(m::Model, years)
    domesticdemand = addcomponent(m, DomesticDemand)

    # Blue water from http://waterfootprint.org/media/downloads/Hoekstra_and_Chapagain_2006.pdf
    domesticdemand[:waterdemandperperson] = 575 * 365.25 * .001 # m^3 / yr

    # How much of each crop will people buy per year?
    domesticdemand[:cropinterestperperson] = 365.25 * [1., # .2 pounds meat (alfalfa / 10) per day
                                                       1., # .2 pounds meat (otherhay / 10) per day
                                                       .005, # bushels Barley per day
                                                       .005, # bushels Barley.Winter per day
                                                       .05, # bushels Maize per day
    .01, # pounds Sorghum per day
    .02, # bushels Soybeans per day
    .05, # bushels Wheat per day
    .05] # bushels Wheat.Winter per day

    allpops = Matrix{Float64}(m.indices_counts[:regions], length(years))
    totalpop = 0
    for tt in 1:length(years)
        year = years[tt]
        for ii in 1:m.indices_counts[:regions]
            fips = m.indices_values[:regions][ii]
            pop = getpopulation(fips, year)
            if isna(pop) && mod(year, 10) != 0
                # Estimate from decade
                pop0 = getpopulation(fips, div(year, 10) * 10)
                pop1 = getpopulation(fips, (div(year, 10) + 1) * 10)
                if isna(pop1)
                    pop = pop0
                else
                    pop = pop0 * (1 - mod(year, 10) / 10) + pop1 * mod(year, 10) / 10
                end
            end
            if isna(pop)
                pop = 0.
            end
            allpops[ii, tt] = pop
            totalpop += pop
        end
    end

    domesticdemand[:population] = allpops

    domesticdemand
end

function constraintoffset_domesticdemand_waterdemand(m::Model)
    gen(rr, tt) = m.parameters[:population].values[rr, tt] * m.parameters[:waterdemandperperson].value
    hallsingle(m, :DomesticDemand, :waterdemand, gen)
end

function constraintoffset_domesticdemand_cropinterest(m::Model)
    gen(rr, cc, tt) = -m.parameters[:population].values[rr, tt] * m.parameters[:cropinterestperperson].values[cc]
    hallsingle(m, :DomesticDemand, :cropinterest, gen)
end

