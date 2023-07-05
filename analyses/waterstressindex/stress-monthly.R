setwd("~/research/water/awash/analyses/waterstressindex")
library(dplyr)
library(ggplot2)
library(maps)

do.commonbias <- T

source("vsenv-lib.R")

df <- read.csv("demands.csv")
df <- subset(df, scale == "monthly")
df <- df %>% left_join(read.csv("../../data/counties/county-info.csv"), by=c('fips'='FIPS'))

if (do.commonbias) {
    flowdf.sw <- read.csv("results/stress-monthly-withres.csv")
    flowdf.sw$timestep <- (flowdf.sw$startyear - 1949) * 12 + flowdf.sw$time

    ## Plot the bias correction
    df2 <- df %>% left_join(flowdf.sw)

    df$commonbias <- df2$supersource

    df2$failurefrac.correct <- pmin(df2$supersource / df2$alldemand, 1)

    df3 <- df2 %>% group_by(fips) %>% summarize(failurefrac.correct.median=median(failurefrac.correct, na.rm=T), failurefrac.correct.worst=max(failurefrac.correct, na.rm=T))

    gl <- rasterGrob(readPNG("failfrac-legend.png"), interpolate=TRUE)
    gg <- gg.usmap(df3$failurefrac.correct.median, df3$fips, df3$failurefrac.correct.worst, extra.polygon.aes=aes(size=borders)) +
        scale_fill_gradientn(name="Correction\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_colour_gradientn(name="Correction\nFraction", colours=c("#91bfdb", "#ffffe5", "#fe9929", "#662506"), values=c(0, .001, .5, 1), labels = scales::percent, limits=c(0, 1)) +
    scale_size(range=c(0, .5)) + guides(size=F) +
        theme(legend.justification=c(1,0), legend.position=c(1,0),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              axis.text.x=element_blank(), axis.text.y=element_blank(),
              plot.margin=unit(rep(0, 4), "cm")) + scale_x_continuous(expand=c(0, 0)) + scale_y_continuous(expand=c(0, 0))
    hh <- ggdraw(gg)
    hh + draw_grob(gl, 0.05, 0.02, 0.22, 0.2)
    ggsave("biascorrect.pdf", width=5.9, height=3.2)
}

for (suffix in c('nores-nocanal', 'nores', 'withres')) {
    flowdf.all <- read.csv(paste0("results/stress-monthly-alldemand-", suffix, ".csv"))
    flowdf.sw <- read.csv(paste0("results/stress-monthly-", suffix, ".csv"))
    flowdf <- flowdf.all %>% left_join(flowdf.sw, by=c('startyear', 'fips', 'time'), suffix=c('.all', '.sw'))
    ## Always start with calcs with Oct., and timestep 1 = 10/1949
    flowdf$timestep <- (flowdf$startyear - 1949) * 12 + flowdf$time

    df2 <- df %>% left_join(flowdf)
    if (do.commonbias) {
        df2$supersource.excess <- pmax(0, df2$supersource.all - df2$commonbias)
        df2$failurefrac.excess <- pmin(df2$supersource.excess / df2$alldemand, 1)
        ## 1 - alldemand / (flow + commonbias) = nf.excess
        ## Also, 1 - alldemand / flow = nf.all => flow = alldemand / (1 - nf.all)
        df2$natflowav.excess <- 1 - df2$alldemand / (df2$alldemand / (1 - df2$minefp.all / 100) + df2$commonbias)
    } else {
        df2$supersource.excess <- pmax(0, df2$supersource.all - df2$supersource.sw)
        df2$failurefrac.excess <- pmin(df2$supersource.excess / df2$alldemand, 1)
        ## 1 - alldemand / (flow + ss.sw) = nf.excess
        ## Also, 1 - alldemand / flow = nf.all => flow = alldemand / (1 - nf.all)
        df2$natflowav.excess <- 1 - df2$alldemand / (df2$alldemand / (1 - df2$minefp.all / 100) + df2$supersource.sw)
    }

    df3 <- df2 %>% group_by(fips) %>% summarize(reliability.model=sum(supersource.sw == 0, na.rm=T) / sum(!is.na(supersource.sw)), reliability.excess=sum(failurefrac.excess == 0, na.rm=T) / sum(!is.na(failurefrac.excess)), failurefrac.excess.median=median(failurefrac.excess, na.rm=T), failurefrac.excess.worst=max(failurefrac.excess, na.rm=T), natflowav.excess=median(natflowav.excess, na.rm=T), natflowav.excess.worst=min(natflowav.excess, na.rm=T))

    plot.relity.both(df3$fips, df3$reliability.model, df3$reliability.excess, paste0("monthly-excess-", suffix))
    plot.failavail(df3$fips, df3$failurefrac.excess.median, df3$failurefrac.excess.worst, df3$natflowav.excess, df3$natflowav.excess.worst, paste0("monthly-excess-", suffix))

    write.csv(df2[, c('timestep', 'fips', 'supersource.sw', 'supersource.excess', 'failurefrac.excess', 'natflowav.excess')], paste0("fipstime-monthly-excess-", suffix, ".csv"), row.names=F)

    df2$yearoct <- floor(df2$timestep / 12) + 1949
    df4 <- df2 %>% group_by(yearoct, fips) %>% summarize(failurefrac.excess.worst=max(failurefrac.excess), natflowav.excess.worst=min(natflowav.excess))

    df5 <- df4 %>% group_by(fips) %>% summarize(failurefrac.excess.worstbest=min(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstbest=max(natflowav.excess.worst, na.rm=T), failurefrac.excess.worstmedian=median(failurefrac.excess.worst, na.rm=T), natflowav.excess.worstmedian=median(natflowav.excess.worst, na.rm=T))

    df6 <- df3 %>% left_join(df5)
    write.csv(df6, paste0("byfips-monthly-excess-", suffix, ".csv"), row.names=F)

    ## Numbers for paper
    df.byyear <- df2 %>% group_by(floor(timestep / 12 - 1)) %>% summarize(numstressed=sum(failurefrac.excess > 0, na.rm=T) / length(unique(timestep)), unmet=sum(failurefrac.excess * alldemand, na.rm=T) / sum(alldemand, na.rm=T))
    print(c(suffix, median(df.byyear$numstressed) / length(unique(df2$fips)), median(df.byyear$unmet)))
}
