setwd("~/research/water/awash/analyses/landvalue")

df <- read.csv("farmvalue-limited.csv") #"farmvalue.csv")

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
  geom_polygon(aes(fill = profitsource), colour = rgb(1,1,1,0.2))  +
    coord_quickmap() + theme_minimal()
ggsave("farmvalue-limited.png", width=8, height=4)
