using Mimi
using Distributions

#include("world.jl")

@defcomp Watercost begin
    regions = Index()
    aquifers = Index()

    costgwlift = Parameter() #from Calvin
    depth = Parameter(index=[aquifers, time])
    costgw = Variable(index=[aquifers, time]) #to be passed to allocation
    costswpar = Parameter(index=[aquifers, time])
    costsw = Variable(index=[aquifers, time]) #to be passed to allocation

end

function timestep(c::Watercost, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for aa in d.aquifers
        v.costgw[aa, tt] = p.costgwlift * p.depth[aa, tt]
    end
    for rr in d.regions
        v.costsw[rr,tt] = p.costswpar[rr,tt]
    end
end

function initwatercost(m::Model)
    watercost = addcomponent(m, Watercost)
    watercost[:costgwlift] = 0.2/(43560*(0.305^4)) #in $/(m3*m of lift) || from Calvin $0.20/(af*ft) * 1af/43560ft^3 * (1ft/0.305m)^4
    watercost[:depth] = 100*ones(m.indices_counts[:aquifers],m.indices_counts[:time])#to be replaced by actual depth
    watercost[:costswpar] = 30.0/(43560*0.305^3) * ones(m.indices_counts[:regions],m.indices_counts[:time]) #in $/m3 || from Calvin $30/af * 1af/43560ft^3 * (1ft/0.305m)^3
    watercost
end
