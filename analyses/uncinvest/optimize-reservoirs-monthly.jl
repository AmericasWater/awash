#### Determine the gauge-level SW/GW extractions that satisfy demands at minimum cost

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/monthly-6scen.yml")
config["proportionnaturalflowforenvironment"] = .37

include("../../src/optimization-investment.jl")
