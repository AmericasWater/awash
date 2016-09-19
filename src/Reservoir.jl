# The reservoir component
#
# Manages the storage in reservoirs over time
using Mimi
using Distributions

reservoirdata=readtable(datapath("reservoirs/allreservoirs.csv"))

@defcomp Reservoir begin
    reservoirs = Index()
    gauges = Index()
    # Streamflow connections from optim
    inflowsgauges = Parameter(index=[gauges, time], unit="1000 m^3")
    captures = Parameter(index=[reservoirs, time], unit="1000 m^3") # positive or negative
    # Reservoir inflows
    inflows = Variable(index=[reservoirs, time], unit="m^3")
    # releases = inflows - captures
    releases = Variable(index=[reservoirs, time], unit="m^3")

    # Evaporation
    evaporation = Parameter(index=[reservoirs, time], unit="m^3")

    # Storage
    storage = Variable(index=[reservoirs, time], unit="m^3")
    storage0 = Parameter(index=[reservoirs], unit="m^3")
    storagecapacitymin = Parameter(index=[reservoirs], unit="m^3")
    storagecapacitymax = Parameter(index=[reservoirs], unit="m^3")
end

"""
Compute the storage for the reservoirs as they change in time
"""
function run_timestep(c::Reservoir, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions
    if tt==1
        for rr in d.reservoirs
            v.releases[rr, tt] = p.inflows[rr,tt] - p.captures[rr, tt]
	    v.storage[rr,tt] = (1-p.evaporation[rr,tt])^config["timestep"]*p.storage0[rr] + p.captures[rr, tt]
        end
    else
        for rr in d.reservoirs
            v.releases[rr, tt] = p.inflows[rr,tt] - p.captures[rr, tt]
	    v.storage[rr,tt] = (1-p.evaporation[rr,tt])^config["timestep"]*v.storage[rr,tt-1] + p.captures[rr, tt]
        end
    end
end

function makeconstraintresmin(rr, tt)
    function constraint(model)
       -m[:Reservoir, :storage][rr, tt] + m.components[:Reservoir].Parameters.storagecapacitymin[rr]
    end
end

function makeconstraintresmax(rr, tt)
    function constraint(model)
       m[:Reservoir, :storage][rr, tt] - m.components[:Reservoir].Parameters.storagecapacitymax[rr] #
    end
end

function initreservoir(m::Model, name=nothing)
    if name == nothing
        reservoir = addcomponent(m, Reservoir)
    else
        reservoir = addcomponent(m, Reservoir, name)
    end

    reservoir[:captures] = cached_fallback("extraction/captures$suffix", () -> zeros(m.indices_counts[:reservoirs], m.indices_counts[:time]));


    if config["netset"] == "three"
        reservoir[:storagecapacitymax] = 8.2*ones(numreservoirs)
        reservoir[:storagecapacitymin] = 0.5*ones(numreservoirs)
        reservoir[:storage0] = 1.3*ones(numreservoirs)
        reservoir[:evaporation] = 0.01*ones(numreservoirs, numsteps)
    else
        rcmax = convert(Vector{Float64}, reservoirdata[:MAXCAP])
        rcmax = rcmax*1233.48
        reservoir[:storagecapacitymax] = rcmax;
        reservoir[:storagecapacitymin] = 0.1*rcmax;
        reservoir[:storage0] = (rcmax-0.1*rcmax)/2; #initial storate value: (max-min)/2
	reservoir[:evaporation] = 0.01*ones(m.indices_counts[:reservoirs],m.indices_counts[:time]);
    end
    reservoir
end

function grad_reservoir_outflows_captures(m::Model)
    function generate(A, tt)
        # Fill in GAUGES x RESERVOIRS matrix
        # Propogate in downstream order
        for hh in 1:numgauges
            gg = vertex_index(downstreamorder[hh])
            gauge = downstreamorder[hh].label
            for upstream in out_neighbors(wateridverts[gauge], waternet)
                index = vertex_index(upstream, waternet)
                println(index)
                if isreservoir[index] > 0
                    A[gg, isreservoir[index]] = -1
                else
                    A[gg, :] += A[index, :]
                end
            end
        end
    end
    roomintersect(m, :WaterNetwork, :outflows, :Reservoir, :captures, generate)
end

function grad_reservoir_storage_captures(m::Model)
    roomsingle(m, :Reservoir, :storage, :captures, (vrr, vtt, prr, ptt) -> (1-m.parameters[:evaporation].values[prr])^(vtt-ptt) * ((vrr == prr) && (vtt >= ptt)))
end

function constraintoffset_reservoir_storagecapacitymin(m::Model)
    gen(rr, tt) = m.parameters[:storagecapacitymin].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end

function constraintoffset_reservoir_storagecapacitymax(m::Model)
    gen(rr, tt) = m.parameters[:storagecapacitymax].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end

function constraintoffset_reservoir_storage0(m::Model)
    gen(rr, tt) = (1-m.parameters[:evaporation].values[rr])^(tt-1) * m.parameters[:storage0].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end

