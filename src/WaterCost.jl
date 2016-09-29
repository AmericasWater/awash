using Mimi
using Distributions

include("lib/datastore.jl")

@defcomp WaterCost begin
    regions = Index()
    canals = Index()
    aquifers = Index()

    # UNIT COST
    # Groundwater
    unitgwcost = Parameter(index=[aquifers, time], unit="\$/1000 m^3")
    # Surfacewater
    unitswcost = Parameter(index=[canals, time], unit="\$/1000 m^3")
    # Supersource
    unitsupersourcecost = Parameter(index=[regions, time], unit="\$/1000 m^3")
    
    # VOLUMES 
    swwithdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    gwextraction = Parameter(index=[aquifers, time], unit="1000 m^3")
    supersourcesupply = Parameter(index=[regions, time], unit="1000 m^3")
    # COST
    gwcost = Variable(index=[regions, time], unit="\$/1000 m^3")
    swcost = Variable(index=[regions, time], unit="\$/1000 m^3")
    supersourcecost = Variable(index=[regions, time], unit="\$/1000 m^3")
    totalcost = Variable(index=[regions, time], unit="\$/1000 m^3")
    
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
		    v.swcost[rr,tt] += p.swwithdrawals[pp,tt]*p.unitswcost[pp, tt]
	    end
    end

    for rr in 1:numcounties
	    v.gwcost[rr,tt] = p.unitgwcost[rr,tt]*p.gwextraction[rr,tt]
	    v.supersourcecost[rr,tt] = p.supersourcesupply[rr,tt]*p.unitsupersourcecost[rr,tt]
	    v.totalcost[rr,tt] = v.swcost[rr,tt] + v.gwcost[rr,tt] + v.supersourcecost[rr,tt]
    end
    
end

"""
Add a cost component to the model.
"""
function initwatercost(m::Model)
    watercost = addcomponent(m, WaterCost);
    if config["watercostmodel"] == "basic"
	    watercost[:unitgwcost] = 100*ones(m.indices_counts[:aquifers], m.indices_counts[:time]);
	    watercost[:unitswcost] = 1*ones(m.indices_counts[:canals], m.indices_counts[:time]);
    
    elseif config["watercostmodel"] == "extractiongw"
	    watercost[:unitgwcost] = 1e2+repeat(readdlm(datapath("cost/drawdown0.txt")), outer=[1, m.indices_counts[:time]]);
	    watercost[:unitswcost] = 1*ones(m.indices_counts[:canals], m.indices_counts[:time]);
	   
    elseif config["watercostmodel"] == "extractionswgw"
	    watercost[:unitgwcost] = 1e2+repeat(readdlm(datapath("cost/drawdown0.txt")), outer=[1, m.indices_counts[:time]]);
 	    
	    watercost[:unitswcost] = 1*ones(m.indices_counts[:canals], m.indices_counts[:time]); #to be changed
    end

    watercost[:unitsupersourcecost] = 1e6*ones(m.indices_counts[:regions], m.indices_counts[:time]);
    watercost
end


function waterallocationobj(m::Model)
     -sum(m.components[:WaterCost].Variables.totalcost)
end

function soleobjective_allocation(m::Model)
     sum(model[:WaterCost, :totalcost])
end

function grad_costgw(m::Model)
	roomdiagonal(m, :WaterCost, :gwcost, :gwextraction, (rr, tt) -> m.parameters[:unitgwcost].values[rr,tt])
end
 
function grad_costsupersource(m::Model)
	roomdiagonal(m, :WaterCost, :supersourcecost, :supersourcesupply, (rr, tt) -> m.parameters[:unitsupersourcecost].values[rr,tt])
end
 
## Optional cost for drawing down a river (environmental change)
function grad_allocation_cost_withdrawals(m::Model)
     roomdiagonal(m, :Allocation, :cost, :withdrawals, (cc, tt) -> .01)
end

