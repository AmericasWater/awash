setwd("~/research/awash/analyses/landvalue")

library(dplyr)

df <- read.csv("farmvalue-limited.csv")
df <- df %>% left_join(read.csv("../../data/counties/agriculture/ers/reglink.csv"), by=c("fips"="FIPS"))
ers <- read.csv("../../data/global/ers.csv")

df$erscosts <- NA # Fill in loop

changes <- data.frame()
for (cc in unique(df$estprofitsource)) {
    if (cc == 'none')
        next
    subers <- subset(ers, year == 2010 & crop == as.character(cc) & item == "Total, operating costs")
    if (cc == 'rice')
        subers <- subers[c(1, 2, 4),] # Multiple rows
    subdf <- subset(df, obscrop == cc) %>% left_join(subers, by=c("ABBR"="region"))
    subdf$value[is.na(subdf$value)] <- subers$value[subers$region == 'us']
    df$erscosts[!is.na(df$obscrop) & df$obscrop == cc] <- subdf$value

    ## changes <- rbind(changes, data.frame(crop=cc, assump=c('ERS-only', 'Estimated', '(with Irrig.)'), zeros=c(sum(subdf$toadd == 0, na.rm=T), sum(subdf$esttoadd == 0, na.rm=T), sum(subdf$esttoadd_changeirr == 0, na.rm=T)) / nrow(subdf), change=c(mean(subdf$toadd / subdf$value, na.rm=T), mean(subdf$esttoadd / subdf$value, na.rm=T), mean(subdf$esttoadd_changeirr / subdf$value, na.rm=T))))

    changes <- rbind(changes, data.frame(crop=cc, ers.diff=100 * sum(subdf$toadd > 0, na.rm=T) / nrow(subdf),
                                         est.diff=100 * sum(subdf$esttoadd > 0, na.rm=T) / nrow(subdf),
                                        #est.changeirr.diff=100 * sum(subdf$esttoadd_changeirr > 0, na.rm=T) / nrow(subdf),
                                         ers.change=100 * median((subdf$toadd / subdf$value)[subdf$toadd > 0], na.rm=T),
                                         est.change=100 * median((subdf$esttoadd / subdf$value)[subdf$esttoadd > 0], na.rm=T)))
                                        #est.changeirr.change=100 * mean(subdf$esttoadd_changeirr / subdf$value, na.rm=T)))
}

changes <- rbind(changes, data.frame(crop="All", ers.diff=100 * sum(df$toadd > 0, na.rm=T) / nrow(df),
                                     est.diff=100 * sum(df$esttoadd > 0, na.rm=T) / nrow(df),
                                     ers.change=100 * median((df$toadd / df$erscosts)[df$toadd > 0], na.rm=T),
                                     est.change=100 * median((df$esttoadd / df$erscosts)[df$esttoadd > 0], na.rm=T)))

library(xtable)
print(xtable(changes, digits=0), include.rownames=F)
