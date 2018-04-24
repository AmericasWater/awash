canals <- read.csv("nhd-canals.csv")

## Add the "known", NHD canals
draws <- rbind(draws, data.frame(fips=canals$fips, source=canals$netsource,
                                 justif=paste0('canal-', canals$creation),
                                 downhill=NA, exdist=0))

## Add the "missing" canals
misscanals=read.table("missing-canals.txt")

# copier until it's different
version2 = draws[1,]
ref=draws[1,1]
for(i in 2:dim(draws)[1]){
  if(ref == draws$fips[i]){
    version2 = rbind(version2,draws[i,])
  }else{
    if(ref %in% misscanals$V1){
      posi = which(ref==misscanals$V1)
      #print(paste(ref,"is in the list of missing canal"))
      for(j in 2:10){
        if(misscanals[posi,j]!=0){
          othersource = misscanals[posi,j]
          #print(paste(othersource %in%draws$fips,"it has a source"))
          if(othersource %in% draws$fips){
            rowsource = which(othersource==draws$fips)
            toadd_ = draws[rowsource,]
            if("contains" %in% toadd_[,3]){
            toadd = toadd_[which(toadd_[,3]=="contains"),]
            toadd[,3] = "missingcanal" # Note: previously included `othersource` information
            toadd[,4] = NA
            toadd[,5] = 0
            toadd[,1] = ref
            version2 = rbind(version2,toadd)
    }}}}}
    # pass to the next one
    version2 = rbind(version2,draws[i,])
    ref = draws$fips[i]
}}

draws = version2
