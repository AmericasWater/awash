include("world-minimal.jl")
include("regionnet.jl")
include("waternet.jl")

# Prepare the model

if config["filterstate"] == "08"
    unicrops = ["barley", "corn.co.rainfed", "corn.co.irrigated", "sorghum", "soybeans", "wheat.co.rainfed", "wheat.co.irrigated", "hay"] # UnivariateAgriculture component crops
    irrcrops = [] # Full Agriculture component, with rainfed/irrigated choice
    #irrcrops = ["alfalfa", "otherhay", "Barley", "Barley.Winter", "Maize", "Sorghum", "Soybeans", "Wheat", "Wheat.Winter"]
elseif config["filterstate"]=="08"
    unicrops = ["barley", "corn.co.rainfed", "corn.co.irrigated", "sorghum", "soybeans", "wheat.co.rainfed", "wheat.co.irrigated", "hay"] # "corn", "wheat" # UnivariateAgriculture component crops
    irrcrops = []

else
    unicrops = ["barley", "corn", "sorghum", "soybeans", "wheat", "hay"] # UnivariateAgriculture component crops
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

if "scenarios" in keys(config)
    numsteps = config["scenario-length"]
elseif config["dataset"] == "three"
    numsteps = 3
elseif "endmonth" in keys(config) && "startmonth" in keys(config)
    numsteps = round.(Int64, (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"])
    if (parsemonth(config["endmonth"]) - parsemonth(config["startmonth"]) + 1) / config["timestep"] != numsteps
        println("Configuration does not describe an integer number of timesteps")
    end
else
    numsteps = floor.(Int64, getmaxsteps() / config["timestep"])
end

numscenarios = length(get(config, "scenarios", [1]))

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

function newmodel()
    m = Model()

    if config["dataset"] == "three"
        setindex(m, :time, collect(1:3))
    elseif "scenario-length" in keys(config)
        setindex(m, :time, collect(1:config["scenario-length"]))
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
    setindex(m, :scenarios, get(config, "scenarios", [1]))

    return m
end
