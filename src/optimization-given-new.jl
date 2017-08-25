using Mimi
using OptiMimi


redohouse = true #!isfile(cachepath("fullhouse$suffix.jld"))
redogwwo = true #!isfile(cachepath("partialhouse2$suffix.jld"))

include("world.jl")
include("weather.jl")
include("WaterDemand.jl")
include("WaterNetwork.jl")
include("Allocation.jl")
include("ReturnFlows.jl")
include("Reservoir.jl")
include("Groundwater.jl")

function optimization_given(allowgw=false, allowreservoirs=true, demandmodel=nothing)
    # First solve entire problem in a single timestep
    m = newmodel();

    # Add all of the components
    waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
    allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
    reservoir = initreservoir(m); # Allocation or optimization-only
    returnflows = initreturnflows(m); # dep. Allocation
    waternetwork = initwaternetwork(m); # dep. ReturnFlows
    aquifer = initaquifer(m);

    # Only include variables needed in constraints and parameters needed in optimization

    paramcomps = [:Allocation, :Allocation, :Allocation]
    parameters = [:waterfromsupersource, :withdrawals, :waterfromgw]

    constcomps = [:WaterNetwork, :Allocation, :Allocation]
    constraints = [:outflows, :balance, :returnbalance]

   
    ## Constraint definitions:
    # outflows is the water in the stream
    # swbalance is the demand minus supply
    # Reservoir storage cannot be <min or >max

    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints, Dict(:storagemin => :storage, :storagemax => :storage));

    # Minimize supersource_cost + withdrawal_cost + suboptimallevel_cost
    
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
    setobjective!(house, -varsum(grad_allocation_cost_waterfromsupersource(m)))

    # Constrain that the water in the stream is non-negative:
    # That is, outflows + runoff > 0, or -outflows < runoff
    if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(datapath("partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_outflows(m);
        serialize(open(datapath("partialhouse2$suffix.jld"), "w"), cwro);
    else
        gwwo = deserialize(open(datapath("partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(datapath("partialhouse2$suffix.jld"), "r"));
    end

    # Specify the components affecting outflow: withdrawals, returns, captures
    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraintoffset!(house, cwro) # +

    # Constrain swdemand < swsupply, or recorded < supersource + withdrawals, or -supersource - withdrawals < -recorded
    
    setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_balance_waterfromsupersource(m))
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
    
    setconstraintoffset!(house, -constraintoffset_allocation_recordedtotal(m, allowgw, demandmodel)) # -

    # Constraint returnbalance < 0, or returns - waterreturn < 0, or returns < waterreturn
    # `waterreturn` is by region, and is then distributed into canals as `returns`
    # `returns` must be less than `waterreturn`, so that additional water doesn't appear in streams
    
    


    # Clean up

    house.b[isnan(house.b)] = 0
    house.b[house.b .== Inf] = 1e9
    house.b[house.b .== -Inf] = -1e9
    house.f[isnan(house.f)] = 0
    house.f[house.f .== Inf] = 1e9
    house.f[house.f .== -Inf] = -1e9

    ri, ci, vv = findnz(house.A)
    for ii in find(isnan(vv))
        house.A[ri[ii], ci[ii]] = vv[ii]
    end
    for ii in find(!isfinite(vv))
        house.A[ri[ii], ci[ii]] = 1e9
    end

    house
end 