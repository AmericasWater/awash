## Irrigation-invariate Agriculture Component
#
# Calculates the water demands for agriculture where irrigation demand
# is a constant function of area.

using DataFrames
using CSV
using Mimi

include("lib/coding.jl")
include("lib/agriculture.jl")

@defcomp UnivariateAgriculture begin
    harvestyear = Index()
    regions = Index()
    unicrops = Index()
    scenarios = Index()

    # Optimized
    # Land area appropriated to each crop
    totalareas = Parameter(index=[regions, unicrops, harvestyear], unit="Ha") # vs. harvestyear

    # Internal
    # Yield per hectare
    yield = Parameter(index=[regions, unicrops, scenarios, harvestyear], unit="none") # vs. harvestyear

    # Coefficient on the effects of water deficits
    irrigation_rate = Parameter(index=[regions, unicrops, scenarios, time], unit="mm")

    # Computed
    # Total agricultural area
    totalareas2 = Variable(index=[regions, unicrops, harvestyear], unit="Ha") # copy of totalareas, vs. harvestyear
    allagarea = Variable(index=[regions, harvestyear], unit="Ha") # vs. harvestyear

    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # Total production: lb or bu
    yield2 = Variable(index=[regions, unicrops, scenarios, harvestyear], unit="none") # vs. harvestyear
    production = Variable(index=[regions, unicrops, scenarios, harvestyear], unit="lborbu") # vs. harvestyear
    #total Op cost
    opcost = Variable(index=[regions, unicrops, time], unit="\$")

    # Total cultivation costs per crop
    unicultivationcost = Variable(index=[regions, unicrops, time], unit="\$")

    production_sumregion = Variable(index=[unicrops, scenarios, time], unit="lborbu")
    area_sumregion = Variable(index=[unicrops, time], unit="lborbu")

    function run_timestep(p, v, d, tt)
        yys = timeindex2yearindexes(tt)
        contyys = timeindex2contributingyearindexes(tt)
        
        if numunicrops == 0
            for rr in d.regions
                v.totalirrigation[rr, :, tt] .= 0
                v.totalareas2[rr, :, contyys] .= 0.
                v.allagarea[rr, contyys] .= 0
            end
            return
        end

        for rr in d.regions
            totalirrigation = zeros(numscenarios)
            allagarea = 0.

            for cc in d.unicrops
                v.totalareas2[rr, cc, contyys] .= p.totalareas[rr, cc, contyys]
                allagarea += maximum(p.totalareas[rr, cc, contyys])

                # Calculate irrigation water, summed across all crops: 1 mm * Ha = 10 m^3
                totalirrigation += maximum(p.totalareas[rr, cc, contyys]) * p.irrigation_rate[rr, cc, :, tt] / 100

                # Calculate total production
                v.yield2[rr, cc, :, yys] .= p.yield[rr, cc, :, yys]
                v.production[rr, cc, :, yys] .= p.yield[rr, cc, :, yys] * minimum(p.totalareas[rr, cc, contyys]) * 2.47105 # convert acres to Ha

                # Calculate cultivation costs
                v.unicultivationcost[rr, cc, tt] = mean(p.totalareas[rr, cc, contyys]) * cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha

                # Calculate Operating cost
                v.opcost[rr,cc,tt] = mean(p.totalareas[rr, cc, contyys]) * uniopcost[rr,cc] * 2.47105 * config["timestep"] / 12
            end

            v.totalirrigation[rr, :, tt] = totalirrigation
            v.allagarea[rr, contyys] .= allagarea
        end

        if length(yys) > 0
            v.production_sumregion[:, :, tt] .= dropdims(sum(sum(v.production[:, :, :, yys], dims=4), dims=1), dims=(1, 4))
        else
            v.production_sumregion[:, :, tt] .= 0.
        end
        v.area_sumregion[:, tt] .= dropdims(sum(maximum(p.totalareas[:, :, contyys], dims=3), dims=1), dims=(1, 3))
    end
end

