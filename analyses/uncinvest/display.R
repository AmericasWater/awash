setwd("~/research/water/awash6/analyses/uncinvest")

decrease <- read.csv("decrease-bycost.csv")

library(ggplot2)

ggplot(decrease, aes(scale, decrease)) +
    geom_line() + scale_y_log10() + scale_x_log10(breaks=c(1e8, 1e9))

decrease$factscale <- factor(decrease$scale, levels=sort(decrease$scale))

alldf <- data.frame(factscale=rep(decrease$factscale, 2), decrease=c(decrease$decrease, -decrease$increase), group=rep(c("Decrease", "Increase"), each=nrow(decrease)))

ggplot(alldf, aes(factscale, decrease, fill=group)) +
    geom_bar(stat="identity") + theme_bw() + ggtitle("Optimal removal vs. costs") +
    xlab("Scaling for costs") + ylab("Removal capacity (1000 m^3)")
