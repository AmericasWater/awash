using Mimi
include("linproghouse.jl")

netset = "usa" # dummy or usa

# Only include counties within this state (give as 2 digit FIPS)
# "10" for Delaware (3 counties), "08" for Colorado (64 counties)
filterstate = nothing #"10"

include("world.jl")
include("weather.jl")

redogwwo = !isfile(joinpath(todata, "partialhouse2$suffix.jld"))

include("WaterNetwork.jl")
include("Allocation.jl")
include("ReturnFlows.jl")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
returnflows = initreturnflows(m); # exogenous/optimization
allocation = initallocation(m); # dep. WaterDemand
waternetwork = initwaternetwork(m); # dep. Allocation

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation]
parameters = [:waterfromsupersource, :withdrawals]
constcomps = [:WaterNetwork, :Allocation]
constraints = [:outflows, :balance]

## Constraint definitions:
# outflows is the water in the stream
# swbalance is the demand minus supply

house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

# Optimize revenue_domestic + revenue_international - pumping_cost - transit_cost
setobjective!(house, -varsum(grad_allocation_cost_waterfromsupersource(m)))
setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))

# Constrain outflows + runoff > 0, or -outflows < runoff
if redogwwo
    gwwo = grad_waternetwork_outflows_withdrawals(m);
    serialize(open(joinpath(todata, "partialhouse$suffix.jld"), "w"), gwwo);
    cwro = constraintoffset_waternetwork_outflows(m);
    serialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "w"), cwro);
else
    gwwo = deserialize(open(joinpath(todata, "partialhouse$suffix.jld"), "r"));
    cwro = deserialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "r"));
end

setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
setconstraintoffset!(house, cwro) # +

# Constrain swdemand < swsupply, or recorded < supersource + withdrawals, or -supersource - withdrawals < -recorded
setconstraint!(house, -grad_allocation_balance_waterfromsupersource(m)) # -
setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # -
setconstraintoffset!(house, -constraintoffset_allocation_recordedbalance(m)) # -

# Clean up

house.b[isnan(house.b)] = 0
house.b[!isfinite(house.b)] = 0
house.f[isnan(house.f)] = 0
house.f[!isfinite(house.f)] = 0

ri, ci, vv = findnz(house.A)
for ii in find(isnan(vv))
    house.A[ri[ii], ci[ii]] = vv[ii]
end
for ii in find(!isfinite(vv))
    house.A[ri[ii], ci[ii]] = 1e9
end

using MathProgBase
@time sol = linprog(-house.f, house.A, '<', house.b, house.lowers, house.uppers)

# Look at parameter values
varlens = varlengths(m, house.paramcomps, house.parameters)
for ii in 1:length(house.parameters)
    println(house.parameters[ii])
    index1 = sum(varlens[1:ii-1]) + 1
    index2 = sum(varlens[1:ii])

    values = sol.sol[index1:index2]

    if (sum(values .!= 0) == 0)
        println("All zero.")
    else
        println(values[1:min(100, index2 - index1 + 1)])
        println("Sum: $(sum(values))")
    end
end

# Save the results
serialize(open("../data/extraction/withdrawals$suffix.jld", "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], m.indices_counts[:canals], m.indices_counts[:time]))
serialize(open("../data/extraction/returns$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:2])+1:end], m.indices_counts[:canals], m.indices_counts[:time]))
