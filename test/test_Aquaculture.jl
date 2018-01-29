using Base.Test

# Load the component
include("../src/lib/readconfig.jl")
config = readconfig("../configs/single-state.yml")

include("../src/Aquaculture.jl")

# Set up the model
regions = regionindex(readtable(datapath("aquaculture/usgsextract.csv")), :)

numsteps = 1
numcounties = length(regions)

m = Model()
setindex(m, :time, [1]) # Single period
setindex(m, :regions, convert(Vector{UTF8String}, regions))

# Add the component
initaquaculture(m)

# Run the model
run(m)

# Check that it matches 2010
demand_baseline = repeat(convert(Vector{Float64}, readtable(datapath("aquaculture/usgsextract.csv"))[:AQ_WFrTo]), outer=[1, m.indices_counts[:time]])
@test m[:Aquaculture, :demand] == demand_baseline
