## Irrigation-invariate Agriculture Component
#
# Calculates the water demands for agriculture where irrigation demand
# is a constant function of area.

using DataFrames
using Mimi

include("lib/agriculture.jl")

@defcomp UnivariateAgriculture begin
    year = Index()
    regions = Index()
    unicrops = Index()

    # Optimized
    # Land area appropriated to each crop
    totalareas = Parameter(index=[regions, unicrops, year], unit="Ha") # vs. year

    # Internal
    # Yield per hectare
    yield = Parameter(index=[regions, unicrops, year], unit="none") # vs. year

    # Coefficient on the effects of water deficits
    irrigation_rate = Parameter(index=[regions, unicrops, time], unit="mm")

    # Computed
    # Total agricultural area
    totalareas2 = Variable(index=[regions, unicrops, year], unit="Ha") # copy of totalareas, vs. year
    allagarea = Variable(index=[regions, year], unit="Ha") # vs. year

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    # Total production: lb or bu
    yield2 = Variable(index=[regions, unicrops, year], unit="none") # vs. year
    production = Variable(index=[regions, unicrops, year], unit="lborbu") # vs. year
    #total Op cost
    opcost = Variable(index=[regions, unicrops, time], unit="\$")

    # Total cultivation costs per crop
    unicultivationcost = Variable(index=[regions, unicrops, time], unit="\$")
end

function run_timestep(s::UnivariateAgriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    yys = timeindex2yearindexes(tt)
    contyys = timeindex2contributingyearindexes(tt)

    for rr in d.regions
        totalirrigation = 0.
        allagarea = 0.

        for cc in d.unicrops
            v.totalareas2[rr, cc, contyys] = p.totalareas[rr, cc, contyys]
            allagarea += maximum(p.totalareas[rr, cc, contyys])

            # Calculate irrigation water, summed across all crops: 1 mm * Ha = 10 m^3
            totalirrigation += maximum(p.totalareas[rr, cc, contyys]) * p.irrigation_rate[rr, cc, tt] / 100

            # Calculate total production
            v.yield2[rr, cc, yys] = p.yield[rr, cc, yys]
            v.production[rr, cc, yys] = p.yield[rr, cc, yys] * minimum(p.totalareas[rr, cc, contyys]) * 2.47105 # convert acres to Ha

            # Calculate cultivation costs
            v.unicultivationcost[rr, cc, tt] = mean(p.totalareas[rr, cc, contyys]) * cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha

            # Calculate Operating cost
            v.opcost[rr,cc,tt] = mean(p.totalareas[rr, cc, contyys]) * uniopcost[rr,cc] * 2.47105 * config["timestep"] / 12
        end

        v.totalirrigation[rr, tt] = totalirrigation
        v.allagarea[rr, contyys] = allagarea
    end
end

function initunivariateagriculture(m::Model)
    # precip loaded by weather.jl
    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 2) - cumsum([zeros(numcounties, stepsperyear) precip[:, 1:size(precip)[2] - stepsperyear]],2)

    # Match up values by FIPS
    yield = zeros(numcounties, numunicrops, numyears)
    irrigation_rate = zeros(numcounties, numunicrops, numsteps)

    for cc in 1:numunicrops
        if unicrops[cc] in ["corn.co.rainfed", "corn.co.irrigated", "wheat.co.rainfed", "wheat.co.irrigated"]
            yield[:,cc,:] = read_nareshyields(unicrops[cc])
            irrigation_rate[:,cc,:] = known_irrigationrate[unicrops[cc]]
            continue
        end

        # Load degree day data
        gdds = readtable(findcroppath("agriculture/edds/", unicrops[cc], "-gdd.csv"))
        kdds = readtable(findcroppath("agriculture/edds/", unicrops[cc], "-kdd.csv"))

        for rr in 1:numcounties
            if config["dataset"] == "counties"
                regionid = masterregions[rr, :fips]
            else
                regionid = masterregions[rr, :state]
            end
            if regionid in keys(agmodels[unicrops[cc]])
                thismodel = agmodels[unicrops[cc]][regionid]
                for yy in 1:numyears
                    tts, weights = yearindex2timeindexes(yy)
                    year = index2year(tts[end])
                    if year >= 1949 && year <= 2009
                        numgdds = gdds[rr, Symbol("x$year")]
                        if isna.(numgdds)
                            numgdds = 0
                        end

                        numkdds = kdds[rr, Symbol("x$year")]
                        if isna.(numkdds)
                            numkdds = 0
                        end
                    else
                        numgdds = numkdds = 0
                    end

                    water_demand = water_requirements[unicrops[cc]] * 1000 # mm
                    water_deficit = sum(max.(0., water_demand - rollingsum[rr, tts])) # mm

                    logmodelyield = thismodel.intercept + thismodel.gdds * (numgdds - thismodel.gddoffset) + thismodel.kdds * (numkdds - thismodel.kddoffset) + (thismodel.wreq / 1000) * water_deficit # wreq: delta / m
                    yield[rr, cc, yy] = min(exp(logmodelyield), maximum_yields[unicrops[cc]])

                    irrigation_rate[rr, cc, tts] = unicrop_irrigationrate[unicrops[cc]] + water_deficit * unicrop_irrigationstress[unicrops[cc]] / 1000
                end
            end
        end
    end
    agriculture = addcomponent(m, UnivariateAgriculture)

    agriculture[:yield] = yield
    agriculture[:irrigation_rate] = irrigation_rate

    # Load in planted area
    totalareas = getfilteredtable("agriculture/totalareas.csv")

    if isempty(unicrops)
        agriculture[:totalareas] = zeros(Float64, (nrow(totalareas), 0, numyears))
    else
        constantareas = zeros(numcounties, numunicrops)
        for cc in 1:numunicrops
            if unicrops[cc] in keys(quickstats_planted)
                constantareas[:, cc] = read_quickstats(datapath(quickstats_planted[unicrops[cc]]))
            else
                column = findfirst(Symbol(unicrops[cc]) .== names(totalareas))
                constantareas[:, cc] = totalareas[column] * 0.404686 # Convert to Ha
                constantareas[isna.(totalareas[column]), cc] = 0. # Replace NAs with 0, and convert to float.
            end
        end
        agriculture[:totalareas] = repeat(constantareas, outer=[1, 1, numyears])
    end

    agriculture
