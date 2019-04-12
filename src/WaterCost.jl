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

    """
    Sets the cost of the water in function of the state of the system
    """
    function run_timestep(p, v, d, t)
        for ss in 1:numscenarios
            v.swcost[:, ss, tt] = zeros(numcounties)
            for pp in 1:nrow(draws)
                regionids = regionindex(draws, pp)
                rr = findfirst(regionindex(masterregions, :) .== regionids)
	        if rr != nothing
	            v.swcost[rr, ss, tt] += p.swwithdrawals[pp, ss, tt]*(p.unitswextractioncost[pp, ss, tt]+p.unitswtreatmentcost[rr, ss, tt]+p.unitdistributioncost[rr, ss, tt])
	        end
            end

            for rr in 1:numcounties
	        aa = rr
	        v.gwcost[rr, ss, tt] = (p.unitgwextractioncost[aa, ss, tt] + p.unitgwtreatmentcost[rr, ss, tt] + p.unitdistributioncost[rr, ss, tt]) * p.gwextraction[rr, ss, tt]
	        v.supersourcecost[rr, ss, tt] = p.supersourcesupply[rr, ss, tt]*p.unitsupersourcecost[rr, ss, tt]
	        v.totalcost[rr, ss, tt] = v.swcost[rr, ss, tt] + v.gwcost[rr, ss, tt] + v.supersourcecost[rr, ss, tt]
            end
        end
    end
end

"""
Add a cost component to the model.
"""
function initwatercost(m::Model)
    watercost = add_comp!(m, WaterCost);
    watercost[:unitgwextractioncost] = repeat(aquiferextractioncost, outer = [1,numscenarios, numsteps])
    watercost[:unitswextractioncost] = repeat(canalextractioncost, outer = [1,numscenarios, numsteps])

    watercost[:unitgwtreatmentcost] = repeat(gwtreatmentcost, outer = [1,numscenarios, numsteps])
    watercost[:unitswtreatmentcost] = repeat(swtreatmentcost, outer = [1,numscenarios, numsteps])

    watercost[:unitdistributioncost] = repeat(distributioncost, outer = [1,numscenarios, numsteps])
    watercost[:unitsupersourcecost] = 1e6*ones(m.indices_counts[:regions], numscenarios, numsteps);
    watercost
end


function waterallocationobj(m::Model)
     -sum(m.components[:WaterCost].Variables.totalcost)
end

function soleobjective_allocation(m::Model)
     sum(model[:WaterCost, :totalcost])
end

function grad_watercost_costgw(m::Model)
	roomdiagonal(m, :WaterCost, :gwcost, :gwextraction, (rr, ss, tt) -> m.md.external_params[:unitgwextractioncost].values[rr, ss, tt] + m.md.external_params[:unitgwtreatmentcost].values[rr, ss, tt] + m.md.external_params[:unitdistributioncost].values[rr, ss, tt])
end

function grad_watercost_costsupersource(m::Model)
	roomdiagonal(m, :WaterCost, :supersourcecost, :supersourcesupply, (rr, ss, tt) -> m.md.external_params[:unitsupersourcecost].values[rr, ss, tt])
end

function grad_watercost_costswwithdrawals(m::Model)
    # Check if cost data is duplicated across s and t
    isduplicated = true
    for pp in 1:nrow(draws)
        if !all(m.md.external_params[:unitswextractioncost].values[pp, :, :] .== m.md.external_params[:unitswextractioncost].values[pp, 1, 1])
            isduplicated = false
            break
        end
    end
    if isduplicated
        for rr in 1:numregions
            if !all(m.md.external_params[:unitswtreatmentcost].values[rr, :, :] .== m.md.external_params[:unitswtreatmentcost].values[rr, 1, 1]) || !all(m.md.external_params[:unitdistributioncost].values[rr, :, :] .== m.md.external_params[:unitdistributioncost].values[rr, 1, 1])
                isduplicated = false
                break
            end
        end
    end

    if isduplicated
        function generate(A)
            # Fill in COUNTIES x CANALS matrix
            for pp in 1:nrow(draws)
                regionids = regionindex(draws, pp)
                rr = findfirst(regionindex(masterregions, :) .== regionids)
                if rr != nothing
		    A[rr, pp] = m.md.external_params[:unitswextractioncost].values[pp, 1, 1] + m.md.external_params[:unitswtreatmentcost].values[rr, 1, 1] + m.md.external_params[:unitdistributioncost].values[rr, 1, 1]
                end
            end
        end

        return roomintersect(m, :WaterCost, :totalcost, :swwithdrawals, generate, [:scenarios, :time], [:scenarios, :time])
    end

    function generate(A, ss, tt)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            regionids = regionindex(draws, pp)
            rr = findfirst(regionindex(masterregions, :) .== regionids)
            if rr != nothing
		A[rr, pp] = m.md.external_params[:unitswextractioncost].values[pp, ss, tt] + m.md.external_params[:unitswtreatmentcost].values[rr, ss, tt] + m.md.external_params[:unitdistributioncost].values[rr, ss, tt]
            end
        end
    end

    roomintersect(m, :WaterCost, :totalcost, :swwithdrawals, generate)
end

