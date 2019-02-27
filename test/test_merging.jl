using Test

include("../prepare/bystate/mergelib.jl")

## TEST CASE M-[1-2][1]-M
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

# start with most downstream
newwateridverts, newwaternet, result = mergedown([aa, bb, cc, dd, ee], twaternet)
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)

@test length(vertices(newwaternet)) == 3

## TEST CASE M-[1-2]
twaternet = empty_extnetwork();
aa = ExVertex(1, "missing")
bb = ExVertex(2, "left 1")
cc = ExVertex(3, "left 2")
add_vertex!(twaternet, aa)
add_vertex!(twaternet, bb)
add_vertex!(twaternet, cc)
add_edge!(twaternet, aa, bb)
add_edge!(twaternet, bb, cc)

getregion(label) = split(label)[1]
allregions() = ["left", "right"]

# start with most downstream
newwateridverts, newwaternet, result = mergedown([aa, bb, cc], twaternet)
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)

@test length(vertices(newwaternet)) == 2

## TEST CASE M-[1<2,3][1]
twaternet = empty_extnetwork();
aa = ExVertex(1, "missing")
bb = ExVertex(2, "left 1")
cc = ExVertex(3, "left 2")
dd = ExVertex(4, "left 3")
ee = ExVertex(5, "right 1")
add_vertex!(twaternet, aa)
add_vertex!(twaternet, bb)
add_vertex!(twaternet, cc)
add_vertex!(twaternet, dd)
add_vertex!(twaternet, ee)
add_edge!(twaternet, aa, bb)
add_edge!(twaternet, bb, cc)
add_edge!(twaternet, bb, dd)
add_edge!(twaternet, dd, ee)

getregion(label) = split(label)[1]
allregions() = ["left", "right"]

# start with most downstream
newwateridverts, newwaternet, result = mergedown([aa, bb, cc, dd, ee], twaternet)
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)

@test length(vertices(newwaternet)) == 3

## TEST CASE M-[1][1,2]
twaternet = empty_extnetwork();
aa = ExVertex(1, "missing")
bb = ExVertex(2, "left 1")
cc = ExVertex(3, "right 1")
dd = ExVertex(4, "right 2")
add_vertex!(twaternet, aa)
add_vertex!(twaternet, bb)
add_vertex!(twaternet, cc)
add_vertex!(twaternet, dd)
add_edge!(twaternet, aa, bb)
add_edge!(twaternet, bb, cc)
add_edge!(twaternet, bb, dd)

getregion(label) = split(label)[1]
allregions() = ["left", "right"]

# start with most downstream
newwateridverts, newwaternet, result = mergedown([aa, bb, cc, dd], twaternet)
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)

@test length(vertices(newwaternet)) == 3

## TEST CASE M-[1<2,][1-2]
twaternet = empty_extnetwork();
aa = ExVertex(1, "missing")
bb = ExVertex(2, "left 1")
cc = ExVertex(3, "left 2")
dd = ExVertex(4, "right 1")
ee = ExVertex(5, "right 2")
add_vertex!(twaternet, aa)
add_vertex!(twaternet, bb)
add_vertex!(twaternet, cc)
add_vertex!(twaternet, dd)
add_vertex!(twaternet, ee)
add_edge!(twaternet, aa, bb)
add_edge!(twaternet, bb, cc)
add_edge!(twaternet, bb, dd)
add_edge!(twaternet, dd, ee)

getregion(label) = split(label)[1]
allregions() = ["left", "right"]

# start with most downstream
newwateridverts, newwaternet, result = mergedown([aa, bb, cc, dd, ee], twaternet)
newwateridverts, newwaternet, result = clearunconnected(newwateridverts, newwaternet, result)

println(newwateridverts)
println(newwaternet)
println(result)

@test length(vertices(newwaternet)) == 3
