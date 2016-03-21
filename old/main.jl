using OptiMimi

include("Demand.jl")
include("WaterNetwork.jl")
include("Reservoir.jl")

println("Creating model...")

m = Model()

setindex(m, :time, collect(2000:5:2030))
setindex(m, :counties, TODO1)
setindex(m, :reservoirs, TODO2)
setindex(m, :edges, TODO3)

# Add all of the components
reservoir = addcomponent(m, Reservoir);
waternetwork = initwaternetwork(m);
demand = initdemand(m);

# Connect up the components
reservoir[:inflows] = waternetwork[:inflows];
reservoir[:outflow] = waternetwork[:outflows];
demand[:releases] = reservoir[:releases];

# Defaults to be overwritten by optimization
waternetwork[:streamflow] = TODO
reservoir[:releases] = TODO

# Run it and time it!
@time run(m)
