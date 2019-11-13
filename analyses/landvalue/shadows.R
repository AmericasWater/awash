setwd("~/research/water/awash/analyses/landvalue")

df <- read.csv("results/shadows.csv")
df.map <- df[1:3109,]
df.map$fips <- as.numeric(as.character(df.map$fips))

library(ggplot2)
library(maps)
library(dplyr)

cnty <- map_data("county")
data(county.fips)

cnty2 <- cnty %>%
        mutate(polyname = paste(region,subregion,sep=",")) %>%
    left_join(county.fips, by="polyname")

cnty2.df1 <- inner_join(cnty2, df.map, by="fips")



library(ggnewscale)

isFALSE <- function(x) {
    x == F
}

cnty2.df1$diff <- pmax(0, cnty2.df1$all2070profits.pfixmo.notime.histco - cnty2.df1$currentprofits.pfixmo.chirr)
ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = diff), colour = rgb(1,1,1,0.2))  +
    scale_fill_gradient(low='#a6611a', high='#018571', trans="log") +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")

cnty2.df1$diff <- log(-cnty2.df1$all2070profits.pfixmo.notime.histco) - log(-cnty2.df1$currentprofits.pfixmo.chirr)
cnty2.df1$dclass <- c('planted', 'fallow0', 'fallow1', 'fallow')[2 * (cnty2.df1$all2070profits.pfixmo.notime.histco == 0) + (cnty2.df1$currentprofits.pfixmo.chirr == 0) + 1]
ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = diff), colour = rgb(1,1,1,0.2))  +
    scale_fill_gradient2(low='#a6611a', high='#018571') +
    new_scale_fill() +
    geom_polygon(aes(fill = dclass)) +
    scale_fill_manual(values=c('#808080', '#808080', '#d95f02', '#00000000')) +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")

cnty2.df1$diff <- cnty2.df1$all2070profits.pfixmo.notime.histco / cnty2.df1$currentprofits.pfixmo.chirr
cnty2.df1$dclass <- c('planted', 'fallow0', 'fallow1', 'fallow')[2 * (cnty2.df1$all2070profits.pfixmo.notime.histco == 0) + (cnty2.df1$currentprofits.pfixmo.chirr == 0) + 1]

ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = diff), lwd=0) +
    scale_fill_gradient2(name="Shadow\nRatio", low='#a6611a', high='#018571', trans="log10", breaks=c(.01, .1, 1, 10)) +
    new_scale_fill() +
    geom_polygon(aes(fill = dclass)) +
    scale_fill_manual(values=c('#808080', '#808080', '#d95f02', '#00000000')) +
coord_quickmap() + theme_minimal() + xlab("") + ylab("")

ggsave("shadowmap.pdf", width=8, height=4)
ggsave("shadowmap.png", width=8, height=4)

pts <- cnty2.df1 %>% group_by(group) %>% summarize(long=mean(long), lat=mean(lat), level0=mean(currentprofits.pfixmo.chirr), level1=mean(all2070profits.pfixmo.notime.histco), diff1=mean(all2050profits.pfixmo.notime.histco - currentprofits.pfixmo.chirr), diff2=mean(all2070profits.pfixmo.notime.histco - currentprofits.pfixmo.chirr), logdiff=mean(log(-all2070profits.pfixmo.notime.histco) - log(-currentprofits.pfixmo.chirr)))

ggplot(pts[pts$diff != 0,], aes(lat, diff)) +
    geom_point() + geom_smooth()

pts$latgrp <- factor(floor((pts$lat - min(pts$lat)) / 5))

ggplot(pts[pts$level0 != 0 & pts$lat > 27,], aes(factor(round(lat)), -diff2)) +
    geom_boxplot(outlier.shape = NA) + geom_hline(yintercept=0, colour="#A0A0A0") +
    ylim(-750, 250) + coord_flip() + xlab("Latitude") +
    ylab("Change in shadow price by 2070 ($/Ha)") + theme_bw()

pts2 <- data.frame(latgrp=rep(pts$latgrp[pts$level0 != 0], 2), diff=c(pts$diff1[pts$level0 != 0], pts$diff2[pts$level0 != 0]), period=rep(c('2050', '2070'), each=sum(pts$level0 != 0)))
pts2$latgrp <- factor(pts2$latgrp)

ggplot(pts2, aes(latgrp, diff, fill=period)) +
    geom_boxplot(outlier.shape = NA) + ylim(-300, 500)

ggplot(pts, aes(lat, diff)) +
    geom_point() + scale_y_log10()
ggplot(pts, aes(lat, logdiff)) +
    geom_point() + geom_smooth()

summary(lm(logdiff ~ lat, data=pts[is.finite(pts$logdiff),]))
summary(lm(diff ~ lat, data=pts[pts$diff != 0,]))

df.bycrop <- df[3110:3115, c('fips', 'currentprofits.pfixmo.chirr', 'all2050profits.pfixmo.notime.histco', 'all2070profits.pfixmo.notime.histco')]
names(df.bycrop) <- c("Crop", "Current", "2050", "2070")
df.bycrop[, -1] <- -df.bycrop[, -1]
colSums(df.bycrop[, -1])
