setwd("~/research/awash/prepare/evaporation")

df <- read.csv("../../analyses/gaugecompare/optimizes-monthly.csv")
startmonth <- 673

source("../../../water/network4/discharges.R", chdir=T)
df$observed <- NA

numdone <- 0
for (gauge in unique(df$gauge)) {
    numdone <- numdone + 1
    print(numdone / 22559)
    dfrows <- which(df$gauge == gauge)
    parts <- strsplit(as.character(gauge), "\\.")[[1]]
    if (parts[1] %in% c("rivdis", "usgs")) {
        values <- get.flow.data(parts[1], parts[2])
        if (class(values) == "logical")
            next
        starttime <- (1950 - 1960) * 12 - 3 + startmonth - 1
        maxtime <- max(values$time)
        if (starttime >= maxtime)
            next
        for (time in 1:60) {
            df$observed[dfrows[time]] <- values$flow[values$time == starttime]
            starttime <- starttime + 1
            if (starttime > maxtime)
                break
        }
    }
}

df$observed <- df$observed * 60 * 60 * 24 * 365 / 1000 # 1000 m^3
df$observed <- df$observed / 12

load("../../../water/temps/temps.RData")
temps2005 <- temps[(temps$year > 2005 & !(temps$year == 2010 & temps$month > 9)) | (temps$year == 2005 & temps$month >= 10),]

df$observed.up <- 0
df$flows_rfwr.up <- 0
df$tempsum <- 0
df$distsum <- 0
df$upstreamnum <- 0
for (ii in 1:nrow(network)) {
    print(ii)
    if (ii == 6528)
        next # inf loop
    
    upstream <- paste0(network$collection[ii], '.', network$colid[ii])
    if (sum(!is.na(df$observed[df$gauge == upstream])) == 0)
        next
    ## Find the next observed downstream
    distance <- network$dist[ii]
    jj <- network$nextpt[ii]
    downstream <- paste0(network$collection[jj], '.', network$colid[jj])
    while (!is.na(jj) && sum(!is.na(df$observed[df$gauge == downstream])) == 0) {
        print(downstream)
        distance <- distance + network$dist[jj]
        jj <- network$nextpt[jj]
        downstream <- paste0(network$collection[jj], '.', network$colid[jj])
    }
    if (is.na(jj))
        next

    ## Fill in the data
    uprows <- which(df$gauge == upstream)
    downrows <- which(df$gauge == downstream)
    df$observed.up[downrows] <- df$observed.up[downrows] + df$observed[uprows]
    df$flows_rfwr.up[downrows] <- df$flows_rfwr.up[downrows] + df$flows_rfwr[uprows]
    
    uptempdf <- temps2005[temps2005$collection == network$collection[ii] & temps2005$colid == network$colid[ii],]
    downtempdf <- temps2005[temps2005$collection == network$collection[jj] & temps2005$colid == network$colid[jj],]

    df$tempsum[downrows] <- df$tempsum[downrows] + (uptempdf$tas + downtempdf$tas) / 2
    df$distsum[downrows] <- df$distsum[downrows] + distance
    df$upstreamnum[downrows] <- df$upstreamnum[downrows] + 1
}

df$distance <- df$distsum / df$upstreamnum
df$temp <- df$tempsum / df$upstreamnum

## Version 1

df$modeldiff <- df$flows_rfwr - .99 * df$flows_rfwr.up / df$upstreamnum
df$unexplain <- df$observed - df$modeldiff
df$deltaunexplain <- df$observed - df$modeldiff - df$observed.up / df$upstreamnum

df$logunexplain <- log(df$unexplain)
df$logunexplain[!is.finite(df$logunexplain)] <- NA
df$logobserved.up <- log(df$observed.up / df$upstreamnum)
df$logobserved.up[!is.finite(df$logobserved.up)] <- NA
df$logdistance <- log(df$distsum / df$upstreamnum)
df$logdistance[!is.finite(df$logdistance)] <- NA
df$logtemp <- log(df$tempsum / df$upstreamnum)
df$logtemp[!is.finite(df$logtemp)] <- NA

summary(lm(logunexplain ~ logobserved.up + logdistance + logtemp, data=df))

