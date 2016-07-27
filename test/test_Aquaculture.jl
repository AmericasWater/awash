# Load the component
include("../src/Aquaculture.jl")
include("../src/lib/readconfig.jl")

# Set up the model
counties = convert(Vector{Float64}, readtable(datapath("aquaculture/usgsextract.csv"))[:,:FIPS])

config = readconfig("../configs/single.yml")
numsteps = 1
numcounties = length(counties)

m = Model()
setindex(m, :time, [1]) # Single period
setindex(m, :regions, counties)

# Add the component
initaquaculture(m)

# Run the model
run(m)

# Check that it matches 2010
demand_baseline = repeat(convert(Vector{Float64}, readtable(datapath("aquaculture/usgsextract.csv"))[:AQ_WFrTo]), outer=[1, m.indices_counts[:time]])
println(m[:Aquaculture, :demand] - demand_baseline)
