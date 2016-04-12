workspace()
using OptiMimi

include("Allocation.jl")
include("Groundwater.jl")
include("Reservoir.jl")
include("Watercost.jl")
println("Creating model...")
m = Model()

setindex(m, :time, collect(1:10))
setindex(m, :regions, collect(1:5))
setindex(m, :aquifers, collect(1:5))
setindex(m, :reservoirs, collect(1:5))

# Add all of the components
allocation = initallocation(m);
aquifer = initaquifer(m);
reservoir = initreservoir(m);
watercost = initwatercost(m);
# Set links between components
aquifer[:withdrawal] = allocation[:watergw]
reservoir[:withdrawal] = allocation[:waterreservoir]
#allocation[:costfromgw] = watercost[:costgw]
#allocation[:costfromreservoir] = watercost[:costsw]
watercost[:depth] = aquifer[:meandepth]
# Run it and time it!
@time run(m)
m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Allocation].Parameters.waterfromreservoir

m.components[:Reservoir].Parameters.inflows
m.components[:Reservoir].Parameters.outflows
m.components[:Reservoir].Parameters.withdrawal
m.components[:Reservoir].Variables.storage

println("Optimizing...")
# Make sure that all constraints are currently satisifed. All must be < 0
constraints = Function[]
for tt in 1:m.indices_counts[:time]
    constraints = [constraints; map(aa -> makeconstraintdemandmet(aa, tt), 1:m.indices_counts[:regions])]
    constraints = [constraints; map(aa -> makeconstraintpiezomin(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(aa -> makeconstraintpiezomax(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(rr -> makeconstraintresmin(rr, tt), 1:m.indices_counts[:reservoirs])]
    constraints = [constraints; map(rr -> makeconstraintresmax(rr, tt), 1:m.indices_counts[:reservoirs])]
end

function objective(m)
    # Cost is minimized
    return -sum(m.components[:Allocation].Variables.cost)
end

optprob = problem(m, [:Allocation, :Allocation, :Allocation, :Reservoir], [:waterfromreservoir, :waterfromgw, :waterfromsupersource, :outflows], [0., 0., 0., 0., 0.], [1e9,1e9,1e9,1e9,1e9], objective, constraints=constraints, algorithm=:GUROBI_LINPROG);
println("Solving...")
@time sol = solution(optprob); ###### CANNOT COMPUTE THE BASELINE FOR GRADIENTS
# re-run model with optimised parameters
setparameters(m, [:Allocation, :Allocation, :Allocation, :Reservoir], [:waterfromreservoir, :waterfromgw, :waterfromsupersource, :outflows], sol)
@time run(m)
objective(m)

m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterdemand
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Allocation].Parameters.waterfromreservoir
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Parameters.layerthick
m.components[:Aquifer].Parameters.withdrawal
m.components[:Reservoir].Variables.storage
m.components[:Reservoir].Parameters.storagecapacitymin
m.components[:Reservoir].Parameters.storagecapacitymax
m.components[:Reservoir].Parameters.outflows
