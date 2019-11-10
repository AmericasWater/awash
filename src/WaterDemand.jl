## Combined Water Demand Component
#
# Combines all of the sources of water demand.

using Mimi
using DataFrames
include("lib/datastore.jl")

# Load consumptive use data
consumption = CSV.read(loadpath("returnflows/consumption.csv"))
returnpart = Dict([consumption[ii, :sector] => (1 - consumption[ii, :consumption]) * consumption[ii, :usablesw] for ii = 1:nrow(consumption)])

@defcomp WaterDemand begin
    regions = Index()
    scenarios = Index()

    # External
    # Irrigation water (1000 m^3)
    totalirrigation = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    domesticuse = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    # Industrial and mining demand, self supplied
    industrialuse = Parameter(index=[regions, scenarios, time],unit="1000 m^3")
    urbanuse = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    # Demand for thermoelectric power (1000 m^3)
    thermoelectricuse = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    # Combined water use for domestic sinks (1000 m^3)
    livestockuse = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # Internal
    # Total water demand (1000 m^3)
    totaldemand = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    otherdemand = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    # How much is returned by region
    totalreturn = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    """
    Compute the amount extracted and the cost for doing it.
    """
    function run_timestep(p, v, d, tt)
        for rr in d.regions
            # Sum all demands
            v.totaldemand[rr, :, tt] = p.totalirrigation[rr, :, tt] + p.domesticuse[rr, :, tt] + p.industrialuse[rr, :, tt] + p.urbanuse[rr, :, tt] + p.thermoelectricuse[rr, :, tt] + p.livestockuse[rr, :, tt]
            v.otherdemand[rr, :, tt] = p.domesticuse[rr, :, tt] + p.industrialuse[rr, :, tt] + p.urbanuse[rr, :, tt] + p.thermoelectricuse[rr, :, tt] + p.livestockuse[rr, :, tt]

            v.totalreturn[rr, :, tt] = returnpart["irrigation/livestock"] * p.totalirrigation[rr, :, tt] + returnpart["domestic/commercial"] * p.domesticuse[rr, :, tt] + returnpart["industrial/mining"] * p.industrialuse[rr, :, tt] + returnpart["domestic/commercial"] * p.urbanuse[rr, :, tt] + returnpart["thermoelectric"] * p.thermoelectricuse[rr, :, tt] + returnpart["irrigation/livestock"] * p.livestockuse[rr, :, tt]
        end
    end
end

