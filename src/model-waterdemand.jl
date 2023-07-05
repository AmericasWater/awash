## Water Model construction
#
# Creates and constructs the model with all demands.

## `config` must be defined before loading this file!

include("world.jl")
include("weather.jl")

if get(config, "demandmodel", nothing) == "USGS"
    include("WaterDemand.jl")
else
    include("Thermoelectric.jl")
    include("Livestock.jl")
    include("Agriculture.jl");
    include("IrrigationAgriculture.jl");
    include("UnivariateAgriculture.jl");
    include("IndustrialDemand.jl");
    include("UrbanDemand.jl");
    include("WaterDemand.jl");
end


## Check if the optimize-surface script has been called
storedresult = cached_fallback("extraction/withdrawals", () -> false)
if storedresult == false
    @warn "Missing saved allocation files.  Please run optimize-surface.jl"
elseif size(storedresult)[1] != numcanals || size(storedresult)[3] != numsteps
    @warn "Cache file does not match current configuration.  Please remove."
end

println("Creating model...")
model = newmodel();

# Add all of the components
if get(config, "demandmodel", nothing) != "USGS"
    thermoelectric = initthermoelectric(model); # exogenous
    livestock = initlivestock(model); # exogenous
    irrigationagriculture = initirrigationagriculture(model); # optimization-only
    univariateagriculture = initunivariateagriculture(model); # optimization-only
    agriculture = initagriculture(model); # optimization-only
    industrialdemand = initindustrialdemand(model); # exogenous
    urbandemand = initurbandemand(model); # exogenous
end
waterdemand = initwaterdemand(model); # dep. Agriculture, PopulationDemand

# Connect up the components
if get(config, "demandmodel", nothing) != "USGS"
    agriculture[:irrcropareas] = irrigationagriculture[:totalareas]
    agriculture[:irrcropproduction] = irrigationagriculture[:production]
    agriculture[:irrirrigation] = irrigationagriculture[:totalirrigation]

    agriculture[:unicropareas] = univariateagriculture[:totalareas2]
    agriculture[:unicropproduction] = univariateagriculture[:production]
    agriculture[:uniirrigation] = univariateagriculture[:totalirrigation]

    waterdemand[:totalirrigation] = agriculture[:allirrigation];
    waterdemand[:thermoelectricuse] = thermoelectric[:demand_copy];
    waterdemand[:livestockuse] = livestock[:demand_copy];
    waterdemand[:urbanuse] = urbandemand[:waterdemand];
    waterdemand[:industrialuse] = industrialdemand[:waterdemand];
end
