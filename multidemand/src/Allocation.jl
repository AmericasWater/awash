using Mimi
using Distributions

@defcomp Allocation begin
    regions = Index()

    # Water demand
    waterdemandag = Parameter(index=[regions, time])
    waterdemanddom = Parameter(index=[regions, time])
    # Extracted water (m3) to be set by optimisation - super source represents failure.
    waterfromgwag = Parameter(index=[regions, time])
    waterfromreservoirag = Parameter(index=[regions,time])
    waterfromsupersourceag = Parameter(index=[regions,time])
    waterfromgwdom = Parameter(index=[regions, time])
    waterfromreservoirdom = Parameter(index=[regions,time])
    waterfromsupersourcedom = Parameter(index=[regions,time])
    watergw = Variable(index=[regions, time])
    waterreservoir = Variable(index=[regions,time])
    watersupersource = Variable(index=[regions,time])

    # Unit costs ($/m3)
    costfromgwag = Parameter(index=[regions,time])
    costfromreservoirag = Parameter(index=[regions,time])
    costfromgwdom = Parameter(index=[regions,time])
    costfromreservoirdom = Parameter(index=[regions,time])
    costfromsupersource = Parameter()
    costgwlift = Parameter()
    depth = Parameter(index=[regions, time])

    # Total cost and volumes for each county
    cost = Variable(index=[regions, time])
    waterallocateddom = Variable(index=[regions,time])
    waterallocatedag = Variable(index=[regions,time])

end

"""
Sums the water from various sources and computes the cost
"""
function timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for cty in d.regions
        #v.waterfromSuperSource[cty,tt]= p.waterdemand[cty,tt] - (p.waterfromGW[cty,tt]+p.waterfromreservoir[cty,tt])
        v.watergw[cty,tt] = p.waterfromgwag[cty,tt]+p.waterfromgwdom[cty,tt]
        v.waterreservoir[cty,tt] = p.waterfromreservoirag[cty,tt]+p.waterfromreservoirdom[cty,tt]
        v.watersupersource[cty,tt] = p.waterfromsupersourcedom[cty,tt]+p.waterfromsupersourceag[cty,tt]
        v.waterallocateddom[cty,tt] = p.waterfromgwdom[cty,tt] + p.waterfromreservoirdom[cty,tt] + p.waterfromsupersourcedom[cty,tt]
        v.waterallocatedag[cty,tt] = p.waterfromgwag[cty,tt] + p.waterfromreservoirag[cty,tt] + p.waterfromsupersourceag[cty,tt]
        v.cost[cty, tt] = p.waterfromgwdom[cty,tt]*p.costfromgwdom[cty,tt] +
                          p.waterfromgwag[cty,tt]*p.costfromgwag[cty,tt]+
                          p.waterfromreservoirag[cty,tt]*p.costfromreservoirag[cty,tt] +
                          p.waterfromreservoirdom[cty,tt]*p.costfromreservoirdom[cty,tt] +
                          (p.waterfromsupersourceag[cty,tt] + p.waterfromsupersourcedom[cty,tt])*p.costfromsupersource

    end
end

"""
Add a demand component to the model.
"""
function initallocation(m::Model)
    allocation = addcomponent(m, Allocation)
    # Use random demands, from a LogNormal distribution and constant across all
    # time.
    Adem = rand(Normal(5e4, 1e3), m.indices_counts[:regions]*m.indices_counts[:time]);
    allocation[:waterdemandag] = 100*reshape(Adem,m.indices_counts[:regions],m.indices_counts[:time]);
    allocation[:waterdemanddom] = 10*reshape(Adem,m.indices_counts[:regions],m.indices_counts[:time]);

    #demand[:waterdemand] = repeat(rand(LogNormal(log(1000.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    costgroundwater = 0.12*ones(m.indices_counts[:regions],m.indices_counts[:time])#((1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromgwdom] = costgroundwater#(1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromreservoirdom] = 0.35*ones(m.indices_counts[:regions],m.indices_counts[:time])#(1/100)*repeat(rand(Normal(55, 3), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromgwag] = costgroundwater
    allocation[:costfromreservoirag] = 0.05*ones(m.indices_counts[:regions],m.indices_counts[:time])#(1/100)*repeat(rand(Uniform(2, 8), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100.0;

    allocation[:waterfromgwag] = repeat(rand(LogNormal(log(50.0), log(10.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromreservoirag] = repeat(rand(LogNormal(log(300.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromsupersourceag] = repeat(rand(LogNormal(log(500.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromgwdom] = repeat(rand(LogNormal(log(50.0), log(10.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromreservoirdom] = repeat(rand(LogNormal(log(300.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromsupersourcedom] = repeat(rand(LogNormal(log(500.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costgwlift] = 0.2/(43560*(0.305^4))
    allocation[:depth] = 80*ones(m.indices_counts[:regions],m.indices_counts[:time])
    allocation
end
"""
The objective is to minimize water allocation costs at all time
"""
function waterallocationobj(m::Model)
    -sum(m.components[:Allocation].Variables.cost)
end

function makeconstraintdemandmetag(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.waterdemandag[aa,tt] - m.components[:Allocation].Variables.waterallocatedag[aa,tt]
    end
end
function makeconstraintdemandmetdom(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.waterdemanddom[aa,tt] - m.components[:Allocation].Variables.waterallocateddom[aa,tt]
    end
end
