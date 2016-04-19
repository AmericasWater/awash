using Mimi
include("linproghouse.jl")

netset = "usa" # dummy or usa

# Only include counties within this state (give as 2 digit FIPS)
# "10" for Delaware (3 counties), "08" for Colorado (64 counties)
filterstate = nothing #"10"

redohouse = isfile(joinpath(todata, "fullhouse$suffix.jld"))
redogwwo = isfile(joinpath(todata, "partialhouse2$suffix.jld"))

include("world.jl")
include("weather.jl")

include("Agriculture.jl")
include("WaterDemand.jl")
include("DomesticDemand.jl")
include("Market.jl")
include("Transportation.jl")
include("WaterNetwork.jl")
include("Allocation.jl")

println("Creating model...")

# First solve entire problem in a single timestep
m = newmodel();

# Add all of the components
domesticdemand = initdomesticdemand(m, m.indices_values[:time]); # exogenous
agriculture = initagriculture(m); # optimization-only
waterdemand = initwaterdemand(m); # dep. Agriculture, DomesticDemand
waternetwork = initwaternetwork(m); # dep. WaterDemand
transportation = inittransportation(m); # optimization-only
market = initmarket(m); # dep. Transporation, Agriculture

# Only include variables needed in constraints and parameters needed in optimization

paramcomps = [:Allocation, :Allocation, :Agriculture, :Agriculture, :Transportation, :Market]
parameters = [:waterfromgw, :withdrawals, :rainfedareas, :irrigatedareas, :imported, :internationalsales]
constcomps = [:Agriculture, :WaterNetwork, :Allocation, :Market, :Market]
constraints = [:allagarea, :outflows, :swbalance, :available, :domesticbalance]
## Constraint definitions:
# domesticbalance is the amount being supplied to local markets
# outflows is the water in the stream
# swbalance is the demand minus supply

if redohouse
    house = LinearProgrammingHouse(m, paramcomps, parameters, constcomps, constraints);

    # Optimize revenue_domestic + revenue_international - pumping_cost - transit_cost
    setobjective!(house, -varsum(grad_allocation_cost_waterfromgw(m)))
    setobjective!(house, -varsum(grad_transportation_cost_imported(m)))
    setobjective!(house, -varsum(grad_agriculture_cost_rainfedareas(m)))
    setobjective!(house, -varsum(grad_agriculture_cost_irrigatedareas(m)))
    setobjective!(house, deriv_market_totalrevenue_internationalsales(m))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_production_rainfedareas(m), :production, :Market, :produced))
    setobjective!(house, deriv_market_totalrevenue_produced(m) * room_relabel(grad_agriculture_production_irrigatedareas(m), :production, :Market, :produced))

    # Constrain agriculture < county area
    setconstraint!(house, grad_agriculture_allagarea_irrigatedareas(m)) # +
    setconstraint!(house, grad_agriculture_allagarea_rainfedareas(m)) # +
    setconstraintoffset!(house, constraintoffset_agriculture_allagarea(m))

    # Constrain outflows + runoff > 0, or -outflows < runoff
    if redogwwo
        gwwo = grad_waternetwork_outflows_withdrawals(m);
        serialize(open(joinpath(todata, "partialhouse$suffix.jld"), "w"), gwwo);
        cwro = constraintoffset_waternetwork_runoff(m);
        serialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "w"), cwro);
    else
        gwwo = deserialize(open(joinpath(todata, "partialhouse$suffix.jld"), "r"));
        cwro = deserialize(open(joinpath(todata, "partialhouse2$suffix.jld"), "r"));
    end

    setconstraint!(house, -room_relabel_parameter(gwwo, :withdrawals, :Allocation, :withdrawals)) # +
    setconstraintoffset!(house, cwro) # +

    # Constrain available market > 0
    setconstraint!(house, -grad_market_available_produced(m) * room_relabel(grad_agriculture_production_irrigatedareas(m), :production, :Market, :produced)) # -
    setconstraint!(house, -grad_market_available_produced(m) * room_relabel(grad_agriculture_production_rainfedareas(m), :production, :Market, :produced)) # -
    setconstraint!(house, -grad_market_available_internationalsales(m)) # +
    setconstraint!(house, -(grad_market_available_regionimports(m) * grad_transportation_regionimports_imported(m) +
                   grad_market_available_regionexports(m) * grad_transportation_regionexports_imported(m))) # +-

    # Constrain swdemand < swsupply, or irrigation + domestic < pumping + withdrawals, or irrigation - pumping - withdrawals < -domestic
    setconstraint!(house, grad_waterdemand_swbalance_totalirrigation(m) * grad_agriculture_totalirrigation_irrigatedareas(m)) # +
    setconstraint!(house, -grad_allocation_swbalance_waterfromgw(m)) # -
    setconstraint!(house, -grad_allocation_swbalance_withdrawals(m)) # - THIS IS SUPPLY
    setconstraintoffset!(house, -hall_relabel(constraintoffset_domesticdemand_waterdemand(m), :waterdemand, :Allocation, :swbalance)) # -

    # Constrain domesticsales < domesticdemand
    # Reproduce 'available'
    setconstraint!(house, room_relabel(grad_market_available_produced(m) * room_relabel(grad_agriculture_production_irrigatedareas(m), :production, :Market, :produced), :available, :Market, :domesticbalance)) # +
    setconstraint!(house, room_relabel(grad_market_available_produced(m) * room_relabel(grad_agriculture_production_rainfedareas(m), :production, :Market, :produced), :available, :Market, :domesticbalance)) # +
    setconstraint!(house, room_relabel(grad_market_available_internationalsales(m), :available, :Market, :domesticbalance)) # -
    setconstraint!(house, room_relabel(grad_market_available_regionimports(m) * grad_transportation_regionimports_imported(m) +
                                       grad_market_available_regionexports(m) * grad_transportation_regionexports_imported(m), :available, :Market, :domesticbalance)) # +-
    setconstraintoffset!(house, -hall_relabel(constraintoffset_domesticdemand_cropinterest(m), :cropinterest, :Market, :domesticbalance)) # -

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

    serialize(open(joinpath(todata, "fullhouse$suffix.jld"), "w"), house)
