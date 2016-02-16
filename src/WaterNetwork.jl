# The water network component
#
# This component passes water between the reservoirs through the connectivity matrix.

using Mimi
using Distributions

@defcomp WaterNetwork begin
    reservoirs = Index()
    edges = Index()

    # Set by optimiation
    # Amount of water sent through each edge
    streamflow = Parameter(index=[edges, time])

    # The total imported to and exported from each region
    inflows = Variable(index=[reservoirs, time])
    outflows = Variable(index=[reservoirs, time])
end

"""
Compute the amount imported and exported by region.
"""
function timestep(c::WaterNetwork, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # TODO
end

"""
Add a waternetwork component to the model.
"""
function initwaternetwork(m::Model)
    transit = addcomponent(m, WaterNetwork)

    transit
end

"Default import is 0"
default_imported(m::Model) = zeros(m.indices_counts[:edges], m.indices_counts[:time])

