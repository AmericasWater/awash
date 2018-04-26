## Irrigation-invariate Agriculture Component
#
# Calculates the water demands for agriculture where irrigation demand
# is a constant function of area.

using DataFrames
using Mimi

include("lib/coding.jl")
include("lib/agriculture.jl")

@defcomp UnivariateAgriculture begin
    regions = Index()
    unicrops = Index()
    scenarios = Index()

    # Optimized
    # Land area appropriated to each crop
    totalareas = Parameter(index=[regions, unicrops, time], unit="Ha")

    # Internal
    # Yield per hectare
    yield = Parameter(index=[regions, unicrops, scenarios, time], unit="none")

    # Coefficient on the effects of water deficits
    irrigation_rate = Parameter(index=[regions, unicrops, scenarios, time], unit="mm")

    # Computed
    # Total agricultural area
    totalareas2 = Variable(index=[regions, unicrops, time], unit="Ha") # copy of totalareas
    allagarea = Variable(index=[regions, time], unit="Ha")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # Total production: lb or bu
    yield2 = Variable(index=[regions, unicrops, scenarios, time], unit="none")
    production = Variable(index=[regions, unicrops, scenarios, time], unit="lborbu")
    #total Op cost
    opcost = Variable(index=[regions, unicrops, time], unit="\$")

    # Total cultivation costs per crop
    unicultivationcost = Variable(index=[regions, unicrops, time], unit="\$")

    production_sumregion = Variable(index=[unicrops, scenarios, time], unit="lborbu")
    area_sumregion = Variable(index=[unicrops, time], unit="lborbu")
end

function run_timestep(s::UnivariateAgriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        totalirrigation = zeros(numscenarios)
        allagarea = 0.

        for cc in d.unicrops
            v.totalareas2[rr, cc, tt] = p.totalareas[rr, cc, tt]
            allagarea += p.totalareas[rr, cc, tt]

            # Calculate irrigation water, summed across all crops: 1 mm * Ha = 10 m^3
            totalirrigation += p.totalareas[rr, cc, tt] * p.irrigation_rate[rr, cc, :, tt] / 100

            # Calculate total production
            v.yield2[rr, cc, :, tt] = p.yield[rr, cc, :, tt]
            v.production[rr, cc, :, tt] = p.yield[rr, cc, :, tt] * p.totalareas[rr, cc, tt] * 2.47105 # convert acres to Ha

            # Calculate cultivation costs
            v.unicultivationcost[rr, cc, tt] = p.totalareas[rr, cc, tt] * cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha

            # Calculate Operating cost
            v.opcost[rr,cc,tt]= p.totalareas[rr, cc, tt] * uniopcost[rr,cc] * 2.47105 * config["timestep"] / 12
        end

        v.totalirrigation[rr, :, tt] = totalirrigation
        v.allagarea[rr, tt] = allagarea
    end

    v.production_sumregion[:, :, tt] = sum(v.production[:, :, :, tt], 1)
    v.area_sumregion[:, tt] = sum(p.totalareas[:, :, tt], 1)
end

function initunivariateagriculture(m::Model)
    # precip loaded by weather.jl
    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 3) - cumsum(cat(3, zeros(numcounties, numscenarios, stepsperyear), precip[:, :, 1:size(precip)[3] - stepsperyear]), 3)

    # Match up values by FIPS
    yield = zeros(numcounties, numunicrops, numscenarios, numsteps)
    irrigation_rate = zeros(numcounties, numunicrops, numscenarios, numsteps)

    for cc in 1:numunicrops
        if unicrops[cc] in ["corn.co.rainfed", "corn.co.irrigated", "wheat.co.rainfed", "wheat.co.irrigated"]
            yield[:, cc, :, :] = read_nareshyields(unicrops[cc])
            irrigation_rate[:,cc,:,:] = known_irrigationrate[unicrops[cc]]
            continue
        end

        # Load degree day data
        gdds = readtable(findcroppath("agriculture/edds/", unicrops[cc], "-gdd.csv"))
        kdds = readtable(findcroppath("agriculture/edds/", unicrops[cc], "-kdd.csv"))

        for rr in 1:numcounties
            if configdescends(config, "counties")
                regionid = masterregions[rr, :fips]
            else
                regionid = masterregions[rr, :state]
            end
            if regionid in keys(agmodels[unicrops[cc]])
                thismodel = agmodels[unicrops[cc]][regionid]
                for tt in 1:numsteps
                    year = index2year(tt)
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
                    water_deficit = max.(0., water_demand - rollingsum[rr, :, tt]) # mm

                    logmodelyield = thismodel.intercept + thismodel.gdds * (numgdds - thismodel.gddoffset) + thismodel.kdds * (numkdds - thismodel.kddoffset) + (thismodel.wreq / 1000) * water_deficit # wreq: delta / m
                    warnonce("LOGIC: This should be sensitive to scenario weather.")
                    yield[rr, cc, :, tt] = min.(exp.(logmodelyield), maximum_yields[unicrops[cc]])

                    irrigation_rate[rr, cc, :, tt] = unicrop_irrigationrate[unicrops[cc]] + water_deficit * unicrop_irrigationstress[unicrops[cc]] / 1000
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
        agriculture[:totalareas] = zeros(Float64, (nrow(totalareas), 0, numsteps))
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
        agriculture[:totalareas] = repeat(constantareas, outer=[1, 1, numsteps])
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
    ## Common rr, cc, tt
    roomdiagonalintersect(m, :UnivariateAgriculture, :production, :totalareas, (ss1) -> m.external_parameters[:yield].values[:, :, ss1, :] * 2.47105 * config["timestep"]/12) # Convert Ha to acres
end

function grad_univariateagriculture_areasumregion_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :area_sumregion, :totalareas, (cc, tt) -> 1, [:regions])
end

function grad_univariateagriculture_totalirrigation_totalareas(m::Model)
    function generate(A, tt)
        for ss in 1:numscenarios
            for rr in 1:numcounties
                for cc in 1:numunicrops
                    A[fromindex([rr, ss], [numcounties, numscenarios]), fromindex([rr, cc], [numcounties, numunicrops])] = m.external_parameters[:irrigation_rate].values[rr, cc, ss, tt] / 100
                end
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

function constraintoffset_univariateagriculture_productionsumregion(m::Model)
    productions = currentcropproduction.(unicrops)
    gen(cc) = productions[cc]
    hallsingle(m, :UnivariateAgriculture, :production_sumregion, gen, [:scenarios, :time])
end

function constraintoffset_univariateagriculture_areasumregion(m::Model)
    areas = sum.(currentcroparea.(unicrops))
    hallsingle(m, :UnivariateAgriculture, :area_sumregion, (cc) -> areas[cc], [:time])
end

