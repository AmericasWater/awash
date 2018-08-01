setwd("~/research/water/awash/analyses/waterstressindex")

source("vsenv-lib.R")

demanddf <- read.csv("../../data/counties/extraction/USGS-2010.csv")

srcname <- "annual-worst" #"annual"

get.terms <- function(filename, demand) {
    df <- read.csv(paste0("results/", filename))

    supersources <- split.fipsyears(df$supersource, max)
    minefps <- split.fipsyears(df$minefp, min)

    demand[demand == 0] <- 1

    minefps$median <- minefps$median - 3 # Turn into "just before failure"
    minefps$worst <- minefps$worst - 3 # Turn into "just before failure"

    list(fips=df$fips[1:3109], failfrac=pmin(supersources$median / demand, 1),
         failfrac.worst=pmin(supersources$worst / demand, 1),
         natflowa=minefps$median / 100,
         natflowa.worst=minefps$worst / 100)
}

save.demandsw <- demanddf$TO_SW * 1383 + .001
terms0 <- get.terms(paste0("stress-", srcname, "-nores.csv"), save.demandsw)
plot.failavail(terms0$fips, terms0$failfrac, terms0$failfrac.worst, terms0$natflowa, terms0$natflowa.worst, paste0(srcname, "-nores"))

save.demand <- demanddf$TO_To * 1383 + .001
terms1 <- get.terms(paste0("stress-", srcname, "-alldemand-nores.csv"), save.demand)
plot.failavail(terms1$fips, terms1$failfrac, terms1$failfrac.worst, terms1$natflowa, terms1$natflowa.worst, paste0(srcname, "-alldemand-nores"))

terms1$natflowa[terms1$natflowa == .34] <- 0
terms1$natflowa.worst[terms1$natflowa.worst == .34] <- 0
plot.failavail(terms0$fips, pmax(0, (save.demand * terms1$failfrac - save.demandsw * terms0$failfrac) / save.demand), pmax(0, (save.demand * terms1$failfrac.worst - save.demandsw * terms0$failfrac.worst) / save.demand), terms1$natflowa + (1 - terms0$natflowa), terms1$natflowa.worst + (1 - terms0$natflowa.worst), paste0(srcname, "-excess-nores"))

## Look at all differences

infix <- "annual-worst-" #"annual-alldemand-" #""
demand <- demanddf$TO_SW * 1383 + .001 #demanddf$TO_To * 1383 + .001

df <- read.csv(paste0("stress-", infix, "nores-nocanal.csv"))
supersources1 <- split.fipsyears(df$supersource, max)
minefps1 <- split.fipsyears(df$minefp, min)

df <- read.csv(paste0("stress-", infix, "nores.csv"))
supersources2 <- split.fipsyears(df$supersource, max)
minefps2 <- split.fipsyears(df$minefp, min)

df <- read.csv(paste0("stress-", infix, "withres.csv"))
supersources3 <- split.fipsyears(df$supersource, max)
minefps3 <- split.fipsyears(df$minefp, min)

deltass12.median <- (supersources1$median - supersources2$median) / demand
deltass12.worst <- (supersources1$worst - supersources2$worst) / demand
deltame12.median <- (minefps1$median - minefps2$median) / 100
deltame12.worst <- (minefps1$worst - minefps2$worst) / 100

deltass32.median <- (supersources3$median - supersources2$median) / demand
deltass32.worst <- (supersources3$worst - supersources2$worst) / demand
deltame32.median <- (minefps3$median - minefps2$median) / 100
deltame32.worst <- (minefps3$worst - minefps2$worst) / 100

colorscale.ss <- matrix(c(5,113,176, # Blue
                         146,197,222,
                         247,247,247, # White
                         244,165,130,
                         202,0,32), 3, 5) # Red
colorscale.me <- matrix(c(123,50,148, # Purple
                          194,165,207,
                          247,247,247, # White
                          166,219,160,
                          0,136,55), 3, 5) # Green

get.color2d <- function(delta.ss, delta.me) {
    color.ss <- get.smoothcolor(delta.ss, colorscale.ss)
    color.me <- get.smoothcolor(delta.me, colorscale.me)
    color <- rep(255, 3) - (rep(255, 3) - color.ss) - (rep(255, 3) - color.me)
    color <- pmin(pmax(color, 0), 255)
    rgb(color[1] / 255, color[2] / 255, color[3] / 255)
}

get.smoothcolor <- function(delta, colorscale) {
    if (delta > .1)
        get.color.wavg(colorscale[, 4], colorscale[, 5], (delta - .1) / .9) # Red/Purple-side
    else if (delta >= 0)
        get.color.wavg(rep(255, 3), colorscale[, 4], delta / .1)
    else if (delta > -.1)
        get.color.wavg(rep(255, 3), colorscale[, 2], delta / -.1)
    else
        get.color.wavg(colorscale[, 2], colorscale[, 1], (-delta - .1) / .9) # Blue/Green-side
}

get.color.wavg <- function(col1, col2, weight2) {
    col1 * (1 - weight2) + col2 * weight2
}

