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
    domestic_prices = Parameter(index=[regions, crops], unit="\$/lborbu")
    international_prices = Parameter(index=[regions, crops], unit="\$/lborbu")

    # Optimized
    internationalsales = Parameter(index=[regions, crops, time], unit="lborbu")

    # External
    # Local production from Agriculture
    produced = Parameter(index=[regions, crops, time], unit="lborbu")

    # Imports and exports from Transportation
    regionimports = Parameter(index=[regions, crops, time], unit="lborbu")
    regionexports = Parameter(index=[regions, crops, time], unit="lborbu")

    # How much domestic buy if available
    domestic_interest = Parameter(index=[regions, crops, time], unit="lborbu")

    # Internal

    # The balance of available resource
    available = Variable(index=[regions, crops, time], unit="lborbu")

    # Remaining after international are sold
    domesticbalance = Variable(index=[regions, crops, time], unit="lborbu")

    # Total revenue from selling all available
    domesticrevenue = Variable(index=[regions, crops, time], unit="\$")
    internationalrevenue = Variable(index=[regions, crops, time], unit="\$")
end

"""
Compute the available local resource for consumption, `available`.
"""
function run_timestep(c::Market, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        for cc in d.crops
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

    prices = [102.51 / 2204.62, # alfalfa
              102.51 / 2204.62, # otherhay
              120.12 * .021772, # barley
              120.12 * .021772, # barley.winter
              160.63 * .0254, # maize
              174.90 / 2204.62, # sorghum: $/MT / lb/MT
              349.52 * .0272155, # soybeans
              5.1675, # wheat
              171.50 * .0272155] # wheat.winter

    market[:produced] = repeat([0.], outer=[m.indices_counts[:regions], m.indices_counts[:crops], m.indices_counts[:time]])
    market[:domestic_prices] = repeat(transpose(prices), outer=[m.indices_counts[:regions], 1])
    market[:international_prices] = repeat(transpose(prices / 2), outer=[m.indices_counts[:regions], 1])
    market[:internationalsales] = zeros(numcounties, numcrops, numsteps)
    market[:regionimports] = zeros(numcounties, numcrops, numsteps)
    market[:regionexports] = zeros(numcounties, numcrops, numsteps)

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
