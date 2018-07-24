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

# - failure filename
filename <- "failure.csv"

# - time
time_ind0 <- 1:11
time_ind <- t(matrix(time_ind0, nrow = length(time_ind0), ncol = 3109)) %>% as.vector() %>% as.factor()

# - county fips, state fips, region index
mastercounties <- read.csv("../../data/global/counties.csv")
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
fmv <- . %>% as.matrix() %>% as.vector()
failure <- read.csv(filename, header = F) %>% fmv

# - water demand
dem_tot <- read.csv("dem_tot.csv", header = F) %>% fmv
#dem_tot=c(dem_tot, rep(1, (37308-34199)))
# form the dataset
df <- data.frame(time_ind, fips, state_ind, region_ind, failure, dem_tot)

# _________________________________________________________________________________________
# 1. Timeseries analyses.
# @Luc: add line between the losange
cols <- c("per county"="cyan3","national"="lightsalmon2")
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(name="", values=cols) + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
p


# @Luc: add line between the losange?
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
  geom_line(aes(colour="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(colour="national")) +
  stat_summary(fun.y=sum, geom="path",  aes(colour="national"), size=1, group = 1) +
  scale_colour_manual(values=cols, name="") + 
  labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
p


# @Luc: add line between the losange
p<-ggplot(data=df,aes(x=time_ind, y=failure)) +
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
# @Luc: histogram de la failure par region ...

# _________________________________________________________________________________________
# 3. Maps.
failure <- read.csv(filename, header = F)
source("plotting.R")

failure_means=rowMeans(failure)
mapdata(failure_means, varname = "Mean Failure (volume in 1000 m3)",
        breaks=c(0, (max(failure_means)/2), (max(failure_means)*4/5)), 
        limits=c(0,max(failure_means)))

per_cent_failure=100*failure/dem_tot
per_cent_failure[per_cent_failure==Inf]=0
mapdata2(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure")
mapdata(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure",
        breaks=c(0, (max(per_cent_failure, na.rm=T)/2), (max(per_cent_failure, na.rm=T)*4/5)), 
        limits=c(0,max(per_cent_failure, na.rm=T)))

std_failure=apply(failure, MARGIN=1, FUN=sd)
mapdata(std_failure, varname = "Std of failure", 
        breaks=c(0, (max(std_failure, na.rm=T)/2), (max(std_failure, na.rm=T)*4/5)), 
        limits=c(0,max(std_failure, na.rm=T)))

# _________________________________________________________________________________________
# 4. Animations.

#png(file="example%02d.png", width=700, height=400)
for (t in c(1:max(time_ind0))){
  mapdata(failure[,t], varname = paste("t =",t), 
          breaks=c(0, (median(failure)/2), (mean(failure)*4/5)), 
          limits=c(0,max(failure)))
}
#dev.off()
# should be compiled in a gif using: convert -delay 80 *.png failure.gif
# @Luc: would you know how to set the scale so that it is the same on all plots = max(failure)?