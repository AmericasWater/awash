# The groundwater component
#
# Manages the groundwater drawdowns over time

using Mimi
using Distributions

gw = load(datapath("gwmodel/contusgwmodel.RData"))
vfips = readdlm(datapath("gwmodel/v_FIPS.txt"));

@defcomp Aquifer begin
  aquifers = Index()

  # Aquifer description
  depthaquif = Parameter(index=[aquifers], unit="m")
  areaaquif = Parameter(index=[aquifers], unit="1000 m^2")
  storagecoef = Parameter(index=[aquifers], unit="none")
  piezohead0 = Parameter(index=[aquifers], unit="m") # used for initialisation
  elevation = Parameter(index=[aquifers], unit="m")
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
  piezohead = Variable(index=[aquifers, time], unit="m")
end

"""
Compute the piezometric head for each reservoirs and the lateral flows between adjacent aquifers
"""
function run_timestep(c::Aquifer, tt::Int)
  v = c.Variables
  p = c.Parameters
  d = c.Dimensions
  ## initialization
  if tt==1
	  v.piezohead[:,tt] = p.piezohead0;
  else
	  v.piezohead[:,tt] = v.piezohead[:,tt-1]; 
  end
  
  v.lateralflows[:,tt] = zeros(d.aquifers[end],1);
  ## repeat simulation timestep time
  for mm in 1:config["timestep"]
  
  	# computation of lateral flows:
  	lflows=zeros(d.aquifers[end],1)
  	for aa in 1:d.aquifers[end]
		connections = p.aquiferconnexion[aa, (aa+1):(d.aquifers[end]-1)]
		for aa_ in find(connections) + aa
			latflow = p.lateralconductivity[aa,aa_]*(v.piezohead[aa_,tt]-v.piezohead[aa,tt]); # in m3/month
			lflows[aa] += latflow/1000;
			lflows[aa_] -= latflow/1000;
	                v.lateralflows[aa,tt] += latflow/1000;
	                v.lateralflows[aa_,tt] -= latflow/1000;
		end
	end

  # piezometric head initialisation and simulation (piezohead is actually a drawdown)
	for aa in d.aquifers
		v.piezohead[aa,tt] = v.piezohead[aa,tt] + (1/(p.storagecoef[aa]*p.areaaquif[aa]))*(p.recharge[aa,tt]/config["timestep"] - p.withdrawal[aa,tt]/config["timestep"] + lflows[aa])
	end  
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
function initaquifer(m::Model)
  aquifer = addcomponent(m, Aquifer)

  if config["netset"] == "three"
  	aquifer[:depthaquif] = [-100.; -90.; -95.];
	aquifer[:storagecoef] = [5e-4; 5e-4; 5e-4];
 	aquifer[:piezohead0] = [-55.; -45.; -53.];
  	aquifer[:areaaquif] = [8e8; 6e8; 5e8];

  	aquifer[:withdrawal] = repeat(rand(Normal(190000,3700), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  	aquifer[:recharge] = repeat(rand(Normal(240000,1000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);

  	aquifer[:lateralconductivity] = [  0  1e-4     0;
                                        1e-4     0  1e-4;
                                   	   0  1e-6     0];

  	aquifer[:aquiferconnexion] = [0. 1. 0.; 1. 0. 1.; 0 1. 0];
  else

  	if config["filterstate"] != nothing
		vstates = round(Int64, floor(vfips / 1000));
		subfips = (vstates .== parse(Int64, get(config,"filterstate", nothing)));
	else
		subfips = 1:3109;
	end
	aquifer[:depthaquif] = gw["aquifer_depth"][subfips[1:3109]];
	aquifer[:piezohead0] = zeros(numaquifers);#gw["piezohead0"].data[subfips[1:3109]];
  	aquifer[:storagecoef] = gw["vector_storativity"][subfips[1:3109]];
  	aquifer[:areaaquif] = gw["county_area"][subfips[1:3109]]/1000;
	aquifer[:elevation] = gw["county_elevation"][:V1][subfips[1:3109]];
  	aquifer[:recharge] = zeros(m.indices_counts[:regions],m.indices_counts[:time]);;
  	aquifer[:withdrawal] = zeros(m.indices_counts[:regions],m.indices_counts[:time]);


  	aquifer[:lateralconductivity] = gw["matrix_leakage_factor"][subfips[1:3109],subfips[1:3109]];
  	aquifer[:deltatime] = convert(Float64, config["timestep"]);
	aquifer[:aquiferconnexion] =  gw["connectivity_matrix"][subfips[1:3109],subfips[1:3109]];
  end
  aquifer
end
