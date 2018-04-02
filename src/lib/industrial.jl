indata=readtable(datapath("extraction/Industrial_Water_Use_Data.csv")); #4092,14
[indata[indata[nm].==".",nm]="0" for nm in names(indata)]
indata=indata[indata[:fips].!=36059,:];
indata=indata[indata[:fips].!=36103,:];
ind_id= ["311","312", "322", "324", "325", "326", "327","331","332","333","335"]

ind_dummy=Dict(311=>0,312 => 0.292,322=>-0.037, 324=>-0.131, 325=>0.166, 326=>0.221,327=>0.253, 
331=>0.043,332=>0.037,333=>0.021,335=>0.15)
coef=zeros(size(indata)[1]);

for ii in 1:3960
    coef[ii]=exp(0.396*parse(Float64,indata[:ln_hours][ii]))*
    exp(0.587*parse(Float64,indata[:ln_materials][ii]))*exp(-4.348)*exp(ind_dummy[indata[:naics][ii]])
end 

indata[:coef]=coef;
y1=zeros(size(indata)[1]);
y2=zeros(size(indata)[1]);
m=zeros(size(indata)[1]);
b=zeros(size(indata)[1]);
y_hat=zeros(size(indata)[1]);
fix_rev=zeros(size(indata)[1]);

for ii in 1:3960 
    y1[ii]=(parse(Float64,indata[:MG_min_of_min_withdrawal][ii])^0.046)*indata[:coef][ii]
    y2[ii]=(parse(Float64,indata[:MG_max_of_maxwithdrawl][ii])^0.046)*indata[:coef][ii]
    m[ii]=(y2[ii]-y1[ii])/(parse(Float64,indata[:MG_max_of_maxwithdrawl][ii])-(parse(Float64,indata[:MG_min_of_min_withdrawal][ii])))
    b[ii]=y1[ii]-m[ii]*parse(Float64,indata[:MG_min_of_min_withdrawal][ii])
    y_hat[ii]=b[ii]+m[ii]*parse(Float64,indata[:MGwithdrawal][ii])
    fix_rev[ii]=parse(Float64,indata[:ln_fix_revenue][ii])
end 

indata[:y1]=y1;
indata[:y2]=y2;
indata[:m]=m;
indata[:b]=b;  #Linear Approximation of values 
indata[:y_hat]=y_hat;
indata[:fix_revenue]=exp(fix_rev);

writetable("industrial.csv",indata)