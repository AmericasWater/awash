setwd("~/research/water/awash/analyses/landvalue")

basename = "maxbayesian"
column = "crop"

df <- read.csv(paste0(basename, ".csv")) #"farmvalue-limited.csv") #"farmvalue.csv")
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

ggplot(cnty2.df1, aes(long, lat,group = group)) +
  geom_polygon(aes(fill = crop), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")
ggsave(paste0(basename, ".png"), width=8, height=4)
