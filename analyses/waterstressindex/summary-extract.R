setwd("~/research/water/awash/analyses/waterstressindex/")

df <- read.csv("summary.csv")


sum(df$failfrac.local == 0 & df$failfrac.reservoirs == 0)
sum(df$failfrac.local != 0)
sum(df$failfrac.reservoirs != 0)
sum(df$failfrac.local != 0 | df$failfrac.reservoirs != 0)
sum(df$failfrac.local != 0 & df$failfrac.reservoirs != 0)
sum(df$failfrac.local == 0 & df$failfrac.reservoirs != 0) / sum(df$failfrac.reservoirs != 0)
sum(df$failfrac.local != 0 & df$failfrac.reservoirs == 0) / sum(df$failfrac.local != 0)

plot(hist((df$failfrac.local - df$failfrac.reservoirs)[(df$failfrac.local == 0 & df$failfrac.reservoirs != 0) | (df$failfrac.local != 0 & df$failfrac.reservoirs == 0)]))
