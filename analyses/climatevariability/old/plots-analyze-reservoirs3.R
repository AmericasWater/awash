
## Parameters to change
result_path = paste0("C:/Users/luc/Desktop/awash/analyses/climatevariability/", "paleo_yrs_1month/2/")

start_year=1451
end_year=1455
tstep_py=12

## Load libraries and finish set-up
library(PBSmapping)
library(RColorBrewer)
library(dplyr)
library(ggplot2)
library(ggmap)
library(maps)
library(maptools)
library(tmap)      # package for plotting
library(readxl)    # for reading Excel
library(tmaptools) 
data(wrld_simpl)
setwd(result_path)

nyears=end_year-start_year+1
time_ind0 <- 1:(nyears*tstep_py)
dir.create('plots', showWarnings=F)

# - county fips, state fips, region indexes
mastercounties <- read.csv("../../../../data/global/counties.csv")
fips <- matrix(mastercounties$fips, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
time_ind <- t(matrix(time_ind0, nrow = length(time_ind0), ncol = 3109)) %>% as.vector() %>% as.factor()
state_ind <- matrix(mastercounties$state, nrow = 3109, ncol = max(time_ind0)) %>% as.vector()
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

# Read-in reservoir data
resdf <- read.csv("../../../../data/paleo/reservoirs/allreservoirs.csv")

# Read-in results
#captures <- as.matrix(read.csv("captures.csv", header = F)) # reservoir level
#storage <- as.matrix(read.csv("storage.csv", header = F)) # reservoir level
#smax <- matrix(as.matrix(read.csv("storagecapmax.csv", header = F)), nrow = dim(captures)[1], ncol = dim(captures)[2])#*(1-0.05)^12

fmv <- . %>% as.matrix() %>% as.vector()
failure <- read.csv("failuresin.csv", header = F) %>% fmv
#failurecon <- read.csv("failurecon.csv", header = F)

dem_tot=read.csv("dem_tot.csv", header=F)


df <- data.frame(time_ind, fips, state_ind, region_ind, failure, dem_tot)

# _________________________________________________________________________________________
# 1. Timeseries analyses.
# @Luc: add line between the losange
cols <- c("per county"="cyan3","national"="lightsalmon2")
png(file="plots/ts1.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
p
dev.off()

png(file="plots/ts2.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
dev.off()

# @Luc: add line between the losange
png(file="plots/ts3.png", width=700, height=400)
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=mean, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=mean, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Average failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p
dev.off()

png(file="plots/histo.png", width=700, height=400)
p<-ggplot(data = df)+
  facet_wrap(~region_ind) +
  geom_histogram(aes(x = log1p(failure)),binwidth = 1)
p
dev.off()


failure <- read.csv("failuresin.csv", header = F)
source("../../plotting.R")



failure_means=rowMeans(failure)

png(file="plots/map1.png", width=700, height=400)
mapdata(failure_means, varname = "Mean Failure (volume in 1000 m3)",
        breaks=c(0, (max(failure_means)/2), (max(failure_means)*4/5)), 
        limits=c(0,max(failure_means)))
dev.off()
per_cent_failure=100*failure/dem_tot
per_cent_failure[per_cent_failure==Inf]=0

png(file="plots/map2.png", width=700, height=400)
mapdata2(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure")
dev.off()

png(file="plots/map3.png", width=700, height=400)
mapdata(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure",
        breaks=c(0, (max(per_cent_failure, na.rm=T)/2), (max(per_cent_failure, na.rm=T)*4/5)), 
        limits=c(0,max(per_cent_failure, na.rm=T)))
dev.off()



std_failure=apply(failure, MARGIN=1, FUN=sd)
png(file="plots/map_std.png", width=700, height=400)
mapdata(std_failure, varname = "Std of failure", 
        breaks=c(0, (max(std_failure, na.rm=T)/2), (max(std_failure, na.rm=T)*4/5)), 
        limits=c(0,max(std_failure, na.rm=T)))
dev.off()

# png(file="plots/example.png", width=700, height=400)
# for (t in c(1:max(time_ind0))){
#   mapdata(failure[,t], varname = paste("t =",t), 
#           breaks=c(0, (median(failure)/2), (mean(failure)*4/5)), 
#           limits=c(0,max(failure)))
# }
# dev.off()






















