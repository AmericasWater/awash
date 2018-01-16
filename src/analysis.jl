using DataFrames
using RCall
include("lib/graphing-rcall.jl")

R_barplot = R"barplot" 
df=readtable(datapath("sample.csv")); #sample dataframe 
rename!(df, :x, :value)

year=[1951:2010];

#Map Area
area=getdata(:UnivariateAgriculture,:totalareas)[:,:,1];
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


netrev=total_revenue-sum(swcost,2)[:,1]-sum(gwcost,2)[:,1]-sum(opcost,2)[:,1];

df[:value]=netrev/60
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
swcost=getdata(:Allocation,:swcost);
df[:value]=sum(swcost,2)[:,1]./sum(sw,2)[:,1]
usmap_colorado(df,true)
gwcost=getdata(:Allocation,:cost)-getdata(:Allocation,:swcost);
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



total water use, sw, gw, swcost, gwcost, watercost, net revenue 
totalwateruse=getdata(:Allocation,:waterallocated);
sw=getdata(:Allocation,:swsupply);
gw=getdata(:Allocation,:waterfromgw);
swcost=getdata(:Allocation,:swcost);
gwcost=getdata(:Allocation,:cost)-getdata(:Allocation,:swcost)
watercost=getdata(:Allocation,:cost);

revenue=getdata(:Market,:domesticrevenue);
opcost=getdata(:UnivariateAgriculture,:opcost);
nv=revenue-opcost-watercost 



writetable(datapath("water-ag-opt.csv"), df3)

writetable(datapath("../../opt_cst2.csv"), df3)

revenue=getdata(:Market,:domesticrevenue);

rev_barl=revenue[:,1,:];

rev_barl=reshape(rev_barl,63,60);

rev_corn_rain=revenue[:,2,:];

 rev_corn_rain=reshape(rev_corn_rain,63,60);

 rev_corn_irr=revenue[:,3,:];

 rev_corn_irr=reshape(rev_corn_irr,63,60);

 rev_sorghum=revenue[:,4,:];

 rev_sorghum=reshape(rev_sorghum,63,60);

 rev_soy=revenue[:,5,:];
 rev_soy=reshape(rev_soy,63,60);

 rev_wh_rain=revenue[:,6,:];

 rev_wh_rain=reshape(rev_wh_rain,63,60);

 rev_wh_irr=revenue[:,7,:];

 rev_wh_irr=reshape(rev_wh_irr,63,60);

 rev_hay=revenue[:,8,:];

 rev_hay=reshape(rev_hay,63,60);

 rev_crop=DataFrame(barl=sum(rev_barl,2)[:,1]/60
       ,corn_rain=sum(rev_corn_rain,2)[:,1]/60,corn_irr=sum(rev_corn_irr,2)[:,1]/60,
           sorghum=sum(rev_sorghum,2)[:,1]/60,soy=sum(rev_soy,2)[:,1]/60,
       wheat_rain=sum(rev_wh_rain,2)[:,1]/60,wheat_irr=sum(rev_wh_irr,2)[:,1]/60,
           hay=sum(rev_hay,2)[:,1]/60);

writetable(datapath("rev_barl.csv"),convert(DataFrame,rev_barl));
writetable(datapath("rev_corn_rain.csv"),convert(DataFrame,rev_corn_rain));
writetable(datapath("rev_corn_irr.csv"),convert(DataFrame,rev_corn_irr));
writetable(datapath("rev_sorghum.csv"),convert(DataFrame,rev_sorghum));
writetable(datapath("rev_wh_rain.csv"),convert(DataFrame,rev_wh_rain));
writetable(datapath("rev_wh_irr.csv"),convert(DataFrame,rev_wh_irr));
writetable(datapath("rev_soy.csv"),convert(DataFrame,rev_soy));
writetable(datapath("rev_hay.csv"),convert(DataFrame,rev_hay));




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