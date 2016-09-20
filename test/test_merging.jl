include("../prepare/bystate/mergelib.jl")

## TEST CASE
twaternet = empty_extnetwork();
aa = ExVertex(1, "missing")
bb = ExVertex(2, "left 1")
cc = ExVertex(3, "left 2")
dd = ExVertex(4, "right 1")
ee = ExVertex(5, "missing")
add_vertex!(twaternet, aa)
add_vertex!(twaternet, bb)
add_vertex!(twaternet, cc)
add_vertex!(twaternet, dd)
add_vertex!(twaternet, ee)
add_edge!(twaternet, aa, bb)
add_edge!(twaternet, bb, cc)
add_edge!(twaternet, cc, dd)
add_edge!(twaternet, dd, ee)

getregion(label) = split(label)[1]
allregions() = ["left", "right"]

nodes = [ee, dd, cc, bb, aa]
waternet = twaternet
