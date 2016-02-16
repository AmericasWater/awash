# The reservoir component
#
# Manages the storage in reservoirs over time

using Mimi

@defcomp Reservoir begin
    reservoirs = Index()
    counties = Index()

    # Streamflow connnections
    inflows = Parameter(index=[reservoirs, time])
    outflows = Parameter(index=[reservoirs, time])

    # Municipality connections
    releases = Parameter(index=[counties, time])

    # Remaining storage
    storage = Variable(index=[reservoirs, time])
end

"""
Compute the storage for the reservoirs as they change in time
"""
function timestep(c::Reservoir, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.reservoirs
        # TODO
    end
end
