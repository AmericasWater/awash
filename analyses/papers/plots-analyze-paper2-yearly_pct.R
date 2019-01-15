# Script to analyze the water stress indeces
setwd("~/AW-julia/awash/analyses/papers/")
#setwd("~/Google Drive/AWASH/awash/analyses/papers")
setwd("paper2-yearly/")
suffix <- "-1"
require("ggplot2")
require("reshape")

flowprop <- c("0.0","0.37","0.5")
ee <- 3
yearstot <- 60
ismultiyr <- F
ttperyy <- 1

regiondef <- "climateregion"

widthplots <- 800
wdtp_s <- 500
wdtp_lg <- 800
printplots <- T
screenplots <- T
theme_set(theme_bw())
theme_update(legend.position="bottom")



vrights <- c("-SWGW","-GW","-SW","-norightconst")
voptim <- c("conj","conj","conj","conj")
vreval <- c("zero","zero","zero","zero")
namescenario <- c("SWGW","GW","SW","no")

source("../readAWASHresults.R")

tokm3 <- T
if(tokm3){
  result <- result *1e-6
  unitvol <- "[km3/yr]"
}else{unitvol <- "[1000m3/yr]"}



#source("../readDemand.R")



# _________________________________________________________________________________________
# 1. Distribution analysis
# build the dataframe.
if(ismultiyr){
df <- melt(apply(result[2:4,,,,], c(1,2,3,5), sum))}else{
  result_ <- result
  result_[2,,,] <- result_[2,,,]/result_[1,,,]
  result_[3,,,] <- result_[3,,,]/result_[1,,,]
  result_[4,,,] <- result_[4,,,]/result_[1,,,]
  result_[which(is.na(result_))] <- 0
  result_ <- result_*100
  df <- melt(apply(result_[2:4,,,], c(1,3,2,4), sum))
}
names(df) <- c("variable","year","fips","scenario","percent")

state_ind <- df$fips
for(cc in 1:dim(mc)[1]){
  state_ind[which(df$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}
source("../loadingregion.R")

df <- cbind(df, region_ind)
names(df) <- c("variable","year","fips","scenario","percent","region")


##### Boxplot of yearly failure
dfbx <- aggregate(percent~year+scenario+variable, mean, data=df)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario, ordered = TRUE)
h <- ggplot(dfbx, aes(scenario, percent))
#print(h+geom_boxplot(aes(fill=variable)))
#print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ variable, nrow = 3, scales = "free"))

print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ variable, ncol = 3, scales = "free"))

if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_nat.png"), device=png, width=wdtp_s)}

# facet per region
dfbx <- aggregate(percent~year+scenario+variable+region, mean, data=df)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario, ordered = TRUE)
dfbx$region <- factor(dfbx$region, levels = c("Southeast","Southwest","East North Central","Central","South","West","West North Central","Northwest","Northeast"), ordered = TRUE)
#h <- ggplot(dfbx, aes(scenario, percent))
#print(h+geom_boxplot(aes(fill=region)) + facet_wrap( ~ variable, nrow = 3, scales = "free"))

h <- ggplot(dfbx, aes(scenario, percent))
print(h+geom_boxplot(aes(fill=scenario)) + facet_grid(variable ~ region, scales = "free", margins = F))


if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_reg.png"), device=png, width=wdtp_lg)}


##### Timeseries of yearly Failure
p <- ggplot(data=df,aes(x=year, y=percent)) +
  stat_summary(fun.y=mean, geom="line",  aes(colour=scenario, linetype = scenario)) +
  labs(title="Failure to meet water demand", x="year", y=paste("percentage"))
#print(p)
#print(p + facet_grid(variable ~ scenario, scales = "free_y"))
print(p + facet_wrap(~ variable, scales = "free"))
#print(p + facet_wrap(~ scenario, scales = "free"))

if(printplots){dev.print(file=paste0(savingresultspath, "time_nat.png"), device=png, width=wdtp_s)}

# facet per region
print(p + facet_grid(variable ~ region, scales = "free"))
if(printplots){dev.print(file=paste0(savingresultspath, "time_reg.png"), device=png, width=wdtp_lg)}

