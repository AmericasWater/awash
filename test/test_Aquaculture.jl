using Test
using CSV

# Load the component
include("../src/lib/readconfig.jl")
config = readconfig("../configs/single-state.yml")

include("../src/Aquaculture.jl")

# Set up the model
regions = regionindex(CSV.read(datapath("aquaculture/usgsextract.csv")), :)

numsteps = 1
numcounties = length(regions)

m = Model()
set_dimension!(m, :time, [1]) # Single period
set_dimension!(m, :regions, convert(Vector{AbstractString}, regions))

# Add the component
initaquaculture(m)

# Run the model
run(m)

# Check that it matches 2010
demand_baseline = repeat(convert(Vector{Float64}, CSV.read(datapath("aquaculture/usgsextract.csv"))[:AQ_WFrTo]), outer=[1, m.indices_counts[:time]])
@test m[:Aquaculture, :demand] == demand_baseline
