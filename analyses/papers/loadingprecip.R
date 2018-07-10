library(ncdf4)

vic<-nc_open("../../../data/cache/counties/VIC_WB.nc")

#attributes(vic)
#print(vic)

#attributes(vic$var)$names
precip <- ncvar_get(vic, "precip")
FIPS <- ncvar_get(vic, "state_fips")*1000+ncvar_get(vic, "county_fips")
precip[which(is.na(precip))] <- 0

rsum.cumsum <- function(x, n = 3L) {tail(cumsum(x) - cumsum(c(rep(0, n), head(x, -n))), -n + 1)}

rain <- matrix(nrow = length(fips), ncol = yearstot)
for(ff in 1:length(fips)){
  rain[ff,] <- rsum.cumsum(precip[,which(FIPS == fips[ff])], 12)[seq(1,yearstot*12,12)]
}
rain[which(is.na(rain))] <- 0

Rain <- result[1,,,]
Rain_var <- result[1,,,]
for(ss in 1:length(vrights)){Rain[,,ss] <- rain}
for(ss in 1:length(vrights)){
  Rain_var[,,ss] <- (rain - rowMeans(rain))/rowMeans(rain)
  Rain_var[which(rowSums(rain)==0),,ss] <- 0
}
