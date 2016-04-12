# The market component
#
# Determines the available resource for consumption, as a balance between local
# production, imports, and exports.

using Mimi

@defcomp Market begin
    regions = Index()
    crops = Index()

    # Configuration
    # Selling prices
    domestic_prices = Parameter(index=[regions, crops, time])
    international_prices = Parameter(index=[regions, crops, time])

    # Optimized
    internationalsales = Parameter(index=[regions, crops, time])

    # External
    # Local production from Agriculture
    produced = Parameter(index=[regions, crops, time])

    # Imports and exports from Transportation
    regionimports = Parameter(index=[regions, crops, time])
    regionexports = Parameter(index=[regions, crops, time])

    # How much domestic buy if available
    domestic_interest = Parameter(index=[regions, crops, time])

    # Internal

    # The balance of available resource
    available = Variable(index=[regions, crops, time])

    # Remaining after international are sold
    domesticbalance = Variable(index=[regions, crops, time])

    # Total revenue from selling all available
    domesticrevenue = Variable(index=[regions, crops, time])
    internationalrevenue = Variable(index=[regions, crops, time])
end

"""
Compute the available local resource for consumption, `available`.
"""
function timestep(c::Market, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        for cc in d.crops
            v.available[rr, cc, tt] = p.produced[rr, cc, tt] + p.regionimports[rr, cc, tt] - p.regionexports[rr, cc, tt]
            v.domestic_revenue[rr, cc, tt] = p.domestic_prices[rr, cc, tt] * (v.available[rr, cc, tt] - p.internationalsales[rr, cc, tt])
            v.international_revenue[rr, cc, tt] = p.international_prices[rr, cc, tt] * p.internationalsales[rr, cc, tt]
        end
    end
end

"""
Add a market component to the model.
"""
function initmarket(m::Model)
    market = addcomponent(m, Market)

    prices = [102.51 / 2204.62, # alfalfa
              102.51 / 2204.62, # otherhay
              120.12 * .021772, # barley
              120.12 * .021772, # barley.winter
              160.63 * .0254, # maize
              174.90 * .0254, # sorghum
              349.52 * .0272155, # soybeans
              5.1675, # wheat
              171.50 * .0272155] # wheat.winter

    market[:produced] = repeat([0.], outer=[m.indices_counts[:regions], m.indices_counts[:crops], m.indices_counts[:time]])
    market[:domestic_prices] = repeat(transpose(prices), outer=[m.indices_counts[:regions], 1, m.indices_counts[:time]])
    market[:international_prices] = repeat(transpose(prices / 2), outer=[m.indices_counts[:regions], 1, m.indices_counts[:time]])
    market[:internationalsales] = zeros(numcounties, numcrops, numsteps)
    market[:regionimports] = zeros(numcounties, numcrops, numsteps)
    market[:regionexports] = zeros(numcounties, numcrops, numsteps)

    market
end

function grad_market_regionimports_available(m::Model)
    roomdiagonal(m, :Market, :available, :regionimports, (rr, cc, tt) -> 1.)
end

function grad_market_regionexports_available(m::Model)
    roomdiagonal(m, :Market, :available, :regionexports, (rr, cc, tt) -> -1.)
end

function grad_market_produced_available(m::Model)
    roomdiagonal(m, :Market, :available, :produced, (rr, cc, tt) -> 1.)
end

function grad_market_internationalsales_available(m::Model)
    roomdiagonal(m, :Market, :available, :internationalsales, (rr, cc, tt) -> -1.)
end

function deriv_market_produced_totalrevenue(m::Model)
    gen(rr, cc, tt) = m.parameters[:domestic_prices].values[rr, cc, tt]
    hallsingle(m, :Market, :produced, gen)
end

function deriv_market_internationalsales_totalrevenue(m::Model)
    gen(rr, cc, tt) = -m.parameters[:domestic_prices].values[rr, cc, tt] + m.parameters[:international_prices].values[rr, cc, tt]
    hallsingle(m, :Market, :internationalsales, gen)
end

function grad_market_available_domesticbalance(m::Model)
    roomdiagonal(m, :Market, :domesticbalance, :available, (rr, cc, tt) -> 1.)
end
