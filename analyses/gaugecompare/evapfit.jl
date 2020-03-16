using CSV, Distributions

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete-5year.yml")

using Gurobi
solver = GurobiSolver()

## Want lfdist * 10000 + lfdisttas * 10000 * 20 = log(.99)
## Use -5e-7 * 10000 + -2.5e-8 * 10000 * 20
lfdist0 = -1.701192e-06 / 2 #-7.607885e-07 #-5e-7
lfdisttas0 = (-2.379683e-08 + -7.749796e-08) / 2 #-3.127531e-08 #-2.5e-8
lfdowns0 = 1 - (0.997068 + 0.9847768)/2 #9.867759e-01 #.99
lfcanal0 = 1 - 1 / ((1 + 1.0004)/2) #1.001435 #.01 # for 1 / .99

#parvals = DataFrame(iter=Int64[], DOWNSTREAM_FACTOR=Float64[], LOSSFACTOR_DIST=Float64[], LOSSFACTOR_DISTTAS=Float64[], CANAL_FACTOR=Float64[])
parvals = CSV.read("evapfit-params.csv")

for iter in (maximum(parvals[!, :iter]) + 1):1000 #1:1000
    global DOWNSTREAM_FACTOR, LOSSFACTOR_DIST, LOSSFACTOR_DISTTAS, CANAL_FACTOR, parvals

    include("../../src/optimization-given.jl")
    redogwwo = true
    DOWNSTREAM_FACTOR = (1 - max(rand(Normal(lfdowns0, lfdowns0)), 0))
    LOSSFACTOR_DIST = min(rand(Normal(lfdist0, abs(lfdist0))), 0)
    LOSSFACTOR_DISTTAS = min(rand(Normal(lfdisttas0, abs(lfdisttas0))), 0)
    CANAL_FACTOR = 1 / (1 - max(rand(Normal(lfcanal0, lfcanal0)), 0))
    if (DOWNSTREAM_FACTOR == 1) && (LOSSFACTOR_DIST == 0) && (LOSSFACTOR_DISTTAS == 0) && (CANAL_FACTOR == 1)
        continue
    end

    house = optimization_given(false, false, nocache=true)
    flows_nw = constraintoffset_waternetwork_outflows(house.model).f # Natural flows
    sol = houseoptimize(house, solver)
    flows_rfnr = flows_nw - getconstraintsolution(house, sol, :outflows) # Return flows, no reservoirs
    
    df = DataFrame(gauge=repeat(gaugeorder, outer=numsteps),
                   time=repeat(1:numsteps, inner=numgauges),
                   flows_rfnr=flows_rfnr)
    CSV.write("evapfit-$(iter).csv", df)
    
    parvals = vcat(parvals, DataFrame(iter=[iter], DOWNSTREAM_FACTOR=[DOWNSTREAM_FACTOR], LOSSFACTOR_DIST=[LOSSFACTOR_DIST], LOSSFACTOR_DISTTAS=[LOSSFACTOR_DISTTAS], CANAL_FACTOR=[CANAL_FACTOR]))
    CSV.write("evapfit-params.csv", parvals)
end
