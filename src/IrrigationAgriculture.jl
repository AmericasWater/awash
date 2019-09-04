## Irrigation-managed Agriculture Component
#
# Calculates the water demands for agriculture where irrigation rates
# are responsive to precipitation.

using DataFrames
using Mimi

include("lib/coding.jl")
include("lib/agriculture.jl")

@defcomp IrrigationAgriculture begin
    regions = Index()
    irrcrops = Index()
    scenarios = Index()

    # Optimized
    # Land area appropriated to each crop, irrigated to full demand (Ha)
    irrigatedareas = Parameter(index=[regions, irrcrops, time], unit="Ha")
    rainfedareas = Parameter(index=[regions, irrcrops, time], unit="Ha")

    # Internal
    # Yield base: combination of GDDs, KDDs, and intercept
    logirrigatedyield = Parameter(index=[regions, irrcrops, scenarios, time], unit="none")

    # Coefficient on the effects of water deficits
    deficit_coeff = Parameter(index=[regions, irrcrops], unit="1/mm")

    # Water requirements per unit area, in mm
    water_demand = Parameter(index=[irrcrops], unit="mm")

    # Precipitation water per unit area, in mm
    precipitation = Parameter(index=[regions, scenarios, time], unit="mm")

    # Computed
    # Land area appropriated to each crop
    totalareas = Variable(index=[regions, irrcrops, time], unit="Ha")
    # Total agricultural area
    allagarea = Variable(index=[regions, time], unit="Ha")

    # Deficit for any unirrigated areas, in mm
    water_deficit = Variable(index=[regions, irrcrops, scenarios, time], unit="mm")

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # Yield per hectare for rainfed (irrigated has irrigatedyield)
    lograinfedyield = Variable(index=[regions, irrcrops, scenarios, time], unit="none")

    # Total production: lb or bu
    production = Variable(index=[regions, irrcrops, scenarios, time], unit="lborbu")
    # Total cultivation costs per crop
    irrcultivationcost = Variable(index=[regions, irrcrops, time], unit="\$")

    production_sumregion = Variable(index=[irrcrops, scenarios, time], unit="lborbu")
    area_sumregion = Variable(index=[irrcrops, time], unit="lborbu")

    function run_timestep(p, v, d, tt)
        contyys = timeindex2contributingyearindexes(tt)

        if numirrcrops == 0
            for rr in d.regions
                v.totalirrigation[rr, :, tt] .= 0
                v.totalareas[rr, :, contyys] .= 0.
                v.allagarea[rr, tt] = 0
            end
            return
        end

        for rr in d.regions
            totalirrigation = zeros(numscenarios)
            allagarea = 0.
            for cc in d.irrcrops
                v.totalareas[rr, cc, tt] = p.irrigatedareas[rr, cc, tt] + p.rainfedareas[rr, cc, tt]
                allagarea += v.totalareas[rr, cc, tt]

                # Calculate deficit by crop, for unirrigated areas
                v.water_deficit[rr, cc, :, tt] .= max(0., p.water_demand[cc] - p.precipitation[rr, :, tt])

                # Calculate irrigation water, summed across all crops: 1 mm * Ha^2 = 10 m^3
                totalirrigation += v.water_deficit[rr, cc, :, tt] * p.irrigatedareas[rr, cc, tt] / 100

                # Calculate rainfed yield
                v.lograinfedyield[rr, cc, :, tt] .= p.logirrigatedyield[rr, cc, :, tt] + p.deficit_coeff[rr, cc] * v.water_deficit[rr, cc, :, tt]

                # Calculate total production
                v.production[rr, cc, :, tt] .= exp.(p.logirrigatedyield[rr, cc, :, tt]) * p.irrigatedareas[rr, cc, tt] * 2.47105 + exp.(v.lograinfedyield[rr, cc, :, tt]) * p.rainfedareas[rr, cc, tt] * 2.47105 # convert acres to Ha

                # Calculate cultivation costs
                v.irrcultivationcost[rr, cc, tt] = v.totalareas[rr, cc, tt] * cultivation_costs[irrcrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha
            end

            v.totalirrigation[rr, :, tt] .= totalirrigation
            v.allagarea[rr, tt] = allagarea
        end

        v.production_sumregion[:, :, tt] .= sum(v.production[:, :, :, tt], dims=1)
        v.area_sumregion[:, tt] .= sum(p.irrigatedareas[:, :, tt], dims=1) .+ sum(p.rainfedareas[:, :, tt], dims=1)
    end
end

function initirrigationagriculture(m::Model)
    # precip loaded by weather.jl

    # Match up values by FIPS
    logirrigatedyield = -Inf * ones(numcounties, numirrcrops, numscenarios, numsteps)
    deficit_coeff = zeros(numcounties, numirrcrops)
    for cc in 1:numirrcrops
        # Load degree day data
        gdds = readtable(joinpath(datapath("agriculture/edds/$(irrcrops[cc])-gdd.csv")))
        kdds = readtable(joinpath(datapath("agriculture/edds/$(irrcrops[cc])-kdd.csv")))

        for rr in 1:numcounties
            if configdescends(config, "counties")
                regionid = masterregions[rr, :fips]
            else
                regionid = masterregions[rr, :state]
            end
            if regionid in keys(agmodels[irrcrops[cc]])
                thismodel = agmodels[irrcrops[cc]][regionid]
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

                    logmodelyield = thismodel.intercept + thismodel.gdds * (numgdds - thismodel.gddoffset) + thismodel.kdds * (numkdds - thismodel.kddoffset)
                    warnonce("LOGIC: This should be sensitive to scenario weather.")
                    logirrigatedyield[rr, cc, :, tt] = min(logmodelyield, log(maximum_yields[irrcrops[cc]]))
                end

                deficit_coeff[rr, cc] = min(0., thismodel.wreq / 1000) # must be negative, convert to 1/mm
            end
        end
    end

    water_demand = zeros(numirrcrops)
    for cc in 1:numirrcrops
        water_demand[cc] = water_requirements[irrcrops[cc]] * 1000
    end

    agriculture = add_comp!(m, IrrigationAgriculture)

    agriculture[:logirrigatedyield] = logirrigatedyield
    agriculture[:deficit_coeff] = deficit_coeff
    agriculture[:water_demand] = water_demand

    # Sum precip to a yearly level
    stepsperyear = floor(Int64, 12 / config["timestep"])
    rollingsum = cumsum(precip, dims=3) - cumsum(cat(zeros(numcounties, numscenarios, stepsperyear), precip[:, :, 1:size(precip)[3] - stepsperyear], dims=3), dims=3)
    agriculture[:precipitation] = rollingsum

    # Load in planted area by water management
    rainfeds = getfilteredtable("agriculture/rainfedareas.csv")
    irrigateds = getfilteredtable("agriculture/irrigatedareas.csv")

    if isempty(irrcrops)
        agriculture[:rainfedareas] = zeros(Float64, (nrow(rainfeds), 0, numsteps))
        agriculture[:irrigatedareas] = zeros(Float64, (nrow(rainfeds), 0, numsteps))
    else
        columns = map(crop -> findfirst(Symbol(crop) .== names(rainfeds)), irrcrops)
        columns = convert(Vector{Int64}, columns)
        for cc in columns
            # Replace NAs with 0, and convert to float. TODO: improve this
            rainfeds[isna.(rainfeds[cc]), cc] .= 0.
            irrigateds[isna.(irrigateds[cc]), cc] .= 0.
            # Convert to Ha
            rainfeds[cc] = rainfeds[cc] * 0.404686
            irrigateds[cc] = irrigateds[cc] * 0.404686
        end
        agriculture[:rainfedareas] = repeat(convert(Matrix, rainfeds[:, columns]), outer=[1, 1, numsteps])
        agriculture[:irrigatedareas] = repeat(convert(Matrix, irrigateds[:, columns]), outer=[1, 1, numsteps])
    end

    agriculture
end

function grad_irrigationagriculture_production_irrigatedareas(m::Model)
    ## Common rr, cc, tt
    roomdiagonalintersect(m, :IrrigationAgriculture, :production, :irrigatedareas, (ss1) -> exp.(m.md.external_params[:logirrigatedyield].values[:, :, ss1, :]) * 2.47105 * .99 * config["timestep"]/12) # Convert Ha to acres
    # 1% lost to irrigation technology (makes irrigated and rainfed not perfectly equivalent)
end

function grad_irrigationagriculture_production_rainfedareas(m::Model)
    ## Common rr, cc, tt
    function gen(ss1)
        A = zeros(numregions, numirrcrops, numsteps)
        for cc in 1:numirrcrops
            for tt in 1:numsteps
                A[:, cc, tt] = exp.(m.md.external_params[:logirrigatedyield].values[:, cc, ss1, tt] + m.md.external_params[:deficit_coeff].values[:, cc] * max.(0., m.md.external_params[:water_demand].values[cc] - m.md.external_params[:precipitation].values[:, ss1, tt])) * 2.47105 * config["timestep"]/12 # Convert Ha to acres
            end
        end
        A
    end
    roomdiagonalintersect(m, :IrrigationAgriculture, :production, :rainfedareas, gen)
end

function grad_irrigationagriculture_totalirrigation_irrigatedareas(m::Model)
    function generate(A)
        # A: R * S x R * C * S
        for rr in 1:numcounties
            for cc in 1:numirrcrops
                for ss in 1:numscenarios
                    A[fromindex([rr, ss], [numcounties, numscenarios]), fromindex([rr, cc, ss], [numcounties, numirrcrops, numscenarios])] = max(0., m.md.external_params[:water_demand].values[cc] - m.md.external_params[:precipitation].values[rr, ss, tt]) / 100
                end
            end
        end

        return A
    end
    roomintersect(m, :IrrigationAgriculture, :totalirrigation, :irrigatedareas, generate, [:time], [:time])
end

function grad_irrigationagriculture_allagarea_irrigatedareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for cc in 1:numirrcrops
                A[rr, fromindex([rr, cc], [numcounties, numirrcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :IrrigationAgriculture, :allagarea, :irrigatedareas, generate, [:time], [:time])
end

function grad_irrigationagriculture_allagarea_rainfedareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for cc in 1:numirrcrops
                A[rr, fromindex([rr, cc], [numcounties, numirrcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :IrrigationAgriculture, :allagarea, :rainfedareas, generate, [:time], [:time])
end

function grad_irrigationagriculture_cost_rainfedareas(m::Model)
    roomdiagonal(m, :IrrigationAgriculture, :irrcultivationcost, :rainfedareas, (rr, cc, tt) -> cultivation_costs[irrcrops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end

function grad_irrigationagriculture_cost_irrigatedareas(m::Model)
    roomdiagonal(m, :IrrigationAgriculture, :irrcultivationcost, :irrigatedareas, (rr, cc, tt) -> cultivation_costs[irrcrops[cc]] * 2.47105 * config["timestep"]/12) # convert acres t
end

function constraintoffset_irrigationagriculture_productionsumregion(m::Model)
    productions = currentcropproduction.(irrcrops)
    gen(cc) = productions[cc]
    hallsingle(m, :IrrigationAgriculture, :production_sumregion, gen, [:scenarios, :time])
end

function grad_irrigationagriculture_areasumregion_irrigatedareas(m::Model)
    roomdiagonal(m, :IrrigationAgriculture, :area_sumregion, :irrigatedareas, (cc, tt) -> 1, [:regions])
end

function grad_irrigationagriculture_areasumregion_rainfedareas(m::Model)
    roomdiagonal(m, :IrrigationAgriculture, :area_sumregion, :rainfedareas, (cc, tt) -> 1, [:regions])
end

function constraintoffset_irrigationagriculture_areasumregion(m::Model)
    areas = currentcroparea.(irrcrops)
    hallsingle(m, :IrrigationAgriculture, :area_sumregion, (cc) -> areas[cc], [:time])
end
