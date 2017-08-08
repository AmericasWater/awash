using DataFrames

#######NY COEF#######
fips_coeff=Dict(36005=>0, 36047=>0.045343, 36061=>1.408523, 36081=>-0.9553143, 36085=>-2.21095)
ny_year=Dict(2009=>-0.0875259, 2010=>-0.0546695,2011=>-0.0504871,2012=>-0.0447242,2013=>-0.0343744,2014=>-0.0277973) 
ny_month=Dict(1=>0,2=>-0.0864586,3=>0.0017015,4=>-0.0423206,5=>0.0020836,6=>0.0406138,7=>0.1115331,
8=>0.1094295,9=>0.0335813,10=>-0.0312783,11=>-0.0711181,12=>-0.0416774)

other_year=Dict(2009=>0,2010=>0.0657581,2011=>0.1119927,2012=>0.1191364,2013=>0.1662839,2014=>0.1711605)
other_month=Dict(1=>0,2=>-0.0893275,3=>0.0025978,4=>-0.0030955,5=>0.1499964,6=>0.2248584,7=>0.3429464,8=>0.3082912,9=>0.1784957,10=>0.0762598,11=>-0.0440493,12=>-0.0062064)

Demand_data=getfilteredtable("extraction/NY_Demand_pwsid.csv");
demand=Demand_data[Demand_data[:month_num].<13,:];
demand=demand[demand[:year_cal].<=2014,:];
demand=demand[demand[:year_cal].>=2009,:]; #Data from 2009-2014 
demands=zeros(size(demand)[1]);


nys=findin(demand[:FIPS],[36005, 36047, 36061, 36081, 36085])
others=[1:size(demand)[1]];
others=deleteat!(others,nys);

for ii in 1:size(nys)[1]
    demands[nys[ii]]=(-0.054349*demand[:ln_avg_p][nys[ii]])+
        (-0.054349*parse(Float64,demand[:precip_monthly_total][nys[ii]]))+
        (-1.358096*log(demand[:housing_density][nys[ii]]))+
        ny_year[demand[:year_cal][nys[ii]]]+
        ny_month[demand[:month_num][nys[ii]]]+
        fips_coeff[demand[:FIPS][nys[ii]]]+
        21.04626
end 
##WORKING     
for ii in 1:size(others)[1]
    demands[others[ii]]=(21.04626*demand[:ln_avg_p][others[ii]])+
        (-0.014255*demand[:precip_annual_avg_monthly_total][others[ii]])+
        (3.045463*demand[:unemployment][others[ii]])+
        (2.603077*demand[:owner_occupied_housing_units][others[ii]])+
        (-0.4233581*demand[:college_more][others[ii]])+
        (-1.949609*demand[:ln_average_household_size][others[ii]])+
        (-0.0717986*demand[:median_age][others[ii]])+
        (-0.0213585*demand[:median_year_structure_built][others[ii]])+
        0.2892381+
        other_year[demand[:year_cal][others[ii]]]+
        other_month[demand[:month_num][others[ii]]]+
        52.53768
end 
demand[:calculated]=exp(demands)

 demand_by_FIPS=by(demand,[:FIPS,:year_cal,:month_num]) do demand 
    DataFrame(calculated=sum(demand[:calculated]))
       end
data_demand=transpose(reshape(demand_by_FIPS[:calculated],72,60))
####60*72 calculated ########