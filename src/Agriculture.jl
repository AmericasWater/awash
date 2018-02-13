using DataFrames
using Mimi

include("lib/agriculture.jl")

@defcomp Agriculture begin
    regions = Index()
    irrcrops = Index()
    unicrops = Index()
    allcrops = Index()

    # Inputs
    othercropsarea = Parameter(index=[regions, time], unit="Ha")
    othercropsirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    irrcropareas = Parameter(index=[regions, irrcrops, time], unit="Ha")
    irrcropproduction = Parameter(index=[regions, irrcrops, time], unit="lborbu")
    irrirrigation = Parameter(index=[regions, time], unit="1000 m^3")

    unicropareas = Parameter(index=[regions, unicrops, time], unit="Ha")
    unicropproduction = Parameter(index=[regions, unicrops, time], unit="lborbu")
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

    for rr in d.regions
        v.allirrigation[rr, tt] = p.othercropsirrigation[rr, tt]
        v.allagarea[rr, tt] = p.othercropsarea[rr, tt]
        for cc in d.allcrops
            irrcc = findfirst(irrcrops, allcrops[cc])
            if irrcc > 0
                v.allcropareas[rr, cc, tt] = p.irrcropareas[rr, irrcc, tt]
                v.allcropproduction[rr, cc, tt] = p.irrcropproduction[rr, irrcc, tt]
            else
                unicc = findfirst(unicrops, allcrops[cc])
                v.allcropareas[rr, cc, tt] = p.unicropareas[rr, unicc, tt]
                v.allcropproduction[rr, cc, tt] = p.unicropproduction[rr, unicc, tt]
            end

            v.allagarea[rr, tt] += v.allcropareas[rr, cc, tt]
        end
    end
end

function initagriculture(m::Model)
    agriculture = addcomponent(m, Agriculture)

    knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)
    agriculture[:othercropsarea] = repeat(convert(Vector, (knownareas[:total] - knownareas[:known]) * 0.404686), outer=[1, numsteps]) # Convert to Ha

    recorded = getfilteredtable("extraction/USGS-2010.csv")
    othercropirrigation = ((knownareas[:total] - knownareas[:known]) ./ knownareas[:total]) * config["timestep"] .* recorded[:, :IR_To] * 1383. / 12
    othercropirrigation[knownareas[:total] .== 0] = 0
    agriculture[:othercropsirrigation] = repeat(convert(Vector, othercropirrigation), outer=[1, numsteps])

    agriculture[:irrcropproduction] = zeros(Float64, (numregions, numirrcrops, numsteps))
    agriculture[:unicropproduction] = zeros(Float64, (numregions, numunicrops, numsteps))

    agriculture
end

function grad_agriculture_allirrigation_irrirrigation(m::Model)
    roomintersect(m, :Agriculture, :allirrigation, :irrirrigation, (rr, tt) -> 1.)
end

function grad_agriculture_allirrigation_uniirrigation(m::Model)
    roomintersect(m, :Agriculture, :allirrigation, :uniirrigation, (rr, tt) -> 1.)
end

function grad_agriculture_allagarea_irrcropareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for irrcc in 1:numirrcrops
                cc = findfirst(irrcrops[cc], allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :irrcropareas, generate)
end

function grad_agriculture_allagarea_unicropareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for unicc in 1:numunicrops
                cc = findfirst(unicrops[cc], allcrops)
                A[rr, fromindex([rr, cc], [numcounties, numallcrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :Agriculture, :allagarea, :unicropareas, generate)
end

function constraintoffset_agriculture_allagarea(m::Model)
    hallsingle(m, :Agriculture, :allagarea, (rr, tt) -> max(countylandareas[rr] - m.parameters[:othercropsarea].values[rr, tt], 0))
end

function grad_agriculture_allcropproduction_unicropproduction(m::Model)
    function gen(A, tt)
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
    roomintersect(m, :Agriculture, :allcropproduction, :unicropproduction, gen)
end

function grad_agriculture_allcropproduction_irrcropproduction(m::Model)
    function gen(A, tt)
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
    roomintersect(m, :Agriculture, :allcropproduction, :irrcropproduction, gen)
end


function constraintoffset_colorado_agriculture_sorghumarea(m::Model)
    sorghum=readtable(datapath("../Colorado/sorghum.csv"))[:x][:,1]
    sorghum=repeat(convert(Vector,allarea),outer=[1,numsteps])
    gen(rr,tt)=sorghum[rr,tt]
    hallsingle(m, :Agriculture, :sorghumarea,gen)
end
