## Known Demand Optimization Model construction
#
# Provides `optimization_given`, which produces a linear programming
# model where demands are exogenous.

using Mimi
using OptiMimi

include("world.jl")
if config["dataset"] == "three"
    include("weather-three.jl")
else
    include("weather.jl")
end

redogwwo = !isfile(cachepath("partialhouse2$suffix.jld"))

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
    if allowreservoirs
        reservoir = initreservoir(m); # Allocation or optimization-only
    end
    returnflows = initreturnflows(m); # dep. Allocation
    waternetwork = initwaternetwork(m); # dep. ReturnFlows
    aquifer = initaquifer(m);

    # Only include variables needed in constraints and parameters needed in optimization

    paramcomps = [:Allocation, :Allocation, :Allocation]
    parameters = [:waterfromsupersource, :withdrawals, :returns]

    constcomps = [:WaterNetwork, :Allocation, :Allocation]
    constraints = [:outflows, :balance, :returnbalance]

    if allowgw
        # Include groundwater
        paramcomps = [paramcomps; :Allocation]
        parameters = [parameters; :waterfromgw]
    end

    if allowreservoirs
        # Include reservoir logic
        paramcomps = [paramcomps; :Reservoir]
        parameters = [parameters; :captures]

        constcomps = [constcomps; :Reservoir; :Reservoir]
        constraints = [constraints; :storagemin; :storagemax]
    end

    ## Constraint definitions:
    # outflows is the water in the stream
    # swbalance is the demand minus supply
    # Reservoir storage cannot be <min or >max

    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints, Dict(:storagemin => :storage, :storagemax => :storage));

    # Minimize supersource_cost + withdrawal_cost + suboptimallevel_cost
    if allowgw
        setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    end
    setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
    setobjective!(house, -varsum(grad_allocation_cost_waterfromsupersource(m)))

    # Constrain that the water in the stream is non-negative:
    # That is, outflows + runoff > 0, or -outflows < runoff
    if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(cachepath("partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_outflows(m);
        serialize(open(cachepath("partialhouse2$suffix.jld"), "w"), cwro);
        if allowreservoirs
            gror = grad_reservoir_outflows_captures(m);
            serialize(open(cachepath("partialhouse-gror$suffix.jld"), "w"), gror);
        end
    else
        gwwo = deserialize(open(cachepath("partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(cachepath("partialhouse2$suffix.jld"), "r"));
        if allowreservoirs
            gror = deserialize(open(cachepath("partialhouse-gror$suffix.jld"), "r"));
        end
    end

    # Specify the components affecting outflow: withdrawals, returns, captures
    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraint!(house, room_relabel_parameter(gwwo - grad_waternetwork_immediateoutflows_withdrawals(m), :withdrawals, :Allocation, :returns)) # -
    if allowreservoirs
        setconstraint!(house, -gror) # +
    end
    # Specify that these can at most equal the cummulative runoff
    setconstraintoffset!(house, cwro) # +

    # Constrain swdemand < swsupply, or recorded < supersource + withdrawals, or -supersource - withdrawals < -recorded
    setconstraint!(house, -grad_allocation_balance_waterfromsupersource(m)) # -
    if allowgw
        setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    end
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # -
    setconstraintoffset!(house, -constraintoffset_allocation_recordedtotal(m, allowgw, demandmodel)) # -

    # Constraint returnbalance < 0, or returns - waterreturn < 0, or returns < waterreturn
    # `waterreturn` is by region, and is then distributed into canals as `returns`
    # `returns` must be less than `waterreturn`, so that additional water doesn't appear in streams
    setconstraint!(house, grad_allocation_returnbalance_returns(m)) # +
    if config["dataset"] == "three"
        setconstraintoffset!(house, LinearProgrammingHall(:Allocation, :returnbalance, [0., 0., 0., 0., 0., 0., 0., 0., 0.]))
    else
        setconstraintoffset!(house, -hall_relabel(grad_waterdemand_totalreturn_totalirrigation(m) * values_waterdemand_recordedirrigation(m, allowgw, demandmodel) +
                                                  grad_waterdemand_totalreturn_domesticuse(m) * values_waterdemand_recordeddomestic(m) +
			                          grad_waterdemand_totalreturn_industrialuse(m) * values_waterdemand_recordedindustrial(m) +
                                                  grad_waterdemand_totalreturn_thermoelectricuse(m) * values_waterdemand_recordedthermoelectric(m) +
                                                  grad_waterdemand_totalreturn_livestockuse(m) * values_waterdemand_recordedlivestock(m),
        :totalreturn, :Allocation, :returnbalance)) # +
    end

    if allowreservoirs
        # Reservoir constraints:
        # initial storage and evaporation have been added
        # min storage is reservoir min
        # max storage is reservoir max

        # Constrain storage > min or -storage < -min
        setconstraint!(house, -room_relabel(grad_reservoir_storage_captures(m), :storage, :Reservoir, :storagemin)) # -
        setconstraintoffset!(house, hall_relabel(-constraintoffset_reservoir_storagecapacitymin(m)+constraintoffset_reservoir_storage0(m), :storage, :Reservoir, :storagemin))

        # Constrain storage < max
        setconstraint!(house, room_relabel(grad_reservoir_storage_captures(m), :storage, :Reservoir, :storagemax)) # +
        setconstraintoffset!(house, hall_relabel(constraintoffset_reservoir_storagecapacitymax(m)-constraintoffset_reservoir_storage0(m), :storage, :Reservoir, :storagemax))

        setlower!(house, LinearProgrammingHall(:Reservoir, :captures, ones(numreservoirs * numsteps) * -Inf))
    end

    # Clean up

    house.b[isnan.(house.b)] = 0
    house.b[house.b .== Inf] = 1e9
    house.b[house.b .== -Inf] = -1e9
    house.f[isnan.(house.f)] = 0
    house.f[house.f .== Inf] = 1e9
    house.f[house.f .== -Inf] = -1e9

    ri, ci, vv = findnz(house.A)
    for ii in find(isnan.(vv))
        house.A[ri[ii], ci[ii]] = vv[ii]
    end
    for ii in find(!isfinite.(vv))
        house.A[ri[ii], ci[ii]] = 1e9
    end

    house
end
