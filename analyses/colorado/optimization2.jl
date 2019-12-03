
redohouse = !isfile(datapath("cache/fullhouse$suffix.jld"))
redogwwo = !isfile(datapath("cache/partialhouse2$suffix.jld"))

include("world.jl")
include("weather.jl")
include("Agriculture_CO.jl")
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
agriculture = initagriculture(m); # optimization-only
waterdemand = initwaterdemand(m); # dep. Agriculture, PopulationDemand
urbandemand= initurbandemand(m);
allocation = initallocation(m); # dep. WaterDemand, optimization (withdrawals)
waternetwork = initwaternetwork(m); # dep. WaterDemand
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture


# Only include variables needed
paramcomps = [:Allocation,:Allocation, :Allocation, :Agriculture, :Agriculture]
parameters = [:waterfromsupersource, :waterfromgw, :withdrawals, :rainfedareas, :irrigatedareas]
constcomps = [:WaterNetwork, :Allocation,:Agriculture,:Agriculture]
constraints = [:outflows, :balance,:totalproduction,:netareas]
###parameters=decision variables ###const=

#objective
if redohouse
    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

    # Optimize revenue_domestic-pumping_cost - swcost -agcost
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m))) #rr,cc,tt
    setobjective!(house, -varsum(grad_agriculture_cost_rainfedareas(m))) #rr,cc,tt
    setobjective!(house, -varsum(grad_agriculture_cost_irrigatedareas(m))) #rr,cc,tt
    setobjective!(house, -varsum(grad_allocation_cost_waterfromsupersource(m)))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_production_rainfedareas(m), :production, :Market, :produced))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_production_irrigatedareas(m), :production, :Market, :produced))
    Objective


    # Constrain outflows + runoff > 0, or -outflows < runoff
    if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(joinpath(todata, "cache/partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_outflows(m);
        serialize(open(joinpath(todata, "cache/partialhouse2$suffix.jld"), "w"), cwro);
    else
        gwwo = deserialize(open(joinpath(todata, "cache/partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(joinpath(todata, "cache/partialhouse2$suffix.jld"), "r"));
    end

    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraintoffset!(house, cwro) # +




    # irrigation + domestic+supersource < pumping + withdrawals
    setconstraint!(house, -grad_allocation_balance_waterfromsupersource(m)) # -
    setconstraint!(house, grad_waterdemand_swdemandbalance_totalirrigation(m) *
    grad_agriculture_totalirrigation_irrigatedareas(m)) # +
    setconstraint!(house, grad_waterdemand_gwdemandbalance_totalirrigation(m) *
    grad_agriculture_totalirrigation_irrigatedareas(m)) #+
    setconstraint!(house, -grad_allocation_balance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_balance_withdrawals(m)) # - THIS IS SUPPLY
    setconstraintoffset!(house, -hall_relabel(constraintoffset_urbandemand_waterdemand(m), :waterdemand, :Allocation, :balance)) # -


    # Constrain agriculture < county ag area
    setconstraint!(house, grad_agriculture_netareas_irrigatedareas(m)) # +
    setconstraint!(house, grad_agriculture_netareas_rainfedareas(m)) # +
    setconstraintoffset!(house, constraintoffset_agriculture_NCA(m))

    #crop total -Production<-cropdemand
    setconstraint!(house,-grad_agriculture_totalproduction_rainfedareas(m))#-
    setconstraint!(house,-grad_agriculture_totalproduction_irrigatedareas(m))#-
    setconstraintoffset!(house,-constraintoffset_agriculture_cropdemand(m))#-




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

    serialize(open(joinpath(todata, "cache/fullhouse$suffix.jld"), "w"), house)
else
    house = deserialize(open(joinpath(todata, "cache/fullhouse$suffix.jld"), "r"));
end

