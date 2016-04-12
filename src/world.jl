suffix = (filterstate != nothing ? "-$filterstate" : "")
if (netset == "dummy")
    suffix = "-dummy";
end

include("regionnet.jl")
include("waternet.jl")

# Prepare the model

crops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]

if netset == "dummy"
    numcounties = 5
else
    numcounties = length(names)
end
numedges = num_edges(regionnet)
numgauges = length(keys(wateridverts))
numsteps = 1 #60
numcrops = length(crops)
numcanals = nrow(draws)

function newmodel()
    m = Model()

    setindex(m, :time, collect(2015:2015+numsteps-1))
    setindex(m, :regions, names)
    setindex(m, :crops, crops)
    setindex(m, :gauges, collect(keys(wateridverts)))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))

    return m
end
