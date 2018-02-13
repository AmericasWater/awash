using JuMP
using Clp

time = 0:49
precip1 = repeat([1], inner=length(time))
precip2 = (cos.(2*pi*time / 25) + 1) / 3 + 1/3
demand = repeat([.5], inner=length(time))

m = Model(solver=ClpSolver())

@variable(m, kk[time] >= 0) # Investment
@variable(m, xx1[time] >= 0) # Supersource under scenario 1
@variable(m, ww1[time] >= 0) # Withdrawals under scenario 1
@variable(m, xx2[time] >= 0) # Supersource under scenario 2
@variable(m, ww2[time] >= 0) # Withdrawals under scenario 2

# Always satisfy demand
@constraint(m, ww1[time] + xx1[time] .>= demand[time + 1])
@constraint(m, ww2[time] + xx2[time] .>= demand[time + 1])

for tt1 in time
    # Do not overfill reservoirs (v_t < V_t)
    @constraint(m, sum(precip1[tt+1] - ww1[tt] for tt in 0:tt1) <= sum(kk[tt] for tt in 0:tt1))
    @constraint(m, sum(precip2[tt+1] - ww2[tt] for tt in 0:tt1) <= sum(kk[tt] for tt in 0:tt1))

    # Do not withdraw more than available (w_t < v_t-1 + p_t)
    if (tt1 == 0)
        @constraint(m, ww1[tt1] <= precip1[tt1+1])
        @constraint(m, ww2[tt1] <= precip2[tt1+1])
    else
        @constraint(m, ww1[tt1] <= sum(precip1[tt+1] - ww1[tt] for tt in 0:(tt1-1)) + precip1[tt1+1])
        @constraint(m, ww2[tt1] <= sum(precip2[tt+1] - ww2[tt] for tt in 0:(tt1-1)) + precip2[tt1+1])
    end
end

@objective(m, Min, sum(((xx1[tt] + xx2[tt])/2 + .0001kk[tt]) * exp(-.05tt) for tt in time))

status = solve(m)
println("Objective value: ", getobjectivevalue(m))
getvalue(kk)
getvalue(xx2)
