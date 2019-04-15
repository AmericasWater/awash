setwd("~/research/water/awash/analyses/landvalue")

library(dplyr)

maps <- c("constopt-currentprofits-pfixmo-chirr.csv", "constopt-all2050profits-pfixmo-notime-histco.csv",
          "constopt-all2070profits-pfixmo-notime-histco.csv")
tcol <- c('bio1_mean', 'bio1_2050', 'bio1_2070')
sname <- c('Current', '2050', '2070')

df <- read.csv("~/Dropbox/Agriculture Weather/us-bioclims-new.csv")
for (year in c(2050, 2070)) {
    sumbio1 <- rep(0, nrow(df))
    countmodels <- 0
    for (model in c("ac", "bc", "cc", "cn", "gf", "gs",
                    "hd", "he", "hg", "in", "ip", "mc",
                    "mg", "mi", "mp", "mr" , "no")) {
        moddf <- read.csv(paste0("~/Dropbox/Agriculture Weather/bioclims-", year, "/", model, "85bi", year - 2000, ".csv"))
        sumbio1 <- sumbio1 + moddf$bio1_mean
        countmodels <- countmodels + 1
    }

    df[, paste0("bio1_", year)] <- sumbio1 / countmodels
}
df$fips <- df$STATE * 100 + df$COUNTY / 10

results <- data.frame()
allres <- data.frame()
for (scenario in 1:3) {
    topcrops <- read.csv(paste0("results/", maps[scenario]))
    topcrops <- topcrops %>% left_join(df)
    ## Determine max crop by 1 C bins

    topcrops$bin <- round(topcrops[, tcol[scenario]] / 5) / 2
    for (bin in unique(topcrops$bin)) {
        results <- rbind(results, data.frame(scenario=sname[scenario], bin, count=sum(topcrops$bin == bin), density=mean(topcrops$bin == bin), topcrop=names(which.max(table(topcrops$topcrop[topcrops$bin == bin])))))
        allres <- rbind(allres, data.frame(scenario=sname[scenario], bin, topcrop=topcrops$topcrop[topcrops$bin == bin]))
    }
}

library(ggplot2)

## breaks <- c()
## values <- c()
## if ('Barley' %in% results$topcrop) {
##     breaks <- 'Barley'
##     values <- '#f8766d'
## }
## if ('Cotton' %in% results$topcrop) {
##     breaks <- c(breaks, 'Cotton')
##     values <- c(values, '#00ba38')
## }
## if ('Corn' %in% results$topcrop) {
##     breaks <- c(breaks, 'Corn')
##     values <- c(values, '#b79f00')
## }
## if ('Rice' %in% results$topcrop) {
##     breaks <- c(breaks, 'Rice')
##     values <- c(values, '#00bfc4')
## }
## if ('Soybean' %in% results$topcrop) {
##     breaks <- c(breaks, 'Soybean')
##     values <- c(values, '#619cff')
## }
## if ('Wheat' %in% results$topcrop) {
##     breaks <- c(breaks, 'Wheat')
##     values <- c(values, '#f564e3')
## }

ggplot(results, aes(bin, count, fill=as.character(topcrop))) +
    facet_grid(scenario ~ .) +
    geom_bar(stat="identity") + theme_bw() +
    xlab("Temperature (C)") + ylab("Counties with average temperature") +
    scale_fill_discrete(name=NULL)
##scale_fill_manual(breaks=breaks, values=values)
ggsave("tempdists.pdf", width=6, height=4)

ggplot(allres[!is.na(allres$topcrop),], aes(bin, fill=as.character(topcrop))) +
    facet_grid(scenario ~ .) +
    geom_bar() + theme_bw() +
    xlab("Temperature (C)") + ylab("Counties with average temperature") +
    scale_fill_discrete(name=NULL)
ggsave("tempdists2.pdf", width=6, height=4)
