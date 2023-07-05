setwd("~/research/water/awash/analyses/waterstressindex")

library(dplyr)

df <- read.csv("fipstime-monthly-excess-withres.csv")
demand <- read.csv("demands.csv")

df2 <- df %>% left_join(subset(demand, scale == "monthly"))

library(ggplot2)
library(scales)

gp <- ggplot(df2, aes(alldemand - swdemand, supersource.excess)) +
    geom_point(size=.1, alpha=.1) + geom_abline(intercept=0, slope=1, colour=muted("red")) +
    scale_y_log10("Supersource withdrawals (modeled)", limits=c(1, 2e5), expand=c(0, 0)) +
    scale_x_log10("Groundwater withdrawals (USGS)", limits=c(1, 2e5), expand=c(0, 0)) +
    theme_bw()
ggsave("validate-gw.png", gp, width=6, height=5)

