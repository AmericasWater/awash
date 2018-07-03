include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete-yearly.yml")

using Gurobi
solver = GurobiSolver()

include("../../src/optimization-given.jl")
redogwwo = true

house = optimization_given(false, false)
sol = houseoptimize(house, solver)
supersource0 = getparametersolution(house, sol.sol, :waterfromsupersource)

df = DataFrame(fips=repeat(masterregions[:fips], outer=numsteps), time=repeat(1:61, inner=numregions), ss0=supersource0)
writetable("vsenv-basic.csv", df)

offset0 = constraintoffset_waternetwork_outflows(house.model)
config["proportionnaturalflowforenvironment"] = 1.0
envflow1 = constraintoffset_environmentalflows(house.model)

for efp in 20:10:90 # 10:
    println(efp)    
    setconstraintoffset!(house, offset0 - LinearProgrammingHall(envflow1.component, envflow1.name, (efp / 100.) * envflow1.f))
    sol = houseoptimize(house, solver)
    supersource = getparametersolution(house, sol.sol, :waterfromsupersource)
    df[Symbol("ss$efp")] = supersource
    writetable("vsenv-basic.csv", df)
end
