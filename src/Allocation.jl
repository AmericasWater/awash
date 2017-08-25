using Mimi
using Distributions

include("lib/datastore.jl")
include("watercostdata.jl") 

@defcomp Allocation begin
    regions = Index()

    # Water demand aggregated accross all sectors
    watertotaldemand = Parameter(index=[regions, time], unit="1000 m^3")
    # Water return flows
    waterreturn = Parameter(index=[regions, time], unit="1000 m^3")

    # Extracted water and returned water set by optimisation
    # How much to send from each gauge to each county
    withdrawals = Parameter(index=[canals, time], unit="1000 m^3")
    # How much is returned to each withdrawal source?
    returns = Parameter(index=[canals, time], unit="1000 m^3")

    # For now, exact copy of withdrawals; later, the amount actually provided for each withdrawal?
    copy_withdrawals = Variable(index=[canals, time], unit="1000 m^3")
    # For now, exact copy of returns; later, the amount actually returned?
    copy_returns = Variable(index=[canals, time], unit="1000 m^3")

    # Extracted water (1000 m3) to be set by optimisation - super source represents failure.
    waterfromgw = Parameter(index=[regions, time], unit="1000 m^3")
    waterfromsw = Parameter(index=[regions, time], unit="1000 m^3")
    waterfromreservoir = Parameter(index=[regions,time], unit="1000 m^3")

    waterfromsupersource = Parameter(index=[regions,time], unit="1000 m^3")
    watergw = Variable(index=[regions, time], unit="1000 m^3")

    # The cost in USD / 1000 m^3 of extraction 
    unitgwextractioncost = Parameter(index=[aquifers, time], unit="\$/1000 m^3")
    unitswextractioncost = Parameter(index=[canals, time], unit="\$/1000 m^3")
    unitsupersourcecost = Parameter(unit="\$/1000 m^3")
    
    # Total water cost for eachs county
    cost = Variable(index=[regions, time], "\$")
    swcost = Variable(index=[regions, time], "\$")

    # Combination across all canals supplying the counties
    swsupply = Variable(index=[regions, time], unit="1000 m^3")
    # Combination across all canals routing return flow from the counties
    swreturn = Variable(index=[regions, time], unit="1000 m^3")

    # Amount available from all sources
    waterallocated = Variable(index=[regions,time], unit="1000 m^3")

    # Difference between waterallocated and watertotaldemand
    balance = Variable(index=[regions, time], unit="1000 m^3")
    totalGW=Variable(index=[time],unit="1000m^3")                      #STATE LEVEL CONSTRAINT 
    totalSW=Variable(index=[time],unit="1000m^3")                      #STATE LEVEL CONSTRAINT 
    totalTot=Variable(index=[time],unit="1000m^3") 
    #totaluse=Variable(index=[regions,time],unit="1000m^3")             #COUNTY LEVEL CONSTRAINT 
    recorded_GW=Parameter(index=[regions,time],unit="1000m^3")
    #recorded_Total=Parameter(index=[regions,time],unit="1000m^3")

    # Difference between swreturn and waterreturn: should be <= 0
    returnbalance = Variable(index=[regions, time], unit="1000 m^3")
end

