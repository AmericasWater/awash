#####################
############### DRAFT



# - county fips, state fips, region index
mc <- read.csv("../../../data/global/counties.csv")
state_ind <- vector(length = dim(dffailure)[1])
for(cc in 1:dim(mc)[1]){
  state_ind[which(dffailure$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}

region_ind <- state_ind
if(regiondef == "climateregion"){
  region_ind[which(region_ind %in% c("CT", "DC", "DE", "ME", "MD", "MA", "NH", "NJ", "NY", "PA", "RI", "VT"))] <- "Northeast"
  region_ind[which(region_ind %in% c("AL", "FL", "GA", "NC", "SC", "VA"))] <- "Southeast"
  region_ind[which(region_ind %in% c("IL", "IN", "KY", "MO", "OH", "TN", "WV"))] <- "Central"
  region_ind[which(region_ind %in% c("AR", "KS", "LA", "MS", "OK", "TX"))] <- "South"
  region_ind[which(region_ind %in% c("IA", "MI", "MN", "WI"))] <- "East North Central"
  region_ind[which(region_ind %in% c("AZ", "CO", "NM", "UT"))] <- "Southwest"
  region_ind[which(region_ind %in% c("MT", "NE", "ND", "SD", "WY"))] <- "West North Central"
  region_ind[which(region_ind %in% c("CA", "NV"))] <- "West"
  region_ind[which(region_ind %in% c("ID", "OR", "WA"))] <- "Northwest"
}else if(regiondef == "georegion"){
  region_ind[which(region_ind %in% c("CT", "ME", "MA", "NH", "RI", "VT"))] <- "I"
  region_ind[which(region_ind %in% c("NJ", "NY"))] <- "II"
  region_ind[which(region_ind %in% c("DE", "DC", "MD", "PA", "VA", "WV"))] <- "III"
  region_ind[which(region_ind %in% c("AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN"))] <- "IV"
  region_ind[which(region_ind %in% c("IL", "IN", "MI", "MN", "OH", "WI"))] <- "V"
  region_ind[which(region_ind %in% c("AR", "LA", "NM", "OK", "TX"))] <- "VI"
  region_ind[which(region_ind %in% c("IA", "KS", "MO", "NE"))] <- "VII"
  region_ind[which(region_ind %in% c("CO", "MT", "ND", "SD", "UT", "WY"))] <- "VIII"
  region_ind[which(region_ind %in% c("AZ", "CA", "NV"))] <- "IX"
  region_ind[which(region_ind %in% c("ID", "OR", "WA"))] <- "X"
}

#if(rr == 1){
#  fadj<-failure*dem_ag*100/dem
#  fadj[which(dem==0)]<-0
#  mapsumup(fadj, "failure AG", configname = configname)
#  fadj<-failure/dem_ur*100/dem
#  fadj[which(dem==0)]<-0
#  mapdata(fadj, "failure UR", configname = configname)
#  fadj<-failure/dem_en*100
#  fadj[which(dem==0)]<-0
#  mapdata(fadj, "failure EN", configname = configname)
#}