end

"""
Get the irrigation rate per timestep for each crop
"""
function getunivariateirrigationrates(crop::AbstractString)
    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 2) - cumsum([zeros(numcounties, stepsperyear) precip[:, 1:size(precip)[2] - stepsperyear]],2)

    water_demand = water_requirements[crop] * 1000 # mm
    water_deficit = max(0., water_demand - rollingsum) # mm

    cc = findfirst(unicrops .== crop)

    unicrop_irrigationrate[crop] + water_deficit * unicrop_irrigationstress[crop] / 1000
end

function grad_univariateagriculture_production_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :production, :totalareas, (rr, cc, tt) -> m.external_parameters[:yield].values[rr, cc, tt] * 2.47105 * config["timestep"]/12) # Convert Ha to acres
end

function grad_univariateagriculture_totalirrigation_totalareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                A[rr, fromindex([rr, cc], [numcounties, numunicrops])] = m.external_parameters[:irrigation_rate].values[rr, cc, tt] / 100
            end
        end

        return A
    end
    roomintersect(m, :UnivariateAgriculture, :totalirrigation, :totalareas, generate)
end

function grad_univariateagriculture_cost_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :unicultivationcost, :totalareas, (rr, cc, tt) -> cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end

function grad_univariateagriculture_opcost_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :opcost, :totalareas, (rr, cc) -> uniopcost[rr,cc] * 2.47105* config["timestep"]/12, [:time]) # convert acres to Ha
end

#########Total culti area #########
function grad_univariateagriculture_maxarea_totalareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                A[rr, fromindex([rr, cc], [numcounties, numunicrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :UnivariateAgriculture, :maxarea, :totalareas, generate, [:time], [:time])
end

function grad_univariateagriculture_allagarea_totalareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                A[rr, fromindex([rr, cc], [numcounties, numunicrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :UnivariateAgriculture, :allagarea, :totalareas, generate, [:time], [:time])
end