"""
Sums the water from various sources and computes the cost
"""
function run_timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Surface water calculations
    v.swsupply[:, tt] = zeros(numcounties)
    v.swreturn[:, tt] = zeros(numcounties)
    v.swcost[:,tt] = zeros(numcounties)
    for pp in 1:nrow(draws)
        regionids = regionindex(draws, pp)
        rr = findfirst(regionindex(masterregions, :) .== regionids)
        if rr > 0
            v.swsupply[rr, tt] += p.withdrawals[pp, tt]
            v.swcost[rr, tt] += p.withdrawals[pp, tt] * p.unitswextractioncost[pp,tt]
            v.swreturn[rr, tt] += p.returns[pp, tt]
        end
        v.copy_withdrawals[pp, tt] = p.withdrawals[pp, tt]
        v.copy_returns[pp, tt] = p.returns[pp, tt]
    end


    for rr in d.regions
        v.watergw[rr,tt] = p.waterfromgw[rr,tt]
        v.waterallocated[rr,tt] = p.waterfromgw[rr,tt]+p.waterfromsupersource[rr,tt] + v.swsupply[rr, tt]
        v.cost[rr, tt] = p.waterfromgw[rr,tt]*p.unitgwextractioncost[rr,tt] + v.swcost[rr,tt] + p.waterfromsupersource[rr,tt]*p.unitsupersourcecost 

        v.balance[rr, tt] = v.waterallocated[rr, tt] - p.watertotaldemand[rr, tt]
        #v.totaluse[rr,tt]=v.waterallocated[rr,tt]
        v.returnbalance[rr, tt] = v.swreturn[rr, tt] - p.waterreturn[rr, tt]
       
    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    
    allocation = addcomponent(m, Allocation)
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    allocation[:watertotaldemand] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #allocation[:recorded_GW]=repeat(recorded_GW,outer=[1,numsteps])
    
    
    #allocation[:recorded_GW]=repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"],outer=[1,numsteps])

    allocation[:unitgwextractioncost] = repeat(aquiferextractioncost, outer = [1,numsteps])+0.1;
    allocation[:unitswextractioncost] = repeat(canalextractioncost, outer = [1,numsteps])+0.1;
    allocation[:unitsupersourcecost] = 1e6 
    #was 0.2*0.1 or 0.001 

    # Check if there are saved withdrawals and return flows (from optimize-surface)
    if config["dataset"] == "three"
	    allocation[:withdrawals] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:returns] = zeros(m.indices_counts[:canals], m.indices_counts[:time]);
    	allocation[:waterfromgw] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    	allocation[:waterfromsupersource] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    else

    allocation[:recorded_GW]=repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"],outer=[1,numsteps])    
       
	allocation[:withdrawals] = cached_fallback("../extraction/withdrawals", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
        
        
        
        
	allocation[:returns] = cached_fallback("extraction/returns", () -> zeros(m.indices_counts[:canals], m.indices_counts[:time]))
	#allocation[:waterfromgw] = cached_fallback("../extraction/waterfromgw", () -> repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"], outer=[1,numsteps]));
        if isfile(datapath("../extraction/waterfromgw-08.jld"))
            waterfromgw = deserialize(open(datapath("../extraction/waterfromgw$suffix.jld"), "r"));
            else 
            waterfromgw =repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"], outer=[1,numsteps]);
        end 
            
        
        allocation[:waterfromgw]=waterfromgw     
        
        
        if isfile(datapath("../extraction/withdrawals-08.jld"))
            withdrawals = deserialize(open(datapath("../extraction/withdrawals$suffix.jld"), "r"));
            else 
            withdrawals=repeat(convert(Vector, recorded[:, :TO_SW]) * 1383./12. *config["timestep"], outer=[1,numsteps]);
        end 
allocation[:withdrawals]=withdrawals 
        
        
        
        
        
        #zeros(m.indices_counts[:regions], m.indices_counts[:time]));
        allocation[:waterfromsupersource] = cached_fallback("../extraction/supersource", () -> zeros(m.indices_counts[:regions], m.indices_counts[:time]));

       
        
        
    end

    allocation
end

"""
The objective is to minimize water allocation costs at all time
"""




function waterallocationobj(m::Model)
    -sum(m.components[:Allocation].Variables.cost)
end

function makeconstraintdemandmet(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.watertotaldemand[aa,tt] - m.components[:Allocation].Variables.waterallocated[aa,tt]
    end
end

function soleobjective_allocation(m::Model)
    sum(model[:Allocation, :cost])
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, (rr, tt) -> 1.)
end

function grad_allocation_balance_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromsupersource, (rr, tt) -> 1.)
end

function grad_allocation_balance_waterfromgw(m::Model)
    roomdiagonal(m, :Allocation, :balance, :waterfromgw, (rr, tt) -> 1.)
end

function grad_allocation_cost_waterfromgw(m::Model)

    roomdiagonal(m, :Allocation, :cost, :waterfromgw, (rr, tt) -> m.parameters[:unitgwextractioncost].values[rr,tt])

end

function grad_allocation_cost_waterfromsupersource(m::Model)
    roomdiagonal(m, :Allocation, :cost, :waterfromsupersource, (rr, tt) -> 1e6)
end

## Optional cost for drawing down a river (environmental change)
function grad_allocation_cost_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            mastercounties=readtable(joinpath(datapath("global/counties.csv")));
            fips = draws[pp, :fips] < 10000 ? (draws[pp, :fips] < 10 ? "0000$(draws[pp, :fips])" : "0$(draws[pp, :fips])") : "$(draws[pp, :fips])"
            rr = findfirst(mastercounties[:fips] .== fips)
            if rr > 0
                A[rr, pp] = m.parameters[:unitswextractioncost].values[rr,pp]

            end
        end
    end

    roomintersect(m, :Allocation, :cost, :withdrawals, generate)

end

function grad_allocation_balance_withdrawals(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :balance, :withdrawals, generate)
end


################TOTAL USE CONSTRAINT###########################
function grad_allocation_totalGW_waterfromgw_(m::Model)    #COUNTY LEVEL CONSTRAINT old 
    roomdiagonal(m,:Allocation, :totalGW, :waterfromgw, (rr, tt)-> 1.)
end



