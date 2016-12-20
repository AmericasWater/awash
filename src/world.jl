using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()

if config["dataset"] == "three"
	mastercounties = readtable(datapath("global/counties$suffix.csv"), eltypes=[UTF8String, UTF8String, UTF8String])
else
	mastercounties = readtable(datapath("global/counties.csv"), eltypes=[UTF8String, UTF8String, UTF8String])
end

if get(config, "filterstate", nothing) != nothing
    mastercounties = mastercounties[map(fips -> fips[1:2], mastercounties[:fips]) .== config["filterstate"], :]
end

include("regionnet.jl")
include("waternet.jl")

# Prepare the model

crops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]

if config["dataset"] == "dummy"
    numcounties = 5
else
    numcounties = nrow(mastercounties)
end
numedges = num_edges(regionnet)
numgauges = length(keys(wateridverts)) # Ordering is by the values of vertex_index
if config["dataset"] == "three"
    numsteps = 3
else
    numsteps = round(Int64, (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"])
    if (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"] != numsteps
        println("Configuration does not describe an integer number of timesteps")
    end
end

numcrops = length(crops)
numcanals = nrow(draws)
numreservoirs = nrow(getreservoirs(config))

if config["dataset"] == "three"
    numaquifers = 3;
else
    numaquifers = numcounties;
end

function newmodel()
    m = Model()

    if config["dataset"] == "three"
        setindex(m, :time, collect(1:3))
    else
        setindex(m, :time, collect(parsemonth(config["startmonth"]):config["timestep"]:parsemonth(config["endmonth"])))
    end
    setindex(m, :regions, collect(mastercounties[:fips]))
    setindex(m, :crops, crops)
    setindex(m, :gauges, collect(map(v -> v.label, vertices(waternet))))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))
    setindex(m, :reservoirs, collect(1:numreservoirs))
    setindex(m, :aquifers, collect(1:numaquifers))

    return m
end
