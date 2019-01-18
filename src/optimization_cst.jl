## Complete Optimization Model construction, with constant constraints
#
# Produces a linear programming model where demands are determined by
# the optimization, and some features are required to be constant.

redohouse = true #!isfile(cachepath("fullhouse$suffix.jld"))
redogwwo = true #!isfile(cachepath("partialhouse2$suffix.jld"))
allowreservoirs = false

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

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation, :UnivariateAgriculture,:Allocation]
parameters = [:waterfromgw, :withdrawals, :totalareas_cst,:returns]
constcomps = [:UnivariateAgriculture, :WaterNetwork, :Allocation,:Allocation,:Allocation,
              :UnivariateAgriculture,:UnivariateAgriculture,:UnivariateAgriculture]
constraints = [:allagarea, :outflows, :balance,:totaluse,:returnbalance,
               :sorghumarea,:hayproduction,:barleyproduction]

## Constraint definitions:
# domesticbalance is the amount being supplied to local markets
# outflows is the water in the stream
# balance is the demand minus supply

if redohouse
    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

    # Optimize revenue_domestic + revenue_international - pumping_cost - transit_cost
    println("Objectives...")
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
    setobjective!(house, -varsum(grad_univariateagriculture_opcost_totalareas_cst(m)))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_allcropproduction_unicropproduction(m) * room_relabel(grad_univariateagriculture_production_totalareas_cst(m), :production, :Agriculture, :unicropproduction), :allcropproduction, :Market, :produced))
    irrproduction2allproduction = grad_agriculture_allcropproduction_irrcropproduction(m)



    println("Constraints...")

    # Constrain agriculture < county area ** JUST CHANGE NUMBER
    #Fix to total Ag area
    setconstraint!(house,grad_univariateagriculture_allagarea_totalareas_cst(m))
    setconstraintoffset!(house,constraintoffset_univariateagriculture_allagarea(m))


    # Constrain outflows + runoff > 0, or -outflows < runoff **SAME AS CST
     if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(datapath("partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_outflows(m);
        serialize(open(datapath("partialhouse2$suffix.jld"), "w"), cwro);
    else
        gwwo = deserialize(open(datapath("partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(datapath("partialhouse2$suffix.jld"), "r"));
    end

    # Specify the components affecting outflow: withdrawals, returns, captures
    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraint!(house, room_relabel_parameter(gwwo - grad_waternetwork_immediateoutflows_withdrawals(m), :withdrawals, :Allocation, :returns)) # -
    # Specify that these can at most equal the cummulative runoff
    setconstraintoffset!(house, cwro) # +



    # Constrain swdemand < swsupply, or irrigation + domestic < pumping + withdrawals, or irrigation - pumping - withdrawals < -domestic
    setconstraint!(house, grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_univariateagriculture_totalirrigation_totalareas_cst(m)) # +
    setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
    setconstraintoffset!(house,-constraintoffset_allocation_otherdemand(m))

#, :waterdemand, :Allocation, :balance)) # -
#setconstraintoffset!(house, -constraintoffset_allocation_otherdemand(m))



     # Sorghum Areas<Max Sourghum Area at County  Due to suitability issue
    setconstraint!(house,grad_univariateagriculture_sorghumarea_totalareas_cst(m))
    setconstraintoffset!(house,constraintoffset_univariateagriculture_sorghumarea(m))


 #  -Hay production < -Min State Constraint Value
    setconstraint!(house,-grad_univariateagriculture_hayproduction_totalareas_cst(m))
    setconstraintoffset!(house,-constraintoffset_univariateagriculture_hayproduction(m))


 #  Barley production < Barley Max Constraint Value
    setconstraint!(house,grad_univariateagriculture_barleyproduction_totalareas_cst(m))
    setconstraintoffset!(house,constraintoffset_univariateagriculture_barleyproduction(m))


    setconstraint!(house,grad_allocation_totaluse_withdrawals(m))
    setconstraint!(house,grad_allocation_totaluse_waterfromgw(m))
    setconstraintoffset!(house,constraintoffset_allocation_totaluse(m))



    #Constraint returnbalance < 0, or returns - waterreturn < 0, or returns < waterreturn
    setconstraint!(house, grad_allocation_returnbalance_returns(m)) # +
        setconstraintoffset!(house, -hall_relabel(grad_waterdemand_totalreturn_domesticuse(m) * values_waterdemand_recordeddomestic(m) +
			                          grad_waterdemand_totalreturn_industrialuse(m) * values_waterdemand_recordedindustrial(m) +
                                                  grad_waterdemand_totalreturn_thermoelectricuse(m) * values_waterdemand_recordedthermoelectric(m) +
                                                  grad_waterdemand_totalreturn_livestockuse(m) * values_waterdemand_recordedlivestock(m),
        :totalreturn, :Allocation, :returnbalance)) # +


    # Clean up

    house.b[isnan.(house.b)] = 0
    house.b[!isfinite.(house.b)] = 0
    house.f[isnan.(house.f)] = 0
    house.f[!isfinite.(house.f)] = 0

    ri, ci, vv = findnz(house.A)
    for ii in find(isnan.(vv))
        house.A[ri[ii], ci[ii]] = vv[ii]
    end
    for ii in find(!isfinite.(vv))
        house.A[ri[ii], ci[ii]] = 1e9
    end

    serialize(open(cachepath("fullhouse$suffix.jld"), "w"), house)
    else
    house = deserialize(open(cachepath("fullhouse$suffix.jld"), "r"));
end
