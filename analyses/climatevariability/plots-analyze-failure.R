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
filename <- "failuresin_optsur_year2.csv"

# - time
time_ind0 <- 1:12
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
dem_tot <- read.csv("totaldemand.csv", header = F) %>% fmv

# form the dataset
df <- data.frame(time_ind, fips, state_ind, region_ind, failure, dem_tot)

# _________________________________________________________________________________________
# 1. Timeseries analyses.
ggplot(df,aes(x=time_ind, y=failure)) + geom_line(aes(x=time_ind, y=failure, color="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(color="national")) +
  scale_color_discrete(name="Failure") + labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  theme_minimal()
# @Luc: add line between the losange

ggplot(df,aes(x=time_ind, y=failure)) + geom_line(aes(x=time_ind, y=failure, color="per county", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1, aes(color="per region")) +
  scale_color_discrete(name="Failure") + labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
# @Luc: add line between the losange?

ggplot(df,aes(x=time_ind, y=failure)) + geom_line(aes(x=time_ind, y=failure, color="per county", group=fips)) +
  stat_summary(fun.y=mean, geom="point", shape=5, size=1, aes(color="per region")) +
  scale_color_discrete(name="Failure") + labs(title="Failure to meet water demand", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) +
  theme_minimal()
# @Luc: add line between the losange

# _________________________________________________________________________________________
# 2. Histograms.
ggplot(data = df, aes(x = failure, group = region_ind, color = region_ind)) + geom_density()
# @Luc: histogram de la failure par region ...

# _________________________________________________________________________________________
# 3. Maps.
failure <- read.csv(filename, header = F)
source("plotting.R")
mapdata(rowMeans(failure), varname = "Mean Failure")
mapdata(rowSums(100*failure/dem_tot, na.rm = T), varname = "% of failure")


# _________________________________________________________________________________________
# 4. Animations.

#png(file="example%02d.png", width=700, height=400)
for (t in c(1:12)){
  mapdata(failure[,t], varname = paste("t =",t))
}
#dev.off()
# should be compiled in a gif using: convert -delay 80 *.png failure.gif
# @Luc: would you know how to set the scale so that it is the same on all plots = max(failure)?