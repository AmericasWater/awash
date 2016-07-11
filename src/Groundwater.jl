# The groundwater component
#
# Manages the groundwater drawdowns over time

using Mimi
using Distributions
@defcomp Aquifer begin
  aquifers = Index()

  # Aquifer description
  depthaquif = Parameter(index=[aquifers], unit="1 m")
  areaaquif = Parameter(index=[aquifers], unit="1000 m^2")
  storagecoef = Parameter(index=[aquifers], unit="none")
  piezohead0 = Parameter(index=[aquifers], unit="1 m") # used for initialisation
  elevation = Parameter(index=[aquifers], unit="1 m")
  # Recharge
  recharge = Parameter(index=[aquifers, time], unit="1000 m^3")

  # Withdrawals - to be optimised
  withdrawal = Parameter(index=[aquifers, time], unit="1000 m^3")

  # Lateral flows
  lateralflows = Variable(index=[aquifers, time], unit="1000 m^3")
  aquiferconnexion = Parameter(index=[aquifers, aquifers], unit ="none") # aquiferconnexion[aa,aa']=1 -> aquifers are connected, 0 otherwise.
  lateralconductivity = Parameter(index=[aquifers, aquifers], unit="1 m^2/month") ## how should I specify per month per year?
  deltatime = Parameter(unit="month")

  # Piezometric head
  piezohead = Variable(index=[aquifers, time], unit="1 m")

  # Unit volume cost
  volumetriccost = Variable(index=[aquifers, time], unit="\$/1000 m^3")
end

"""
Compute the piezometric head for each reservoirs and the lateral flows between adjacent aquifers
"""
function run_timestep(c::Aquifer, tt::Int)
  v = c.Variables
  p = c.Parameters
  d = c.Dimensions
  # computation of lateral flows:
  v.lateralflows[:,tt]=zeros(d.aquifers[end],1)
  for aa in 1:d.aquifers[end]
    for aa_ in (aa+1):(d.aquifers[end]-1)
      if p.aquiferconnexion[aa,aa_]==1.
        if tt==1
        latflow = p.lateralconductivity[aa,aa_]*(p.piezohead0[aa_]-p.piezohead0[aa])*p.deltatime; # in m3/month or m3/year if factor 12
        else
        latflow = p.lateralconductivity[aa,aa_]*(v.piezohead[aa_,tt-1]-v.piezohead[aa,tt-1])*p.deltatime; # in m3/month or m3/year if factor 12
        end
        v.lateralflows[aa,tt] += latflow/1000;
        v.lateralflows[aa_,tt] += -latflow/1000;
      end
    end
  end

  # piezometric head initialisation and simulation (piezohead is actually a drawdown)
  for aa in d.aquifers
    if tt==1
      v.piezohead[aa,tt] = p.piezohead0[aa] + 1/(p.storagecoef[aa]*p.areaaquif[aa])*(- p.recharge[aa,tt] + p.withdrawal[aa,tt] + v.lateralflows[aa,tt])
    else
      v.piezohead[aa,tt] = v.piezohead[aa,tt-1] + 1/(p.storagecoef[aa]*p.areaaquif[aa])*(- p.recharge[aa,tt] + p.withdrawal[aa,tt] + v.lateralflows[aa,tt])
    end
  end

  # variable to pass to watercost component. assumption: piezohead does not vary much and it's initial value is representative. piezohead datum is sea level
  for aa in d.aquifers
    v.volumetriccost[aa,tt] = p.piezohead0[aa]
  end
end

function makeconstraintpiezomin(aa, tt)
    function constraint(model)
        -m.components[:Aquifer].Parameters.elevation[aa]+m[:Aquifer, :piezohead][aa, tt]# piezohead < elevation (non-artesian well)
    end
end
function makeconstraintpiezomax(aa, tt)
    function constraint(model)
       -m[:Aquifer, :piezohead][aa, tt] + m.components[:Aquifer].Parameters.depthaquif[aa] # piezohead > aquifer depth (remains confined)
    end
end

"""
Add an Aquifer component to the model.
"""
function initaquiferfive(m::Model)
  aquifer = addcomponent(m, Aquifer)

  #five county test:
  aquifer[:depthaquif] = [-100.; -90.; -100.; -80.; -80.];
  aquifer[:storagecoef] = [5e-4; 5e-4; 5e-4; 5e-4; 5e-4];
  aquifer[:piezohead0] = [-55.; -45.; -53.; -33.; -35.];
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
end

function initaquifercontus(m::Model)
  aquifer = addcomponent(m, Aquifer)
  v=collect(1:3109);

  temp = readdlm(datapath("gwmodel/aquifer_depth.txt"));
  aquifer[:depthaquif] = temp[v,1];
  temp = readdlm(datapath("gwmodel/piezohead0.txt"));
  aquifer[:piezohead0] = temp[v,1]; # needs to be changed
  temp = readdlm(datapath("gwmodel/vector_storativity.txt"));
  aquifer[:storagecoef] = temp[v,1];
  temp = readdlm(datapath("gwmodel/county_area.txt"));
  aquifer[:areaaquif] = temp[v,1]/1000;
  temp = readdlm(datapath("gwmodel/county_elevation.txt"));
  aquifer[:elevation] = temp[v,1];
  #Mtemp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/oneyearrecharge.txt");
  M = zeros(m.indices_counts[:regions],m.indices_counts[:time]);
  aquifer[:recharge] = M;
  #mingw=readdlm(datapath("demand/MIWGWFr.txt"));
  #indgw=readdlm(datapath("demand/INWGWFr.txt"));
  #psgw=readdlm(datapath("demand/PSWGWFr.txt"));
  aquifer[:withdrawal] = zeros(m.indices_counts[:regions],m.indices_counts[:time]);#psgw+indgw+mingw;

  temp = readdlm(datapath("gwmodel/matrix_leakage_factor.txt"));
  aquifer[:lateralconductivity] = temp[v,v];
  aquifer[:deltatime] = convert(Float64, config["timestep"])
  temp = readdlm(datapath("gwmodel/connectivity_matrix.txt"));
  aquifer[:aquiferconnexion] = temp[v,v];
  aquifer
end
