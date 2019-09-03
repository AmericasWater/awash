# Agriculture Market Component
#
# Determines the available resource for consumption, as a balance
# between local production, imports, and exports.

using Mimi

@defcomp Market begin
    regions = Index()
    allcrops = Index()
    scenarios = Index()

    # Configuration
    # Selling prices
    domestic_prices = Parameter(index=[regions, allcrops], unit="\$/lborbu")
    international_prices = Parameter(index=[regions, allcrops], unit="\$/lborbu")

    # Optimized
    internationalsales = Parameter(index=[regions, allcrops, scenarios, time], unit="lborbu")

    # External
    # Local production from Agriculture
    produced = Parameter(index=[regions, allcrops, scenarios, time], unit="lborbu")

    # Imports and exports from Transportation
    regionimports = Parameter(index=[regions, allcrops, scenarios, time], unit="lborbu")
    regionexports = Parameter(index=[regions, allcrops, scenarios, time], unit="lborbu")

    # How much domestic buy if available
    domestic_interest = Parameter(index=[regions, allcrops, time], unit="lborbu")

    # Internal

    # The balance of available resource
    available = Variable(index=[regions, allcrops, scenarios, time], unit="lborbu")

    # Remaining after international are sold
    domesticbalance = Variable(index=[regions, allcrops, scenarios, time], unit="lborbu")

    # Total revenue from selling all available
    domesticrevenue = Variable(index=[regions, allcrops, scenarios, time], unit="\$")
    internationalrevenue = Variable(index=[regions, allcrops, scenarios, time], unit="\$")

    """
    Compute the available local resource for consumption, `available`.
    """
    function run_timestep(p, v, d, tt)
        for rr in d.regions
            for cc in d.allcrops
                v.available[rr, cc, :, tt] = p.produced[rr, cc, :, tt] + p.regionimports[rr, cc, :, tt] - p.regionexports[rr, cc, :, tt]
                v.domesticrevenue[rr, cc, :, tt] = p.domestic_prices[rr, cc] * (v.available[rr, cc, :, tt] - p.internationalsales[rr, cc, :, tt])
                v.internationalrevenue[rr, cc, :, tt] = p.international_prices[rr, cc] * p.internationalsales[rr, cc, :, tt]
            end
        end
    end
end

"""
Add a market component to the model.
"""
function initmarket(m::Model)
    market = add_comp!(m, Market)
    if config["filterstate"]=="08"
        prices=[3.65,5.25,5.25,8.80,11.7,5.6,5.6,124]
    else
        prices = crop_information(allcrops, crop_prices, 0, warnonmiss=true)
    end

    market[:produced] = repeat([0.], outer=[dim_count(m, :regions), dim_count(m, :allcrops), numscenarios, dim_count(m, :time)])
    market[:domestic_prices] = repeat(transpose(prices), outer=[dim_count(m, :regions), 1])
    market[:domestic_interest] = zeros(numcounties, numallcrops, numsteps)
    market[:international_prices] = repeat(transpose(prices / 2), outer=[dim_count(m, :regions), 1])
    market[:internationalsales] = zeros(numcounties, numallcrops, numscenarios, numsteps)
    market[:regionimports] = zeros(numcounties, numallcrops, numscenarios, numsteps)
    market[:regionexports] = zeros(numcounties, numallcrops, numscenarios, numsteps)

    market
end

function grad_market_available_regionimports(m::Model)
    roomdiagonal(m, :Market, :available, :regionimports, 1.)
end

function grad_market_available_regionexports(m::Model)
    roomdiagonal(m, :Market, :available, :regionexports, -1.)
end

function grad_market_available_produced(m::Model)
    roomdiagonal(m, :Market, :available, :produced, 1.)
end

function grad_market_available_internationalsales(m::Model)
    roomdiagonal(m, :Market, :available, :internationalsales, -1.)
end

function deriv_market_totalrevenue_produced(m::Model)
    gen(rr, cc) = m.md.external_params[:domestic_prices].values[rr, cc]
    hallsingle(m, :Market, :produced, gen, [:scenarios, :time])
end

function deriv_market_totalrevenue_internationalsales(m::Model)
    gen(rr, cc) = -m.md.external_params[:domestic_prices].values[rr, cc] + m.md.external_params[:international_prices].values[rr, cc]
    hallsingle(m, :Market, :internationalsales, gen, [:scenarios, :time])
end

function grad_market_domesticbalance_available(m::Model)
    roomdiagonal(m, :Market, :domesticbalance, :available, 1.)
end
