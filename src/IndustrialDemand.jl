## Industrial Demand Component
#
# Models water intensive industry not supplied by the public system

using Mimi
using DataFrames
include("lib/datastore.jl")

@defcomp IndustrialDemand begin
    regions = Index()
    scenarios = Index()

    # Industrial demand
    industrywaterdemand = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    miningwaterdemand = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    # Demanded water
    waterdemand = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    """
    The quantity of water demanded at each timestep
    """
    function run_timestep(p, v, d, tt)
        for rr in d.regions
            v.waterdemand[rr, :, tt] = p.industrywaterdemand[rr, :, tt] + p.miningwaterdemand[rr, :, tt]
        end
    end
end

"""
Add an industrial component to the model.
"""
function initindustrialdemand(m::Model)
    industrialdemand = add_comp!(m, IndustrialDemand);

    # data from USGS 2010 for the 2000 county definition
    recorded = knowndf("exogenous-withdrawals")
    industrialdemand[:industrywaterdemand] = repeat(convert(Vector, recorded[:,:IN_To]) * config["timestep"] * 1383. / 12., outer=[1, numscenarios, numsteps]);
    industrialdemand[:miningwaterdemand] = repeat(convert(Vector,recorded[:,:MI_To]) * config["timestep"] * 1383. / 12., outer=[1, numscenarios, numsteps]);
    industrialdemand
end

function constraintoffset_industrialdemand_waterdemand(m::Model)
    gen(rr, tt) = m.md.external_params[:miningwaterdemand].values[rr, tt] + m.md.external_params[:industrywaterdemand].values[rr,tt]
    hallsingle(m, :IndustrialDemand, :waterdemand, gen, [:scenarios])
end


