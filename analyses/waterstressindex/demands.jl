using DataFrames
using OptiMimi

include("../../src/lib/readconfig.jl")
config = readconfig("../../configs/complete.yml")

## Extract for monthly
include("../../src/world.jl")
include("../../src/weather.jl")

include("../../src/WaterDemand.jl")
include("../../src/Allocation.jl")

# Set up the model
m = newmodel();
waterdemand = initwaterdemand(m);
allocation = initallocation(m);

# Collect the values
sw_monthly = constraintoffset_allocation_recordedtotal(m, false)
all_monthly = constraintoffset_allocation_recordedtotal(m, true)
df_monthly = DataFrame(scale="monthly", timestep=repeat(1:735, inner=length(masterregions[:fips])), fips=repeat(masterregions[:fips], outer=735), swdemand=sw_monthly.f, alldemand=all_monthly.f)

## Extract for annual
config = readconfig("../../configs/complete-yearly.yml")
include("../../src/world.jl")
include("../../src/weather.jl")

m = newmodel();
waterdemand = initwaterdemand(m);
allocation = initallocation(m);

# Collect the values
sw_annual = constraintoffset_allocation_recordedtotal(m, false)
all_annual = constraintoffset_allocation_recordedtotal(m, true)
df_annual = DataFrame(scale="annual", timestep=repeat(1:61, inner=length(masterregions[:fips])), fips=repeat(masterregions[:fips], outer=61), swdemand=sw_annual.f, alldemand=all_annual.f)

df = vcat(df_monthly, df_annual)

CSV.write("demands.csv", df)