else
    house = deserialize(open(joinpath(todata, "fullhouse$suffix.jld"), "r"));
end

using MathProgBase
@time sol = linprog(-house.f, house.A, '<', house.b, house.lowers, house.uppers)

coning = constraining(house, sol.sol)

rdf = DataFrame(fips=names);
cdf = DataFrame(fips=repmat(names, numcrops), crop=vec(repeat(crops, inner=[numcounties, 1])));

# Look at parameter values
varlens = varlengths(m, house.paramcomps, house.parameters)
for ii in 1:length(house.parameters)
    println(house.parameters[ii])
    index1 = sum(varlens[1:ii-1]) + 1
    index2 = sum(varlens[1:ii])

    values = sol.sol[index1:index2]

    if varlens[ii] == nrow(rdf)
        rdf[house.parameters[ii]] = values
    elseif varlens[ii] == nrow(cdf)
        cdf[house.parameters[ii]] = values
    else
        #println("Cannot store: $(varlens[ii])")
    end

    if (sum(values .!= 0) == 0)
        println("All zero.")
    else
        println(values[1:min(100, index2 - index1 + 1)])
        println("Sum: $(sum(values))")
    end
end

# Get constraint values
constvalues = house.A * sol.sol

varlens = varlengths(m, house.constcomps, house.constraints)
for ii in 1:length(house.constraints)
    println(house.constraints[ii])
    index1 = sum(varlens[1:ii-1]) + 1
    index2 = sum(varlens[1:ii])

    values = constvalues[index1:index2]

    if varlens[ii] == nrow(rdf)
        rdf[house.constraints[ii]] = values
    elseif varlens[ii] == nrow(cdf)
        cdf[house.constraints[ii]] = values
    else
        #println("Cannot store: $(varlens[ii])")
    end

    if (sum(values .!= 0) == 0)
        println("All zero.")
    else
        println(values[1:min(100, index2 - index1 + 1)])
    end
end

writetable("../results/regionout.csv", rdf)
writetable("../results/cropsout.csv", cdf)
