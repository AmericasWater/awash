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
<<<<<<< HEAD
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Industrial and mining demand, self supplied
    industrialuse = Parameter(index=[regions,time],unit="1000 m^3")
    urbanuse = Parameter(index=[regions,time], unit="1000 m^3")
    # Demand for thermoelectric power (1000 m^3)
    thermoelectricuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    livestockuse = Parameter(index=[regions, time], unit="1000 m^3")
=======
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Demand for thermoelectric power (1000 m^3)
    thermoelectricuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    livestockuse = Parameter(index=[regions, time], unit="1000 m^3")
    # Combined water use for industry and mining (1000 m^3)
    industrymininguse = Parameter(index=[regions, time], unit="1000 m^3")
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45

    # Internal
    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, time], unit="1000 m^3")
<<<<<<< HEAD
=======

    # How much is returned by region
    totalreturn = Variable(index=[regions, time], unit="1000 m^3")
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45
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
<<<<<<< HEAD
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt] + p.industrialuse[rr, tt] + p.urbanuse[rr, tt] + p.thermoelectricuse[rr, tt] + p.livestockuse[rr, tt]
=======
        v.totaldemand[rr, tt] = p.totalirrigation[rr, tt] + p.domesticuse[rr, tt] + p.thermoelectricuse[rr, tt] + p.livestockuse[rr, tt] + p.industrymininguse[rr, tt]

        v.totalreturn[rr, tt] = returnpart["irrigation/livestock"] * p.totalirrigation[rr, tt] + returnpart["domestic/commercial"] * p.domesticuse[rr, tt] + returnpart["thermoelectric"] * p.thermoelectricuse[rr, tt] + returnpart["irrigation/livestock"] * p.livestockuse[rr, tt] + returnpart["industrial/mining"] * p.industrymininguse[rr, tt]
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45
    end
end

"""
Add a WaterDemand component to the model.
"""
function initwaterdemand(m::Model)
    waterdemand = addcomponent(m, WaterDemand);

    # Set optimized parameters to 0
<<<<<<< HEAD

    #waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:industrialuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:urbanuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    #waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])

    waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:industrialuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:urbanuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:livestockuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
    waterdemand[:thermoelectricuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time]);
=======
    waterdemand[:totalirrigation] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
    waterdemand[:domesticuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
    waterdemand[:thermoelectricuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
    waterdemand[:livestockuse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
    waterdemand[:industrymininguse] = zeros(m.indices_counts[:regions], m.indices_counts[:time])
>>>>>>> 7b10aac957a08796b7813dc5ef207fc667d5ce45

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

function grad_waterdemand_totalreturn_industrymininguse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :industrymininguse, (rr, tt) -> -returnpart["industrial/mining"])
end

function grad_waterdemand_totalreturn_thermoelectricuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :thermoelectricuse, (rr, tt) -> -returnpart["thermoelectric"])
end

function grad_waterdemand_totalreturn_livestockuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :livestockuse, (rr, tt) -> -returnpart["irrigation/livestock"])
end

function values_waterdemand_recordeddomestic(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = (recorded[rr, :PS_SW] + recorded[rr, :DO_SW]) * 1382592. / 1000.
    shaftsingle(m, :WaterDemand, :domesticuse, gen)
end

function values_waterdemand_recordedindustrymining(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = (recorded[rr, :IN_SW] + recorded[rr, :MI_SW]) * 1382592. / 1000.
    shaftsingle(m, :WaterDemand, :industrymininguse, gen)
end

function values_waterdemand_recordedirrigation(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :IR_SW] * 1382592. / 1000.
    shaftsingle(m, :WaterDemand, :totalirrigation, gen)
end

function values_waterdemand_recordedlivestock(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :LI_SW] * 1382592. / 1000.
    shaftsingle(m, :WaterDemand, :livestockuse, gen)
end

function values_waterdemand_recordedthermoelectric(m::Model)
    recorded = readtable("../data/extraction/USGS-2010.csv")
    gen(rr, tt) = recorded[rr, :PT_SW] * 1382592. / 1000.
    shaftsingle(m, :WaterDemand, :thermoelectricuse, gen)
end

