# The economy component
#
# Determines the available resource for consumption, as a balance between local
# production, imports, and exports.

using Mimi

@defcomp Economy begin
    regions = Index()
    edges = Index()

    # External
    # Local production from Production
    produced = Parameter(index=[regions, time])
    # Imports and exports from Transportation
    regionimports = Parameter(index=[regions, time])
    regionexports = Parameter(index=[regions, time])

    # The balance of available resource
    marketed = Variable(index=[regions, time])
end

"""
Compute the available local resource for consumption, `marketed`.
"""
function timestep(c::Economy, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for rr in d.regions
        v.marketed[rr, tt] = p.produced[rr, tt] + p.regionimports[rr, tt] - p.regionexports[rr, tt]
    end
end
