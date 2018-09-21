setwd("~/research/awash/analyses/landvalue")

for (basename in c(paste0("maxbayesian-pfixed", c("", "-2050", "-2070")), "max2050-pfixed", "max2050-pfixed-histco", "max2050-pfixed-notime", "max2050-pfixed-notime-histco", "max2070-pfixed", "max2070-pfixed-histco", "max2070-pfixed-notime", "max2070-pfixed-notime-histco")) {
    ##basename = "constopt-currentprofits-pfixed-2070" #"constopt-all2070profits-pfixed-histco" #"maxbayesian-pfixed-2070" #"max2050-pfixed-histco"

if (startsWith(basename, "constopt")) {
    column <- "topcrop"
} else if (startsWith(basename, "maybayesian") || startsWith(basename, "maxfuture")) {
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
if (length(unique(cnty2.df1$crop)) < 6) {
    breaks <- c()
    values <- c()
    if ('Barley' %in% cnty2.df1$crop) {
        breaks <- 'Barley'
        values <- '#f8766d'
    }
    if ('Cotton' %in% cnty2.df1$crop) {
        breaks <- c(breaks, 'Cotton')
        values <- c(values, '#00ba38')
    }
    if ('Corn' %in% cnty2.df1$crop) {
        breaks <- c(breaks, 'Corn')
        values <- c(values, '#b79f00')
    }
    if ('Rice' %in% cnty2.df1$crop) {
        breaks <- c(breaks, 'Rice')
        values <- c(values, '#00bfc4')
    }
    if ('Soybean' %in% cnty2.df1$crop) {
        breaks <- c(breaks, 'Soybean')
        values <- c(values, '#619cff')
    }
    if ('Wheat' %in% cnty2.df1$crop) {
        breaks <- c(breaks, 'Wheat')
        values <- c(values, '#f564e3')
    }
    gp <- gp + scale_fill_manual(breaks=breaks, values=values)
}
gp
ggsave(paste0(basename, ".png"), width=8, height=4)
}
