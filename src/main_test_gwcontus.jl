workspace()
cd("Dropbox/POSTDOC/AW-julia/operational-problem-main/src/")
using OptiMimi

include("Allocation_contus_GWonly.jl")
include("Groundwater.jl")

println("Creating model...")
m = Model()

ncounty= 3109;
setindex(m, :time, collect(1))
setindex(m, :regions, collect(1:ncounty))
setindex(m, :aquifers, collect(1:ncounty))

# Add all of the components
allocation = initallocationcontus(m);
aquifer = initaquifercontus(m);#contus(m);
# Set links between components
aquifer[:withdrawal] = allocation[:watergw];

# Run it and time it!
@time run(m)
m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Allocation].Parameters.costfromgw
m.components[:Allocation].Parameters.waterdemand
m.components[:Aquifer].Parameters.storagecoef
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Variables.lateralflows
m.components[:Aquifer].Parameters.withdrawal
m.components[:Aquifer].Parameters.recharge
m.components[:Aquifer].Parameters.depthaquif
m.components[:Aquifer].Parameters.lateralconductivity

println("Optimizing...")
# Make sure that all constraints are currently satisifed. All must be < 0
constraints = Function[]
for tt in 1:m.indices_counts[:time]
    constraints = [constraints; map(aa -> makeconstraintdemandmet(aa, tt), 1:m.indices_counts[:regions])]
    constraints = [constraints; map(aa -> makeconstraintpiezomin(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(aa -> makeconstraintpiezomax(aa, tt), 1:m.indices_counts[:aquifers])]
end

function objective(m)
    # Cost is minimized
    return -sum(m.components[:Allocation].Variables.cost)
end

optprob = problem(m, [:Allocation, :Allocation], [:waterfromgw, :waterfromsupersource], [0., 0.], [1e9, Inf], objective, constraints=constraints, algorithm=:GUROBI_LINPROG);
println("Solving...")
@time sol = solution(optprob);

# re-run model with optimised parameters
setparameters(m, [:Allocation, :Allocation], [:waterfromgw, :waterfromsupersource], sol)
@time run(m)
objective(m)

m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterdemand
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Parameters.withdrawal

writedlm("al_cost_1yr.txt", m.components[:Allocation].Variables.cost, "\t")
writedlm("al_wateral_1yr.txt", m.components[:Allocation].Variables.waterallocated, "\t")
writedlm("al_waterdem_1yr.txt", m.components[:Allocation].Parameters.waterdemand, "\t")
writedlm("al_waterfromgw_1yr.txt", m.components[:Allocation].Parameters.waterfromgw, "\t")
writedlm("al_waterss_1yr.txt", m.components[:Allocation].Parameters.waterfromsupersource, "\t")
writedlm("aq_piezohead_1yr.txt", m.components[:Aquifer].Variables.piezohead, "\t")
writedlm("aq_withdrawal_1yr.txt", m.components[:Aquifer].Parameters.withdrawal, "\t")
