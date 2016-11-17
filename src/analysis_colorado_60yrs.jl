using DataFrames
using RCall
include("lib/graphing-rcall.jl")

R_barplot = R"barplot" 
df=readtable(datapath("Colorado/sample.csv")); #sample dataframe 
delete!(df,:fips);#Analysis for Colorado 
delete!(df,:x);
#Map1: Irrigated Area

function clear
    df=readtable(datapath("Colorado/sample.csv")); #sample dataframe 
    delete!(df,:fips);#Analysis for Colorado 
    delete!(df,:x);
end 

#irrigated
irrigated=sum(getdata(:Agriculture,:irrigatedareas),2);
for i in 1:60
    df=hcat(df,irrigated[:,i])
end 
writetable(datapath("../results/Colorado60/irrigatedarea.csv"), df)
clear
#rainfed
rainfed=sum(getdata(:Agriculture,:rainfedareas),2);
for i in 1:60
    df=hcat(df,rainfed[:,i])
end 
writetable(datapath("../results/Colorado60/rainfedarea.csv"), df)
clear
#piezohead
piezohead=getdata(:Aquifer,:piezohead0)-getdata(:Aquifer,:piezohead)[:,numsteps];
for i in 1:60
    df=hcat(df,piezhohead[:,i])
end 
writetable(datapath("../results/Colorado60/piezohead.csv"), df)
clear
#gwsupply
gwsupply=sum(getdata(:Allocation,:waterfromgw);
for i in 1:60
    df=hcat(df,gwsupply[:,i])
end 
writetable(datapath("../results/Colorado60/gwsupply.csv"), df)
clear
#swsupply
swsupply=sum(getdata(:Allocation,:swsupply);
for i in 1:60
    df=hcat(df,swsupply[:,i])
end 
writetable(datapath("../results/Colorado60/swsupply.csv"), df)
clear

#total allocated 
allocated=getdata(:Allocation,:waterallocated);
for i in 1:60
    df=hcat(df,allocated[:,i])
end 
writetable(datapath("../results/Colorado60/allocated.csv"), df)
clear

#SW percentage  
swpercent=swsupply./allocated;
for i in 1:60
    df=hcat(df,swpercent[:,i])
end 
writetable(datapath("../results/Colorado60/swpercent.csv"), df)
clear

#Water Cost 
watercost=getdata(:Allocation,:cost);
for i in 1:60
    df=hcat(df,watercost[:,i])
end 
writetable(datapath("../results/Colorado60/watercost.csv"), df)
clear

#Surface Water Cost percent 
swcost=getdata(:Allocation,:swcost);
swcostpercent=swcost./watercost
for i in 1:60
    df=hcat(df,swcostpercent[:,i])
end 
writetable(datapath("../results/Colorado60/swcostpercent.csv"), df)
clear

#revenue
revenue=getdata(:Market,:domesticrevenue);
for i in 1:60
    df=hcat(df,revenue[:,i])
end 
writetable(datapath("../results/Colorado60/revenue.csv"), df)
clear


culticost=getdata(:Agriculture,:cultivationcost)
#profit
profit=revenue-culticost-watercost
for i in 1:60
    df=hcat(df,profit[:,i])
end 
writetable(datapath("../results/Colorado60/profit.csv"), df)
clear

production=getdata(:Agriculture,:production);

