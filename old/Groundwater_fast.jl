# The groundwater component
#
# Manages the groundwater level over time, watch out for conductivity units and needs connectivity matrix !

using Mimi
using Distributions


@defcomp Aquifer begin
  aquifers = Index()

  #fips indices
  fips = Parameter(index=[aquifers])

  # Aquifer description
  layerthick = Parameter(index=[aquifers])
  depthaquif = Parameter(index=[aquifers])
  elevation = Parameter(index=[aquifers])
  areaaquif = Parameter(index=[aquifers])
  storagecoef = Parameter(index=[aquifers])
  piezohead0 = Parameter(index=[aquifers]) # used both for t=1, but also to have gw costs proportional to head
  meandepth = Variable(index=[aquifers, time])
  # Recharge
  recharge = Parameter(index=[aquifers, time])

  # Withdrawalssetindex(m, :edges, collect(1:3)) ##### TO BE OPTIMISED !!!!!
  withdrawal = Parameter(index=[aquifers, time])

  # Lateral flows
  lateralflows = Variable(index=[aquifers, time])
  aquiferconnexion = Parameter(index=[aquifers, aquifers]) #indicator : aquiferconnexion[aa,aa']=1 -> they are connected, 0 otherwise.
  lateralconductivity = Parameter(index=[aquifers, aquifers])

  # Piezometric head
  piezohead = Variable(index=[aquifers, time])
end

"""
Compute the piezometric head for each reservoirs and the lateral flows between adjacent aquifers
"""
function timestep(c::Aquifer, tt::Int)
  v = c.Variables
  p = c.Parameters
  d = c.Dimensions

  # computation of lateral flows:
  v.lateralflows[:,tt]=zeros(d.aquifers[end],1)
  v.meandepth[:,tt] = p.elevation[:] - p.piezohead0[:]

  if tt==1
    v.piezohead[:,tt] = p.piezohead0[:]
     v.lateralflows[:,tt] = sum((p.aquiferconnexion.*p.lateralconductivity).*(repeat(p.piezohead0[:],outer=[1,m.indices_counts[:aquifers]])-repeat(p.piezohead0[:],outer=[1,m.indices_counts[:aquifers]])'),1)


  else
    v.piezohead[:,tt] = v.piezohead[:,tt-1] + 1./(p.storagecoef[:].*p.areaaquif[:]).*(p.recharge[:,tt-1]-p.withdrawal[:,tt-1]+v.lateralflows[:,tt-1])
    v.lateralflows[:,tt] = sum((p.aquiferconnexion.*p.lateralconductivity).*(repeat(v.piezohead[:,tt],outer=[1,m.indices_counts[:aquifers]])-repeat(v.piezohead[:,tt],outer=[1,m.indices_counts[:aquifers]])'),1)
  end
end

"""
Add an Aquifer component to the model.
"""
function initaquiferfive(m::Model)
  aquifer = addcomponent(m, Aquifer)

  #five county test:
  aquifer[:layerthick] = [30.; 15.; 30.; 20.; 20.]#rand(Normal(30,5), m.indices_counts[:aquifers]);
  aquifer[:depthaquif] = [-100.; -90.; -100.; -80.; -80.]#rand(Normal(40,10), m.indices_counts[:aquifers]);
  aquifer[:storagecoef] = [5e-4; 5e-4; 5e-4; 5e-4; 5e-4];
  aquifer[:piezohead0] = [-55.; -45.; -53.; -33.; -35.];
  aquifer[:elevation] = [15.; 25.; 23.; 33.; 15.];
  aquifer[:areaaquif] = [8e8; 6e8; 5e8; 5e8; 3e8];

  aquifer[:withdrawal] = repeat(rand(Normal(190000,3700), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  aquifer[:recharge] = repeat(rand(Normal(240000,1000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);

  aquifer[:lateralconductivity] = 100*[0    1e-6 1e-4 1e-6 0   ;
                                   1e-6 0    0    1e-6 0   ;
                                   1e-4 0    0    1e-6 0
                                   1e-6 1e-6 1e-6 0    1e-3;
                                   0    0    0    1e-3 0   ];

  aquifer[:aquiferconnexion] = [ 1. 1. 1. 1. 0.; 1. 0 0 1. 0; 1. 0 0 1. 0; 1. 1. 1. 0 1.; 0 0 0 1. 0];
  aquifer

  #aquifer[:layerthick] = rand(Normal(30,5), m.indices_counts[:aquifers]);
  #aquifer[:depthaquif] = rand(Normal(40,10), m.indices_counts[:aquifers]);
  #aquifer[:areaaquif] = rand(Normal(1e9,1e4), m.indices_counts[:aquifers]);
  ##aquifer[:logconductivity] = rand(Normal(-4,1), m.indices_counts[:aquifers]);
  #aquifer[:storagecoef] = rand(Normal(1e-4,1e-5), m.indices_counts[:aquifers]);
  #aquifer[:withdrawal] = repeat(rand(Normal(2600000,10000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  #aquifer[:recharge] = repeat(rand(Normal(1500000,10000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);


end

function makeconstraintpiezomax(aa, tt)
    function constraint(model)
        m[:Aquifer, :piezohead][aa, tt] - m.components[:Aquifer].Parameters.elevation[aa] # piezohead < layerthick + depth (non-artesian well)
    end
end
function makeconstraintpiezomin(aa, tt)
    function constraint(model)
       -m[:Aquifer, :piezohead][aa, tt] + m.components[:Aquifer].Parameters.depthaquif[aa] # piezohead > layerthick
    end
end

function initaquifercontus(m::Model)
  aquifer = addcomponent(m, Aquifer)
  pwd()
  temp = readdlm("data/v_FIPS.txt")
  aquifer[:fips]= temp[:,1];
  temp = readdlm("data/aquifer_thickness.txt")
  aquifer[:layerthick] = temp[:,1];
  #temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/aquifer_depth.txt")
  aquifer[:depthaquif] = rand(Normal(-100,5), m.indices_counts[:aquifers])#temp[:,1];
  #temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/county_elecation.txt",Float64)
  aquifer[:elevation] = rand(Normal(30,5), m.indices_counts[:aquifers])#temp[:,1];
  #temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/vector_storativity.txt")
  aquifer[:storagecoef] = 1e-4*rand(Normal(5,1), m.indices_counts[:aquifers])#temp[:,1];
  #temp = readdlm
  aquifer[:piezohead0] = rand(Normal(-50,0.01), m.indices_counts[:aquifers])
  temp = readdlm("data/county_area.txt")
  aquifer[:areaaquif] = temp[:,1];
  Mtemp = repeat(rand(Normal(19000,1700), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  aquifer[:withdrawal] = Mtemp#repeat(rand(Normal(190000,3700), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  aquifer[:recharge] = Mtemp#repeat(rand(Normal(240000,1000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);

  temp = readdlm("data/matrix_leakage_factor.txt")
  aquifer[:lateralconductivity] = temp;
  temp = readdlm("data/connectivity_matrix.txt")
  aquifer[:aquiferconnexion] = temp;
  aquifer
end
