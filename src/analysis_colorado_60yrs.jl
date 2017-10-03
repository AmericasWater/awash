using DataFrames
using RCall
include("lib/graphing-rcall.jl")

R_barplot = R"barplot" 
df=readtable(datapath("../Colorado/sample.csv")); #sample dataframe 
rename!(df, :x, :value)

year=[1951:2010]

#Map Area
area=getdata(:UnivariateAgriculture,:totalareas)[:,:,1]
df[:value]=sum(area,2)[:,1];
usmap_colorado(df,true)

#Map crops (NO Hay, Wheat irrigated, soybeans (5,7,8))
df[:value]=area[:,1]  #1,2,3,4,6
usmap_colorado(df,true)

#MAP Mean Revenue
revenue=getdata(:Market,:domesticrevenue);
total_revenue=sum(sum(revenue,2),3)[:,1];
df[:value]=total_revenue;
usmap_colorado(df,true)



#Map Total Water Use over 60 yrs
sw=getdata(:Allocation,:swsupply);
df[:value]=sum(sw,2)[:,1];
usmap_colorado(df,true)
gw=getdata(:Allocation,:waterfromgw);
df[:value]=sum(gw,2)[:,1];
usmap_colorado(df,true)
totals=sw+gw;
df[:value]=sum(totals,2)[:,1];
usmap_colorado(df,true)

#Money per Water Use 
df[:value]= total_revenue./sum(totals,2)[:,1]
usmap_colorado(df,true)


#Map unit water cost 
swcost=getdata(:Allocation,:swcost)
df[:value]=sum(swcost,2)[:,1]./sum(sw,2)[:,1]
usmap_colorado(df,true)
gwcost=getdata(:Allocation,:cost)-getdata(:Allocation,:swcost)
df[:value]=sum(gwcost,2)[:,1]./sum(gw,2)[:,1]
usmap_colorado(df,true)
df[:value]=sum(swcost,2)[:,1]
usmap_colorado(df,true)
df[:value]=sum(gwcost,2)[:,1]
usmap_colorado(df,true)




opcost=getdata(:UnivariateAgriculture,:opcost);

df3=DataFrame(year=year,sw=reshape(sum(sw,1),60,1)[:,1],gw=reshape(sum(gw,1),60,1)[:,1],
swcost=reshape(sum(swcost,1),60,1)[:,1],gwcost=reshape(sum(gwcost,1),60,1)[:,1],
revenue=reshape(sum(sum(revenue,1),2),60,1,1)[:,1],opcost=reshape(sum(sum(opcost,1),2),60,1,1)[:,1],
barley=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,1,:],1),60,1,1)[:,1],
corn=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,2,:],1),60,1,1)[:,1]+
reshape(sum(getdata(:UnivariateAgriculture,:production)[:,3,:],1),60,1,1)[:,1],
sorghum=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,4,:],1),60,1,1)[:,1],
soybean=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,5,:],1),60,1,1)[:,1],
wheat=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,6,:],1),60,1,1)[:,1]+
    reshape(sum(getdata(:UnivariateAgriculture,:production)[:,7,:],1),60,1,1)[:,1],
hay=reshape(sum(getdata(:UnivariateAgriculture,:production)[:,8,:],1),60,1,1)[:,1],
precip=reshape(sum(precip,1),60,1)[:,1])
writetable(datapath("../../sim.csv"), df3)











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
    df1=hcat(df,revenue[:,i])
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