df$deltaunexplain <- df$observed - df$modeldiff - df$observed.up / df$upstreamnum
df$logdeltaunexplain <- log(-df$deltaunexplain) # - so get diminishment
df$logdeltaunexplain[!is.finite(df$logdeltaunexplain)] <- NA

summary(lm(logdeltaunexplain ~ logobserved.up + logdistance + logtemp, data=df))

df$ratiounexplain <- (df$observed - df$modeldiff) / (df$observed.up / df$upstreamnum)
df$logratiounexplain <- log(df$ratiounexplain)
df$logratiounexplain[!is.finite(df$logratiounexplain)] <- NA

summary(lm(logratiounexplain ~ logdistance + logtemp, data=df))

df$delrayunexplain <- (df$observed - df$modeldiff - df$observed.up / df$upstreamnum) / (df$observed.up / df$upstreamnum)
quantile(df$delrayunexplain, na.rm=T)
df$delrayunexplain[df$delrayunexplain > 0] <- NA
df$logdelrayunexplain <- log(-df$delrayunexplain) # - so get diminishment
df$logdelrayunexplain[!is.finite(df$logdelrayunexplain)] <- NA

summary(lm(logdelrayunexplain ~ logdistance + logtemp, data=df)) ## preferred

summary(lm(logdelrayunexplain ~ logtemp, data=df))

df$loglogdist <- log(df$logdist)
df$loglogdist[!is.finite(df$loglogdist)] <- NA

summary(lm(logdelrayunexplain ~ loglogdist * logtemp, data=df))

df$modelratio <- df$flows_rfwr / (.99 * df$flows_rfwr.up / df$upstreamnum)
df$modelratio[!is.finite(df$modelratio) | abs(df$modelratio) > 1e2] <- NA
df$logmodelratio <- log(df$modelratio)
df$logmodelratio[!is.finite(df$logmodelratio)] <- NA
df$logobserved <- log(df$observed)
df$logobserved[!is.finite(df$logobserved)] <- NA

summary(lm(logobserved ~ logobserved.up + logmodelratio + logdistance + logtemp, data=df))

df$delmor <- (df$observed - df$observed.up * df$modelratio) / (df$observed.up * df$modelratio)
df$delmor[df$delmor > 0] <- NA
df$logdelmor <- log(-df$delmor) # - so get diminishment
df$logdelmor[!is.finite(df$logdelmor)] <- NA

summary(lm(logdelmor ~ logdistance + logtemp, data=df))

mod <- lm(logdelrayunexplain ~ logdistance + logtemp, data=df)

preddf <- expand.grid(temp=seq(1, 40, length.out=100), dist=exp(seq(log(1000), log(1e5), length.out=100)))
preddf$logdistance <- log(preddf$dist)
preddf$logtemp <- log(preddf$temp)

preddf$effect <- 1 - predict(mod, preddf)
preddf$effect[preddf$effect < 0] <- 0
preddf$effect[preddf$effect > 1] <- 1

library(ggplot2)

ggplot(preddf, aes(temp, dist, fill=effect)) +
    geom_raster() + scale_y_log10(expand=c(0, 0)) +
    scale_x_continuous(expand=c(0, 0)) +
    xlab("Temperature (C)") + ylab("Distance (m)") +
    scale_fill_gradient2(name="Fraction", limits=c(0, 1), low='#800026', mid='#ffffcc', high='#081d58', midpoint=.5)

library(stargazer)

stargazer(mod, single.row=T)

## Version 2: f model0 + delta = observed1

df$modeldiff <- df$flows_rfwr - .99 * df$flows_rfwr.up / df$upstreamnum
df$lhs <- (df$flows_rfwr + df$modeldiff - df$observed) / df$flows_rfwr
df$lhs[df$lhs < 0] <- NA
df$lhs[df$lhs > 1] <- 1
df$loglhs <- log(df$lhs)
df$loglhs[!is.finite(df$loglhs)] <- NA

df$logdistance <- log(df$distsum / df$upstreamnum)
df$logdistance[!is.finite(df$logdistance)] <- NA
df$logtemp <- log(df$tempsum / df$upstreamnum)
df$logtemp[!is.finite(df$logtemp)] <- NA

mod <- lm(loglhs ~ logdistance + logtemp, data=df)
