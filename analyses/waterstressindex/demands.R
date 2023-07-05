setwd("~/research/water/awash/analyses/waterstressindex")

df <- read.csv("demands.csv")
df.monthly <- subset(df, scale == 'monthly' & timestep <= 12)
df.annual <- subset(df, scale == 'annual' & timestep == 1)

df.monthly$swannual <- rep(df.annual$swdemand, 12)
df.monthly$allannual <- rep(df.annual$alldemand, 12)
df.monthly$month <- c('Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep')[df.monthly$timestep]
df.monthly$month <- factor(df.monthly$month, levels=c('Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'))

library(ggplot2)

ggplot(df.monthly, aes(month, swdemand / swannual)) +
    geom_boxplot() + geom_hline(yintercept=1/12) +
    theme_bw() + xlab(NULL) + ylab("Monthly demand (fraction of annual)")

ggplot(df.monthly, aes(month, alldemand / allannual)) +
    geom_boxplot() + geom_hline(yintercept=1/12) +
    theme_bw() + xlab(NULL) + ylab("Monthly demand (fraction of annual)")
