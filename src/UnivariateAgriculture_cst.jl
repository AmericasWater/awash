## Irrigation-invariate Agriculture Component
#
# Calculates the water demands for agriculture where irrigation demand
# is a constant function of area.
#
# This version (in the _cst file) constrains areas to be constant of
# the whole scope of optimization.

using DataFrames
using Mimi

include("lib/coding.jl")
include("lib/agriculture.jl")

@defcomp UnivariateAgriculture begin
    regions = Index()
    unicrops = Index()

    # Optimized
    # Land area appropriated to each crop
    totalareas = Parameter(index=[regions, unicrops, time], unit="Ha")
    totalareas_cst=Parameter(index=[regions,unicrops],unit="Ha") #Parameter used for single area over years

    # Internal
    # Yield per hectare
    yield = Parameter(index=[regions, unicrops, time], unit="none")

    # Coefficient on the effects of water deficits
    irrigation_rate = Parameter(index=[regions, unicrops, time], unit="mm")

    # Computed
    # Total agricultural area
    totalareas2 = Variable(index=[regions, unicrops, time], unit="Ha") # copy of totalareas
    allagarea = Variable(index=[regions, time], unit="Ha")
    maxarea = Variable(index=[regions, time], unit="Ha")
    sorghumarea=Parameter(index=[regions, time], unit="Ha")
    # Total irrigation water (1000 m^3)
    totalirrigation = Variable(index=[regions, time], unit="1000 m^3")

    hayproduction=Parameter(index=[time],unit="ton")
    barleyproduction=Parameter(index=[time],unit="bu")

    # Total production: lb or bu
    yield2 = Variable(index=[regions, unicrops, time], unit="none")
    production = Variable(index=[regions, unicrops, time], unit="lborbu")
    #total Op cost
    opcost = Variable(index=[regions, unicrops, time], unit="\$")
    # Total cultivation costs per crop
    unicultivationcost = Variable(index=[regions, unicrops, time], unit="\$")

    function run_timestep(p, v, d, tt)
        for rr in d.regions
            totalirrigation = 0.
            allagarea = 0.

            for cc in d.unicrops
                v.totalareas2[rr, cc, tt] = p.totalareas[rr, cc, tt]
                v.allagarea += p.totalareas[rr, cc, tt]

                # Calculate irrigation water, summed across all crops: 1 mm * Ha = 10 m^3
                totalirrigation += p.totalareas[rr, cc, tt] * p.irrigation_rate[rr, cc, tt] / 100

                # Calculate total production
                v.yield2[rr, cc, tt] = p.yield[rr, cc, tt]
                v.production[rr, cc, tt] = p.yield[rr, cc, tt] * p.totalareas[rr, cc, tt] * 2.47105 # convert acres to Ha

                # Calculate cultivation costs
                v.unicultivationcost[rr, cc, tt] = p.totalareas[rr, cc, tt] * cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"] / 12 # convert acres to Ha
                # Calculate Operating cost
                v.opcost[rr,cc,tt]= p.totalareas[rr, cc, tt] * uniopcost[rr,cc] * 2.47105 * config["timestep"] / 12

            end

            v.totalirrigation[rr, tt] = totalirrigation
            #v.allagarea[rr, tt] = allagarea
        end
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
      if unicrops[cc] in ["corn.co.rainfed", "corn.co.irrigated", "wheat.co.rainfed", "wheat.co.irrigated"]
            yield[:,cc,:] = read_nareshyields(unicrops[cc])
            for rr in 1:numcounties
                for tt in 1:numsteps
                    water_demand = water_requirements[unicrops[cc]] * 1000
                    water_deficit = max(0., water_demand - rollingsum[rr, tt])
                    irrigation_rate[rr, cc, tt] = unicrop_irrigationrate[unicrops[cc]] + water_deficit * unicrop_irrigationstress[unicrops[cc]] / 1000
                end
            end
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
                        if ismissing(numgdds)
                            numgdds = 0
                        end

                        numkdds = kdds[rr, Symbol("x$year")]
                        if ismissing(numkdds)
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
  agriculture = add_comp!(m, UnivariateAgriculture)

    agriculture[:yield] = yield
    #if config["filterstate"]=="08"
    #    yield[:,5,:]=yield[:,5,:]*10
    #    yield[:,8,:]=min(yield[:,8,:]*1.5,maximum_yields["hay"])
    #    end
   # agriculture[:yield] = yield
    agriculture[:irrigation_rate] = irrigation_rate

    # Load in planted area
    totalareas = getfilteredtable("agriculture/totalareas.csv")
    if isempty(unicrops)
        agriculture[:totalareas] = zeros(Float64, (nrow(totalareas), 0, numsteps))
        agriculture[:totalareas_cst] = zeros(Float64, (nrow(totalareas), 0))
    else
        constantareas = zeros(numcounties, numunicrops)
        sorghumarea=zeros(numcounties, numsteps)
        allagarea=zeros(numcounties, numsteps)
        maxarea=zeros(numcounties, numsteps)
        hayproduction=ones(numsteps)
        barleyproduction=ones(numsteps)
        if config["filterstate"]=="08"
            agriculture[:hayproduction]=3.63e6*hayproduction
            agriculture[:barleyproduction]=6.7397e6*barleyproduction
            constantareas=convert(Array,readtable(datapath("../Colorado/coloradoarea.csv")))
            sorghumarea=constantareas[:,4]
            maxarea=sum(constantareas,2)
            else
            for cc in 1:numunicrops
                if unicrops[cc] in keys(quickstats_planted)
                    constantareas[:, cc] = read_quickstats(datapath(quickstats_planted[unicrops[cc]]))
                else
                    column = findfirst(Symbol(unicrops[cc]) .== names(totalareas))
                    constantareas[:, cc] = totalareas[column]*0.404686#Convert to Ha
                    constantareas[isna(totalareas[column]), cc] .= 0.

                    end
            end
            if isfile(datapath("../Colorado/totalareas_cst-08.jld"))
            constantareas=
