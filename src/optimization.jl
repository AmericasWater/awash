redohouse = true #!isfile(cachepath("fullhouse$suffix.jld"))
redogwwo = true #!isfile(cachepath("partialhouse2$suffix.jld"))

include("world.jl")
include("weather.jl")

include("Agriculture.jl")
include("WaterDemand.jl")
include("IndustrialDemand.jl")
include("PopulationDemand.jl")
#include("Market.jl")
#include("Transportation.jl")
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
industrialdemand = initindustrialdemand(m) # optimization-only
agriculture = initagriculture(m); # dep. IrrigationAgriculture, UnivariateAgriculture
waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
waternetwork = initwaternetwork(m); # dep. WaterDemand
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture
urbandemand = initurbandemand(m) # Just here for the parameters

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation,:IndustrialDemand,:IndustrialDemand,:IndudstrialDemand]
parameters = [:waterfromgw, :withdrawals,:supersource,:waterused,:dummy]
constcomps = [:WaterNetwork, :Allocation]
constraints = [:outflows, :balance]
## Constraint definitions:
# domesticbalance is the amount being supplied to local markets
# outflows is the water in the stream
# balance is the demand minus supply

if redohouse
    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

    # Optimize industrial revenue-gw cost - swcost 
    #Industrial Revenue=(supersource-C)+a*industrial water use= Revenue 
    println("Objectives...")
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    setobjective!(house, -varsum(grad_allocation_cost_withdrawals(m)))
    setobjective!(house,deriv_industrialdemand_totalrevenue_waterused(m)*grad_industrialdemand_totalrevenue_waterused(m))
    setobjective!(house,deriv_industrialdemand_totalrevenue_supersource(m)*grad_industrialdemand_totalrevenue_supersource(m))    
    setobjective!(house,-deriv_industrialdemand_totalrevenue_dummy(m)*grad_industrialdemand_totalrevenue_dummy(m))        
   
    

    println("Constraints...")

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

    
    # industrial - pumping - withdrawals < -otherdemands
    setconstraint!(house, grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_univariateagriculture_totalirrigation_totalareas(m)) # +
    setconstraint!(house, grad_waterdemand_swdemandbalance_totalirrigation(m) * grad_irrigationagriculture_totalirrigation_irrigatedareas(m)) # +
    setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
    setconstraintoffset!(house, -hall_relabel(constraintoffset_urbandemand_waterdemand(m), :waterdemand, :Allocation, :balance)) # -

    ####FIX ABOVE######
    
    
    #-Dummy<=0
    setconstraint!(house,-grad_industrialdemand_positive_dummy(m))
    setconstraintoffset!(house,constraintoffset_industrialdemand_positive(m))
    
    #-Supersource<=0
    setconstraint!(house,-grad_industrialdemand_positive2_supersource(m))
    setconstraintoffset!(house,hall_relabel(constraintoffset_industrialdemand_positive(m),:supersource,:IndustrialDemand,:positive2))
    
    #BALANCE1::::Supersource-Dummy<=1
    setconstraint!(house,-room_relable(grad_industrialdemand_positive2_supersource(m),:supersource,:IndustrialDemand,:balance1)
    setconstraint!(house,-room_relable(grad_industrialdemand_positive_dummy(m),:dummy,:IndustrialDemand,:balance1)
    setconstraintoffset!(house,constraintoffset_industrialdemand_balance1(m))
    
        
    #BALANCE2:::Dummy-Supersource<=0
    setconstraint!(house,-room_relabel(grad_industrialdemand_positive2_supersource(m),:supersource,:IndustrialDemand,:balance2))
    setconstraint!(house,room_relabel(grad_industrialdemand_positive_dummy(m),:dummy,:IndustrialDemand,:balance2)
    setconstraintoffset!(house,constraintoffset_industrialdemand_balance2(m))
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    # Clean up

    house.b[isnan(house.b)] = 0
    house.b[!isfinite(house.b)] = 0
    house.f[isnan(house.f)] = 0
    house.f[!isfinite(house.f)] = 0

    ri, ci, vv = findnz(house.A)
    for ii in find(isnan(vv))
        house.A[ri[ii], ci[ii]] = vv[ii]
    end
    for ii in find(!isfinite(vv))
        house.A[ri[ii], ci[ii]] = 1e9
    end

    serialize(open(cachepath("fullhouse$suffix.jld"), "w"), house)
else
    house = deserialize(open(cachepath("fullhouse$suffix.jld"), "r"));
end