"""
Add a WaterDemand component to the model.
"""
function initwaterdemand(m::Model)
    waterdemand = add_comp!(m, WaterDemand);

    # Initialized at USGS values, replaced by model-waterdemand
    recorded = knowndf("exogenous-withdrawals")
    waterdemand[:totalirrigation] = repeat(convert(Vector, recorded[:,:IR_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);
    waterdemand[:industrialuse] = repeat(convert(Vector, recorded[:,:IN_To] + recorded[:,:MI_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);
    waterdemand[:urbanuse] = repeat(convert(Vector, recorded[:,:PS_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);
    waterdemand[:domesticuse] = repeat(convert(Vector, recorded[:,:DO_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);
    waterdemand[:livestockuse] = repeat(convert(Vector, recorded[:,:LI_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);
    waterdemand[:thermoelectricuse] = repeat(convert(Vector, recorded[:,:PT_To]) * config["timestep"] * 1383.0/12., outer=[1, numscenarios, dim_count(m, :time)]);

    waterdemand
end

function grad_waterdemand_swdemandbalance_totalirrigation(m::Model)
    roomdiagonal(m, :WaterDemand, :totaldemand, :totalirrigation, 1.)
end

function grad_waterdemand_swdemandbalance_domesticuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totaldemand, :domesticuse, 1.)
end

function grad_waterdemand_swdemandbalance_thermoelectricuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totaldemand, :thermoelectricuse, 1.)
end

function grad_waterdemand_swdemandbalance_livestockuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totaldemand, :livestockuse, 1.)
end

function grad_waterdemand_totalreturn_totalirrigation(m::Model)
    ##roomdiagonal(m, :WaterDemand, :totalreturn, :totalirrigation, -returnpart["irrigation/livestock"], [:scenarios])
    TODO # load from prepare/returnflows/rf-bycounty.csv
end

function grad_waterdemand_totalreturn_domesticuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :domesticuse, -returnpart["domestic/commercial"], [:scenarios])
end

function grad_waterdemand_totalreturn_industrialuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :industrialuse, -returnpart["industrial/mining"], [:scenarios])
end

function grad_waterdemand_totalreturn_thermoelectricuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :thermoelectricuse, -returnpart["thermoelectric"], [:scenarios])
end

function grad_waterdemand_totalreturn_livestockuse(m::Model)
    roomdiagonal(m, :WaterDemand, :totalreturn, :livestockuse, -returnpart["irrigation/livestock"], [:scenarios])
end

function values_waterdemand_recordedirrigation(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        if includegw
            values_waterdemand_recordedsurfaceirrigation(m) + values_waterdemand_recordedgroundirrigation(m)
        else
            values_waterdemand_recordedsurfaceirrigation(m)
        end
    else
        shaftvalues(m, :WaterDemand, :totalirrigation, demandmodel[:Agriculture, :allirrigation])
    end
end

function values_waterdemand_recordeddomestic(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        if includegw
            values_waterdemand_recordedsurfacedomestic(m) + values_waterdemand_recordedgrounddomestic(m)
        else
            values_waterdemand_recordedsurfacedomestic(m)
        end
    else
        shaftvalues(m, :WaterDemand, :domesticuse, demandmodel[:UrbanDemand, :waterdemand])
    end
end

function values_waterdemand_recordedindustrial(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        if includegw
            values_waterdemand_recordedsurfaceindustrial(m) + values_waterdemand_recordedgroundindustrial(m)
        else
            values_waterdemand_recordedsurfaceindustrial(m)
        end
    else
        shaftvalues(m, :WaterDemand, :industrialuse, demandmodel[:IndustrialDemand, :waterdemand])
    end
end

function values_waterdemand_recordedthermoelectric(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        if includegw
            values_waterdemand_recordedsurfacethermoelectric(m) + values_waterdemand_recordedgroundthermoelectric(m)
        else
            values_waterdemand_recordedsurfacethermoelectric(m)
        end
    else
        shaftvalues(m, :WaterDemand, :thermoelectricuse, demandmodel[:Thermoelectric, :demand_copy])
    end
end

function values_waterdemand_recordedlivestock(m::Model, includegw::Bool, demandmodel::Union{Model, Nothing}=nothing)
    if demandmodel == nothing
        if includegw
            values_waterdemand_recordedsurfacelivestock(m) + values_waterdemand_recordedgroundlivestock(m)
        else
            values_waterdemand_recordedsurfacelivestock(m)
        end
    else
        shaftvalues(m, :WaterDemand, :livestockuse, demandmodel[:Livestock, :demand_copy])
    end
end

function values_waterdemand_recordedsurfacedomestic(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * (recorded[rr, :PS_SW] + recorded[rr, :DO_SW]) * 1383. / 12.
    shaftsingle(m, :WaterDemand, :domesticuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedsurfaceindustrial(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * (recorded[rr, :IN_SW] + recorded[rr, :MI_SW]) * 1383. / 12.
    shaftsingle(m, :WaterDemand, :industrialuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedsurfaceirrigation(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :IR_SW] * 1383. / 12.
    shaftsingle(m, :WaterDemand, :totalirrigation, gen, [:scenarios, :time])
end

function values_waterdemand_recordedsurfacelivestock(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :LI_SW] * 13883. / 12.
    shaftsingle(m, :WaterDemand, :livestockuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedsurfacethermoelectric(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :PT_SW] * 1383. / 12.
    shaftsingle(m, :WaterDemand, :thermoelectricuse, gen, [:scenarios, :time])
end


function values_waterdemand_recordedgrounddomestic(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * (recorded[rr, :PS_GW] + recorded[rr, :DO_GW]) * 1383. / 12.
    shaftsingle(m, :WaterDemand, :domesticuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedgroundindustrial(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * (recorded[rr, :IN_GW] + recorded[rr, :MI_GW]) * 1383. / 12.
    shaftsingle(m, :WaterDemand, :industrialuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedgroundirrigation(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :IR_GW] * 1383. / 12.
    shaftsingle(m, :WaterDemand, :totalirrigation, gen, [:scenarios, :time])
end

function values_waterdemand_recordedgroundlivestock(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :LI_GW] * 1383. / 12.
    shaftsingle(m, :WaterDemand, :livestockuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordedgroundthermoelectric(m::Model)
    recorded = knowndf("exogenous-withdrawals")
    gen(rr) = config["timestep"] * recorded[rr, :PT_GW] * 1383. / 12.
    shaftsingle(m, :WaterDemand, :thermoelectricuse, gen, [:scenarios, :time])
end

function values_waterdemand_recordeddomestic(m::Model)
    values_waterdemand_recordedsurfacedomestic(m) + values_waterdemand_recordedgrounddomestic(m)
end

function values_waterdemand_recordedindustrial(m::Model)
    values_waterdemand_recordedsurfaceindustrial(m) + values_waterdemand_recordedgroundindustrial(m)
end

function values_waterdemand_recordedthermoelectric(m::Model)
    values_waterdemand_recordedsurfacethermoelectric(m) + values_waterdemand_recordedgroundthermoelectric(m)
end

function values_waterdemand_recordedlivestock(m::Model)
    values_waterdemand_recordedsurfacelivestock(m) + values_waterdemand_recordedgroundlivestock(m)
end