deserialize(open(datapath("../Colorado/totalareas_cst-08.jld"), "r"));
            elseif isfile(datapath("../Colorado/totalarea1-08.csv"))
             constantareas=convert(Array,readtable(datapath("../Colorado/totalarea1-08.csv")))
            end
        end
        constantareas=convert(Array,readtable(datapath("../Colorado/totalarea1-08.csv")))
        agriculture[:totalareas_cst] =constantareas
        agriculture[:totalareas] = repnew(constantareas, numsteps)
        agriculture[:sorghumarea] =repeat(sorghumarea, outer=[1, numsteps])
        agriculture[:maxarea] =repeat(maxarea, outer=[1, numsteps])
        if isfile(datapath("../extraction/totalareas$suffix.jld"))
            agriculture[:totalareas]=
deserialize(open(datapath("../extraction/totalareas$suffix.jld"), "r"));
            end
    end

    agriculture
end


#########PRODUCTION#########
function grad_univariateagriculture_production_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :production, :totalareas, (rr, cc, tt) -> m.parameters[:yield].values[rr, cc, tt] * 2.47105 * config["timestep"]/12) # Convert Ha to acres
end
function grad_univariateagriculture_production_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                for tt in 1:numsteps
                    A[fromindex([rr,cc,tt],[numcounties,numunicrops,numsteps]), fromindex([rr,cc],[numcounties,numunicrops])] =m.parameters[:yield].values[rr, cc, tt] * 2.47105 * config["timestep"]/12
                end
            end
        end
        return A
    end
    roomintersect(m,:UnivariateAgriculture, :production, :totalareas_cst ,generate)
end




#########IRRIGATION#########
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

function grad_univariateagriculture_totalirrigation_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for tt in 1:numsteps
                for cc in 1:numunicrops
                    A[fromindex([rr, tt], [numcounties, numsteps]),fromindex([rr, cc], [numcounties, numunicrops])] = m.parameters[:irrigation_rate].values[rr, cc, tt] / 100
                end
            end
        end

        return A
    end
    roomintersect(m, :UnivariateAgriculture, :totalirrigation, :totalareas_cst, generate)
end





#########CULTIVATION COSTS #########
function grad_univariateagriculture_cost_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :unicultivationcost, :totalareas, (rr, cc, tt) -> cultivation_costs[unicrops[cc]] * 2.47105 * config["timestep"]/12) # convert acres to Ha
end

function grad_univariateagriculture_opcost_totalareas(m::Model)
    roomdiagonal(m, :UnivariateAgriculture, :opcost, :totalareas, (rr, cc, tt) -> uniopcost[rr,cc] * 2.47105* config["timestep"]/12) # convert acres to Ha
end

function grad_univariateagriculture_opcost_totalareas_cst(m::Model)
        function generate(A)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                for tt in 1:numsteps
                    A[fromindex([rr,cc,tt],[numcounties,numunicrops,numsteps]), fromindex([rr,cc],[numcounties,numunicrops])] = uniopcost[rr,cc] * 2.47105* config["timestep"]/12
                end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture,:opcost,:totalareas_cst,generate)
