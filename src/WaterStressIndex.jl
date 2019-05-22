## Component computing the water stress indeces corresponding to various definitions from the litterature

using Mimi
using DataFrames


@defcomp WaterStressIndex begin
    regions = Index()
    gauges = Index()

    rechargegw = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    inflowgauge = Parameter(index=[gauges, scenarios, time], unit="1000 m^3")
    runoffgauge = Parameter(index=[gauges, scenarios, time], unit="1000 m^3")
    environmentalfactor = Parameter(unit="none")
    withdrawalgw = Parameter(index=[regions, scenarios, time], unit="1000 m^3")
    withdrawalsw = Parameter(index=[gauges, scenarios, time], unit="1000 m^3")
    withdrawalswregion = Parameter(index=[regions, scenarios, time], unit="1000 m^3")

    availabilityrunoffall = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    availabilityrunofflocal = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    availabilityinflowlocal = Variable(index=[regions, scenarios, time], unit="1000 m^3")

    indexgw = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    indexsw = Variable(index=[gauges, scenarios, time], unit="1000 m^3")

    indexWaSSli = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    indexWaSSI = Variable(index=[regions, scenarios, time], unit="1000 m^3")
    # indexWSI = Variable(index=[regions, time], unit="1000 m^3")

    """
    Compute the amount extracted and the cost for doing it.
    """
    function run_timestep(p, v, d, tt)
        for rr in d.regions
            v.indexgw[rr, :, tt] .= p.withdrawalgw[rr, :, tt]./p.rechargegw[rr, :, tt]
        end

        for gg in d.gauges
            v.indexsw[gg, :, tt] .= p.withdrawalsw[gg, :, tt]./(p.inflowgauge[gg, :, tt]+p.runoffgauge[gg, :, tt])
        end

        v.availabilityrunoffall[:,:,tt] .= zeros(numcounties, numscenarios)
        v.availabilityrunofflocal[:,:,tt] .= zeros(numcounties, numscenarios)
        v.availabilityinflowlocal[:,:,tt] .= zeros(numcounties, numscenarios)

        if config["dataset"] == "counties"
            for pp in 1:nrow(draws)
                gaugeid = draws[pp, :gaugeid]
                vertex = get(wateridverts, gaugeid, nothing)
                if vertex != nothing
                    gg = vertex_index(vertex)
                    regionids = regionindex(draws, pp)
                    rr = findfirst(regionindex(masterregions, :) .== regionids)
                    if rr != nothing
                        v.availabilityrunoffall[rr, :, tt] += p.runoffgauge[gg, :, tt]
                        if draws[pp, :justif] == "contains"
                            v.availabilityrunofflocal[rr, :, tt] += p.runoffgauge[gg, :, tt]

                            # Checking if the gauge is the last one
                            gauge = downstreamorder[gg].label
                            for upstream in out_neighbors(wateridverts[gauge], waternet)
                                for ii in findall(draws[:gaugeid] .== upstream.label)
                                    if draws[:justif][ii] == "contains"
                                        if draws[:fips][ii] != draws[:fips][pp]
                                            v.availabilityinflowlocal[rr, :, tt] += p.inflowgauge[gg, :, tt]
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        elseif config["dataset"] == "states"
            for pp in 1:nrow(draws)
                gaugeid = draws[pp, :gaugeid]
                vertex = get(wateridverts, gaugeid, nothing)
                if vertex != nothing
                    gg = vertex_index(vertex)
                    regionids = regionindex(draws, pp)
                    rr = findfirst(regionindex(masterregions, :) .== regionids)
                    if rr != nothing
                        v.availabilityrunoffall[rr, :, tt] += p.runoffgauge[gg, :, tt]
                        v.availabilityrunofflocal[rr, :, tt] += p.runoffgauge[gg, :, tt]

                        # Checking if the gauge is the last one
                        gauge = downstreamorder[gg].label
                        for upstream in out_neighbors(wateridverts[gauge], waternet)
                            for ii in findall(draws[:gaugeid] .== upstream.label)
                                if draws[:state][ii] != draws[:state][pp]
                                    v.availabilityinflowlocal[rr, :, tt] += p.inflowgauge[gg, :, tt]
                                end
                            end
                        end
                    end
                end
            end
        end

        v.indexWaSSli[:, :, tt] .= (p.withdrawalgw[:, :, tt] + p.withdrawalswregion[:, :, tt])./(v.availabilityrunofflocal[:, :, tt] + v.availabilityinflowlocal[:, :, tt] + p.rechargegw[:, :, tt])
        v.indexWaSSI[:, :, tt] .= (p.withdrawalgw[:, :, tt] + p.withdrawalswregion[:, :, tt])./((1.-p.environmentalfactor[:, :, tt]).*(v.availabilityrunofflocal[:, :, tt] + v.availabilityinflowlocal[:, :, tt]) + p.rechargegw[:, :, tt])
        # v.indexWSI = 1./(1+exp(-6.4*v.withdrawalgw + v.withdrawalswregion)./(v.availabilityrunofflocal + v.availabilityinflowlocal + p.rechargegw)

    end
end

"""
Add a WaterStressIndex component to the model.
"""
function initwaterstressindex(m::Model)
    waterstressindex = add_comp!(m, WaterStressIndex);

    waterstressindex[:runoffgauge] = addeds[:, :, 1:numsteps]
    waterstressindex[:rechargegw] = recharge;
    waterstressindex[:environmentalfactor] = 0.37; #conservative estimate: 37% annual flow, 50% annual flow. source: doi:10.1088/1748-9326/aa51dc

    waterstressindex
end
