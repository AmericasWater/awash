## Environment setup
#
# Load the necessary information into the global environment for
# creating simulation and optimization models.

include("world-minimal.jl")
include("regionnet.jl")
include("lib/leapsteps.jl")
include("initwaternet.jl")

# Prepare the model

if config["filterstate"] == "08"
    unicrops = ["barley", "corn.co.rainfed", "corn.co.irrigated", "sorghum", "soybeans", "wheat.co.rainfed", "wheat.co.irrigated", "hay"] # "corn", "wheat" # UnivariateAgriculture component crops
    irrcrops = String[] # Full Agriculture component, with rainfed/irrigated choice
else
    unicrops = ["barley", "corn", "sorghum", "soybeans", "wheat", "hay"] # UnivariateAgriculture component crops
    irrcrops = String[] # Full Agriculture component, with rainfed/irrigated choice
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
numharvestyears = length(unique(cat(timeindex2yearindexes.(1:numsteps)..., dims=1)))
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
        set_dimension!(m, :time, collect(1:3))
    elseif "scenario-length" in keys(config)
        set_dimension!(m, :time, collect(1:config["scenario-length"]))
    else
        set_dimension!(m, :time, collect(parsemonth(config["startmonth"]):config["timestep"]:parsemonth(config["endmonth"])))
    end

    yearnames = collect(parseyear(config["startmonth"]):parseyear(config["endmonth"]))
    yearindexes = cat(timeindex2yearindexes.(1:numsteps)..., dims=1)

    set_dimension!(m, :harvestyear, length(yearnames) == maximum(yearindexes) ? yearnames[yearindexes] : yearnames[yearindexes + 1]) # Happens if first year gets no harvest
    set_dimension!(m, :regions, collect(masterregions[:fips]))
    set_dimension!(m, :unicrops, unicrops)
    set_dimension!(m, :irrcrops, irrcrops)
    set_dimension!(m, :allcrops, allcrops)
    set_dimension!(m, :gauges, collect(map(v -> v.label, vertices(waternet))))
    set_dimension!(m, :edges, collect(1:num_edges(regionnet)))
    set_dimension!(m, :canals, collect(1:numcanals))
    set_dimension!(m, :reservoirs, collect(1:numreservoirs))
    set_dimension!(m, :aquifers, collect(1:numaquifers))
    set_dimension!(m, :scenarios, get(config, "scenarios", [1]))

    return m
end
