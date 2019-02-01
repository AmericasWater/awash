# Script to analyze the water stress indeces
setwd("~/AW-julia/awash/analyses/papers/")
setwd("~/Google Drive/AWASH/awash/analyses/papers")
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
# 1. Yearly failure analysis
# build the dataframe.
if(ismultiyr){
df <- melt(apply(result[2:4,,,,], c(1,2,3,5), sum))}else{
  df <- melt(apply(result[2:4,,,], c(1,3,2,4), sum))  
}
names(df) <- c("variable","year","fips","scenario","volume")

state_ind <- df$fips
for(cc in 1:dim(mc)[1]){
  state_ind[which(df$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}
source("../loadingregion.R")

df <- cbind(df, region_ind)
names(df) <- c("variable","year","fips","scenario","volume","region")


##### Boxplot of yearly failure
dfbx <- aggregate(volume~year+scenario+variable, sum, data=df)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario, ordered = TRUE)
h <- ggplot(dfbx, aes(scenario, volume))
#print(h+geom_boxplot(aes(fill=variable)))
print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ variable, nrow = 3, scales = "free"))

if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_nat.png"), device=png, width=wdtp_s)}

# facet per region
dfbx <- aggregate(volume~year+scenario+variable+region, sum, data=df)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario, ordered = TRUE)
dfbx$region <- factor(dfbx$region, levels = c("Southeast","Southwest","East North Central","Central","South","West","West North Central","Northwest","Northeast"), ordered = TRUE)
h <- ggplot(dfbx, aes(scenario, volume))
print(h+geom_boxplot(aes(fill=region)) + facet_wrap( ~ variable, nrow = 3, scales = "free"))

h <- ggplot(dfbx, aes(scenario, volume))
print(h+geom_boxplot(aes(fill=scenario)) + facet_grid(variable ~ region, scales = "free", margins = F))


if(printplots){dev.print(file=paste0(savingresultspath, "bxplot_reg.png"), device=png, width=wdtp_lg)}


##### Timeseries of yearly Failure
p <- ggplot(data=df,aes(x=year, y=volume)) +
  stat_summary(fun.y=sum, geom="line",  aes(colour=scenario, linetype = scenario)) +
  labs(title="Failure to meet water demand", x="year", y=paste("volume", unitvol))
#print(p)
#print(p + facet_grid(variable ~ scenario, scales = "free_y"))
print(p + facet_wrap(~ variable, scales = "free"))
#print(p + facet_wrap(~ scenario, scales = "free"))

if(printplots){dev.print(file=paste0(savingresultspath, "time_nat.png"), device=png, width=wdtp_s)}

# facet per region
print(p + facet_grid(variable ~ region, scales = "free"))
if(printplots){dev.print(file=paste0(savingresultspath, "time_reg.png"), device=png, width=wdtp_lg)}


# _________________________________________________________________________________________
# 2. Seasonnal analysis
dffmonth <- melt(result[4,,,,])
names(dffmonth) <- c("year","fips","month","scenario","failure")

state_ind <- dffmonth$fips
for(cc in 1:dim(mc)[1]){
  state_ind[which(dffmonth$fips==mc$fips[cc])] <- as.character(mc$state[cc])
}
source("../loadingregion.R")

dffmonth <- cbind(dffmonth, region_ind)
names(dffmonth) <- c("year","fips","month","scenario","failure","region")
#dffmonth$month <- factor(dffmonth$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
#dffmonth$scenario <- factor(dffmonth$scenario, levels = c("w/o canal, w/o res", "w/ canal, w/o res", "w/ canal, w/ res") ,ordered = TRUE)

##### Boxplot of monthly failure
dfbx <- aggregate(failure~year+month+scenario, sum, data=dffmonth)
dfbx$month <- factor(dfbx$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario ,ordered = TRUE)
h <- ggplot(dfbx, aes(month, failure))
print(h+geom_boxplot(aes(fill=scenario)))
if(printplots){dev.print(file=paste0(savingresultspath, "season_nat.png"), device=png, width=wdtp_s)}

##### Boxplot of monthly failure per region
dfbx <- aggregate(failure~year+month+scenario+region, sum, data=dffmonth)
dfbx$month <- factor(dfbx$month, levels = c("Oct","Nov","Dec","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep"),ordered = TRUE)
dfbx$scenario <- factor(dfbx$scenario, levels = namescenario ,ordered = TRUE)
h <- ggplot(dfbx, aes(month, failure))
print(h+geom_boxplot(aes(fill=scenario)) + facet_wrap( ~ region, ncol = 3))
if(printplots){dev.print(file=paste0(savingresultspath, "season_reg.png"), device=png, width=wdtp_lg)}






# _________________________________________________________________________________________
# 3. Maps.
## MAPPING mean and std SW and Failure maps
namescenario <- paste0(vreval, "reservoir",vrights)
setwd("..")
source("plotting.R")
setwd("paper2")

if(tokm3){unitvol <- "[km3 yr]"
}else{unitvol <- "[1000m3 yr]"}


if(ismultiyr){
  for(rr in 1:length(vrights)){for(vv in c(4)){
    mapsumup(apply(result[vv,,,,rr], c(2,1), sum), valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}else{
  for(rr in 1:length(vrights)){for(vv in c(4)){
      mapsumup(result[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],unitvol), configname = namescenario[rr])
  }}
}
