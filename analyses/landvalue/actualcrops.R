setwd("~/research/awash/analyses/landvalue")

do.cropdrop <- T

df <- read.csv("../../prepare/agriculture/all2010.csv")
if (do.cropdrop)
    df <- subset(df, Commodity %in% c("BARLEY", "CORN", "COTTON", "RICE", "SOYBEANS", "WHEAT"))

df$value <- as.numeric(gsub(",", "", as.character(df$Value)))
df$fips <- df$State.ANSI * 1000 + df$County.ANSI
df$fips[is.na(df$fips)] <- df$State.ANSI[is.na(df$fips)] * 1000

results <- data.frame(fips=c(), maxcrop=c())
for (fipsii in unique(df$fips)) {
    subdf <- subset(df, fips == fipsii)
    rows <- grep("ACRES", subdf$Data.Item)
    best <- rows[subdf$value[rows] == max(subdf$value[rows])][1]
    results <- rbind(results, data.frame(fips=fipsii, maxcrop=subdf$Commodity[best]))
}

library(dplyr)
library(maps)

data(county.fips)

results2 <- county.fips %>% left_join(results)
results2$maxcrop <- as.character(results2$maxcrop)
results2$maxcrop.before <- results2$maxcrop

for (stateii in floor(results2$fips / 1000)) {
    maxcrop <- as.character(results$maxcrop[results$fips == 1000 * stateii])
    if (length(maxcrop) > 0)
        results2$maxcrop[is.na(results2$maxcrop) & floor(results2$fips / 1000) == stateii] <- maxcrop
}

write.csv(results2, "actualcrops.csv", row.names=F)

cnty <- map_data("county")

cnty2 <- cnty %>%
    mutate(polyname = paste(region,subregion,sep=",")) %>%
    left_join(results2, by="polyname")

library(ggplot2)

ggplot(cnty2, aes(long, lat, group = group)) +
    geom_polygon(aes(fill = maxcrop))  +
    coord_quickmap() + theme_minimal() + xlab("") + ylab("")
if (do.cropdrop) {
    ggsave("maxcrop-limited.png", width=10, height=5)
} else {
    ggsave("maxcrop.png", width=10, height=5)
}

