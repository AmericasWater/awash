# The reservoir component
#
# Manages the storage in reservoirs over time
using Mimi
using Distributions

@defcomp Reservoir begin
    regions = Index()

    # Streamflow connnections
    inflows = Parameter(index=[regions, time])
    outflows = Parameter(index=[regions, time])

    # Municipality connections
    withdrawal = Parameter(index=[regions, time])

    # Evaporation
    evaporation = Parameter(index=[regions,time])

    # Storage
    storage = Variable(index=[regions, time])
    storage0 = Parameter(index=[regions])
    storagecapacitymin = Parameter(index=[regions])
    storagecapacitymax = Parameter(index=[regions])
end

"""
Compute the storage for the reservoirs as they change in time
"""
function timestep(c::Reservoir, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions
    if tt==1
        for rr in d.regions
          v.storage[rr,tt] = (1-p.evaporation[rr,tt])*p.storage0[rr] + sum(p.withdrawal[rr,tt]) + p.inflows[rr,tt] - p.outflows[rr,tt] ### by LJ - temporary
        end
    else
      for rr in d.regions
        v.storage[rr,tt] = (1-p.evaporation[rr,tt])*v.storage[rr,tt-1] + sum(p.withdrawal[rr,tt]) + p.inflows[rr,tt] - p.outflows[rr,tt] ### by LJ - temporary
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

function initreservoir(m::Model)
    reservoir = addcomponent(m, Reservoir)
    Ainf = rand(Normal(5e5, 7e4), m.indices_counts[:regions]*m.indices_counts[:time]);
    Aout = rand(Normal(5e5, 7e4), m.indices_counts[:regions]*m.indices_counts[:time]);
    reservoir[:inflows] = reshape(Ainf,m.indices_counts[:regions],m.indices_counts[:time]);
    reservoir[:outflows] = reshape(Ainf,m.indices_counts[:regions],m.indices_counts[:time]);
    reservoir[:withdrawal] = repeat(0*rand(LogNormal(log(50.0), log(10.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    rcmax = rand(Normal(3e6,4e5), m.indices_counts[:regions])
    reservoir[:storagecapacitymax] = rcmax;
    reservoir[:storagecapacitymin] = 0.1*rcmax;
    reservoir[:storage0] = 0.75*rcmax; #initial storate value: 3/4 max capacity
    reservoir[:evaporation] = 0.01*ones(m.indices_counts[:regions],m.indices_counts[:time]);
    reservoir
end
