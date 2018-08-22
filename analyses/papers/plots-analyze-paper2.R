# Script to analyze the water stress indeces
setwd("~/AW-julia/awash/analyses/papers/paper2")

reval <- "zero"
flowprop <- c("0.0","0.37","0.5")
ee <- 3
yearstot <- 1
ismultiyr <- F
ttperyy <- 2


widthplots <- 800
printplots <- F
screenplots <- T
setwd("..")
source("plotting.R")
setwd("paper2")


vrights <- c("-SWGW","-SW","-GW","-norightconst")
voptim <- c("conj","conj","conj","conj")
vreval <- c("zero","zero","zero","zero")
namescenario <- paste0(voptim, vrights)

source("../readAWASHresults.R")

tokm3 <- T
if(tokm3){
  result <- result *1e-6
  ylb <- "[km3/yr]"
}else{ylb<- "[1000m3/yr]"}




source("../readDemand.R")


############################### WHAT PLOT
## MAPPING mean and std SW, GW and Failure maps
if(ismultiyr){
  for(rr in 1:length(vrights)){for(vv in 2:4){
    if(tokm3){
      mapsumup(result[vv,,,,rr], valeurname = paste(dimnames(result)[[1]][vv],"[km3/yr]"), configname = namescenario[rr])
    }else{
      mapsumup(result[vv,,,,rr], valeurname = paste(dimnames(result)[[1]][vv],"[1000m3/yr]"), configname = namescenario[rr])}
  }}
}else{
  for(rr in 1:length(vrights)){for(vv in 2:4){
    if(tokm3){
      mapsumup(result[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],"[km3/yr]"), configname = namescenario[rr])
    }else{
      mapsumup(result[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],"[1000m3/yr]"), configname = namescenario[rr])
    }
  }}
}

# FAILURE maps per sector
if(ismultiyr){

}else{
  vv <- 3
    if(tokm3){
      mapsumup(result[vv,,,rr]*dem_ag, valeurname = paste(dimnames(result)[[1]][vv],"AG [km3/yr]"), configname = namescenario[rr])
      mapsumup(result[vv,,,rr]*dem_ur, valeurname = paste(dimnames(result)[[1]][vv],"UR [km3/yr]"), configname = namescenario[rr])
      mapsumup(result[vv,,,rr]*dem_ec, valeurname = paste(dimnames(result)[[1]][vv],"EN [km3/yr]"), configname = namescenario[rr])
    }else{
      mapsumup(result[vv,,,rr], valeurname = paste(dimnames(result)[[1]][vv],"[1000m3/yr]"), configname = namescenario[rr])
    }
}
  
############################### Temporal variability
## comparison of the scenarios nationaly
par(mfrow=c(2,1))
colscenario = 1:4
for(vv in 3:4){
  plot(apply(result[vv,,,1], 2, sum), ylim = c(0, max(apply(result[vv,,,], c(2,3), sum))), type="l", col=colscenario[1], ylab = "volume", xlab ="timestep")
  for(rr in 2:length(vrights)){
    lines(apply(result[vv,,,rr], 2, sum), col=colscenario[rr])
  }
  title(dimnames(result)[[1]][vv])
}

# facet per region

# facet per sector
      


# build the dataframe. 



# failure, month, year, region.

# - month
month_ind0 <- c("Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep")
month_ind <- rep(as.vector(t(matrix(month_ind0, nrow = 12, ncol=3109))),yearstot) %>% as.factor()
years_ind <- t(matrix(1:yearstot, nrow = yearstot, ncol = 3109*12)) %>% as.vector() %>% as.factor()

# - county fips, state fips, region index
mastercounties <- read.csv("../../data/global/counties.csv")
fips <- matrix(mastercounties$fips, nrow = 3109, ncol = yearstot*12) %>% as.vector()
state_ind <- matrix(mastercounties$state, nrow = 3109, ncol = yearstot*12) %>% as.vector()
region_ind <- state_ind
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


# - failure matrix, swsupply matrix, gwsupply matrix
failure <- as.vector(resspace[5,,,,1])

# - water demand
dem_tot <- as.vector(resspace[1,,,,1])
#dem_tot=c(dem_tot, rep(1, (37308-34199)))
# form the dataset
df <- data.frame(month_ind, years_ind, fips, state_ind, region_ind, failure, dem_tot)

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





if(screenplots){
  fadj<-apply(resspace[5,,,,rr],c(2,1),sum)/apply(resspace[1,,,,rr],c(2,1),sum)*100
  fadj[which(apply(resspace[1,,,,rr],c(2,1),sum)==0)]<-0
  mapsumup(fadj, "pct failure", configname = configname)
  gwadj<-apply(resspace[3,,,,rr],c(2,1),sum)/apply(resspace[1,,,,rr],c(2,1),sum)*100
  gwadj[which(apply(resspace[1,,,,rr],c(2,1),sum)==0)]<-0
  mapsumup(gwadj, "pct GW", configname = configname)
  
}





cols <- c("per county"="cyan3","national"="lightsalmon2")
p<-ggplot(data=df,aes(x=years_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
p

cols <- c("per county"="cyan3","national"="lightsalmon2")
p<-ggplot(data=df,aes(x=month_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
p


# @Luc: add line between the losange?
p<-ggplot(data=df,aes(x=month_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p

p<-ggplot(data=df,aes(x=years_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p


# @Luc: add line between the losange
p<-ggplot(data=df,aes(x=years_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=mean, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=mean, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Average failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
p<-ggplot(data=df,aes(x=month_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=mean, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=mean, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Average failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
# _________________________________________________________________________________________
# 2. Histograms.
p<-ggplot(data = df)+
  facet_wrap(~region_ind) +
  geom_histogram(aes(x = log1p(failure)),binwidth = 1)
p


p<-ggplot(data = df)+
  facet_wrap(~years_ind) +
  geom_histogram(aes(x = log1p(failure)),binwidth = 1)
p


p<-ggplot(data = df)+
  facet_wrap(~month_ind) +
  geom_histogram(aes(x = log1p(failure)),binwidth = 1)
p


theme = theme_set(theme_minimal())
theme = theme_update(legend.position="top", legend.title=element_blank(), panel.grid.major.x=element_blank())

#Data
boxplot = ggplot(df, mapping=aes(y = failure, x = month_ind))



#Stylized Boxplot
boxplot = boxplot + geom_boxplot(outlier.colour = NULL) + # geom_boxplot(notch=T) to compare groups
  stat_summary(geom = "crossbar", width=0.65, fatten=0, color="white", fun.data = function(x){ return(c(y=median(x), ymin=median(x), ymax=median(x))) })


#Different Scale Per Facet
boxplot = boxplot + facet_wrap(~ region_ind, nrow = 1, scales="free")
#Same Scale Per Facet
boxplot = boxplot + facet_grid(facets = ". ~ region_ind")

boxplot

ggplot(df, aes(x=month_ind, y=failure, fill="orange")) + 
  geom_boxplot()
ggplot(df, aes(x=region_ind, y=failure, fill="orange")) + 
  geom_boxplot()
ggplot(df, aes(x=years_ind, y=failure, fill="orange")) + 
  geom_boxplot()
# _________________________________________________________________________________________
# 3. Maps.
failure <- read.csv(filename, header = F)
