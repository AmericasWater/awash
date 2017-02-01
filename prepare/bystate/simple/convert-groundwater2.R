aquifer_depth = as.matrix(read.delim("../../../data/states/gwmodel/aquifer_depth.txt", header=F))
connectivity_matrix = as.matrix(read.table("../../../data/states/gwmodel/connectivity_matrix.txt", header=F))
county_area = as.matrix(read.delim("../../../data/states/gwmodel/county_area.txt", header=F))
county_elevation = read.delim("../../../data/states/gwmodel/county_elevation.txt", header=F)
matrix_leakage_factor = as.matrix(read.table("../../../data/states/gwmodel/matrix_leakage_factor.txt", header=F))
piezohead0 = as.matrix(read.delim("../../../data/states/gwmodel/piezohead0.txt", header=F))
vector_storativity = as.matrix(read.delim("../../../data/states/gwmodel/vector_storativity.txt", header=F))

save(aquifer_depth, connectivity_matrix, county_area, county_elevation, matrix_leakage_factor, piezohead0, vector_storativity, file="../../../data/states/gwmodel/contusgwmodel.RData")
