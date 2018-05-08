## Component computing the water stress indeces corresponding to various definitions from the litterature

using Mimi
using DataFrames


@defcomp WaterStressIndex begin
    regions = Index()
    gauges = Index()

    rechargegw = Parameter(index=[regions, time], unit="1000 m^3")
    inflowgauge = Parameter(index=[gauges, time], unit="1000 m^3")
    runoffgauge = Parameter(index=[gauges, time], unit="1000 m^3")
    environmentalfactor = Parameter(unit="none")
    withdrawalgw = Parameter(index=[regions, time], unit="1000 m^3")
    withdrawalsw = Parameter(index=[gauges, time], unit="1000 m^3")

    indexgw = Variable(index=[regions, time], unit="1000 m^3")
    indexsw = Variable(index=[gauges, time], unit="1000 m^3")
end

"""
Compute the amount extracted and the cost for doing it.
"""
function run_timestep(c::WaterStressIndex, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.indexgw[rr, tt] = p.withdrawalgw[rr, tt]/p.rechargegw[rr, tt]
    end

    for gg in d.gauges
        v.indexsw[gg, tt] = p.withdrawalsw[gg, tt]/(p.inflowgauge[gg, tt]+p.runoffgauge[gg, tt])
    end
end

"""
Add a WaterStressIndex component to the model.
"""
function initwaterstressindex(m::Model)
    waterstressindex = addcomponent(m, WaterStressIndex);

    waterstressindex[:runoffgauge] = addeds[:, 1:numsteps]
    waterstressindex[:rechargegw] = recharge;
    waterstressindex
end

