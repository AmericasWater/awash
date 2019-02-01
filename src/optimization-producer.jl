## Complete Optimization Model construction, with constant constraints
#
# Produces a linear programming model where demands are determined by
# the optimization, and some features are required to be constant.

using OptiMimi

redogwwo = true #!isfile(cachepath("partialhouse2$suffix.jld"))
allowreservoirs = false
agconstraint = :area # or production

include("world.jl")
include("weather.jl")

include("Agriculture.jl")
include("UnivariateAgriculture.jl")
include("IrrigationAgriculture.jl")
include("WaterDemand.jl")
include("PopulationDemand.jl")
include("WaterNetwork.jl")
include("Allocation.jl")
include("ReturnFlows.jl")
include("UrbanDemand.jl")

println("Creating model...")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
populationdemand = initpopulationdemand(m, m.indices_values[:time]); # exogenous
univariateagriculture = initunivariateagriculture(m); # optimization-only
irrigationagriculture = initirrigationagriculture(m); # optimization-only
agriculture = initagriculture(m); # dep. IrrigationAgriculture, UnivariateAgriculture
waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
waternetwork = initwaternetwork(m); # dep. WaterDemand
urbandemand = initurbandemand(m) # Just here for the parameters

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation, :UnivariateAgriculture, :IrrigationAgriculture, :IrrigationAgriculture, :Allocation]
parameters = [:waterfromgw, :withdrawals, :totalareas, :rainfedareas, :irrigatedareas, :returns]
if agconstraint == :production
    constcomps = [:Agriculture, :WaterNetwork, :Allocation, :Allocation, :UnivariateAgriculture, :IrrigationAgriculture]
    constraints = [:allagarea, :outflows, :balance, :returnbalance, :production_sumregion, :production_sumregion]
else
    constcomps = [:Agriculture, :WaterNetwork, :Allocation, :Allocation, :UnivariateAgriculture, :IrrigationAgriculture]
    constraints = [:allagarea, :outflows, :balance, :returnbalance, :area_sumregion, :area_sumregion]
end

## Constraint definitions:
# domesticbalance is the amount being supplied to local markets
# outflows is the water in the stream
# balance is the demand minus supply

house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

# Optimize revenue_domestic + revenue_international - pumping_cost - transit_cost
println("Objectives...")
setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
setobjective!(house, -varsum(grad_univariateagriculture_cost_totalareas(m)))
setobjective!(house, -varsum(grad_irrigationagriculture_cost_rainfedareas(m)))
setobjective!(house, -varsum(grad_irrigationagriculture_cost_irrigatedareas(m)))

println("Constraints...")

# Constrain agriculture < county area
setconstraint!(house, room_relabel(grad_univariateagriculture_allagarea_totalareas(m), :allagarea, :Agriculture, :allagarea)) # +
setconstraint!(house, room_relabel(grad_irrigationagriculture_allagarea_irrigatedareas(m), :allagarea, :Agriculture, :allagarea)) # +
setconstraint!(house, room_relabel(grad_irrigationagriculture_allagarea_rainfedareas(m), :allagarea, :Agriculture, :allagarea)) # +
setconstraintoffset!(house, constraintoffset_agriculture_allagarea(m))

# Constrain outflows + runoff > 0, or -outflows < runoff **SAME AS CST
if redogwwo
    gwwo = grad_waternetwork_outflows_swwithdrawals(m);
    serialize(open(datapath("partialhouse$suffix.jld"), "w"), gwwo);
    cwro = constraintoffset_waternetwork_outflows(m);
    serialize(open(datapath("partialhouse2$suffix.jld"), "w"), cwro);
else
    gwwo = deserialize(open(datapath("partialhouse$suffix.jld"), "r"));
    cwro = deserialize(open(datapath("partialhouse2$suffix.jld"), "r"));
end

# Specify the components affecting outflow: withdrawals, returns, captures
setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
setconstraint!(house, room_relabel_parameter(gwwo - grad_waternetwork_immediateoutflows_swwithdrawals(m), :withdrawals, :Allocation, :returns)) # -
# Specify that these can at most equal the cummulative runoff
setconstraintoffset!(house, cwro) # +

# Constrain swdemand < swsupply, or irrigation + domestic < pumping + withdrawals, or irrigation - pumping - withdrawals < -domestic
setconstraint!(house, room_relabel(grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_univariateagriculture_totalirrigation_totalareas(m), :totaldemand, :Allocation, :balance)) # +
setconstraint!(house, room_relabel(grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_irrigationagriculture_totalirrigation_irrigatedareas(m), :totaldemand, :Allocation, :balance)) # +
setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
setconstraintoffset!(house, -hall_duplicate(constraintoffset_urbandemand_waterdemand(m), :waterdemand, :Allocation, :balance, m, [false, true, false])) # -

#Constraint returnbalance < 0, or returns - waterreturn < 0, or returns < waterreturn
setconstraint!(house, grad_allocation_returnbalance_returns(m)) # +
setconstraintoffset!(house, -hall_relabel(grad_waterdemand_totalreturn_domesticuse(m) * values_waterdemand_recordeddomestic(m) +
			                  grad_waterdemand_totalreturn_industrialuse(m) * values_waterdemand_recordedindustrial(m) +
                                          grad_waterdemand_totalreturn_thermoelectricuse(m) * values_waterdemand_recordedthermoelectric(m) +
                                          grad_waterdemand_totalreturn_livestockuse(m) * values_waterdemand_recordedlivestock(m),
                                          :totalreturn, :Allocation, :returnbalance)) # +

# Constrain sum over region of production for each crop < observed production
if agconstraint == :production
    setconstraint!(house, varsum(grad_univariateagriculture_production_totalareas(m), 1, m, :production_sumregion))
    setconstraintoffset!(house, constraintoffset_univariateagriculture_productionsumregion(m))
    setconstraint!(house, varsum(grad_irrigationagriculture_production_irrigatedareas(m), 1, m, :production_sumregion))
    setconstraint!(house, varsum(grad_irrigationagriculture_production_rainfedareas(m), 1, m, :production_sumregion))
    setconstraintoffset!(house, constraintoffset_irrigationagriculture_productionsumregion(m))
else
    setconstraint!(house, grad_univariateagriculture_areasumregion_totalareas(m))
    setconstraintoffset!(house, constraintoffset_univariateagriculture_areasumregion(m))
    setconstraint!(house, grad_irrigationagriculture_areasumregion_irrigatedareas(m))
    setconstraint!(house, grad_irrigationagriculture_areasumregion_rainfedareas(m))
    setconstraintoffset!(house, constraintoffset_irrigationagriculture_areasumregion(m))
end

# Clean up

house.b[isnan.(house.b)] = 0
house.b[.!isfinite.(house.b)] = 0
house.f[isnan.(house.f)] = 0
house.f[.!isfinite.(house.f)] = 0

ri, ci, vv = findnz(house.A)
for ii in find(isnan.(vv))
    house.A[ri[ii], ci[ii]] = vv[ii]
end
for ii in find(.!isfinite.(vv))
    house.A[ri[ii], ci[ii]] = 1e9
end

# rhs = sum(abs.(house.A), 2)
# invalid = (rhs .== 0) .& (house.b .!= 0)

# valid = (rhs .> 0)
# scaling = house.b ./ rhs
# findfirst(isnan.(scaling))
# findfirst(isnan.(scaling[valid]))

# quantile(abs.(vec(scaling[valid & (house.b .!= 0)])))

# cumsum(varlengths(house.model, house.constcomps, house.constraints))
