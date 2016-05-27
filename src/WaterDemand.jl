# The Water Demand component
#
# Combines all of the sources of water demand.

using Mimi
using DataFrames

# Load consumptive use data
consumption = readtable("../data/returnflows/consumption.csv")
returnpart = [consumption[ii, :sector] => 1 - consumption[ii, :consumption] for ii = 1:nrow(consumption)]

@defcomp WaterDemand begin
    regions = Index()

    # External
    # Irrigation water (1000 m^3)
    totalirrigation = Parameter(index=[regions, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Industrial and mining demand, self supplied
    industrialuse = Parameter(index=[regions,time],unit="1000 m^3")
    urbanuse = Parameter(index=[regions,time], unit="1000 m^3")
    # Demand for thermoelectric power (1000 m^3)
    thermoelectricuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    livestockuse = Parameter(index=[regions, time], unit="1000 m^3")

    # Internal
    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, time], unit="1000 m^3")

    # How much is returned by region
    totalreturn = Variable(index=[regions, time], unit="1000 m^3")
end

"""
Compute the amount extracted and the cost for doing it.
"""
function timestep(c::WaterDemand, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        # Sum all demands
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt] + p.industrialuse[rr, tt] + p.urbanuse[rr, tt] + p.thermoelectricuse[rr, tt] + p.livestockuse[rr, tt]

        v.totalreturn[rr, tt] = returnpart["irrigation/livestock"] * p.totalirrigation[rr, tt] + returnpart["domestic/commercial"] * p.domesticuse[rr, tt] + returnpart["industrial/mining"] * p.industrialuse[rr, tt] + returnpart["domestic/commercial"] * p.urbanuse[rr, tt] + returnpart["thermoelectric"] * p.thermoelectricuse[rr, tt] + returnpart["irrigation/livestock"] * p.livestockuse[rr, tt]
    end
end

"""
Add a WaterDemand component to the model.
"""
function initwaterdemand(m::Model)
    waterdemand = addcomponent(m, WaterDemand);

    # Set optimized parameters to 0
    waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:industrialuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:urbanuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:livestockuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:thermoelectricuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);

    waterdemand
end

function grad_waterdemand_swdemandbalance_totalirrigation(m::Model)
    roomdiagonal(m, :Allocation, :balance, :totalirrigation, (rr, tt) -> 1.)
end

function grad_waterdemand_swdemandbalance_domesticuse(m::Model)
    roomdiagonal(m, :Allocation, :balance, :domesticuse, (rr, tt) -> 1.)
end

function grad_waterdemand_swdemandbalance_thermoelectricuse(m::Model)
    roomdiagonal(m, :Allocation, :balance, :thermoelectricuse, (rr, tt) -> 1.)
end

function grad_waterdemand_swdemandbalance_livestockuse(m::Model)
    roomdiagonal(m, :Allocation, :balance, :livestockuse, (rr, tt) -> 1.)
end

function grad_waterdemand_totalreturn_totalirrigation(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :totalirrigation, (rr, tt) -> -returnpart["irrigation/livestock"])
end

function grad_waterdemand_totalreturn_domesticuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :domesticuse, (rr, tt) -> -returnpart["domestic/commercial"])
end

function grad_waterdemand_totalreturn_industrialuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :industrialuse, (rr, tt) -> -returnpart["industrial/mining"])
end

function grad_waterdemand_totalreturn_thermoelectricuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :thermoelectricuse, (rr, tt) -> -returnpart["thermoelectric"])
end

function grad_waterdemand_totalreturn_livestockuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :livestockuse, (rr, tt) -> -returnpart["irrigation/livestock"])
end

function values_waterdemand_recordedsurfacedomestic(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = (recorded[rr, :PS_SW] + recorded[rr, :DO_SW]) * 1382592. / (1000. * config["timestep"])
    shaftsingle(m, :WaterDemand, :domesticuse, gen)
end

function values_waterdemand_recordedsurfaceindustrial(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = (recorded[rr, :IN_SW] + recorded[rr, :MI_SW]) * 1382592. / (1000. * config["timestep"])
    shaftsingle(m, :WaterDemand, :industrialuse, gen)
end

function values_waterdemand_recordedsurfaceirrigation(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :IR_SW] * 1382592. / (1000. * config["timestep"])
    shaftsingle(m, :WaterDemand, :totalirrigation, gen)
end

function values_waterdemand_recordedsurfacelivestock(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :LI_SW] * 1382592. / (1000. * config["timestep"])
    shaftsingle(m, :WaterDemand, :livestockuse, gen)
end

function values_waterdemand_recordedsurfacethermoelectric(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :PT_SW] * 1382592. / (1000. * config["timestep"])
    shaftsingle(m, :WaterDemand, :thermoelectricuse, gen)
end

