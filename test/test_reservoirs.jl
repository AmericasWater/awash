include("../src/lib/readconfig.jl")
config = readconfig("../configs/standard.yml")

# Check that we can read reservoirs
include("../src/lib/reservoirs.jl")
allreservoirs = getreservoirs(config)
@test nrow(allreservoirs) > 2000

# Check that we can filter reservoirs
config["filterstate"] = "08"
coloradoreservoirs = getreservoirs(config)
@test nrow(coloradoreservoirs) < 200
