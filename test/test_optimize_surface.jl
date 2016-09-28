using Base.Test

include("../src/optimization-given.jl")

house = optimization_given(false)

using MathProgBase
using Gurobi
solver = GurobiSolver()

@time sol = houseoptimize(house, solver)
