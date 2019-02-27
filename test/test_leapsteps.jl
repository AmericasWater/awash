using Test

include("../src/lib/leapsteps.jl")

leaps = []
for tt in 1:4
    push!(leaps, timeindex2leapindexes(tt, 3, 6))
end
@test leaps == [[], [1], [], [2]]

leaps = []
for tt in 1:2
    push!(leaps, timeindex2leapindexes(tt, 6, 3))
end
@test leaps == [[1, 2], [3, 4]]

times = []
for yy in 1:2
    push!(times, leapindex2timeindexes(yy, 3, 6))
end
@test times == [([1, 2], [1., 1.]), ([3, 4], [1., 1.])]

times = []
for yy in 1:4
    push!(times, leapindex2timeindexes(yy, 6, 3))
end
@test times == [([1], [.5]), ([1], [.5]), ([2], [.5]), ([2], [.5])]
