setwd("~/research/water/awash/analyses/landvalue")

basename = "constopt-currentprofits-pfixed-lybymc"

if (basename %in% c("constopt-futureprofits", "constopt-currentprofits", "constopt-futureprofits-pfixed", "constopt-futureprofits-pfixed-notime", "constopt-currentprofits-pfixed", "constopt-currentprofits-pfixed-lybymc")) {
    column <- "topcrop"
} else if (basename %in% c("maybayesian", "maxbayesian-pfixed", "maxfuture-pfixed", "maxfuture-pfixed-notime", "maxbayesian-pfixed-lybymc")) {
    column <- "crop"
} else {
    column = "crop" #"profitsource"
}

df <- read.csv(paste0(basename, ".csv"))
df$crop <- df[, column]

library(ggplot2)
library(maps)
library(dplyr)

cnty <- map_data("county")

data(county.fips)

cnty2 <- cnty %>%
        mutate(polyname = paste(region,subregion,sep=",")) %>%
    left_join(county.fips, by="polyname")

cnty2.df1 <- inner_join(cnty2, df, by="fips")

gp <- ggplot(cnty2.df1, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = crop), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")
if (basename %in% c("maxfuture-pfixed")) {
    gp <- gp + scale_fill_manual(breaks=c('Barley', 'Cotton', 'Rice', "Soybean"), values=c('#f8766d', '#00ba38', '#00bfc4', '#619cff'))
} else if (basename %in% c("maxfuture-pfixed-notime")) {
    gp <- gp + scale_fill_manual(breaks=c('Barley', 'Rice', "Soybean"), values=c('#f8766d', '#00bfc4', '#619cff'))
} else {
    ##scale_fill_manual(breaks=c('corn', 'rice', 'whea'), labels=c("Corn", "Rice", "Wheat"), values=c('#b79f00', '#00bfc4', '#f564e3'))
    ##scale_fill_manual(breaks=c('corn', 'pean', 'rice', 'whea'), labels=c("Corn", "Peanuts", "Rice", "Wheat"), values=c('#b79f00', '#00be67', '#00bfc4', '#f564e3'))
}
gp
ggsave(paste0(basename, ".png"), width=8, height=4)