legenddf <- data.frame(delta.ss=c(), delta.me=c(), col=c())
for (delta.ss in c(-1, -.5, -.1, -.05, 0, .05, .1, .5, 1))
    for (delta.me in c(-1, -.5, -.1, -.05, 0, .05, .1, .5, 1)) {
        if ((delta.ss < 0 && delta.me < 0) || (delta.ss > 0 && delta.me > 0))
            legenddf <- rbind(legenddf, data.frame(delta.ss, delta.me, col='#A0A0A0'))
        else
            legenddf <- rbind(legenddf, data.frame(delta.ss, delta.me, col=get.color2d(delta.ss, delta.me)))
    }

legenddf$delta.ss <- factor(legenddf$delta.ss, levels=c(-1, -.5, -.1, -.05, 0, .05, .1, .5, 1))
legenddf$delta.me <- factor(legenddf$delta.me, levels=c(-1, -.5, -.1, -.05, 0, .05, .1, .5, 1))

ggplot(legenddf, aes(delta.me, delta.ss, fill=col)) +
    geom_tile() + scale_fill_identity() + guides(fill=F) +
    ylab("Change in failure fraction") + xlab("Change in natural flow available")

color12.median <- rep(NA, 3109)
color12.worst <- rep(NA, 3109)
color32.median <- rep(NA, 3109)
color32.worst <- rep(NA, 3109)
for (ii in 1:3109) {
    color12.median[ii] <- get.color2d(deltass12.median[ii], deltame12.median[ii])
    color12.worst[ii] <- get.color2d(deltass12.worst[ii], deltame12.worst[ii])
    color32.median[ii] <- get.color2d(deltass32.median[ii], deltame32.median[ii])
    color32.worst[ii] <- get.color2d(deltass32.worst[ii], deltame32.worst[ii])
}

source("~/projects/research-common/R/ggmap.R")

gl <- rasterGrob(readPNG("legend2d.png"), interpolate=TRUE)

gg <- gg.usmap(color12.median, df$fips[1:3109], color12.worst, extra.df.cols=data.frame(size=1*(color12.worst != "#FFFFFF")), extra.polygon.aes=aes(size=size), statecol="#80808080") +
    scale_fill_identity(name="Failure\nFraction") +
    scale_colour_identity(name="Failure\nFraction") +
    scale_size(range=c(0, .5)) + guides(size=F) +
    theme(panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
          axis.text.x=element_blank(), axis.text.y=element_blank(),
          plot.margin=unit(rep(0, 4), "cm")) +
    scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
hh <- ggdraw(gg)
hh + draw_grob(gl, .74, 0.0, 0.3, 0.3)
ggsave(paste0("delta-", infix, "nocanal.pdf"), width=5.9, height=3.2)

gg <- gg.usmap(color32.median, df$fips[1:3109], color32.worst, extra.df.cols=data.frame(size=1*(color32.worst != "#FFFFFF")), extra.polygon.aes=aes(size=size), statecol="#80808080") +
    scale_fill_identity(name="Failure\nFraction") +
    scale_colour_identity(name="Failure\nFraction") +
    scale_size(range=c(0, .5)) + guides(size=F) +
    theme(panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
          axis.text.x=element_blank(), axis.text.y=element_blank(),
          plot.margin=unit(rep(0, 4), "cm")) +
    scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
hh <- ggdraw(gg)
hh + draw_grob(gl, .74, 0.0, 0.3, 0.3)
ggsave(paste0("delta-", infix, "withres.pdf"), width=5.9, height=3.2)

## Time-series comparison

library(dplyr)
library(ggplot2)

infix <- "" #"alldemand-"

df <- cbind(data.frame(assump="Default"), read.csv(paste0("stress-annual-", infix, "nores.csv")))
df <- rbind(df, cbind(data.frame(assump="Storage"), read.csv(paste0("stress-annual-", infix, "withres.csv"))))
df <- rbind(df, cbind(data.frame(assump="No canals"), read.csv(paste0("stress-annual-", infix, "nores-nocanal.csv"))))

timedf <- df %>% group_by(time, assump) %>% summarize(supersource=sum(supersource), minefp=mean(minefp))

ggplot() +
    geom_line(data=timedf, aes(time + 1949, supersource, colour=assump)) +
    theme_minimal() + scale_colour_discrete(name="Assumption") +
    xlab(NULL) + ylab("Demand Failure (1000 m^3)")
ggsave(paste0("time-failfrac-annual-", infix, "compare.pdf"), width=7, height=4)

mean(timedf$supersource[timedf$assump == "With Res."] / timedf$supersource[timedf$assump == "No Res."])
mean(timedf$supersource[timedf$assump == "No Canals"] / timedf$supersource[timedf$assump == "No Res."])

ggplot() +
    geom_line(data=timedf, aes(time + 1948, minefp, colour=assump)) +
    theme_minimal() + scale_colour_discrete(name="Assumption") +
    xlab(NULL) + ylab("Average natural flow (1000 m^3)")
ggsave(paste0("time-natflowa-annual-", infix, "compare.pdf"), width=7, height=4)

## Time-series by region

infix <- "" #"alldemand-"

df <- cbind(data.frame(assump="Default"), read.csv(paste0("stress-annual-", infix, "nores.csv")))
df <- rbind(df, cbind(data.frame(assump="Storage"), read.csv(paste0("stress-annual-", infix, "withres.csv"))))
df <- rbind(df, cbind(data.frame(assump="No canals"), read.csv(paste0("stress-annual-", infix, "nores-nocanal.csv"))))

source("../papers/loadingregion.R")
