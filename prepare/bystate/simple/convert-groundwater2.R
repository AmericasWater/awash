aquifer_depth = read.delim("../../../data/states/gwmodel/aquifer_depth.txt")
connectivity_matrix = read.table("../../../data/states/gwmodel/connectivity_matrix.txt")
county_area = read.delim("../../../data/states/gwmodel/county_area.txt")
county_elevation = read.delim("../../../data/states/gwmodel/county_elevation.txt")
matrix_leakage_factor = read.table("../../../data/states/gwmodel/matrix_leakage_factor.txt")
piezohead0 = read.delim("../../../data/states/gwmodel/piezohead0.txt")
vector_storativity = read.delim("../../../data/states/gwmodel/vector_storativity.txt")

save(aquifer_depth, connectivity_matrix, county_area, county_elevation, matrix_leakage_factor, piezohead0, vector_storativity, file="../../../data/states/gwmodel/contusgwmodel.RData")
