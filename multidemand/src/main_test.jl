workspace()
using OptiMimi

include("Allocation.jl")
include("Groundwater.jl")
include("Reservoir.jl")
#include("Watercost.jl")
println("Creating model...")
m = Model()

setindex(m, :time, collect(1:100))
setindex(m, :regions, collect(1:5))
setindex(m, :aquifers, collect(1:5))
setindex(m, :reservoirs, collect(1:5))

# Add all of the components
allocation = initallocation(m);
aquifer = initaquifer(m);
reservoir = initreservoir(m);
#watercost = initwatercost(m);
# Set links between components
aquifer[:withdrawal] = allocation[:watergw]
reservoir[:withdrawal] = allocation[:waterreservoir]
#allocation[:depth] = aquifer[:meandepth]
#allocation[:costfromgw] = watercost[:costgw]
#allocation[:costfromreservoir] = watercost[:costsw]
#watercost[:depth] = aquifer[:meandepth]
# Run it and time it!
@time run(m)
m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocateddom
m.components[:Allocation].Parameters.waterfromgwdom
m.components[:Allocation].Parameters.waterfromsupersourcedom
m.components[:Allocation].Parameters.waterfromreservoirdom
m.components[:Allocation].Parameters.costfromgwdom
m.components[:Allocation].Parameters.costfromreservoirdom

m.components[:Allocation].Variables.waterallocatedag
m.components[:Allocation].Parameters.waterdemandag
m.components[:Allocation].Parameters.waterfromgwag
m.components[:Allocation].Parameters.waterfromsupersourceag
m.components[:Allocation].Parameters.waterfromreservoirag
m.components[:Allocation].Parameters.costfromgwag
m.components[:Allocation].Parameters.costfromreservoirag

#m.components[:Watercost].Variables.costsw
#m.components[:Watercost].Variables.costgw
#m.components[:Watercost].Parameters.depth

m.components[:Aquifer].Variables.meandepth
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Variables.lateralflows
m.components[:Aquifer].Parameters.withdrawal

m.components[:Reservoir].Parameters.inflows
m.components[:Reservoir].Parameters.outflows
m.components[:Reservoir].Parameters.withdrawal
m.components[:Reservoir].Variables.storage

println("Optimizing...")
# Make sure that all constraints are currently satisifed. All must be < 0
constraints = Function[]
for tt in 1:m.indices_counts[:time]
    constraints = [constraints; map(aa -> makeconstraintdemandmetag(aa, tt), 1:m.indices_counts[:regions])]
    constraints = [constraints; map(aa -> makeconstraintdemandmetdom(aa, tt), 1:m.indices_counts[:regions])]
    constraints = [constraints; map(aa -> makeconstraintpiezomin(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(aa -> makeconstraintpiezomax(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(rr -> makeconstraintresmin(rr, tt), 1:m.indices_counts[:reservoirs])]
    constraints = [constraints; map(rr -> makeconstraintresmax(rr, tt), 1:m.indices_counts[:reservoirs])]
end

function objective(m)
    # Cost is minimized
    return -sum((m.components[:Allocation].Variables.cost).^2)
end

vectormoduletooptimise=[:Allocation, :Allocation, :Allocation, :Allocation, :Allocation, :Allocation, :Reservoir]
vectorparametertooptimise= [:waterfromreservoirag, :waterfromgwag, :waterfromsupersourceag, :waterfromreservoirdom, :waterfromgwdom, :waterfromsupersourcedom, :outflows]
optprob = problem(m,vectormoduletooptimise,vectorparametertooptimise, [0., 0., 0., 0., 0., 0., 0.], [1e9,1e9,Inf,1e9,1e9,Inf, Inf], objective, constraints=constraints, algorithm=:GUROBI_LINPROG);


println("Solving...")
@time sol = solution(optprob); ###### CANNOT COMPUTE THE BASELINE FOR GRADIENTS

# re-run model with optimised parameters
setparameters(m,vectormoduletooptimise,vectorparametertooptimise, sol)
@time run(m)
objective(m)

println("Results")
m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocateddom
m.components[:Allocation].Parameters.waterfromgwdom
m.components[:Allocation].Parameters.waterfromsupersourcedom
m.components[:Allocation].Parameters.waterfromreservoirdom
m.components[:Allocation].Parameters.costfromgwdom
m.components[:Allocation].Parameters.costfromreservoirdom

m.components[:Allocation].Variables.waterallocatedag
m.components[:Allocation].Parameters.waterdemandag
m.components[:Allocation].Parameters.waterfromgwag
m.components[:Allocation].Parameters.waterfromsupersourceag
m.components[:Allocation].Parameters.waterfromreservoirag
m.components[:Allocation].Parameters.costfromgwag
m.components[:Allocation].Parameters.costfromreservoirag

#m.components[:Watercost].Variables.costsw
#m.components[:Watercost].Variables.costgw
#m.components[:Watercost].Parameters.depth

m.components[:Aquifer].Variables.meandepth
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Variables.lateralflows
m.components[:Aquifer].Parameters.withdrawal

m.components[:Reservoir].Parameters.inflows
m.components[:Reservoir].Parameters.outflows
m.components[:Reservoir].Parameters.withdrawal
m.components[:Reservoir].Variables.storage

println("Results")
