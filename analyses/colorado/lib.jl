## Agriculture

function constraintoffset_colorado_agriculture_sorghumarea(m::Model)
    sorghum=readtable(datapath("../Colorado/sorghum.csv"))[:x][:,1]
    sorghum=repeat(convert(Vector,allarea),outer=[1,numsteps])
    gen(rr,tt)=sorghum[rr,tt]
    hallsingle(m, :Agriculture, :sorghumarea,gen)
end