function initunivariateagriculture(m::Model)
    # Match up values by FIPS
    yield = zeros(numcounties, numunicrops, numscenarios, numharvestyears)
    irrigation_rate = zeros(numcounties, numunicrops, numscenarios, numsteps)

    for cc in 1:numunicrops
        if unicrops[cc] in ["corn.co.rainfed", "corn.co.irrigated", "wheat.co.rainfed", "wheat.co.irrigated"]
            yield[:, cc, :, :] = read_nareshyields(unicrops[cc])
            irrigation_rate[:,cc,:,:] .= known_irrigationrate[unicrops[cc]] * config["timestep"] / 12
            continue
        end

        # Load degree day data
        gdds = CSV.read(findcroppath("agriculture/edds/", unicrops[cc], "-gdd.csv"), missingstring="NA")
        kdds = CSV.read(findcroppath("agriculture/edds/", unicrops[cc], "-kdd.csv"), missingstring="NA")

        cropirrigationrate, waterdeficits = getunivariateirrigationrates(unicrops[cc])

        for rr in 1:numcounties
            if configdescends(config, "counties")
                regionid = masterregions[rr, :fips]
            else
                regionid = masterregions[rr, :state]
            end
            if regionid in keys(agmodels[unicrops[cc]])
                thismodel = agmodels[unicrops[cc]][regionid]
                for yy in 1:numharvestyears
                    tts, weights = yearindex2timeindexes(yy)
                    year = index2year(tts[1]) + 1 # XXX: Always year after planting
                    if year >= 1949 && year <= 2009
                        numgdds = gdds[rr, Symbol("$year")]
                        if ismissing.(numgdds)
                            numgdds = 0
                        end

                        numkdds = kdds[rr, Symbol("$year")]
                        if ismissing.(numkdds)
                            numkdds = 0
                        end
                    else
                        numgdds = numkdds = 0
                    end

                    logmodelyield = thismodel.intercept .+ thismodel.gdds * (numgdds - thismodel.gddoffset) .+ thismodel.kdds * (numkdds - thismodel.kddoffset) .+ (thismodel.wreq / 1000) * waterdeficits[rr, :, yy] # wreq: delta / m
                    yield[rr, cc, :, yy] = min.(exp.(logmodelyield), maximum_yields[unicrops[cc]])

                    irrigation_rate[rr, cc, :, tts] = cropirrigationrate[rr, :, tts]
                end
            end
        end
    end
    agriculture = add_comp!(m, UnivariateAgriculture)

    agriculture[:yield] = yield
    agriculture[:irrigation_rate] = irrigation_rate

    # Load in planted area
    totalareas = getfilteredtable("agriculture/totalareas.csv")

    if isempty(unicrops)
        agriculture[:totalareas] = zeros(Float64, (nrow(totalareas), 0, numharvestyears))
    else
        constantareas = zeros(numcounties, numunicrops)
        for cc in 1:numunicrops
            if unicrops[cc] in keys(quickstats_planted)
                constantareas[:, cc] = read_quickstats(datapath(quickstats_planted[unicrops[cc]]))
            else
                column = findfirst(Symbol(unicrops[cc]) .== names(totalareas))
                constantareas[:, cc] = totalareas[!, column] * 0.404686 # Convert to Ha
                constantareas[ismissing.(totalareas[!, column]), cc] .= 0. # Replace NAs with 0, and convert to float.
            end
        end
        agriculture[:totalareas] = repeat(constantareas, outer=[1, 1, numharvestyears])
    end

    agriculture
end

"""
Get the irrigation rate per timestep for each crop
"""
function getunivariateirrigationrates(crop::AbstractString)
    water_demand = water_requirements[crop] * 1000 # mm

    irrigationrate = zeros(numcounties, numscenarios, numsteps)
    waterdeficits = zeros(numcounties, numscenarios, numharvestyears)
    for yy in 1:numharvestyears
        tts, weights = yearindex2timeindexes(yy)
        # fullprecip loaded by weather.jl
        fulltts, fullweights = leapindex2timeindexes(yy, 1, 12)
        fullweights = fullweights[fulltts .<= size(fullprecip)[3]]
        fulltts = fulltts[fulltts .<= size(fullprecip)[3]]
        for rr in 1:numregions
            for ss in 1:numscenarios
                waterdeficit = sum(max.(0., water_demand / 12 .- fullprecip[rr, ss, fulltts]) .* fullweights)  # XXX: Assume precip over 12 months
                waterdeficits[rr, ss, yy] = waterdeficit
                irrigationrate[rr, ss, tts] = (unicrop_irrigationrate[crop] + waterdeficit * unicrop_irrigationstress[crop] / 1000) * weights / sum(weights)
            end
        end
    end

    irrigationrate, waterdeficits
end

function grad_univariateagriculture_production_totalareas(m::Model)
    ## Common rr, cc, tt
    roomdiagonalintersect(m, :UnivariateAgriculture, :production, :totalareas, (ss1) -> m.md.external_params[:yield].values[:, :, ss1, :] * 2.47105 * config["timestep"]/12) # Convert Ha to acres
end

function grad_univariateagriculture_areasumregion_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :area_sumregion, :totalareas, (cc, tt) -> 1, [:regions])
end

function grad_univariateagriculture_totalirrigation_totalareas(m::Model)
    function generate(A, tt)
        for ss in 1:numscenarios
            for rr in 1:numcounties
                for cc in 1:numunicrops
                    A[fromindex([rr, ss], [numcounties, numscenarios]), fromindex([rr, cc], [numcounties, numunicrops])] = m.md.external_params[:irrigation_rate].values[rr, cc, ss, tt] / 100
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

