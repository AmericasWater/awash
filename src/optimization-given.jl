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

redogwwo = !isfile(cachepath("partialhouse-gwwo$suffix.jld")) || !isfile(cachepath("partialhouse-grwo$suffix.jld"))

include("WaterDemand.jl")
include("WaterNetwork.jl")
include("Allocation.jl")
include("ReturnFlows.jl")
include("Reservoir.jl")
include("Groundwater.jl")
include("WaterCost.jl")
include("EnvironmentalDemand.jl")
include("WaterRight.jl")

"""
allowgw: can be false (only surface optimization), true (conjunctive use), or "demandonly" (water stress test)
"""
function optimization_given(allowgw=false, allowreservoirs=true, demandmodel=nothing, waterrightconst=nothing; nocache=redogwwo)
    # First solve entire problem in a single timestep
    m = newmodel();

    # Add all of the components
    waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
    allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
    watercost = initwatercost(m);
    if allowreservoirs
        reservoir = initreservoir(m); # Allocation or optimization-only
    end
    returnflows = initreturnflows(m, allowreservoirs, demandmodel); # dep. Allocation
    waternetwork = initwaternetwork(m); # dep. ReturnFlows
    aquifer = initaquifer(m);
    environmentaldemand = initenvironmentaldemand(m); # dep. WaterNetwork
    waterright = initwaterright(m); # dep. Allocation


    # Only include variables needed in constraints and parameters needed in optimization

    paramcomps = [:Allocation, :Allocation, :Allocation]
    parameters = [:quartersupersourcesupply, :supersourcesupply, :swwithdrawals]

    constcomps = [:WaterNetwork, :Allocation]
    constraints = [:outflows, :balance]

    if allowgw == true
        # Include groundwater
        paramcomps = [paramcomps; :Allocation]
        parameters = [parameters; :gwextraction]
    end

    if allowreservoirs
        # Include reservoir logic
        paramcomps = [paramcomps; :Reservoir]
        parameters = [parameters; :captures]

        constcomps = [constcomps; :Reservoir; :Reservoir]
        constraints = [constraints; :storagemin; :storagemax]
    end

    if waterrightconst == "SW"
        constcomps = [constcomps; :WaterRight]
        constraints = [constraints; :swtotal]
    elseif waterrightconst == "GW"
        constcomps = [constcomps; :WaterRight]
        constraints = [constraints; :gwtotal]
    elseif waterrightconst == "SWGW"
        constcomps = [constcomps; :WaterRight; :WaterRight]
        constraints = [constraints; :swtotal; :gwtotal]
    end

    ## Constraint definitions:
    # outflows is the water in the stream
    # swbalance is the demand minus supply
    # Reservoir storage cannot be <min or >max

    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints, Dict(:quartersupersourcesupply => :supersourcesupply, :storagemin => :storage, :storagemax => :storage));

    # Minimize supersource_cost + withdrawal_cost + suboptimallevel_cost
    if allowgw == true
        setobjective!(house, -hall_relabel(varsum(grad_watercost_costgw(m)), :gwextraction,:Allocation, :gwextraction))
    end
    setobjective!(house, -hall_relabel(varsum(grad_watercost_costswwithdrawals(m)), :swwithdrawals, :Allocation, :swwithdrawals))
    setobjective!(house, -.5 * hall_relabel(varsum(grad_watercost_costsupersource(m)), :supersourcesupply, :Allocation, :quartersupersourcesupply))
    setobjective!(house, -hall_relabel(varsum(grad_watercost_costsupersource(m)), :supersourcesupply, :Allocation, :quartersupersourcesupply))
    if allowreservoirs
        setobjective!(house, -varsum(grad_reservoir_cost_captures(m)))
    end

    # Constrain that the water in the stream is non-negative, or superior to environmental requirement
    # That is, outflows + runoff > envrequirement, or -outflows < runoff - envrequirement
    if nocache
        gwwo = grad_waternetwork_outflows_swwithdrawals(m);
        serialize(open(cachepath("partialhouse-gwwo$suffix.jld"), "w"), gwwo);
        grwo = grad_returnflows_outflows_swwithdrawals(m, allowgw != false, demandmodel);
        serialize(open(cachepath("partialhouse-grwo$suffix.jld"), "w"), grwo);
        if allowreservoirs
            gror = grad_reservoir_outflows_captures(m);
            serialize(open(cachepath("partialhouse-gror$suffix.jld"), "w"), gror);
        end
    else
        gwwo = deserialize(open(cachepath("partialhouse-gwwo$suffix.jld"), "r"));
        grwo = deserialize(open(cachepath("partialhouse-grwo$suffix.jld"), "r"));
        if allowreservoirs
            if isfile(cachepath("partialhouse-gror$suffix.jld"))
                gror = deserialize(open(cachepath("partialhouse-gror$suffix.jld"), "r"));
            else
                gror = grad_reservoir_outflows_captures(m);
            end
        end
    end

    # Specify the components affecting outflow: withdrawals - returns + captures < runoff
    setconstraint!(house, -gwwo + grwo) # + -
    if allowreservoirs
        setconstraint!(house, -gror) # +
    end
    # Specify that these can at most equal the cummulative runoff
    if get(config, "proportionnaturalflowforenvironment", 0.) > 0.
        setconstraintoffset!(house, constraintoffset_waternetwork_outflows(m) - constraintoffset_environmentalflows(m)) # +
    else
        setconstraintoffset!(house, constraintoffset_waternetwork_outflows(m)) # +
    end

    # Constrain swdemand < swsupply, or recorded < supersource + withdrawals, or -supersource - withdrawals < -recorded
    setconstraint!(house, -room_relabel_parameter(grad_allocation_balance_supersourcesupply(m), :supersourcesupply, :Allocation, :quartersupersourcesupply)) # -
    setconstraint!(house, -grad_allocation_balance_supersourcesupply(m)) # -
    if allowgw == true
        setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    end
    setconstraint!(house, -grad_allocation_balance_swwithdrawals(m)) # -
    setconstraintoffset!(house, -constraintoffset_allocation_recordedtotal(m, allowgw != false, demandmodel)) # -

    recorded = knowndf("exogenous-withdrawals")
    setupper!(house, LinearProgrammingHall(:Allocation, :quartersupersourcesupply, vec(repeat((config["timestep"] * convert(Vector, recorded[:, :TO_SW]) * 1383. / 12) / 4, outer=[1, numsteps]))))

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

    # Water rights constraints: swwithdrawals < swwaterights | gwwithdrawals < gwwaterrights
    if waterrightconst == "SW"
        setconstraint!(house, room_relabel_parameter(grad_waterright_swtotal_withdrawals(m), :swtimestep, :Allocation, :withdrawals)) # +
        setconstraintoffset!(house, constraintoffset_waterright_swrighttotal(m)) # +
    elseif waterrightconst == "GW"
        setconstraint!(house, room_relabel_parameter(grad_waterright_gwtotal_waterfromgw(m), :gwtimestep, :Allocation, :waterfromgw))
        setconstraintoffset!(house, constraintoffset_waterright_gwrighttotal(m)) # +
    elseif waterrightconst == "SWGW"
        setconstraint!(house, room_relabel_parameter(grad_waterright_swtotal_withdrawals(m), :swtimestep, :Allocation, :withdrawals)) # +
        setconstraintoffset!(house, constraintoffset_waterright_swrighttotal(m)) # +
        setconstraint!(house, room_relabel_parameter(grad_waterright_gwtotal_waterfromgw(m), :gwtimestep, :Allocation, :waterfromgw))
        setconstraintoffset!(house, constraintoffset_waterright_gwrighttotal(m)) # +
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
    for ii in find(.!isfinite.(vv))
        house.A[ri[ii], ci[ii]] = 1e9
    end

    house
