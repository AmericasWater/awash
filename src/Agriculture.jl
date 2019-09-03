## Combined Agriculture Component
#
# Combines the water demands, land use, and production from the
# irrigated, univariate, and other (unmodeled) crops.

using DataFrames
using Mimi

include("lib/agriculture.jl")
include("lib/leapsteps.jl")

@defcomp Agriculture begin
    harvestyear = Index()
    regions = Index()
    irrcrops = Index()
    unicrops = Index()
    allcrops = Index()
    scenarios = Index()

    # Inputs
    othercropsarea = Parameter(index=[regions, harvestyear], unit="Ha") # vs. harvestyear
    othercropsirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    # From IrrigationAgriculture
    irrcropareas = Parameter(index=[regions, irrcrops, harvestyear], unit="Ha") # vs. harvestyear
    irrcropproduction = Parameter(index=[regions, irrcrops, scenarios, harvestyear], unit="lborbu") # vs. harvestyear
    irrirrigation = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # From UnivariateAgriculture
    unicropareas = Parameter(index=[regions, unicrops, harvestyear], unit="Ha") # vs. harvestyear
    unicropproduction = Parameter(index=[regions, unicrops, scenarios, harvestyear], unit="lborbu") # vs. harvestyear
    uniirrigation = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # Outputs
    allcropareas = Variable(index=[regions, allcrops, time], unit="Ha")
    allcropproduction = Variable(index=[regions, allcrops, scenarios, time], unit="lborbu")
    allcropproduction_sumregion = Variable(index=[allcrops, scenarios, time], unit="lborbu")
    allirrigation = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    allagarea = Variable(index=[regions, time], unit="Ha")

    function run_timestep(p, v, d, tt)
        yys = timeindex2yearindexes(tt)
        contyys = timeindex2contributingyearindexes(tt)

        for rr in d.regions
            v.allirrigation[rr, :, tt] .= p.othercropsirrigation[rr, tt] .+ p.irrirrigation[rr, :, tt] .+ p.uniirrigation[rr, :, tt]
            v.allagarea[rr, tt] = maximum(p.othercropsarea[rr, contyys])
            for cc in d.allcrops
                irrcc = findfirst(irrcrops .== allcrops[cc])
                if irrcc != nothing
                    v.allcropareas[rr, cc, tt] = maximum(p.irrcropareas[rr, irrcc, contyys])
                    if (length(yys) > 0)
                        v.allcropproduction[rr, cc, :, tt] .= dropdims(sum(p.irrcropproduction[rr, irrcc, :, yys], dims=2), dims=2)
                    else
                        v.allcropproduction[rr, cc, :, tt] .= 0
                    end
                else
                    unicc = findfirst(unicrops .== allcrops[cc])
                    v.allcropareas[rr, cc, tt] = maximum(p.unicropareas[rr, unicc, contyys])
                    if (length(yys) > 0)
                        v.allcropproduction[rr, cc, :, tt] .= dropdims(sum(p.unicropproduction[rr, unicc, :, yys], dims=2), dims=2)
                    else
                        v.allcropproduction[rr, cc, :, tt] .= 0
                    end
                end

                v.allagarea[rr, tt] += maximum(v.allcropareas[rr, cc, contyys])
            end
        end

        v.allcropproduction_sumregion[:, :, tt] .= dropdims(sum(v.allcropproduction[:, :, :, tt], dims=1), dims=1)
    end
end

