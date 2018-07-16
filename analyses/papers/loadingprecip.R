library(ncdf4)

vic<-nc_open("../../../data/cache/counties/VIC_WB.nc")

#attributes(vic)
#print(vic)

#attributes(vic$var)$names
precip <- ncvar_get(vic, "precip")
runoff <- ncvar_get(vic, "runoff")
FIPS <- ncvar_get(vic, "state_fips")*1000+ncvar_get(vic, "county_fips")
precip[which(is.na(precip))] <- 0
runoff[which(is.na(runoff))] <- 0

rsum.cumsum <- function(x, n = 3L) {tail(cumsum(x) - cumsum(c(rep(0, n), head(x, -n))), -n + 1)}

rain <- matrix(nrow = length(fips), ncol = yearstot)
rnoff <- matrix(nrow = length(fips), ncol = yearstot)
for(ff in 1:length(fips)){
  rain[ff,] <- rsum.cumsum(precip[,which(FIPS == fips[ff])], 12)[seq(1,yearstot*12,12)]
  rnoff[ff,] <- rsum.cumsum(runoff[,which(FIPS == fips[ff])], 12)[seq(1,yearstot*12,12)]
}
rain[which(is.na(rain))] <- 0
rnoff[which(is.na(rnoff))] <- 0

Rain <- result[1,,,]
Rain_var <- result[1,,,]
Runoff <- result[1,,,]
Runoff_var <- result[1,,,]
for(ss in 1:length(vrights)){
  Rain[,,ss] <- rain
  Runoff[,,ss] <- rnoff
  Rain_var[,,ss] <- (rain - rowMeans(rain))/rowMeans(rain)
  Rain_var[which(rowSums(rain)==0),,ss] <- 0
  Runoff_var[,,ss] <- (rnoff - rowMeans(rnoff))/rowMeans(rnoff)
  Runoff_var[which(rowSums(rnoff)==0),,ss] <- 0
  
}


## plotting the weather:
dfr <- melt(Rain[,,1])
dfrvar <- melt(Rain_var[,,1])
dfrf <- melt(Runoff[,,1])
dfrfvar <- melt(Runoff_var[,,1])

dfweather <- cbind(dfr, dfrvar$value, dfrf$value, dfrfvar$value)
names(dfweather)<- c("fips", "year", "rain", "rain_var", "runoff", "runoff_var")


state_ind <- dfweather$fips
for(cc in 1:dim(mc)[1]){state_ind[which(dfweather$fips==mc$fips[cc])] <- as.character(mc$state[cc])}
source("../loadingregion.R")
dfweather <- cbind(dfweather, region_ind)
names(dfweather) <- c("fips", "year", "rain", "rain_var", "runoff", "runoff_var","region")

# What do I want to plot:
# precip per region, rain per region
# same thing with var
# ! runoff may need to be multiplied by contributing area ...

dfw <- aggregate(.~region+year, sum,data=dfweather)
dfw_ <- melt(dfw[,-3], id=c(1:2))
plot(dfw$rain, dfw$runoff)
ggplot(subset(dfw_,variable %in% c("rain" , "runoff")), aes(x=year, y=value)) +geom_line(aes(colour=variable))+facet_grid(~region)
ggplot(subset(dfw_,variable %in% c("rain_var" , "runoff_var")), aes(x=year, y=value)) +geom_line(aes(colour=variable))+facet_grid(~region)


## will need to add these lines on the failure plots in the future.


require(biwavelet)
dftest<-subset(dfw, region %in% "South")

wtrain <- wt(cbind(dftest$year, dftest$rain))
wtrainvar <- wt(cbind(dftest$year, dftest$rain_var))
wtrunoff <- wt(cbind(dftest$year, dftest$runoff))
wtrunoffvar <- wt(cbind(dftest$year, dftest$runoff_var))
par(mfrow = c(2,2))
plot(wtrain, type = "power.corr.norm", main = "rain")
plot(wtrainvar, type = "power.corr.norm", main = "rain var")
plot(wtrunoff, type = "power.corr.norm", main = "runoff")
plot(wtrunoffvar, type = "power.corr.norm", main = "runoff var")
par(oma = c(0, 0, 0, 1), mar = c(5, 4, 4, 5) + 0.1)

plot(wtrain, plot.cb = TRUE, plot.phase = TRUE)
plot(wtrainvar, plot.cb = TRUE, plot.phase = TRUE)
plot(wtrunoff, plot.cb = TRUE, plot.phase = TRUE)
plot(wtrunoffvar, plot.cb = TRUE, plot.phase = TRUE)

# Cross-wavelet
xwtrr <- xwt(cbind(dftest$year, dftest$rain), cbind(dftest$year, dftest$runoff))
xwtrvrv <- xwt(cbind(dftest$year, dftest$rain_var), cbind(dftest$year, dftest$runoff_var))

# Make room to the right for the color bar
par(mfrow=c(2,1))
par(oma = c(0, 0, 0, 1), mar = c(5, 4, 4, 5) + 0.1)
plot(xwtrr, plot.cb = TRUE, plot.phase = TRUE,
     main = "Cross wavelet power and phase difference (arrows)")
plot(xwtrvrv, plot.cb = TRUE, plot.phase = TRUE,
     main = "Cross wavelet power and phase difference (arrows)")



## what I need to do: compare how much of the climate signal stays in the failure, gw and sw use ...
# plot to do : 2x2, runoff, SW, GW, failure - for each scenario.
# plot to do : 2x2 failure for each scenario. 

# other things to do: get rid off additional scenario. just have current, SWGW and no. Also have James' scenario. 

