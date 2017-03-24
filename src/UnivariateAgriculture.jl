using DataFrames
using Mimi

include("lib/agriculture.jl")

@defcomp UnivariateAgriculture begin
    regions = Index()
    unicrops = Index()

    # Optimized
    # Land area appropriated to each crop
    totalareas = Parameter(index=[regions, unicrops, time], unit="Ha")

    # Internal
    # Yield per hectare
    yield = Parameter(index=[regions, unicrops, time], unit="none")

    # Coefficient on the effects of water deficits
    irrigation_rate = Parameter(index=[regions, unicrops, time], unit="mm")

    # Computed
    # Total agricultural area
    totalareas2 = Variable(index=[regions, unicrops, time], unit="Ha") # copy of totalareas
    allagarea = Variable(index=[regions, time], unit="Ha")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    # Total production: lb or bu
    yield2 = Variable(index=[regions, unicrops, time], unit="none")
    production = Variable(index=[regions, unicrops, time], unit="lborbu")
    # Total cultivation costs per crop
    cultivationcost = Variable(index=[regions, unicrops, time], unit="\$")
end

function run_timestep(s::UnivariateAgriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    for rr in d.regions
        totalirrigation = 0.
        allagarea = 0.

        for cc in d.unicrops
            v.totalareas2[rr, cc, tt] = p.totalareas[rr, cc, tt]
            allagarea += p.totalareas[rr, cc, tt]

            # Calculate irrigation water, summed across all crops: 1 mm * Ha = 10 m^3
            totalirrigation += p.totalareas[rr, cc, tt] * p.irrigation_rate[rr, cc, tt] / 100

            # Calculate total production
            v.yield2[rr, cc, tt] = p.yield[rr, cc, tt]
            v.production[rr, cc, tt] = p.yield[rr, cc, tt] * p.totalareas[rr, cc, tt] * 2.47105 # convert acres to Ha

            # Calculate cultivation costs
            v.cultivationcost[rr, cc, tt] = p.totalareas[rr, cc, tt] * cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha
        end

        v.totalirrigation[rr, tt] = totalirrigation
        v.allagarea[rr, tt] = allagarea
    end
end

function initunivariateagriculture(m::Model)
    # precip loaded by weather.jl
    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, 2) - cumsum([zeros(numcounties, stepsperyear) precip[:, 1:size(precip)[2] - stepsperyear]],2)

    # Match up values by FIPS
    yield = zeros(numcounties, numunicrops, numsteps)
    irrigation_rate = zeros(numcounties, numunicrops, numsteps)
    for cc in 1:numunicrops
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
                for tt in 1:numsteps
                    year = index2year(tt)
                    if year >= 1949 && year <= 2009
                        numgdds = gdds[rr, symbol("x$year")]
                        if isna(numgdds)
                            numgdds = 0
                        end

                        numkdds = kdds[rr, symbol("x$year")]
                        if isna(numkdds)
                            numkdds = 0
                        end
                    else
                        numgdds = numkdds = 0
                    end

                    water_demand = water_requirements[unicrops[cc]] * 1000
                    water_deficit = max(0., water_demand - rollingsum[rr, tt])

                    logmodelyield = thismodel.intercept + thismodel.gdds * (numgdds - thismodel.gddoffset) + thismodel.kdds * (numkdds - thismodel.kddoffset) + (thismodel.wreq / 1000) * water_deficit
                    yield[rr, cc, tt] = min(exp(logmodelyield), maximum_yields[unicrops[cc]])

                    irrigation_rate[rr, cc, tt] = unicrop_irrigationrate[unicrops[cc]] + water_deficit * unicrop_irrigationstress[unicrops[cc]] / 1000
                end
            end
        end
    end

    agriculture = addcomponent(m, UnivariateAgriculture)

    agriculture[:yield] = yield
    agriculture[:irrigation_rate] = irrigation_rate

    # Load in planted area
    totalareas = getfilteredtable("agriculture/totalareas.csv")

    for cc in 2:ncol(totalareas)
        # Replace NAs with 0, and convert to float. TODO: improve this
        totalareas[isna(totalareas[cc]), cc] = 0.
        # Convert to Ha
        totalareas[cc] = totalareas[cc] * 0.404686
    end
    agriculture[:totalareas] = repeat(convert(Matrix, totalareas[:, 2:end]), outer=[1, 1, numsteps])

    agriculture
end

function grad_univariateagriculture_production_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :production, :totalareas, (rr, cc, tt) -> m.parameters[:yield].values[rr, cc, tt]) * 2.47105 * config["timestep"]/12 # Convert Ha to acres
end

function grad_univariateagriculture_totalirrigation_totalareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                A[rr, fromindex([rr, cc], [numcounties, numunicrops])] = m.parameters[:irrigation_rate].values[rr, cc, tt] / 100
            end
        end

        return A
    end
    roomintersect(m, :UnivariateAgriculture, :totalirrigation, :totalareas, generate)
end

function grad_agriculture_cost_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :cultivationcost, :totalareas, (rr, cc, tt) -> cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end
