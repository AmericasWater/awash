######## FAILURE ANALYSIS DASHBOARD
# This piece of code generates the basic plots to interpret the failures outputted by optimize-surface

# 0. Loading all the relevant information
# - time
time_ind0 <- 1:12
# - county fips, state fips, region index
mastercounties <- read.csv("../../data/global/counties.csv")
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

# - failure matrix, swsupply matrix, gwsupply matrix
library(dplyr)
fmv <- . %>% as.matrix() %>% as.vector()
failurecon <- read.csv("failurecon.csv", header = F) %>% fmv
failuresin <- read.csv("failuresin.csv", header = F) %>% fmv
failureopt <- read.csv("failuresin.csv", header = F) %>% fmv

# - for sectoral analysis: total demand, each sector demand
dem_ag <- read.csv("dem_ag.csv", header = F) %>% fmv
dem_do <- read.csv("dem_do.csv", header = F) %>% fmv
dem_in <- read.csv("dem_in.csv", header = F) %>% fmv
dem_ur <- read.csv("dem_ur.csv", header = F) %>% fmv
dem_li <- read.csv("dem_li.csv", header = F) %>% fmv
dem_th <- read.csv("dem_th.csv", header = F) %>% fmv
dem_tot <- read.csv("totaldemand.csv", header = F) %>% fmv

# form the dataset
df <- data.frame(time_ind, fips, state_ind, region_ind, failureopt, failuresin, failurecon, dem_ag, dem_do, dem_in, dem_ur, dem_li, dem_th)


# 1. Timeseries analyses.
library(tidyr)
library(ggplot2)

ggplot(df,aes(x=time_ind, y=failurecon)) + geom_line(aes(x=time_ind, y=failurecon, color="with", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1) +
#  stat_summary(fun.y=sum, geom="line", size=1) +
  geom_line(aes(x=time_ind, y=failuresin, col="without", group = fips)) +
  scale_color_discrete(name="Reservoirs") + labs(title="Failure", x="time", y="volume [1000m3]") +
  #facet_wrap(~region_ind) +
  theme_minimal()




ggplot(df,aes(x=time_ind, y=failurecon)) + geom_line(aes(x=time_ind, y=failurecon, color="with", group=fips)) +
  stat_summary(fun.y=sum, geom="point", shape=5, size=1) +
  geom_line(aes(x=time_ind, y=failuresin, col="without", group = fips)) +
  scale_color_discrete(name="Reservoirs") + labs(title="Failure", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) + theme_minimal()

ggplot(df) + geom_line(aes(x=time_ind, y=failurecon-failuresin, color="with", group=fips)) +
  scale_color_discrete(name="Reservoirs") + labs(title="Failure", x="time", y="volume [1000m3]") +
  facet_wrap(~region_ind) + theme_minimal()

ggplot(data = df,
       aes(x = time_ind,
           y = failurecon-failuresin,
           group = fips,
           colour = region_ind)) + geom_point() + theme_classic() + geom_line()



# 2. Histograms.
ggplot(df, aes(time_ind, fill=region_ind) ) +
  geom_bar(position="fill")



ggplot(data = df, aes(x = failurecon), group_by(state_ind)) + geom_histogram()
ggplot(data = df, aes(x = failuresin), group_by(state_ind)) + geom_histogram()

ggplot(data = df, aes(x = state_ind, y = failurecon), group_by(time_ind)) + geom_boxplot()
ggplot(data = df, aes(x = time_ind, y = failurecon)) + geom_boxplot()
ggplot(data = df, aes(x = time_ind, y = failuresin)) + geom_boxplot()
ggplot(data = df, aes(x = time_ind, y = failuresin-failurecon, group = state_ind, color = state_ind)) + geom_boxplot()
ggplot(data = df, aes(x = state_ind, y = failuresin-failurecon, group = time_ind, color = time_ind)) + geom_boxplot()


ggplot(data = df, aes(x = failuresin-failurecon, color = time_ind, group = time_ind)) + geom_density()

ggplot(data = df, aes(x = time_ind, y = failurecon, group = time_ind)) + geom_boxplot()
ggplot(data = df, aes(x = time_ind, y = failuresin, group = time_ind)) + geom_boxplot()

ggplot(data = df, aes(x = time_ind, y = failuresin-failurecon, group = time_ind)) + geom_boxplot()


# 3. Maps.
mapdata(rowMeans(failuresin), varname = "Failure w/o")
mapdata(rowMeans(failurecon), varname = "Failure w/")
mapdata(rowMeans(failurecon - failuresin), varname = "Diff Failure w/ - w/o")

for(f in c(failurecon, failuresin, failureopt)){
  mapdata(rowSums(f*dem_ag/dem_tot, na.rm = T), varname = "Failure Ag")
  mapdata(rowSums(f*dem_th/dem_tot, na.rm = T), varname = "Failure Thermo")
  mapdata(rowSums(f*dem_ur/dem_tot, na.rm = T), varname = "Failure Urban")
  mapdata(rowSums(f*dem_do/dem_tot, na.rm = T), varname = "Failure Dom")
  mapdata(rowSums(f*dem_li/dem_tot, na.rm = T), varname = "Failure livestock")
  mapdata(rowSums(f*dem_in/dem_tot, na.rm = T), varname = "Failure industrial")
  mapdata(rowSums(100*f/dem_tot, na.rm = T), varname = "100% of failure")
}



# 4. Animations.

# http://r-statistics.co/Top50-Ggplot2-Visualizations-MasterList-R-Code.html
# https://plot.ly/ggplot2/animations/





# 5. Interative plots with plotly
# https://plot.ly/r/bubble-maps/ to create the bubble maps



# references
# https://www.r-bloggers.com/ggplot2-themes-examples/ to choose the theme
# http://tutorials.iq.harvard.edu/R/Rgraphics/Rgraphics.html to reproduce economist worthy plots

# horizontal ticks
scale_x_datetime(breaks = date_breaks("6 months"), labels = date_format("%m/%Y")) +
  
  # main y-axis title
  ylab("") +
  
  # main x-axis title
  xlab("") +
  
  # main chart title
  ggtitle(title.string)

