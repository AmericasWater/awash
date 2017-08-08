nydata=readtable(datapath("extraction/Industrial_Water_Use_Data.csv")); #4092,14
nydata=nydata[nydata[:fips].!=36059,:];
nydata=nydata[nydata[:fips].!=36103,:];
industry = ["311","312", "322", "324", "325", "326", "327","331","332","333","335"]
dummy=Dict("311"=>0,"312" => 0.292,"322"=>-0.037, "324"=>-0.131, "325"=>0.166, "326"=>0.221,"327"=>0.253, 
"331"=>0.043,"332"=>0.037,"333"=>0.021,"335"=>0.15)
dummy=Dict(311=>0,312 => 0.292,322=>-0.037, 324=>-0.131, 325=>0.166, 326=>0.221,327=>0.253, 
331=>0.043,332=>0.037,333=>0.021,335=>0.15)


coef=zeros(3960)
for i in length(coef)
    coef[i]=exp(0.396*nydata[:ln_hours][i])*exp(0.587*nydata[:ln_materials][i])*exp(-4.348)*exp(dummy[nydata[:naics][i]])
end 




