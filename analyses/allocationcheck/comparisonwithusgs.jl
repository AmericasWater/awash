include("../../src/nui.jl")
include("../../src/optimize-waterallocation.jl")
include("../../src/simulate.jl")

#include("mapping.jl")
# getting volumes and costs at the county level from the simulation
sw = getdata(:Allocation, :swsupply);
swc = getdata(:WaterCost, :swcost);
gw = getdata(:Allocation, :gwsupply);
gwc = getdata(:WaterCost, :gwcost);
supw = getdata(:Allocation, :supersourcesupply);
supwc = getdata(:WaterCost, :supersourcecost);

# mapping total volumes per source type
mapdata(:Allocation, :swsupply, "sum")
mapdata(:Allocation, :gwsupply, "sum")
mapdata(:Allocation, :supersourcesupply, "sum")

# mapping total costs per source type
mapdata(:WaterCost, :swcost, "sum")
mapdata(:WaterCost, :gwcost, "sum")
mapdata(:WaterCost, :supersourcecost,"sum")

# cost of water per 1000m3
mapdata(sum((supwc+gwc+swc)./(supw+gw+sw),2))

# comparison with usgs estimates - loading the data
recorded = readtable(datapath("extraction/USGS-2010.csv"));
swusgs = recorded[:, :TO_SW] * 1383. / 12 *config["timestep"] * numsteps;
gwusgs = recorded[:, :TO_GW] * 1383. / 12 *config["timestep"] * numsteps;
ugwc=getdata(:WaterCost, :unitgwextractioncost)[:,2]+getdata(:WaterCost, :unitgwtreatmentcost)[:,2] + getdata(:WaterCost, :unitdistributioncost)[:,2];
gwusgsc = gwusgs .* ugwc

# mapping difference in volume per source type
mapdata(sum(sw,2).-swusgs, nothing, nothing, true)
mapdata(sum(gw,2).-gwusgs)

# mapping difference in cost per source type
mapdata(sum(gwc,2).-gwusgsc)



