# The transporation component
#
# Each region is linked to other regions, accoring to the `regionnet`.  This
# component determines the total imports and exports for each region, based on the
# transport on each edge.

using Mimi

volume_per_bushel = 0.0352391 # m^3
density_hay = .25 # MT / m^3
mt_per_pound = 1 / 2205.

volume_per_unit = [mt_per_pound / density_hay, # Lb alfalfa
                   mt_per_pound / density_hay, # Lb otherhay
                   volume_per_bushel, # Bu barley
                   volume_per_bushel, # Bu barley.winter
                   volume_per_bushel, # Bu maize
                   mt_per_pound / density_hay, # Lb sorghum
                   volume_per_bushel, # Bu soybeans
                   volume_per_bushel, # Bu wheat
                   volume_per_bushel] # Bu wheat.winter

@defcomp Transportation begin
    regions = Index()
    edges = Index()
    crops = Index()

    # Internal
    # Cost per unit for transportation on a given edge
    cost_edge = Parameter(index=[edges, time], unit="\$/m^3")

    # Optimized
    # Amount of resource imported on each link
    imported = Parameter(index=[edges, crops, time], unit="lborbu")

    # The costs for each edge"s transportation
    cost = Variable(index=[edges, crops, time], unit="\$")

    # The total imported to and exported from each region
    regionimports = Variable(index=[regions, crops, time], unit="lborbu")
    regionexports = Variable(index=[regions, crops, time], unit="lborbu")
end

"""
Compute the amount imported and exported by region.
"""
function run_timestep(c::Transportation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    # Costs are easy: just resource imported * cost-per-unit
    for ee in d.edges
        for cc in d.crops
            v.cost[ee, cc, tt] = p.imported[ee, cc, tt] * p.cost_edge[ee, tt]
        end
    end

    for cc in d.crops
        for ii in d.regions
            v.regionexports[ii, cc, tt] = 0.0
        end

        # Sum over all edges for each region to translate to region-basis
        edge1 = 1
        for ii in d.regions
            # Get the number of edges this county imports from
            numneighbors = out_degree(regverts[mastercounties[ii, :fips]], regionnet)

            # Sum over all *out-edges* to get import
            v.regionimports[ii, cc, tt] = sum(p.imported[edge1:edge1 + numneighbors - 1, cc, tt])

            # Sum over the edges that have this as an out-edge
            sources = get(sourceiis, ii, Int64[])
            for source in sources
                if source > 0
                    v.regionexports[source, cc, tt] += p.imported[edge1, cc, tt]
                end
                edge1 += 1 # length(sources) == numneighbors
            end
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

    # 40' container = 76.5 m^3
    # Average rate is $1.58 per mile
    # Distance from SF to NYC is 2906 miles
    # Counties crossed is .5 X X = 3121 = 79
    # Average distance between counties = 37 mile
    # Average cost is 0.76 / m^3
    transit[:cost_edge] = repmat([.76], m.indices_counts[:edges], m.indices_counts[:time])

    transit[:imported] = repeat([0.], outer=[m.indices_counts[:edges], m.indices_counts[:crops], m.indices_counts[:time]])

    transit
end

# row: variables, col = parameters
function grad_transportation_regionimports_imported(m::Model)
    function generate(A, cc, tt)
        # Sum over all edges for each region to translate to region-basis
        edge1 = 1
        for ii in 1:numcounties
            # Get the number of edges this county imports from
            numneighbors = out_degree(regverts[mastercounties[ii, :fips]], regionnet)

            # Sum over all *out-edges* to get import
            for jj in edge1:edge1 + numneighbors - 1
                A[ii, jj] = 1
            end
            edge1 += numneighbors
        end
    end

    roomintersect(m, :Transportation, :regionimports, :imported, generate)
end

# row: variables, col = parameters
function grad_transportation_regionexports_imported(m::Model)
    function generate(A, cc, tt)
        # Sum over all edges for each region to translate to region-basis
        edge1 = 1
        for ii in 1:numcounties
            # Sum over the edges that have this as an out-edge
            sources = get(sourceiis, ii, Int64[])
            for source in sources
                A[source, edge1] = 1
                edge1 += 1 # length(sources) == numneighbors
            end
        end
    end

    roomintersect(m, :Transportation, :regionexports, :imported, generate)
end

function grad_transportation_cost_imported(m::Model)
    gen(ee, cc, tt) = m.parameters[:cost_edge].values[ee, tt] * volume_per_unit[cc]
    roomdiagonal(m, :Transportation, :cost, :imported, gen)
end