end


#########Total culti area #########
function grad_univariateagriculture_maxarea_totalareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                A[rr, fromindex([rr, cc], [numcounties, numunicrops])] = 1.
            end
        end

        return A
    end

    roomintersect(m, :UnivariateAgriculture, :maxarea, :totalareas, generate)
end


function grad_univariateagriculture_maxarea_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for tt in 1:numsteps
                for cc in 1:numunicrops
                    A[fromindex([rr, tt], [numcounties, numsteps]),fromindex([rr, cc], [numcounties, numunicrops])] = 1.
                end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture, :maxarea, :totalareas_cst, generate)
end






#Sorghum Area constraint at county level

function grad_univariateagriculture_sorghumarea_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for tt in 1:numsteps
                for cc in 1:numunicrops
                    if unicrops[cc]=="sorghum"
                     A[fromindex([rr, tt], [numcounties, numsteps]),fromindex([rr, cc], [numcounties, numunicrops])] = 1.
                    else
                       A[fromindex([rr, tt], [numcounties, numsteps]),fromindex([rr, cc], [numcounties, numunicrops])] .= 0.
                    end
                end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture, :sorghumarea, :totalareas_cst, generate)
end
function grad_univariateagriculture_sorghumarea_totalareas(m::Model)
    function generate(A, tt)
        for rr in 1:numcounties
            for cc in 1:numunicrops
                if unicrops[cc]=="sorghum"
                    A[rr, fromindex([rr, cc], [numcounties, numunicrops])] .= 1.
                    else
                    A[rr, fromindex([rr, cc], [numcounties, numunicrops])] .= 0
                    end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture, :sorghumarea, :totalareas, generate)
end




#Hay Production constraint at state level

function grad_univariateagriculture_hayproduction_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for tt in 1:numsteps
                for cc in 1:numunicrops
                    if unicrops[cc]=="hay"
                    A[fromindex([tt],[numsteps]),fromindex([rr, cc],[numcounties, numunicrops])] =m.parameters[:yield].values[rr, cc, tt] * 2.47105 * config["timestep"]/12
                    else
                    A[fromindex([tt],[numsteps]),fromindex([rr, cc],[numcounties, numunicrops])] =0.
                    end
                end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture, :hayproduction, :totalareas_cst, generate)
end


#barley Production constraint at state level

function grad_univariateagriculture_barleyproduction_totalareas_cst(m::Model)
    function generate(A)
        for rr in 1:numcounties
            for tt in 1:numsteps
                for cc in 1:numunicrops
                    if unicrops[cc]=="barley"
                    A[fromindex([tt],[numsteps]),fromindex([rr, cc],[numcounties, numunicrops])] =m.parameters[:yield].values[rr, cc, tt] * 2.47105 * config["timestep"]/12
                    else
                    A[fromindex([tt],[numsteps]),fromindex([rr, cc],[numcounties, numunicrops])] =0.
                    end
                end
            end
        end
        return A
    end
    roomintersect(m, :UnivariateAgriculture, :barleyproduction, :totalareas_cst, generate)
end


function constraintoffset_univariateagriculture_sorghumareas(m::Model)
    gen(rr,tt)=m.parameters[:sorghumareas].values[rr,tt]
    hallsingle(m, :UnivariateAgriculture, :sorghumareas,gen)
end



function constraintoffset_univariateagriculture_maxarea(m::Model)
    gen(rr,tt)=m.parameters[:maxarea].values[rr,tt]
    hallsingle(m, :UnivariateAgriculture, :allagarea,gen)
end

function constraintoffset_univariateagriculture_hayproduction(m::Model)
    gen(tt)=3.6334980300628343e6
    hallsingle(m, :UnivariateAgriculture, :hayproduction, gen)
end

function constraintoffset_univariateagriculture_barleyproduction(m::Model)
    gen(tt)=6.7397e6
    hallsingle(m, :UnivariateAgriculture, :barleyproduction, gen)
end



function constraintoffset_univariateagriculture_sorghumarea(m::Model)
    sorghum=readtable(datapath("../Colorado/sorghum.csv"))[:x][:,1]
    sorghum=repeat(convert(Vector,sorghum),outer=[1,numsteps])
    gen(rr,tt)=sorghum[rr,tt]
    hallsingle(m, :UnivariateAgriculture, :sorghumarea,gen)
end


