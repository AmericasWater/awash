workspace()
#cd("Dropbox/POSTDOC/AW-julia/operational-problem-main/src/")
using OptiMimi
using DataFrames
include("Allocation.jl")
include("Groundwater.jl")

println("Creating model...")
m = Model();

ncounty= 3109;
setindex(m, :time, collect(1));
setindex(m, :regions, collect(1:ncounty));
setindex(m, :aquifers, collect(1:ncounty));
setindex(m, :canals, collect(1:ncounty));
# Add all of the components
allocation = initallocation(m);
aquifer = initaquifercontus(m);#contus(m);
# Set links between components
aquifer[:withdrawal] = allocation[:watergw];

# Run it and time it!
@time run(m)

m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Allocation].Parameters.costfromgw
m.components[:Allocation].Parameters.waterdemand
m.components[:Aquifer].Parameters.storagecoef
m.components[:Aquifer].Variables.drawdown
m.components[:Aquifer].Variables.lateralflows
m.components[:Aquifer].Parameters.withdrawal
m.components[:Aquifer].Parameters.recharge
m.components[:Aquifer].Parameters.depthaquif
m.components[:Aquifer].Parameters.lateralconductivity

using RCall
R"library(ggplot2)"
R"library(PBSmapping)"
R"shapes <- importShapefile('../data/mapping/US_county_2000-simple')";
R"polydata <- attributes(shapes)$PolyData";
R"polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]";
R"polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]";
R"shapes$id <- polydata$STATE[shapes$PID]*100 + polydata$COUNTY[shapes$PID]/10";
R"names(shapes) <- tolower(names(shapes))";
recorded = readtable("../data/extraction/USGS-2010.csv");

diffdrawdown = -m.components[:Aquifer].Parameters.drawdown0+m.components[:Aquifer].Variables.drawdown;
recorded[:diffdwn] = diffdrawdown[1:3109];

R"pdf('../results/drawdown_oneyear_use.pdf')";
R"print(ggplot($recorded, aes(fill=diffdwn)) + geom_map(aes(map_id=FIPS), map=shapes) + expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) + scale_fill_gradient(name='Head change [m]', trans='log1p', low='beige', high='grey', breaks=c(0,0.2,0.4,0.6,0.8,1)) + theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab(''))";
R"dev.off()";


Optimizing...")
# Make sure that all constraints are currently satisifed. All must be < 0
constraints = Function[]
for tt in 1:m.indices_counts[:time]
    constraints = [constraints; map(aa -> makeconstraintdemandmet(aa, tt), 1:m.indices_counts[:regions])]
    constraints = [constraints; map(aa -> makeconstraintpiezomin(aa, tt), 1:m.indices_counts[:aquifers])]
    constraints = [constraints; map(aa -> makeconstraintpiezomax(aa, tt), 1:m.indices_counts[:aquifers])]
end

function objective(m)
    # Cost is minimized
    return -sum(m.components[:Allocation].Variables.cost)
end

optprob = problem(m, [:Allocation, :Allocation], [:waterfromgw, :waterfromsupersource], [0., 0.], [1e9, Inf], objective, constraints=constraints, algorithm=:GUROBI_LINPROG);
println("Solving...")
@time sol = solution(optprob);

# re-run model with optimised parameters
setparameters(m, [:Allocation, :Allocation], [:waterfromgw, :waterfromsupersource], sol)
@time run(m)
objective(m)

m.components[:Allocation].Variables.cost
m.components[:Allocation].Variables.waterallocated
m.components[:Allocation].Parameters.waterdemand
m.components[:Allocation].Parameters.waterfromgw
m.components[:Allocation].Parameters.waterfromsupersource
m.components[:Aquifer].Variables.piezohead
m.components[:Aquifer].Parameters.withdrawal

writedlm("al_cost_1yr.txt", m.components[:Allocation].Variables.cost, "\t")
writedlm("al_wateral_1yr.txt", m.components[:Allocation].Variables.waterallocated, "\t")
writedlm("al_waterdem_1yr.txt", m.components[:Allocation].Parameters.waterdemand, "\t")
writedlm("al_waterfromgw_1yr.txt", m.components[:Allocation].Parameters.waterfromgw, "\t")
writedlm("al_waterss_1yr.txt", m.components[:Allocation].Parameters.waterfromsupersource, "\t")
writedlm("aq_piezohead_1yr.txt", m.components[:Aquifer].Variables.piezohead, "\t")
writedlm("aq_withdrawal_1yr.txt", m.components[:Aquifer].Parameters.withdrawal, "\t")
