setwd("~/research/water/awash6/analyses/uncinvest")

decrease <- read.csv("decrease-bycost.csv")

library(ggplot2)

ggplot(decrease, aes(scale, decrease)) +
    geom_line() + scale_y_log10() + scale_x_log10(breaks=c(1e8, 1e9))

decrease$factscale <- factor(decrease$scale, levels=sort(decrease$scale))

ggplot(decrease, aes(factscale, decrease)) +
    geom_bar(stat="identity") + theme_bw() + ggtitle("Optimal removal vs. costs") +
    xlab("Scaling for costs") + ylab("Removal capacity (1000 m^3)")
