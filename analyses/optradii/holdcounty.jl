include("../../src/lib/readconfig.jl")
config = readconfig("../configs/complete-yearly.yml")

allowreservoirs = true

include("../../src/optimization-given.jl")
house = optimization_given(false, allowreservoirs)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol_county = houseoptimize(house, solver)
summarizeparameters(house, sol_county.sol)

recorded = readtable(datapath("extraction/USGS-2010.csv"))

waterfromgw = vec(cached_fallback("extraction/waterfromgw", () -> repeat(convert(Vector, recorded[:, :TO_GW]) * 1383./12. *config["timestep"], outer=[1,numsteps])))

df = DataFrame(variable=[repmat(["withdrawals"], length(getparametersolution(house, sol_county.sol, :withdrawals)));
                         repmat(["waterfromgw"], length(waterfromgw))],
               optimized=[getparametersolution(house, sol_county.sol, :withdrawals);
                          waterfromgw])
writetable("radius-nothing.csv", df)
