## Complete Optimization Model construction
#
# Produces a linear programming model where demands are determined by
# the optimization.

redohouse = true #!isfile(cachepath("fullhouse$suffix.jld"))
redogwwo = true #!isfile(cachepath("partialhouse2$suffix.jld"))

include("world.jl")
include("weather.jl")

include("Agriculture.jl")
include("UnivariateAgriculture.jl")
include("IrrigationAgriculture.jl")
include("WaterDemand.jl")
include("PopulationDemand.jl")
include("Market.jl")
include("Transportation.jl")
include("WaterNetwork.jl")
include("Allocation.jl")
include("UrbanDemand.jl")

println("Creating model...")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
populationdemand = initpopulationdemand(m, m.indices_values[:time]); # exogenous
univariateagriculture = initunivariateagriculture(m) # optimization-only
irrigationagriculture = initirrigationagriculture(m) # optimization-only
agriculture = initagriculture(m); # dep. IrrigationAgriculture, UnivariateAgriculture
waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
waternetwork = initwaternetwork(m); # dep. WaterDemand
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture
urbandemand = initurbandemand(m) # Just here for the parameters

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation, :UnivariateAgriculture, :IrrigationAgriculture, :IrrigationAgriculture, :Transportation, :Market]
parameters = [:waterfromgw, :withdrawals, :totalareas, :rainfedareas, :irrigatedareas, :imported, :internationalsales]
constcomps = [:Agriculture, :WaterNetwork, :Allocation, :Market, :Market]
constraints = [:allagarea, :outflows, :balance, :available, :domesticbalance]

## Constraint definitions:
# domesticbalance is the amount being supplied to local markets
# outflows is the water in the stream
# balance is the demand minus supply

if redohouse
    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

    # Optimize revenue_domestic + revenue_international - pumping_cost - transit_cost
    println("Objectives...")
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    setobjective!(house, -varsum(grad_transportation_cost_imported(m)))
    setobjective!(house, -varsum(grad_univariateagriculture_cost_totalareas(m)))
    setobjective!(house, -varsum(grad_irrigationagriculture_cost_rainfedareas(m)))
    setobjective!(house, -varsum(grad_irrigationagriculture_cost_irrigatedareas(m)))
    setobjective!(house, deriv_market_totalrevenue_internationalsales(m))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_allcropproduction_unicropproduction(m) * room_relabel(grad_univariateagriculture_production_totalareas(m), :production, :Agriculture, :unicropproduction), :allcropproduction, :Market, :produced))
    irrproduction2allproduction = grad_agriculture_allcropproduction_irrcropproduction(m)
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_rainfedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_irrigatedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced))

    println("Constraints...")

    # Constrain agriculture < county area
    setconstraint!(house, room_relabel(grad_univariateagriculture_allagarea_totalareas(m), :allagarea, :Agriculture, :allagarea)) # +
    setconstraint!(house, room_relabel(grad_irrigationagriculture_allagarea_irrigatedareas(m), :allagarea, :Agriculture, :allagarea)) # +
    setconstraint!(house, room_relabel(grad_irrigationagriculture_allagarea_rainfedareas(m), :allagarea, :Agriculture, :allagarea)) # +
    setconstraintoffset!(house, constraintoffset_agriculture_allagarea(m))

    # Constrain outflows + runoff > 0, or -outflows < runoff
    if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(cachepath("partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_outflows(m);
        serialize(open(cachepath("partialhouse2$suffix.jld"), "w"), cwro);
    else
        gwwo = deserialize(open(cachepath("partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(cachepath("partialhouse2$suffix.jld"), "r"));
    end

    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraintoffset!(house, cwro) # +

    # Constrain available market > 0
    setconstraint!(house, -grad_market_available_produced(m) * room_relabel(grad_agriculture_allcropproduction_unicropproduction(m) * room_relabel(grad_univariateagriculture_production_totalareas(m), :production, :Agriculture, :unicropproduction), :allcropproduction, :Market, :produced)) # -
    setconstraint!(house, -grad_market_available_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_rainfedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced)) # -
    setconstraint!(house, -grad_market_available_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_irrigatedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced)) # -
    setconstraint!(house, -grad_market_available_internationalsales(m)) # +
    setconstraint!(house, -(grad_market_available_regionimports(m) * grad_transportation_regionimports_imported(m) +
                   grad_market_available_regionexports(m) * grad_transportation_regionexports_imported(m))) # +-

    # Constrain swdemand < swsupply, or irrigation + domestic < pumping + withdrawals, or irrigation - pumping - withdrawals < -domestic
    setconstraint!(house, room_relabel(grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_univariateagriculture_totalirrigation_totalareas(m), :totaldemand, :Allocation, :balance)) # +
    setconstraint!(house, room_relabel(grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_irrigationagriculture_totalirrigation_irrigatedareas(m), :totaldemand, :Allocation, :balance)) # +
    setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
    setconstraintoffset!(house, -hall_relabel(constraintoffset_urbandemand_waterdemand(m), :waterdemand, :Allocation, :balance)) # -

    # Constrain domesticsales < domesticdemand
    # Reproduce 'available'
    setconstraint!(house, room_relabel(grad_market_available_produced(m) * room_relabel(grad_agriculture_allcropproduction_unicropproduction(m) * room_relabel(grad_univariateagriculture_production_totalareas(m), :production, :Agriculture, :unicropproduction), :allcropproduction, :Market, :produced), :available, :Market, :domesticbalance)) # +
    setconstraint!(house, room_relabel(grad_market_available_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_irrigatedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced), :available, :Market, :domesticbalance)) # +
    setconstraint!(house, room_relabel(grad_market_available_produced(m) * room_relabel(irrproduction2allproduction * room_relabel(grad_irrigationagriculture_production_rainfedareas(m), :production, :Agriculture, :irrcropproduction), :allcropproduction, :Market, :produced), :available, :Market, :domesticbalance)) # +
    setconstraint!(house, room_relabel(grad_market_available_internationalsales(m), :available, :Market, :domesticbalance)) # -
    setconstraint!(house, room_relabel(grad_market_available_regionimports(m) * grad_transportation_regionimports_imported(m) +
                                       grad_market_available_regionexports(m) * grad_transportation_regionexports_imported(m), :available, :Market, :domesticbalance)) # +-
    setconstraintoffset!(house, -hall_relabel(constraintoffset_populationdemand_cropinterest(m), :cropinterest, :Market, :domesticbalance)) # -

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

    serialize(open(cachepath("fullhouse$suffix.jld"), "w"), house)
else
    house = deserialize(open(cachepath("fullhouse$suffix.jld"), "r"));
end
