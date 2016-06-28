using DataFrames

suffix = (get(config, "filterstate", nothing) != nothing ? "-$(config["filterstate"])" : "")
if config["netset"] == "dummy"
    suffix = "-dummy";
elseif config["netset"] == "three"
    suffix = "-three";
end

mastercounties = readtable("../data/global/counties$suffix.csv", eltypes=[UTF8String, UTF8String, UTF8String])
if get(config, "filterstate", nothing) != nothing
    mastercounties = mastercounties[map(fips -> fips[1:2], mastercounties[:fips]) .== config["filterstate"], :]
end

include("regionnet.jl")
include("waternet.jl")

# Prepare the model

crops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]

if config["netset"] == "dummy"
    numcounties = 5
else
    numcounties = nrow(mastercounties)
end
numedges = num_edges(regionnet)
numgauges = length(keys(wateridverts))
if config["netset"] == "three"
    numsteps = 2
else
    numsteps = convert(Int64, (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"])
    if (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"] != numsteps
        println("Configuration does not describe an integer number of timesteps")
    end
end

numcrops = length(crops)
numcanals = nrow(draws)
numreservoirs = nrow(getreservoirs(config))

if config["netset"] == "three"
    naquifers = 3;
else
    naquifers = 3108;
end

function newmodel()
    m = Model()

    if config["netset"] == "three"
        setindex(m, :time, collect(1:2))
    else
        setindex(m, :time, collect(parsemonth(config["startmonth"]):config["timestep"]:parsemonth(config["endmonth"])))
    end
    setindex(m, :regions, collect(mastercounties[:fips]))
    setindex(m, :crops, crops)
    setindex(m, :gauges, collect(keys(wateridverts)))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))
    setindex(m, :reservoirs, collect(1:numreservoirs))
    setindex(m, :aquifers, collect(1:naquifers))

    return m
end
