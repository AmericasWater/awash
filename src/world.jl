using DataFrames

suffix = (filterstate != nothing ? "-$filterstate" : "")
if (netset == "dummy")
    suffix = "-dummy";
end

mastercounties = readtable("../data/global/counties.csv", eltypes=[UTF8String, UTF8String, UTF8String])
if filterstate != nothing
    mastercounties = mastercounties[map(fips -> fips[1:2], mastercounties[:fips]) .== filterstate, :]
end

include("regionnet.jl")
include("waternet.jl")

# Prepare the model

crops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]

if netset == "dummy"
    numcounties = 5
else
    numcounties = nrow(mastercounties)
end
numedges = num_edges(regionnet)
numgauges = length(keys(wateridverts))
numsteps = 1 #60
numcrops = length(crops)
numcanals = nrow(draws)

naquifers = 3108;

function newmodel()
    m = Model()

    setindex(m, :time, collect(2015:2015+numsteps-1))
    setindex(m, :regions, collect(mastercounties[:fips]))
    setindex(m, :crops, crops)
    setindex(m, :gauges, collect(keys(wateridverts)))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))
    setindex(m, :aquifers, collect(1:naquifers))

    return m
end
