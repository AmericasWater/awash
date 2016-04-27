using Mimi
using Distributions

@defcomp Allocation begin
    regions = Index()
    # Water demand
    waterdemand = Parameter(index=[regions, time])
    # Extracted water (m3) to be set by optimisation - super source represents failure.
    waterfromgw = Parameter(index=[regions, time])
    waterfromsupersource = Parameter(index=[regions,time])
    watergw =Variable(index=[regions,time])
    # Unit costs ($/m3)
    costfromgw = Parameter(index=[regions,time])
    costfromsupersource = Parameter()
    # Total cost and volumes for each county
    cost = Variable(index=[regions, time])
    waterallocated = Variable(index=[regions,time])
end

"""
Sums the water from various sources and computes the cost
"""
function timestep(c::Allocation, tt::Int)
    v = c.Variables
    p = c.Parameters
    d = c.Dimensions

    for cty in d.regions
        v.watergw[cty,tt] = p.waterfromgw[cty,tt]
        v.waterallocated[cty,tt] = p.waterfromgw[cty,tt]+p.waterfromsupersource[cty,tt]
        v.cost[cty, tt] = p.waterfromgw[cty,tt]*p.costfromgw[cty,tt] + p.waterfromsupersource[cty,tt]*p.costfromsupersource
    end
end

"""
The objective is to minimize water allocation costs at all time
"""
function waterallocationobj(m::Model)
    -sum(m.components[:Allocation].Variables.cost)
end

function makeconstraintdemandmet(aa, tt)
    # The constraint function
    function constraint(model)
       m.components[:Allocation].Parameters.waterdemand[aa,tt] - m.components[:Allocation].Variables.waterallocated[aa,tt]
    end
end

"""
Add a demand component to the model.
"""
function initallocationcontus(m::Model)
    allocation = addcomponent(m, Allocation)
    v=collect(1:3109)
# Use random demands, from a LogNormal distribution and constant across all
    # time.
    #Adem = rand(Normal(5e4, 1e3), m.indices_counts[:regions]*m.indices_counts[:time]);
    demandirrigation = readdlm("../data/gw_irr_2010.txt");
    demandurban = readdlm("../data/gw_urban_2010.txt");
    demandmining = readdlm("../data/gw_mining_2010.txt");
    waterdemand = repeat(demandurban[v,2]+demandmining[v,2]+demandirrigation[v,2],outer=[1,m.indices_counts[:time]]);
    allocation[:waterdemand] = waterdemand[1:m.indices_counts[:regions],1:m.indices_counts[:time]];
    temp = readdlm("../data/piezohead0.txt");
    costgroundwater = repeat(0.2/(43560*(0.305^4))*(temp[v,1]), outer=[1, m.indices_counts[:time]]); # per m3 per m of lift * lift
    #((1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromgw] = costgroundwater#(1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100.0;


    allocation[:waterfromgw] = repeat(demandurban[v,2]+demandmining[v,2]+demandirrigation[v,2],outer=[1,m.indices_counts[:time]]);
    allocation[:waterfromsupersource] = repeat(0*rand(LogNormal(log(500.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation
end


function initallocation(m::Model)
    allocation = addcomponent(m, Allocation)
    # Use random demands, from a LogNormal distribution and constant across all
    # time.
    Adem = rand(Normal(5e4, 1e3), m.indices_counts[:regions]*m.indices_counts[:time]);
    allocation[:waterdemand] = reshape(Adem,m.indices_counts[:regions],m.indices_counts[:time]);
    #demand[:waterdemand] = repeat(rand(LogNormal(log(1000.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromgw] = (1/100)*repeat(rand(Normal(12.5, 1.5), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:costfromsupersource] = 100.0;
    allocation[:waterfromgw] = repeat(0*rand(LogNormal(log(50.0), log(10.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation[:waterfromsupersource] = repeat(0*rand(LogNormal(log(500.0), log(100.0)), m.indices_counts[:regions]),outer=[1, m.indices_counts[:time]]);
    allocation
end

