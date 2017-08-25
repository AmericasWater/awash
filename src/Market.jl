# The market component
#
# Determines the available resource for consumption, as a balance between local
# production, imports, and exports.

using Mimi

@defcomp Market begin
    regions = Index()
    allcrops = Index()

    # Configuration
    # Selling prices
    domestic_prices = Parameter(index=[regions, allcrops], unit="\$/lborbu")
    international_prices = Parameter(index=[regions, allcrops], unit="\$/lborbu")

    # Optimized
    internationalsales = Parameter(index=[regions, allcrops, time], unit="lborbu")

    # External
    # Local production from Agriculture
    produced = Parameter(index=[regions, allcrops, time], unit="lborbu")

    # Imports and exports from Transportation
    regionimports = Parameter(index=[regions, allcrops, time], unit="lborbu")
    regionexports = Parameter(index=[regions, allcrops, time], unit="lborbu")

    # How much domestic buy if available
    domestic_interest = Parameter(index=[regions, allcrops, time], unit="lborbu")

    # Internal

    # The balance of available resource
    available = Variable(index=[regions, allcrops, time], unit="lborbu")

    # Remaining after international are sold
    domesticbalance = Variable(index=[regions, allcrops, time], unit="lborbu")

    # Total revenue from selling all available
    domesticrevenue = Variable(index=[regions, allcrops, time], unit="\$")
    internationalrevenue = Variable(index=[regions, allcrops, time], unit="\$")
end

"""
Compute the available local resource for consumption, `available`.
"""
function run_timestep(c::Market, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        for cc in d.allcrops
            v.available[rr, cc, tt] = p.produced[rr, cc, tt] + p.regionimports[rr, cc, tt] - p.regionexports[rr, cc, tt]
            v.domesticrevenue[rr, cc, tt] = p.domestic_prices[rr, cc] * (v.available[rr, cc, tt] - p.internationalsales[rr, cc, tt])
            v.internationalrevenue[rr, cc, tt] = p.international_prices[rr, cc] * p.internationalsales[rr, cc, tt]
        end
    end
end

"""
Add a market component to the model.
"""
function initmarket(m::Model)
    market = addcomponent(m, Market)
    prices=[3.65,5.25,5.25,8.80,11.7,5.6,5.6,124/200] #Colorado 2010 Value 0.0722
-    #barley, corn rainfed, corn irrigated, sorghum, soybeans, wheat rain, wheat irri, hay
    #prices = crop_information(allcrops, crop_prices, 0, warnonmiss=true)

    market[:produced] = repeat([0.], outer=[m.indices_counts[:regions], m.indices_counts[:allcrops], m.indices_counts[:time]])
    market[:domestic_prices] = repeat(transpose(prices), outer=[m.indices_counts[:regions], 1])
    market[:international_prices] = repeat(transpose(prices / 2), outer=[m.indices_counts[:regions], 1])
    market[:internationalsales] = zeros(numcounties, numallcrops, numsteps)
    market[:regionimports] = zeros(numcounties, numallcrops, numsteps)
    market[:regionexports] = zeros(numcounties, numallcrops, numsteps)

    market
end

function grad_market_available_regionimports(m::Model)
    roomdiagonal(m, :Market, :available, :regionimports, (rr, cc, tt) -> 1.)
end

function grad_market_available_regionexports(m::Model)
    roomdiagonal(m, :Market, :available, :regionexports, (rr, cc, tt) -> -1.)
end

function grad_market_available_produced(m::Model)
    roomdiagonal(m, :Market, :available, :produced, (rr, cc, tt) -> 1.)
end

function grad_market_available_internationalsales(m::Model)
    roomdiagonal(m, :Market, :available, :internationalsales, (rr, cc, tt) -> -1.)
end

function deriv_market_totalrevenue_produced(m::Model)
    gen(rr, cc, tt) = m.parameters[:domestic_prices].values[rr, cc]
    hallsingle(m, :Market, :produced, gen)
end

function deriv_market_totalrevenue_internationalsales(m::Model)
    gen(rr, cc, tt) = -m.parameters[:domestic_prices].values[rr, cc] + m.parameters[:international_prices].values[rr, cc]
    hallsingle(m, :Market, :internationalsales, gen)
end

function grad_market_domesticbalance_available(m::Model)
    roomdiagonal(m, :Market, :domesticbalance, :available, (rr, cc, tt) -> 1.)
end
