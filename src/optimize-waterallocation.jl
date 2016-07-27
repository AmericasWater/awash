using Mimi
using OptiMimi
include("lib/readconfig.jl")


config = readconfig("../configs/standard-1year.yml") # Just use 1 year for optimization
#config = readconfig("../configs/dummy3.yml")

include("world.jl")
if config["netset"] == "three"
    include("weather-three.jl")
else
    include("weather.jl")
end

redogwwo = !isfile(joinpath(todata, "partialhouse2$suffix.jld"))

include("WaterDemand.jl")
include("WaterNetwork.jl")
include("Allocation.jl")
include("ReturnFlows.jl")
include("Reservoir.jl")
include("Groundwater.jl");
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

paramcomps = [:Allocation, :Allocation, :Allocation, :Reservoir, :Allocation]
parameters = [:waterfromsupersource, :withdrawals, :returns, :captures, :waterfromgw]
constcomps = [:WaterNetwork, :Allocation, :Allocation, :Reservoir, :Reservoir]
constraints = [:outflows, :balance, :returnbalance, :storagemin, :storagemax]

## Constraint definitions:
# outflows is the water in the stream
# swbalance is the demand minus supply
# Reservoir storage cannot be <min or >max

house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints, Dict(:storagemin => :storage, :storagemax => :storage));

# Minimize supersource_cost + withdrawal_cost + suboptimallevel_cost
setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
#setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
setobjective!(house, -varsum(grad_allocation_cost_waterfromsupersource(m)))

# Constrain outflows + runoff > 0, or -outflows < runoff
if redogwwo
    gwwo = grad_waternetwork_outflows_withdrawals(m);
    serialize(open(joinpath(todata, "partialhouse$suffix.jld"), "w"), gwwo);
    cwro = constraintoffset_waternetwork_outflows(m);
    serialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "w"), cwro);
    gror = grad_reservoir_outflows_captures(m);
    serialize(open(joinpath(todata, "partialhouse-gror$suffix.jld"), "w"), gror);
else
    gwwo = deserialize(open(joinpath(todata, "partialhouse$suffix.jld"), "r"));
    cwro = deserialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "r"));
    gror = deserialize(open(joinpath(todata, "partialhouse-gror$suffix.jld"), "r"));
end

setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
setconstraint!(house, room_relabel_parameter(gwwo, :withdrawals, :Allocation, :returns)) # -
setconstraint!(house, -gror) # +
setconstraintoffset!(house, cwro) # +

# Constrain swdemand < swsupply, or recorded < supersource + withdrawals, or -supersource - withdrawals < -recorded
setconstraint!(house, -grad_allocation_balance_waterfromsupersource(m)) # -
setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # -
setconstraintoffset!(house, -constraintoffset_allocation_recordedbalance(m)) # -

# Constraint returnbalance < 0, or returns - waterreturn < 0, or returns < waterreturn
setconstraint!(house, grad_allocation_returnbalance_returns(m)) # +
if config["netset"] == "three"
    setconstraintoffset!(house, LinearProgrammingHall(:Allocation, :returnbalance, [0., 0., 0., 0., 0., 0.]))
else
    setconstraintoffset!(house,
                         -hall_relabel(grad_waterdemand_totalreturn_totalirrigation(m) * (values_waterdemand_recordedsurfaceirrigation(m)+values_waterdemand_recordedgroundirrigation(m)) +
                                       grad_waterdemand_totalreturn_domesticuse(m) * (values_waterdemand_recordedsurfacedomestic(m)+values_waterdemand_recordedgrounddomestic(m)) +
                                       grad_waterdemand_totalreturn_industrialuse(m) * (values_waterdemand_recordedsurfaceindustrial(m)+values_waterdemand_recordedgroundindustrial(m)) +
                                       grad_waterdemand_totalreturn_thermoelectricuse(m) * (values_waterdemand_recordedsurfacethermoelectric(m)+values_waterdemand_recordedgroundthermoelectric(m)) +
    grad_waterdemand_totalreturn_livestockuse(m) * (values_waterdemand_recordedsurfacelivestock(m)+values_waterdemand_recordedgroundlivestock(m)), :totalreturn, :Allocation, :returnbalance)) # +
end

# Reservoir constraints:
# We don't consider an initial storage, so min storage is 0 and max storage is reservoir max - reservoir min

# Constrain storage > 0 or -storage < 0
setconstraint!(house, -room_relabel(grad_reservoir_storage_captures(m), :storage, :Reservoir, :storagemin)) # -

# Constrain storage < max
setconstraint!(house, room_relabel(grad_reservoir_storage_captures(m), :storage, :Reservoir, :storagemax)) # +
setconstraintoffset!(house, hall_relabel(constraintoffset_reservoir_storagecapacitymax(m) - constraintoffset_reservoir_storagecapacitymin(m), :storage, :Reservoir, :storagemax))

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

setlower!(house, LinearProgrammingHall(:Reservoir, :captures, ones(numreservoirs * numsteps) * -Inf))

serialize(open("../data/fullhouse$suffix.jld", "w"), house)

##house = deserialize(open(joinpath(todata, "fullhouse$suffix.jld"), "r"));

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)

# If model is infeasible, figure out what's causing that
#topbot = findinfeasiblepair(house, solver)
#sol = linprog(-house.f, house.A[1:topbot[1],:], '<', house.b[1:topbot[1]], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[1:topbot[1]-1,:], '<', house.b[1:topbot[1]-1], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]:end,:], '<', house.b[topbot[2]:end], house.lowers, house.uppers, solver)
#sol = linprog(-house.f, house.A[topbot[2]+1:end,:], '<', house.b[topbot[2]+1:end], house.lowers, house.uppers, solver)

summarizeparameters(house, sol.sol)

# Look at the constraints: only possible for small models
#constraining(house, sol.sol)

# Save the results
varlens = varlengths(house.model, house.paramcomps, house.parameters)

serialize(open("../data/extraction/withdrawals$suffix.jld", "w"), reshape(sol.sol[varlens[1]+1:sum(varlens[1:2])], m.indices_counts[:canals], m.indices_counts[:time]))
serialize(open("../data/extraction/returns$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:2])+1:sum(varlens[1:3])], m.indices_counts[:canals], m.indices_counts[:time]))
serialize(open("../data/extraction/captures$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:3])+1:sum(varlens[1:4])], m.indices_counts[:reservoirs], m.indices_counts[:time]))
serialize(open("../data/extraction/waterfromgw$suffix.jld", "w"), reshape(sol.sol[sum(varlens[1:4])+1:end], m.indices_counts[:regions], m.indices_counts[:time]))
