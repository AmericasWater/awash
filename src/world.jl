using DataFrames

suffix = (config["filterstate"] != nothing ? "-$(config["filterstate"])" : "")
if (config["netset"] == "dummy")
    suffix = "-dummy";
end

mastercounties = readtable("../data/global/counties.csv", eltypes=[UTF8String, UTF8String, UTF8String])
if config["filterstate"] != nothing
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
numsteps = convert(Int64, (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"])
if (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"] != numsteps
    println("Configuration does not describe an integer number of timesteps")
end

numcrops = length(crops)
numcanals = nrow(draws)

naquifers = 3108;

function newmodel()
    m = Model()

    setindex(m, :time, collect(parsemonth(config["startmonth"]):config["timestep"]:parsemonth(config["endmonth"])))
    setindex(m, :regions, collect(mastercounties[:fips]))
    setindex(m, :crops, crops)
    setindex(m, :gauges, collect(keys(wateridverts)))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))
    setindex(m, :aquifers, collect(1:naquifers))

    return m
end
