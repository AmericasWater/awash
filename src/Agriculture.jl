## Combined Agriculture Component
#
# Combines the water demands, land use, and production from the
# irrigated, univariate, and other (unmodeled) crops.

using DataFrames
using Mimi

include("lib/agriculture.jl")
include("lib/leapsteps.jl")

@defcomp Agriculture begin
    year = Index()
    regions = Index()
    irrcrops = Index()
    unicrops = Index()
    allcrops = Index()

    # Inputs
    othercropsarea = Parameter(index=[regions, year], unit="Ha") # vs. year
    othercropsirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    # From IrrigationAgriculture
    irrcropareas = Parameter(index=[regions, irrcrops, year], unit="Ha") # vs. year
    irrcropproduction = Parameter(index=[regions, irrcrops, year], unit="lborbu") # vs. year
    irrirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    # From UnivariateAgriculture
    unicropareas = Parameter(index=[regions, unicrops, year], unit="Ha") # vs. year
    unicropproduction = Parameter(index=[regions, unicrops, year], unit="lborbu") # vs. year
    uniirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    # Outputs
    allcropareas = Variable(index=[regions, allcrops, time], unit="Ha")
    allcropproduction = Variable(index=[regions, allcrops, time], unit="lborbu")
    allirrigation = Variable(index=[regions, time], unit="1000 m^3")
    allagarea = Variable(index=[regions, time], unit="Ha")
end

function run_timestep(s::Agriculture, tt::Int)
    v = s.Variables
    p = s.Parameters
    d = s.Dimensions

    yys = timeindex2yearindexes(tt)
    contyys = timeindex2contributingyearindexes(tt)

    for rr in d.regions
        v.allirrigation[rr, tt] = p.othercropsirrigation[rr, tt] + p.uniirrigation[rr, tt] + p.irrirrigation[rr, tt]
        v.allagarea[rr, tt] = maximum(p.othercropsarea[rr, contyys])
        for cc in d.allcrops
            irrcc = findfirst(irrcrops, allcrops[cc])
            if irrcc > 0
                v.allcropareas[rr, cc, tt] = maximum(p.irrcropareas[rr, irrcc, contyys])
                v.allcropproduction[rr, cc, tt] = sum(p.irrcropproduction[rr, irrcc, yys])
            else
                unicc = findfirst(unicrops, allcrops[cc])
                v.allcropareas[rr, cc, tt] = maximum(p.unicropareas[rr, unicc, contyys])
                v.allcropproduction[rr, cc, tt] = sum(p.unicropproduction[rr, unicc, yys])
            end

            v.allagarea[rr, tt] += maximum(v.allcropareas[rr, cc, contyys])
        end
    end
end

function initagriculture(m::Model)
    agriculture = addcomponent(m, Agriculture)

    knownareas = knowndf("agriculture-knownareas")
    othercropsarea = repeat(convert(Vector, (knownareas[:total] - knownareas[:known]) * 0.404686), outer=[1, numyears]) # Convert to Ha
    agriculture[:othercropsarea] = othercropsarea

    recorded = knowndf("exogenous-withdrawals")
    othercropsirrigation = ((knownareas[:total] - knownareas[:known]) ./ knownareas[:total]) * config["timestep"] .* recorded[:, :IR_To] * 1383. / 12
    othercropsirrigation[knownareas[:total] .== 0] = 0
    othercropsirrigation = repeat(convert(Vector, othercropsirrigation), outer=[1, numsteps])
    agriculture[:othercropsirrigation] = othercropsirrigation

    for crop in Channel(missingcrops)
        areas = repeat(convert(Vector, currentcroparea(crop)), outer=[1, numyears])
        agriculture[:othercropsarea] = othercropsarea + areas
        savedcropirrigationrates = cropirrigationrates(crop)
        othercropsirrigation = zeros(numregions, numsteps)
        for tt in 1:numsteps
            yys = timeindex2yearindexes(tt)
            if length(yys) > 0
                othercropsirrigation[:, tt] = othercropsirrigation[:, tt] + savedcropirrigationrates[:, tt] .* maximum(areas[:, yys]) / 100
            end
        end
    end

    agriculture[:othercropsirrigation] = othercropsirrigation
    agriculture[:irrcropproduction] = zeros(Float64, (numregions, numirrcrops, numyears))
    agriculture[:unicropproduction] = zeros(Float64, (numregions, numunicrops, numyears))

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
                cc = findfirst(irrcrops[cc], allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :irrcropareas, generate, [:year], [:year])
end

function grad_agriculture_allagarea_unicropareas(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for unicc in 1:numunicrops
                cc = findfirst(unicrops[cc], allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :unicropareas, generate, [:year], [:year])
end

function constraintoffset_agriculture_allagarea(m::Model)
    hallsingle(m, :Agriculture, :allagarea, (rr, yy) -> max(countylandareas[rr] - m.external_parameters[:othercropsarea].values[rr, yy], 0))
end

function grad_agriculture_allcropproduction_unicropproduction(m::Model)
    function gen(A)
        # A: R x ALL x R x UNI
        if !isempty(unicrops)
            for unicc in 1:numunicrops
                allcc = findfirst(allcrops, unicrops[unicc])
                for rr in 1:numregions
                    A[fromindex([rr, allcc], [numregions, numallcrops]), fromindex([rr, unicc], [numregions, numunicrops])] = 1
                end
            end
        end
    end
    roomintersect(m, :Agriculture, :allcropproduction, :unicropproduction, gen, [:year], [:year])
end

function grad_agriculture_allcropproduction_irrcropproduction(m::Model)
    function gen(A)
        # A: R x ALL x R x IRR
        if !isempty(irrcrops)
            for irrcc in 1:numirrcrops
                allcc = findfirst(allcrops, irrcrops[irrcc])
                for rr in 1:numregions
                    A[fromindex([rr, allcc], [numregions, numallcrops]), fromindex([rr, irrcc], [numregions, numirrcrops])] = 1
                end
            end
        end
    end
    roomintersect(m, :Agriculture, :allcropproduction, :irrcropproduction, gen, [:year], [:year])
end