function initagriculture(m::Model)
    agriculture = add_comp!(m, Agriculture)

    knownareas = knowndf("agriculture-knownareas")
    othercropsarea = repeat(convert(Vector, (knownareas[!, :total] - knownareas[!, :known]) * 0.404686), outer=[1, numharvestyears]) # Convert to Ha
    agriculture[:othercropsarea] = othercropsarea

    recorded = knowndf("exogenous-withdrawals")
    othercropsirrigation = ((knownareas[!, :total] - knownareas[!, :known]) ./ knownareas[!, :total]) * config["timestep"] .* recorded[:, :IR_To] * 1383. / 12
    othercropsirrigation[knownareas[!, :total] .== 0] .= 0
    othercropsirrigation = repeat(convert(Vector, othercropsirrigation), outer=[1, numsteps])
    agriculture[:othercropsirrigation] = othercropsirrigation

    for crop in Channel(missingcrops)
        areas = repeat(convert(Vector, currentcroparea(crop)), outer=[1, numharvestyears])
        agriculture[:othercropsarea] = othercropsarea + areas
        savedcropirrigationrates = cropirrigationrates(crop)
        othercropsirrigation = zeros(numregions, numsteps)
        for yy in 1:numharvestyears
            tts, weights = yearindex2timeindexes(yy)
            if length(tts) > 0
                othercropsirrigation[:, tts] = othercropsirrigation[:, tts] + savedcropirrigationrates[:, tts] .* areas[:, yy] / 100
            end
        end
    end

    agriculture[:othercropsirrigation] = othercropsirrigation
    agriculture[:irrcropproduction] = zeros(Float64, (numregions, numirrcrops, numscenarios, numharvestyears))
    agriculture[:unicropproduction] = zeros(Float64, (numregions, numunicrops, numscenarios, numharvestyears))

    agriculture
end

function grad_agriculture_allirrigation_irrirrigation(m::Model)
    roomdiagonal(m, :Agriculture, :allirrigation, :irrirrigation, 1.)
end

function grad_agriculture_allirrigation_uniirrigation(m::Model)
    roomdiagonal(m, :Agriculture, :allirrigation, :uniirrigation, 1.)
end

function grad_agriculture_allagarea_irrcropareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for irrcc in 1:numirrcrops
                cc = findfirst(irrcrops[cc] .== allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :irrcropareas, generate, [:harvestyear], [:harvestyear])
end

function grad_agriculture_allagarea_unicropareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for unicc in 1:numunicrops
                cc = findfirst(unicrops[cc] .== allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :unicropareas, generate, [:harvestyear], [:harvestyear])
end

function constraintoffset_agriculture_allagarea(m::Model)
    hallsingle(m, :Agriculture, :allagarea, (rr, yy) -> max(countylandareas[rr] - m.md.external_params[:othercropsarea].values[rr, yy], 0))
end

function grad_agriculture_allcropproduction_unicropproduction(m::Model)
    function gen(A)
        # A: R x ALL x R x UNI
        if !isempty(unicrops)
            for unicc in 1:numunicrops
                allcc = findfirst(allcrops .== unicrops[unicc])
                for rr in 1:numregions
                    A[fromindex([rr, allcc], [numregions, numallcrops]), fromindex([rr, unicc], [numregions, numunicrops])] = 1
                end
            end
        end
    end
    roomintersect(m, :Agriculture, :allcropproduction, :unicropproduction, gen, [:scenarios, :harvestyear], [:scenarios, :harvestyear])
end

function grad_agriculture_allcropproduction_irrcropproduction(m::Model)
    function gen(A)
        # A: R * ALL * S x R * IRR * S
        if !isempty(irrcrops)
            for irrcc in 1:numirrcrops
                allcc = findfirst(allcrops .== irrcrops[irrcc])
                for rr in 1:numregions
                    for ss in 1:numscenarios
                        A[fromindex([rr, allcc, ss], [numregions, numallcrops, numscenarios]), fromindex([rr, irrcc, ss], [numregions, numirrcrops, numscenarios])] = 1
                    end
                end
            end
        end
    end
    roomintersect(m, :Agriculture, :allcropproduction, :irrcropproduction, gen, [:scenarios, :harvestyear], [:scenarios, :harvestyear])
end


function constraintoffset_colorado_agriculture_sorghumarea(m::Model)
    sorghum=readtable(datapath("../Colorado/sorghum.csv"))[!, :x][:,1]
    sorghum=repeat(convert(Vector,allarea),outer=[1,numsteps])
    gen(rr,tt)=sorghum[rr,tt]
    hallsingle(m, :Agriculture, :sorghumarea,gen)
end
