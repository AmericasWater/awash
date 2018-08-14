setwd("~/research/awash/analyses/vsenvstress")

df <- read.csv("vsenv-basic.csv")

vsenv <- .1 * (apply(df[, c(-1, -2)], 1, function(x) min(which(x > 0))) - 1)
vsenv <- matrix(vsenv, 3109, 61)
vsenv[vsenv > 1] <- 1
vsenv.mean <- apply(vsenv, 1, mean)
vsenv.min <- apply(vsenv, 1, min)

source("~/projects/research-common/R/ggmap.R")

gg.usmap(vsenv.mean, df$fips[1:3109]) +
    scale_fill_gradient2(name="Maximum\nSupportable\nEnv. Flow", low="#d7191c", mid="#ffffbf", high="#2c7bb6", midpoint=.5, labels = scales::percent) + coord_map("albers", lat0=39, lat1=45) +
theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("vsenv-nores-mean.pdf", width=7, height=4)

gg.usmap(vsenv.min, df$fips[1:3109]) +
    scale_fill_gradient2(name="Maximum\nSupportable\nEnv. Flow", low="#d7191c", mid="#ffffbf", high="#2c7bb6", midpoint=.5, labels = scales::percent) + coord_map("albers", lat0=39, lat1=45) +
theme(legend.justification=c(1,0), legend.position=c(1,0))
ggsave("vsenv-nores-min.pdf", width=7, height=4)
