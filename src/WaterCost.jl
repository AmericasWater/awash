using Mimi
using Distributions

include("lib/datastore.jl")
include("watercostdata.jl")

@defcomp WaterCost begin
    regions = Index()
    canals = Index()
    aquifers = Index()
    scenarios = Index()

    # UNIT COST
    # extraction COST
    unitgwextractioncost = Parameter(index=[aquifers, scenarios, time], unit="\$/1000 m^3")
    unitswextractioncost = Parameter(index=[canals, scenarios, time], unit="\$/1000 m^3")
    # treatment cost
    unitgwtreatmentcost = Parameter(index=[regions, scenarios, time], unit="\$/1000 m^3")
    unitswtreatmentcost = Parameter(index=[regions, scenarios, time], unit="\$/1000 m^3")
    # distribution cost
    unitdistributioncost = Parameter(index=[regions, scenarios, time], unit="\$/1000 m^3")
    
    # Supersource
    unitsupersourcecost = Parameter(index=[regions, scenarios, time], unit="\$/1000 m^3")

    # VOLUMES 
    swwithdrawals = Parameter(index=[canals, scenarios, time], unit="1000 m^3")
    gwextraction = Parameter(index=[aquifers, scenarios, time], unit="1000 m^3")
    supersourcesupply = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    # COST
    gwcost = Variable(index=[regions, scenarios, time], unit="\$/1000 m^3")
    swcost = Variable(index=[regions, scenarios, time], unit="\$/1000 m^3")
    supersourcecost = Variable(index=[regions, scenarios, time], unit="\$/1000 m^3")
    totalcost = Variable(index=[regions, scenarios, time], unit="\$/1000 m^3")
    
end

"""
Sets the cost of the water in function of the state of the system
"""
function run_timestep(c::WaterCost, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    v.swcost[:,tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
	    fips = draws[pp, :fips] < 10000 ? "0$(draws[pp, :fips])" : "$(draws[pp, :fips])"
	    rr = findfirst(mastercounties[:fips] .== fips)
	    if rr > 0
		    v.swcost[rr,tt] += p.swwithdrawals[pp,tt]*(p.unitswextractioncost[pp,tt]+p.unitswtreatmentcost[rr,tt]+p.unitdistributioncost[rr,tt])
	    end
    end

    for rr in 1:numcounties
	    aa = rr
	    v.gwcost[rr,tt] = (p.unitgwextractioncost[aa,tt] + p.unitgwtreatmentcost[rr,tt] + p.unitdistributioncost[rr,tt]) * p.gwextraction[rr,tt]
	    v.supersourcecost[rr,tt] = p.supersourcesupply[rr,tt]*p.unitsupersourcecost[rr,tt]
	    v.totalcost[rr,tt] = v.swcost[rr,tt] + v.gwcost[rr,tt] + v.supersourcecost[rr,tt]
    end
    
end

"""
Add a cost component to the model.
"""
function initwatercost(m::Model)
    watercost = addcomponent(m, WaterCost);
    watercost[:unitgwextractioncost] = repeat(aquiferextractioncost, outer = [1,numsteps])
    watercost[:unitswextractioncost] = repeat(canalextractioncost, outer = [1,numsteps])

    watercost[:unitgwtreatmentcost] = repeat(gwtreatmentcost, outer = [1,numsteps])
    watercost[:unitswtreatmentcost] = repeat(swtreatmentcost, outer = [1,numsteps])
    
    watercost[:unitdistributioncost] = repeat(distributioncost, outer = [1,numsteps])
    watercost[:unitsupersourcecost] = 1e6*ones(m.indices_counts[:regions], m.indices_counts[:time]);
    watercost
end


function waterallocationobj(m::Model)
     -sum(m.components[:WaterCost].Variables.totalcost)
end

function soleobjective_allocation(m::Model)
     sum(model[:WaterCost, :totalcost])
end

function grad_watercost_costgw(m::Model)
	roomdiagonal(m, :WaterCost, :gwcost, :gwextraction, (rr, tt) -> m.parameters[:unitgwextractioncost].values[rr,tt] + m.parameters[:unitgwtreatmentcost].values[rr,tt] + m.parameters[:unitdistributioncost].values[rr,tt])
end
 
function grad_watercost_costsupersource(m::Model)
	roomdiagonal(m, :WaterCost, :supersourcecost, :supersourcesupply, (rr, tt) -> m.parameters[:unitsupersourcecost].values[rr,tt])
end

function grad_watercost_costswwithdrawals(m::Model)
     function generate(A, tt)
         # Fill in COUNTIES x CANALS matrix
         for pp in 1:nrow(draws)
             fips = draws[pp, :fips] < 10000 ? (draws[pp, :fips] < 10 ? "0000$(draws[pp, :fips])" : "0$(draws[pp, :fips])") : "$(draws[pp, :fips])"
             rr = findfirst(mastercounties[:fips] .== fips)
             if rr > 0
		     A[rr, pp] = m.parameters[:unitswextractioncost].values[pp,tt] + m.parameters[:unitswtreatmentcost].values[rr,tt] + m.parameters[:unitdistributioncost].values[rr,tt]
             end
         end
     end
 
     roomintersect(m, :WaterCost, :totalcost, :swwithdrawals, generate)
end

