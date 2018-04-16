## Groundwater Component
#
# Manages the groundwater drawdowns over time

using Mimi
using Distributions

include("lib/groundwaterdata.jl")

@defcomp Aquifer begin
  aquifers = Index()
  scenarios = Index()

  # Aquifer description
  depthaquif = Parameter(index=[aquifers], unit="m")
  areaaquif = Parameter(index=[aquifers], unit="1000 m^2")
  storagecoef = Parameter(index=[aquifers], unit="none")
  piezohead0 = Parameter(index=[aquifers], unit="m") # used for initialisation
  elevation = Parameter(index=[aquifers], unit="m")
  # Recharge
  recharge = Parameter(index=[aquifers, scenarios, time], unit="1000 m^3")

  # Withdrawals - to be optimised
  withdrawal = Parameter(index=[aquifers, scenarios, time], unit="1000 m^3")

  # Lateral flows
  lateralflows = Variable(index=[aquifers, time], unit="1000 m^3")
  aquiferconnexion = Parameter(index=[aquifers, aquifers], unit ="none") # aquiferconnexion[aa,aa']=1 -> aquifers are connected, 0 otherwise.
  lateralconductivity = Parameter(index=[aquifers, aquifers], unit="1 m^2/month") ## how should I specify per month per year?
  deltatime = Parameter(unit="month")

  # Piezometric head
  piezohead = Variable(index=[aquifers, scenarios, time], unit="m")
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
	  v.piezohead[:,:,tt] = repmat(p.piezohead0, 1, numscenarios);
  else
	  v.piezohead[:,:,tt] = v.piezohead[:,:,tt-1];
  end

  v.lateralflows[:,tt] = zeros(d.aquifers[end],1);
  ## repeat simulation timestep time
  for mm in 1:config["timestep"]
  	lflows=zeros(d.aquifers[end],1)
  	for aa in 1:d.aquifers[end]
		connections = p.aquiferconnexion[aa, (aa+1):(d.aquifers[end]-1)]
		for aa_ in find(connections) + aa
			latflow = p.lateralconductivity[aa,aa_]*mean(v.piezohead[aa_,:,tt]-v.piezohead[aa,:,tt]); # in m3/month
			lflows[aa] += latflow/1000;
			lflows[aa_] -= latflow/1000;
	                v.lateralflows[aa,tt] += latflow/1000;
	                v.lateralflows[aa_,tt] -= latflow/1000;
		end
	end

  # piezometric head initialisation and simulation
	for aa in d.aquifers
		v.piezohead[aa,:,tt] = v.piezohead[aa,:,tt] + (1/(p.storagecoef[aa]*p.areaaquif[aa]))*(p.recharge[aa,:,tt]/config["timestep"] - p.withdrawal[aa,:,tt]/config["timestep"] + lflows[aa])
	end
  end
end

function makeconstraintpiezomin(aa, ss, tt)
    function constraint(model)
        -m.components[:Aquifer].Parameters.elevation[aa]+m[:Aquifer, :piezohead][aa, ss, tt]# piezohead < elevation (non-artesian well)
    end
end
function makeconstraintpiezomax(aa, ss, tt)
    function constraint(model)
       -m[:Aquifer, :piezohead][aa, ss, tt] + m.components[:Aquifer].Parameters.depthaquif[aa] # piezohead > aquifer depth (remains confined)
    end
end

"""
Add an Aquifer component to the model.
"""
function initaquifer(m::Model)
    aquifer = addcomponent(m, Aquifer)
    aquifer[:depthaquif] = dfgw[:depthaquif];
    aquifer[:storagecoef] = dfgw[:storagecoef];
    aquifer[:piezohead0] = dfgw[:piezohead0];
    aquifer[:areaaquif] = dfgw[:areaaquif];
    aquifer[:lateralconductivity] = lateralconductivity;
    aquifer[:aquiferconnexion] = aquiferconnexion;
    aquifer[:recharge] = zeros(m.indices_counts[:regions], numscenarios, m.indices_counts[:time]);;
    aquifer[:withdrawal] = zeros(m.indices_counts[:regions], numscenarios, m.indices_counts[:time]);

    aquifer[:deltatime] = convert(Float64, config["timestep"]);

    # Get elevation from county-info file
    countyinfo = readtable(loadpath("county-info.csv"), eltypes=[String, String, String, String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
    countyinfo[:FIPS] = regionindex(countyinfo, :)

    aquifer[:elevation] = map(x -> ifelse(isna(x), 0., x), dataonmaster(countyinfo[:FIPS], countyinfo[:Elevation_ft]))
    aquifer
end
