## This was extracted from simulate.jl, as the automated method of optimization

println("Testing:")
println(m[:Market, :revenue])

## OPTIMIZATION NOT RIGHT YET
# ADD: sum of areas = county

println("Create linear optimization problem...")
# Make a network constraint for county rr, time tt
function makeconstraint(rr, tt)
    # The constraint function
    function constraint(model)
        -model[:Consumption, :surplus][rr, tt]
    end
end

# Set up the constraints
constraints = Function[]
for tt in 1:m.indices_counts[:time]
    constraints = [constraints; map(rr -> makeconstraint(rr, tt), 1:m.indices_counts[:regions])]
end

# Combine component-specific objectives
function objective(model::Model)
    soleobjective_conjunctivecse(model) + soleobjective_transportation(model)
end

# Create the OptiMimi optimization problem
optprob = problem(m, [:ConjunctiveUse, :Transportation], [:pumping, :imported], [0., 0.], [Inf, Inf], objective, constraints=constraints, algorithm=:GUROBI_LINPROG);

println("Solving...")
@time sol = solution(optprob)
println(sol)

setparameters(m, [:ConjunctiveUse, :Transportation], [:pumping, :imported], sol)
@time run(m)

df = DataFrame(fips=m.indices_values[:regions], demand=vec(m[:Consumption, :demand]),
               allotment=vec(m.components[:ConjunctiveUse].Parameters.free_allotment),
               pumping=vec(m.components[:ConjunctiveUse].Parameters.pumping),
               imports=vec(m[:Transportation, :regionimports]),
               exports=vec(m[:Transportation, :regionexports]))
writetable("results/counties$suffix.csv", df)