# _________________________________________________________________________________________
# Timeseries of absolute values
df <- melt(apply(result[2:4,,,], c(1,3,2,4), sum))
names(df) <- c("variable","year","fips","scenario","volume")
df <- cbind(df, region_ind)
names(df) <- c("variable","year","fips","scenario","volume","region")


##### Timeseries of yearly Failure
p <- ggplot(data=df,aes(x=year, y=volume)) +
  stat_summary(fun.y=sum, geom="line",  aes(colour=scenario, linetype = scenario)) +
  labs(title="Failure to meet water demand", x="year", y=paste("volume", unitvol))
#print(p)
#print(p + facet_grid(variable ~ scenario, scales = "free_y"))
print(p + facet_wrap(~ variable, scales = "free"))
#print(p + facet_wrap(~ scenario, scales = "free"))

if(printplots){dev.print(file=paste0(savingresultspath, "time_abs_nat.png"), device=png, width=wdtp_s)}

# facet per region
print(p + facet_grid(variable ~ region, scales = "free"))
if(printplots){dev.print(file=paste0(savingresultspath, "time_abs_reg.png"), device=png, width=wdtp_lg)}


# _________________________________________________________________________________________
# 3.
dfst <- melt(apply(result[2,,,], c(2,1,3), sum))
dfst_ <- melt(apply(result[3,,,], c(2,1,3), sum))
dfst_r <- melt(apply(Rain_var[,,], c(2,1,3), sum))
dfst <- cbind(dfst, dfst_$value, dfst_r$value)
names(dfst) <- c("year","fips","scenario","SW", "GW", "precip")
state_ind <- dfst$fips
for(cc in 1:dim(mc)[1]){
  state_ind[which(dfst$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}
source("../loadingregion.R")

dfst <- cbind(dfst, region_ind)
names(dfst) <- c("year","fips","scenario","SW", "GW","precip","region")

dfsty <- aggregate(.~year+scenario, sum, data=dfst)
p <- ggplot(data=dfsty,aes(x=SW, y=GW)) + geom_point(aes(colour=precip)) + scale_color_gradient2(midpoint=0, low="blue", mid="yellow", high="red", space ="Lab" )
#  labs(title="Failure to meet water demand")#, x="SW", y=paste("volume", unitvol))
#print(p)
print(p + facet_wrap(~ scenario, scales = "free"))


dfsty <- aggregate(.~year+region, mean, data=dfst)
p <- ggplot(data=dfsty,aes(x=year, y=precip)) + geom_line(aes(colour=region))
#  labs(title="Failure to meet water demand")#, x="SW", y=paste("volume", unitvol))
#print(p)
print(p + facet_wrap(~ region, scales = "free"))

dfsty <- aggregate(.~year+scenario+region, sum, data=dfst)
p <- ggplot(data=dfsty,aes(x=SW, y=GW)) + geom_point(aes(colour=precip)) +scale_color_gradientn(colours = rainbow(5))

if(printplots){dev.print(file=paste0(savingresultspath, "time_abs_nat.png"), device=png, width=wdtp_s)}

#print(p + facet_wrap(~ region, scales = "free"))
print(p + facet_grid(scenario ~ region, scales = "free"))


if(printplots){dev.print(file=paste0(savingresultspath, "time_abs_reg.png"), device=png, width=wdtp_lg)}

# _________________________________________________________________________________________
# 4. Maps.
## MAPPING mean and std SW and Failure maps
namescenario <- paste0(vreval, "reservoir",vrights)
setwd("..")
source("plotting.R")
setwd("paper2-yearly")

if(tokm3){unitvol <- "[km3 yr]"
}else{unitvol <- "[1000m3 yr]"}


if(ismultiyr){
  for(rr in 1:length(vrights)){for(vv in c(3,4)){
    mapsumup(apply(result_[vv,,,,rr], c(2,1), sum), valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}else{
  for(rr in 1:length(vrights)){for(vv in c(3,4)){
      mapsumup(result_[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}
#vv <- 4
#for(ss in c(1,3,2,4)){
#mapdata(apply(result_[vv,,,ss],1,max), paste(dimnames(result)[[1]][vv], "S",ss))}





#usgs <- read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)
#sw <- sum(usgs$TO_SW)* 1383/ttperyy*1e-6
#gw <- sum(usgs$TO_GW)* 1383/ttperyy*1e-6
#tot <- sum(usgs$TO_To)* 1383/ttperyy*1e-6