end

"""
Save the results for simulation runs
"""
function save_optimization_given(house::LinearProgrammingHouse, sol, allowgw=false, allowreservoirs=true)
    # The size of each optimized parameter
    varlens = varlengths(house.model, house.paramcomps, house.parameters, Dict(:quartersupersourcesupply => :supersourcesupply))
    varlens = [varlens; 0] # Add dummy, so allowgw can always refer to 1:4

    # Save into serialized files
    serialize(open(datapath("extraction/supersource$suffix.jld"), "w"), reshape(sol.sol[1:varlens[1]], numcanals, numscenarios, numsteps) + reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], numcanals, numscenarios, numsteps))
    serialize(open(datapath("extraction/withdrawals$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], numcanals, numscenarios, numsteps))

    if allowgw == true
        serialize(open(datapath("extraction/waterfromgw$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], numcounties, numscenarios, numsteps))
    elseif isfile(datapath("extraction/waterfromgw$suffix.jld"))
        rm(datapath("extraction/waterfromgw$suffix.jld"))
    end

    if allowreservoirs
        serialize(open(datapath("extraction/captures$suffix.jld"), "w"), reshape(sol.sol[sum(varlens[1:3+(allowgw == true)])+1:end], numreservoirs, numscenarios, numsteps))
    elseif isfile(datapath("extraction/captures$suffix.jld"))
        rm(datapath("extraction/captures$suffix.jld"))
    end
end
