# The transporation component
#
# Each region is linked to other regions, accoring to the `regionnet`.  This
# component determines the total imports and exports for each region, based on the
# transport on each edge.

using Mimi
using Distributions

@defcomp Transportation begin
    regions = Index()
    edges = Index()

    # Internal
    # Cost per unit for transportation on a given edge
    cost_edge = Parameter(index=[edges, time])

    # Set by optimiation
    # Amount of resource imported on each link
    imported = Parameter(index=[edges, time])

    # The costs for each edge's transportation
    cost = Variable(index=[edges, time])

    # The total imported to and exported from each region
    regionimports = Variable(index=[regions, time])
    regionexports = Variable(index=[regions, time])
end

"""
Compute the amount imported and exported by region.
"""
function timestep(c::Transportation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Costs are easy: just resource imported * cost-per-unit
    for ee in d.edges
        v.cost[ee, tt] = p.imported[ee, tt] * p.cost_edge[ee, tt]
    end

    # Sum over all edges for each region to translate to region-basis
    edge1 = 1
    for ii in d.regions
        # Get the number of edges this county imports from
        numneighbors = out_degree(regverts[names[ii]], regionnet)

        # Sum over all *out-edges* to get import
        v.regionimports[ii, tt] = sum(p.imported[edge1:edge1 + numneighbors - 1, tt])

        # Sum over the edges that have this as an out-edge
        v.regionexports[ii, tt] = 0.0
        sources = get(sourceiis, ii, Int64[])
        for source in sources
            v.regionexports[source, tt] += p.imported[edge1, tt]
            edge1 += 1 # length(sources) == numneighbors
        end
    end
end

"""
The objective of the transportation component is to minimize transport costs.
"""
function soleobjective_transportation(model::Model)
    sum(model[:Transportation, :cost])
end

"""
Add a transportation component to the model.
"""
function inittransportation(m::Model)
    transit = addcomponent(m, Transportation)

    # Transport costs by edge draw from a LogNormal
    transit[:cost_edge] = repeat(convert(Vector{MyNumeric}, rand(LogNormal(log(.1), .1), m.indices_counts[:edges])), outer=[1, m.indices_counts[:time]]);

    transit
end

"Default import is 0"
default_imported(m::Model) = zeros(m.indices_counts[:edges], m.indices_counts[:time])

