using CSV

for do_monthly in [false, true]
    global config

include("../../src/lib/readconfig.jl")
if do_monthly
    config = readconfig("../../configs/complete-5year.yml")
else
    config = readconfig("../../configs/complete-5year-yearly.yml")
end

using Gurobi
solver = GurobiSolver()

include("../../src/optimization-given.jl")
redogwwo = true

house = optimization_given(false, false, nocache=true)
flows_nw = constraintoffset_waternetwork_outflows(house.model).f # Natural flows
sol = houseoptimize(house, solver)
flows_rfnr = flows_nw - getconstraintsolution(house, sol, :outflows) # Return flows, no reservoirs

gwwo = deserialize(open(cachepath("partialhouse-gwwo$suffix.jld"), "r"));
setconstraint!(house, -gwwo) # remove return flows
sol = houseoptimize(house, solver)
flows_nrnr = flows_nw - getconstraintsolution(house, sol, :outflows) # No returns, no reservoirs

house = optimization_given(false, true, nocache=true)
sol = houseoptimize(house, solver)
flows_rfwr = flows_nw - getconstraintsolution(house, sol, :outflows) # Return flows, with reservoirs

df = DataFrame(gauge=repeat(gaugeorder, outer=numsteps),
               time=repeat(1:numsteps, inner=numgauges),
               flows_rfnr=flows_rfnr, flows_nrnr=flows_nrnr,
               flows_rfwr=flows_rfwr, flows_nw=flows_nw)
if do_monthly
    CSV.write("optimizes-monthly.csv", df)
else
    CSV.write("optimizes.csv", df)
end

end
