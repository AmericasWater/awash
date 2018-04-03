using DataFrames
include("lib/datastore.jl")

suffix = getsuffix()

masterregions = readtable(datapath(config["masterregions"]), eltypes=[UTF8String, UTF8String, UTF8String]);



if get(config, "filterstate", nothing) != nothing
    masterregions = masterregions[map(fips -> fips[1:2], masterregions[:fips]) .== config["filterstate"], :]
    
if config["filterstate"]=="36"
    masterregions=masterregions[masterregions[:fips].!="36059",:]
    masterregions=masterregions[masterregions[:fips].!="36103",:]
end 
    
end

    include("regionnet.jl")
include("waternet.jl")

# Prepare the model

if config["dataset"] == "states"
    unicrops = ["barley", "corn", "sorghum", "soybeans", "wheat", "hay"] # UnivariateAgriculture component crops
    irrcrops = [] # Full Agriculture component, with rainfed/irrigated choice
    #irrcrops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]
else
    unicrops = ["barley", "corn.co.rainfed", "corn.co.irrigated", "sorghum", "soybeans", "wheat.co.rainfed", "wheat.co.irrigated", "hay"] # "corn", "wheat" # UnivariateAgriculture component crops
    irrcrops = [] # Full Agriculture component, with rainfed/irrigated choice
    #irrcrops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]
end

allcrops = [unicrops; irrcrops]

if config["dataset"] == "dummy"
    numcounties = 5
else
    numcounties = nrow(masterregions)
end
numregions = numcounties # Going to deprecate `numcounties`
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

numunicrops = length(unicrops)
numirrcrops = length(irrcrops)
numallcrops = length(allcrops)
numcanals = nrow(draws)
numreservoirs = nrow(getreservoirs(config))

if config["dataset"] == "three"
    numaquifers = 3;
else
    numaquifers = numcounties;
end

if config["filterstate"]=="36"    
    industry = ["food","beverage","paper","petroleum","chem","plastic","nonmetal","metal","fabricated metal","machinery","electrical"]
    end 
numindustries=length(industry) 





function newmodel()
    m = Model()

    if config["dataset"] == "three"
        setindex(m, :time, collect(1:3))
    else
        setindex(m, :time, collect(parsemonth(config["startmonth"]):config["timestep"]:parsemonth(config["endmonth"])))
    end
    setindex(m, :regions, collect(masterregions[:fips]))
    setindex(m, :unicrops, unicrops)
    setindex(m, :irrcrops, irrcrops)
    setindex(m, :allcrops, allcrops)
    setindex(m, :gauges, collect(map(v -> v.label, vertices(waternet))))
    setindex(m, :edges, collect(1:num_edges(regionnet)))
    setindex(m, :canals, collect(1:numcanals))
    setindex(m, :reservoirs, collect(1:numreservoirs))
    setindex(m, :aquifers, collect(1:numaquifers))
    if config["filterstate"]=="36"
        setindex(m,:industry,industry)
    end
    return m
end
