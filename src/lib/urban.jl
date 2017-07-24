using DataFrames

dummy_year=[0,
0.0657581,
0.1119927,
0.1191364,
0.1662839,
0.1711605]
dum_year=[dummy_year[div(i,12)+1] for i=0:12*length(dummy_year)-1]
dum_year=convert(Array{Float64},repeat(transpose(dum_year),outer=[numcounties,1]))


#72 year dummies 

dummy_month=[0,
-0.0893275,
0.0025978,
-0.0030955,
0.1499964,
0.2248584,
0.3429464,
0.3082912,
0.1784957,
0.0762598,
-0.0440493,
-0.0062064]
dum_month=repeat(dummy_month,outer=[trunc(Int, numsteps/12)])
dum_month=repeat(transpose(dum_month),outer=[numcounties,1])



con=52.53768



#function UrbanModelData(df::DataFrame)
    nydata=getfilteredtable("extraction/New_York_county_water_use.csv");
    #nydata=df
    nydata_1=nydata[nydata[:month_num].<13,:]
    nydata_1=nydata_1[nydata_1[:year_cal].<=2014,:];
    nydata_1=nydata_1[nydata_1[:year_cal].>=2009,:]; #Data from 2009-2014 
    #avg_p=DataFrame(FIPS=nydata_1[:FIPS],avg_p=nydata_1[:cnty_avg_p]);
    #fips=unique(nydata_1[:FIPS])
# TAKE Ln for Price and Household 
log_avg_p=log(transpose(reshape(convert(Array,nydata_1[:cnty_avg_p]),72,60)));
precip_tot=log(map(x->parse(Float64,x),transpose(reshape(convert(Array,nydata_1[:precip_monthly_avg_dailytot]),72,60))));
unemployment=log(transpose(reshape(convert(Array,nydata_1[:unemployment]),72,60)));
log_oohh=log(transpose(reshape(convert(Array,nydata_1[:owner_occupied_housing_units]),72,60)));
college=log(transpose(reshape(convert(Array,nydata_1[:college_more]),72,60)));
avg_size=log(transpose(reshape(convert(Array,nydata_1[:average_household_size]),72,60)));
med_age=log(transpose(reshape(convert(Array,nydata_1[:median_age]),72,60)));
med_built=log(transpose(reshape(convert(Array,nydata_1[:median_year_structure_built]),72,60)));
newyork=(ones(numcounties,numsteps));


#    UrbanModelData(avg_p,precip_tot,unemployment,oohh,college,avg_size,med_age,med_built)    


coef= Dict("log_avg_p" => -0.2499083,
                      "precip_tot" => -0.014255, 
                      "unemployment" => 250.,
                      "log_oohh" => 3.045463,
                      "college" => 2.603077,
                      "avg_size" => -1.949609, 
                      "med_age" => -0.0717986, 
                      "med_built" => -0.0213585,
"dummy_month"=>1,"dummy_year"=>1,"newyork"=>0.2892381)

in_data= Dict("log_avg_p" => log_avg_p,
                      "precip_tot" => precip_tot, 
                      "unemployment" => unemployment,
                      "log_oohh" => log_oohh,
                      "college" => college,
                      "avg_size" => avg_size, 
                      "med_age" => med_age, 
                      "med_built" => med_built,
"dummy_month"=>dum_month,"dummy_year"=>dum_year,"newyork"=>newyork)


   vars=["log_avg_p","precip_tot","unemployment","log_oohh",
    "college","avg_size","med_age", "med_built","dummy_month","dummy_year","newyork"]

