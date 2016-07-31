# The reservoir component
#
# Manages the storage in reservoirs over time
using Mimi
using Distributions

reservoirdata=readtable(datapath("reservoirs/allreservoirs.csv"))

@defcomp Reservoir begin
    reservoirs = Index()

    # Streamflow connnections
    inflows = Parameter(index=[reservoirs, time], unit="m^3")
    captures = Parameter(index=[reservoirs, time], unit="m^3") # positive or negative
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
            v.storage[rr,tt] = (1-p.evaporation[rr,tt])*p.storage0[rr] + p.captures[rr, tt]
        end
    else
        for rr in d.reservoirs
            v.releases[rr, tt] = p.inflows[rr,tt] - p.captures[rr, tt]
            v.storage[rr,tt] = (1-p.evaporation[rr,tt])*v.storage[rr,tt-1] + p.captures[rr, tt]
        end
    end
end

function makeconstraintresmin(rr, tt)
    function constraint(model)
       -m[:Reservoir, :storage][rr, tt] + m.components[:Reservoir].Parameters.storagecapacitymin[rr] # piezohead > layerthick
    end
end
function makeconstraintresmax(rr, tt)
    function constraint(model)
       m[:Reservoir, :storage][rr, tt] - m.components[:Reservoir].Parameters.storagecapacitymax[rr] # piezohead > layerthick
    end
end

function initreservoir(m::Model, name=nothing)
    if name == nothing
        reservoir = addcomponent(m, Reservoir)
    else
        reservoir = addcomponent(m, Reservoir, name)
    end

    Ainf = rand(Normal(5e5, 7e4), m.indices_counts[:reservoirs]*m.indices_counts[:time]);
    Aout = rand(Normal(5e5, 7e4), m.indices_counts[:reservoirs]*m.indices_counts[:time]);
    reservoir[:inflows] = reshape(Ainf,m.indices_counts[:reservoirs],m.indices_counts[:time]);
    reservoir[:captures] = zeros(m.indices_counts[:reservoirs],m.indices_counts[:time]);

    if config["netset"] == "three"
        reservoir[:storagecapacitymax] = ones(numreservoirs) * Inf
        reservoir[:storagecapacitymin] = zeros(numreservoirs)
        reservoir[:storage0] = zeros(numreservoirs)
        reservoir[:evaporation] = zeros(numreservoirs, numsteps)
    else
        rcmax = repeat(convert(Vector{Float64}, reservoirdata[:MAXCAP]), outer=[1, numtimes])
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
    roomsingle(m, :Reservoir, :storage, :captures, (vrr, vtt, prr, ptt) -> 1. * ((vrr == prr) && (vtt >= ptt)))
end

function constraintoffset_reservoir_storagecapacitymin(m::Model)
    gen(rr, tt) = m.parameters[:storagecapacitymin].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end

function constraintoffset_reservoir_storagecapacitymax(m::Model)
    gen(rr, tt) = m.parameters[:storagecapacitymax].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end