function grad_allocation_totalGW_waterfromgw(m::Model)    #STATE LEVEL CONSTRAINT 
    function generate(A,tt)
        A[:] = 1
    end    
    roomintersect(m,:Allocation, :totalGW, :waterfromgw,generate)
end 

function grad_allocation_totalTot_waterfromgw(m::Model)    #STATE LEVEL CONSTRAINT 
    function generate(A,tt)
        A[:] = 1
    end    
    roomintersect(m,:Allocation, :totalTot, :waterfromgw,generate)
end 


function grad_allocation_totalTot_withdrawals(m::Model)    #STATE LEVEL CONSTRAINT 
    function generate(A,tt)
        A[:] = 1
    end    
    roomintersect(m,:Allocation, :totalTot, :withdrawals,generate)
end 






function constraintoffset_allocation_totaluse_(m::Model) #COUNTY LEVEL CONSTRAINT 
    recorded_GW=repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"],outer=[1,numsteps])
    gen(rr, tt) = recorded_GW[rr,tt]
    hallsingle(m, :Allocation, :totaluse, gen)
end

function constraintoffset_allocation_totalGW(m::Model) #STATE LEVEL CONSTRAINT 
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    recorded_GW=repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"],outer=[1,numsteps])
    recorded_GW=sum(recorded_GW,1)
    gen(tt)=recorded_GW[tt]
    hallsingle(m, :Allocation, :totalGW,gen)
end




function constraintoffset_allocation_totalSW(m::Model) #STATE LEVEL CONSTRAINT 
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    recorded_GW=repeat(convert(Vector, recorded[:, :TO_SW]) * 1383./12. *config["timestep"],outer=[1,numsteps])
    recorded_SW=sum(recorded_SW,1)
    gen(tt)=recorded_SW[tt]
    hallsingle(m, :Allocation, :totalSW,gen)
end


#change GW dimension for County OR State 

function constraintoffset_allocation_totalTot(m::Model) #STATE LEVEL CONSTRAINT 
    recorded = getfilteredtable("extraction/USGS-2010.csv")
    recorded_GW=repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"],outer=[1,numsteps])
    recorded_SW=repeat(convert(Vector, recorded[:, :TO_SW]) * 1383./12. *config["timestep"],outer=[1,numsteps])
    recorded_GW=sum(recorded_GW,1)
    recorded_SW=sum(recorded_SW,1)
    recorded_Tot=recorded_SW+recorded_GW
    gen(tt)=recorded_Tot[tt]
    hallsingle(m, :Allocation, :totalTot,gen)
end



################TOTAL USE CONSTRAINT###########################



function grad_allocation_returnbalance_returns(m::Model)
    function generate(A, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr > 0
                A[rr, pp] = 1.
            end
        end
    end

    roomintersect(m, :Allocation, :returnbalance, :returns, generate)
end

function constraintoffset_allocation_recordedtotal_(m::Model)#, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    #if demandmodel == nothing
    #    println("nothing") 
    #    constraintoffset_allocation_recordedbalance(m, includegw)
    #else
    gen(rr, tt) = demandmodel[:WaterDemand, :totaldemand][rr,tt]
    hallsingle(m, :Allocation,:balance,gen)# :balance, demandmodel[:WaterDemand, :totaldemand])
    #end
end


function constraintoffset_allocation_recordedtotal(m::Model, includegw::Bool, demandmodel::Union{Model, Void}=nothing)
    if demandmodel == nothing
        constraintoffset_allocation_recordedbalance(m, includegw)
    else
        hallvalues(m, :Allocation, :balance, demandmodel[:WaterDemand, :totaldemand])
    end
end





function constraintoffset_allocation_recordedbalance(m::Model, optimtype)
    if config["dataset"] == "three"
		if optimtype == false
			gen(rr, tt) = 1. * (rr > 1)
		elseif optimtype == true
			gen(rr, tt) = 2. * (rr > 1)
		end
	        hallsingle(m, :Allocation, :balance, gen)
    else

          recorded = getfilteredtable("extraction/USGS-2010.csv")
		# MISSING HERE BREAKDOWN IN FUNCTION OF WHAT WE WANT TO OPTIMIZE
		if optimtype == false
			gen(rr, tt) = config["timestep"] * recorded[rr, :TO_SW] * 1383. / 12
		elseif optimtype == true
			gen(rr, tt) = config["timestep"] * recorded[rr, :TO_To] * 1383. / 12
		end

		hallsingle(m, :Allocation, :balance, gen)
    end
end

function grad_allocation_returnbalance_waterreturn(m::Model)
    roomdiagonal(m, :Allocation, :returnbalance, :waterreturn, (rr, tt) -> 1.)
end

#function constraintoffset_allocation_waterlimit(m::Model)
#    gen=6488602.6457371
#    hallsingle(m, :Allocation, :waterlimit, gen)
#end 
