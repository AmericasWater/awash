# _________________________________________________________________________________________
######## FAILURE ANALYSIS DASHBOARD
# This piece of code generates the basic plots to interpret the failures outputted by optimize-surface
# _________________________________________________________________________________________
# 0. Loading all the relevant information
# - required packages
require(tidyr)
require(ggplot2)
require(dplyr)
require(reshape2)
require(MatrixStats)
# - failure filename
filename1 <- "failureoptsurface.csv"

# - time
time_ind0 <- 1:10
time_ind <- t(matrix(time_ind0, nrow = length(time_ind0), ncol = 3109)) %>% as.vector() %>% as.factor()

# - county fips, state fips, region index
mastercounties <- read.csv("../../../data/global/counties.csv")
fips <- matrix(mastercounties$fips, nrow = 3109, ncol = length(time_ind0)) %>% as.vector()
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

# - failure matrix, swsupply matrix, gwsupply matrix
fmv <- . %>% as.matrix()
failure <- read.csv(filename1, header = F) %>% fmv

# - water demand
rec_gw <- read.csv("recordedgw_optsurface.csv", header = F) %>% fmv
rec_sw <- read.csv("recordedsw_optsurface.csv", header = F) %>% fmv
rec_tot <- read.csv("recordedtot_optsurface.csv", header = F) %>% fmv
#gw_optall <- read.csv("waterfromgw_optallocation.csv", header = F) %>% fmv
gw_optallsim <- read.csv("waterfromgw_optallocationsim.csv", header = F) %>% fmv
sw_optallsim <- read.csv("waterfromsw_optallocationsim.csv", header = F) %>% fmv
piezohead <- read.csv("piezohead_optallocationsim.csv", header = F) %>% fmv


# _________________________________________________________________________________________
# 1. Maps.
setwd("..")
source("plotting.R")
setwd("analyzeconjunctive/")
# Recorded values
#png(file="recsw.png", width=700, height=400)
mapdata(rowMeans(rec_sw), varname = "recorded SW (volume in 1000 m3)")
#dev.off()
#png(file="recgw.png", width=700, height=400)
mapdata(rowMeans(rec_gw), varname = "recorded GW (volume in 1000 m3)")
#dev.off()
#png(file="rectot.png", width=700, height=400)
mapdata(rowMeans(rec_tot), varname = "recorded Total (volume in 1000 m3)")
#dev.off()
#png(file="recpctsw.png", width=700, height=400)
# Percentage maps recorded values
mapdata(rowMeans(rec_sw/rec_tot)*100, varname = "recorded % SW")
#dev.off()
#png(file="recpctgw.png", width=700, height=400)
mapdata(rowMeans(rec_gw/rec_tot)*100, varname = "recorded % GW")
#dev.off()

# Analyzing the failure to meet SW demands
#png(file="f.png", width=700, height=400)
mapdata(rowMeans(failure), varname = "Failure (volume in 1000 m3)")
#dev.off()
#mapdata(apply(failure, MARGIN=1, FUN=sd)/rowMeans(rec_sw)*100, varname = "% variation")
#png(file="fpct.png", width=700, height=400)
mapdata(rowMeans(failure/rec_sw)*100, varname = "% Failure")
#dev.off()
#png(file="maxfpct.png", width=700, height=400)
mapdata(rowMaxs(failure/rec_sw)*100, varname = "max % Failure")
#dev.off()

# Conjunctive approach analysis
#png(file="gwopt.png", width=700, height=400)
mapdata(rowMeans(gw_optallsim), varname = "GW")
#dev.off()
#png(file="swopt.png", width=700, height=400)
mapdata(rowMeans(sw_optallsim), varname = "SW")
#dev.off()
#png(file="gwdiff.png", width=700, height=400)
mapdata(rowMeans(rec_gw-gw_optallsim), varname = "Change in GW (volume in 1000 m3)")
#dev.off()
#png(file="swdiff.png", width=700, height=400)
mapdata(rowMeans(rec_sw-sw_optallsim), varname = "Change in SW (volume in 1000 m3)")

#dev.off()
##png(file=".png", width=700, height=400)
#mapdata(rowMeans(gw_optallsim/(gw_optallsim+sw_optallsim)*100), varname = "% GW")
##dev.off()
##png(file=".png", width=700, height=400)
#mapdata(rowMeans(sw_optallsim/(gw_optallsim+sw_optallsim)*100), varname = "% SW")
##dev.off()

#mapdata(-as.matrix(piezohead[,10]), varname = "")


# _________________________________________________________________________________________
# 4. Animations.

#png(file="failure%02d.png", width=700, height=400)
for (t in c(1:max(time_ind0))){
  mapdata(failure[,t], varname = paste("t =",t), 
          limits=c(0,max(failure)))
}
#dev.off()
# should be compiled in a gif using: convert -delay 80 *.png failure.gif
# @Luc: would you know how to set the scale so that it is the same on all plots = max(failure)?




# form the dataset
# - failure matrix, swsupply matrix, gwsupply matrix
fmv <- . %>% as.matrix() %>% as.vector()
failure <- read.csv(filename1, header = F) %>% fmv

# - water demand
rec_gw <- read.csv("recordedgw_optsurface.csv", header = F) %>% fmv
rec_sw <- read.csv("recordedsw_optsurface.csv", header = F) %>% fmv
rec_tot <- read.csv("recordedtot_optsurface.csv", header = F) %>% fmv
#gw_optall <- read.csv("waterfromgw_optallocation.csv", header = F) %>% fmv
gw_optallsim <- read.csv("waterfromgw_optallocationsim.csv", header = F) %>% fmv
sw_optallsim <- read.csv("waterfromsw_optallocationsim.csv", header = F) %>% fmv
piezohead <- read.csv("piezohead_optallocationsim.csv", header = F) %>% fmv



df <- data.frame(time_ind, fips, state_ind, region_ind, failure, rec_gw, rec_sw, gw_optallsim, sw_optallsim, piezohead)



# _________________________________________________________________________________________
# 1. Timeseries analyses.
# @Luc: add line between the losange
cols <- c("per county"="cyan3","national"="lightsalmon2","per region"="lightsalmon2")
theme_set(theme_minimal())
#png(file="tnat.png", width=700, height=400)
ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]")
#dev.off()

#png(file="treg.png", width=700, height=400)
ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="per region")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="per region"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind)
#dev.off()







region_ind <- state_ind
region_ind[which(region_ind %in% c("CT", "ME", "MA", "NH", "RI", "VT"))] <- 3
region_ind[which(region_ind %in% c("NJ", "NY"))] <- 10
region_ind[which(region_ind %in% c("DE", "DC", "MD", "PA", "VA", "WV"))] <- 6
region_ind[which(region_ind %in% c("AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN"))] <- 2
region_ind[which(region_ind %in% c("IL", "IN", "MI", "MN", "OH", "WI"))] <- 8
region_ind[which(region_ind %in% c("AR", "LA", "NM", "OK", "TX"))] <- 4
region_ind[which(region_ind %in% c("IA", "KS", "MO", "NE"))] <- 10
region_ind[which(region_ind %in% c("CO", "MT", "ND", "SD", "UT", "WY"))] <- 1
region_ind[which(region_ind %in% c("AZ", "CA", "NV"))] <- 5
region_ind[which(region_ind %in% c("ID", "OR", "WA"))] <- 7

#png(file="regionind.png", width=700, height=400)
mapdata(as.numeric(region_ind), breaks = 1:10, varname = "")
#dev.off()
