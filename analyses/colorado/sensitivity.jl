using Mimi
using OptiMimi
using RCall
jpeg = R"jpeg"
plot=R"plot"
lines=R"lines"

include("lib/readconfig.jl")
include("lib/datastore.jl")

config = readconfig("../configs/standard-1year-colorado.yml");
suffix = getsuffix()
include("initialize.jl")

vector=[0.001,0.0025,0.005,0.0075,0.01,0.015,0.02,0.025,0.03,0.035,0.04,0.045,0.05,0.1,0.5,1]
irrigated_=zeros(63,length(vector))
rainfed_=zeros(63,length(vector))
irrigationwater=zeros(63,length(vector))
gwuses=zeros(63,length(vector))
swuses=zeros(63,length(vector))


for i in 1:length(vector)
    m.parameters[:energycostfactor].value=vector[i]
    include("optimize-without.jl")
    include("simulate.jl")
    println("parametervalue is")
    println(m.parameters[:energycostfactor].value)
    irrigated=sum(getdata(:Agriculture,:irrigatedareas)[:,:,12],2)
    rainfed=sum(getdata(:Agriculture,:rainfedareas)[:,:,12],2)
    irrigation=getdata(:Agriculture,:totalirrigation)[:,12]
    gwsupply=getdata(:Allocation,:waterfromgw)[:,12]
    swsupply=getdata(:Allocation,:swsupply)[:,12]
    irrigated_[:,i]=irrigated
    rainfed_[:,i]=rainfed
    irrigationwater[:,i]=irrigation
    gwuses[:,i]=gwsupply
    swuses[:,i]=swsupply
    rm(datapath("extraction/irrigatedareas-08.jld"))
    rm(datapath("extraction/rainfedareas-08.jld"))
    rm(datapath("extraction/supersource-08.jld"))
    rm(datapath("extraction/waterfromgw-08.jld"))
    rm(datapath("extraction/withdrawals-08.jld"))
end
irrigated_=convert(DataFrame,irrigated_)
rainfed_=convert(DataFrame,rainfed_)
irrigation_=convert(DataFrame,irrigationwater)
gwuses_=convert(DataFrame,gwuses)
swuses_=convert(DataFrame,swuses)

writetable(datapath("../results/Colorado/sensitivity/irrigated1.csv"), irrigated_)
writetable(datapath("../results/Colorado/sensitivity/rainfed1.csv"), rainfed_)
writetable(datapath("../results/Colorado/sensitivity/irrigationwater1.csv"), irrigation_)
writetable(datapath("../results/Colorado/sensitivity/gwuses1.csv"), gwuses_)
writetable(datapath("../results/Colorado/sensitivity/swuses1.csv"), swuses_)

