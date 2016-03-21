#### inititalisation of the gw component for the national model
#using DataFrames
function initaquifercontus(m::Model)
  aquifer = addcomponent(m, Aquifer)
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/v_FIPS.txt")
  aquifer[:fips]= temp[:,1];
  aquifer[:edges]= readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/connectivity_matrix_sparse.txt")
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/aquifer_thickness.txt")
  aquifer[:layerthick] = temp[:,1];
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/aquifer_depth.txt")
  aquifer[:depthaquif] = temp[:,1];
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/county_elecation.txt",Float64)
  aquifer[:elevation] = temp[:,1];
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/vector_storativity.txt")
  aquifer[:storagecoef] = temp[:,1];
  #temp = readdlm
  aquifer[:piezohead0] = rand(Normal(????,3700), m.indices_counts[:aquifers])
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/county_area.txt")
  aquifer[:areaaquif] = temp[:,1];

  aquifer[:withdrawal] = repeat(rand(Normal(190000,3700), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);
  aquifer[:recharge] = repeat(rand(Normal(240000,1000), m.indices_counts[:aquifers]), outer=[1, m.indices_counts[:time]]);

  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/matrix_leakage_factor.txt")
  aquifer[:lateralconductivity] = temp;
  temp = readdlm("Dropbox/POSTDOC/AW-julia/operational-problem/data/connectivity_matrix.txt")
  aquifer[:aquiferconnexion] = temp;
  aquifer
end


#("Dropbox/POSTDOC/AW-julia/operational-problem/data/connectivity_matrix_sparse.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/lateral_conductivity.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/matrix_aquifer_thickness.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/matrix_county_border_length.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/matrix_county_distance.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/matrix_harmonic_conductivity.txt")
#("Dropbox/POSTDOC/AW-julia/operational-problem/data/specific_storage.txt")



