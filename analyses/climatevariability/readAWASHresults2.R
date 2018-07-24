#### Function to READ the results and construct the dataframe for analysis
mc <- read.csv("../../../data/global/counties.csv")
dem_ <- as.matrix(read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)[,31]) * 1383/ttperyy


readAWASHresult<-function(path_list, config_params){
  for(path in path_list){
    result <- array(dim = c(4, 3109, ttperyy*yearstot, length(vrights)))
    dimnames(result)[[1]] <- c("Demand", "SW", "GW", "Failure")
    dimnames(result)[[2]] <- fips
    dimnames(result)[[3]] <- 1:(yearstot*ttperyy)
    dimnames(result)[[4]] <- run_names
  }
  
  if(ttperyy==12){
    dimnames(result)[[4]] <- c("Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")
  }
  
  
}


fips <- mc$fips




if(ismultiyr){
  dem <- replicate(ttperyy*simyrs,dem_[,1])
  #  dem <- replicate(yearstot,dem)
}else{
  dem <- replicate(ttperyy*yearstot,dem_[,1])
}
# start_years=seq(start_year, end_year-simyrs+1, by=simyrs)
# end_years=seq(start_year+simyrs-1, end_year, by=simyrs)
start_years=start_year
end_years=end_year
for(rr in 1:length(vrights)){
  savingresultspath <- ""
  
  if(ismultiyr){
    for(k in 1:length(start_years)){
      tt=start_years[k]
      configname <- paste0(voptim[rr],"-propenv", flowprop[ee], "-rescap", vreval[rr], "-",vrights[rr],"-",config_t, "-",tt)
      
      failure <- as.matrix(read.csv(paste0(savingresultspath, "failure-", configname,".csv"), header = F))
      failure[which(failure < 0)] <- 0
      if(voptim[rr]=="conj"){
        GW <- as.matrix(read.csv(paste0(savingresultspath, "gw-", configname,".csv"), header = F))
      }else{
        GW_ <- as.matrix(read.csv("../../../../data/counties/extraction/USGS-2010.csv", header = T)[,29]) * 1383./ttperyy
        GW <- replicate(ttperyy*simyrs,GW_[,1])
        #        GW <- replicate(yearstot,GW)
      }
      
      SW <- dem-GW-failure
      SW[which(SW<0)] = 0
      
      result[1,(simyrs*(k-1)+1):(simyrs*k),,,rr] <- dem
      result[2,(simyrs*(k-1)+1):(simyrs*k),,,rr] <- SW
      result[3,(simyrs*(k-1)+1):(simyrs*k),,,rr] <- GW
      result[4,(simyrs*(k-1)+1):(simyrs*k),,,rr] <- failure
    }
    
  }else{
    
    configname <- paste0(voptim[rr],"-propenv", flowprop[ee], "-rescap", vreval[rr], vrights[rr])
    
    failure <- as.matrix(read.csv(paste0(savingresultspath, "failure-", configname,suffix,".csv"), header = F))
    failure[which(failure < 0)] <- 0
    if(voptim[rr]=="conj"){
      GW <- as.matrix(read.csv(paste0(savingresultspath, "gw-", configname,suffix,".csv"), header = F))
    }else{
      GW_ <- as.matrix(read.csv("../../../../data/counties/extraction/USGS-2010.csv", header = T)[,31]) * 1383./ttperyy
      GW <- replicate(ttperyy*simyrs,GW_[,1])
    }
    
    SW <- dem-GW-failure
    SW[which(SW<0)] = 0
    
    result[1,,,rr] <- dem
    result[2,,,rr] <- SW
    result[3,,,rr] <- GW
    result[4,,,rr] <- failure
  }
}

