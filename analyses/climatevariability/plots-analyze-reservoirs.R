# Script to analyze the reservoirs results

resdf <- read.csv("../../prepare/reservoirs/allreservoirs.csv")
dim(resdf)
dim(captures)
plot(resdf$lon, resdf$lat)

c <- captures[1:2667,] 
s <- storage[1:2667,]
smax <- smax[1:2667,]
smeanpct <- rowMeans(s)*100/smax
hist(smax)

sum(smax<s[,2])
hist((smax-s[,4])/smax,breaks = 200)

res_df <- cbind(resdf, c, s, smax, smeanpct)
failure_df <- cbind(v_FIPS,rowSums(failurecon), rowSums(failuresin))
names(failure_df) <- c("fips", "fcon", "fsin")
# density plots to have the failure histograms for the three set-ups
g <- ggplot(failure_df, aes(fcon))
g  + 
  labs(title="Density plot", 
       subtitle="City Mileage Grouped by Number of cylinders",
       caption="Source: mpg",
       x="City Mileage",
       fill="# Cylinders")


# Scatterplot
theme_set(theme_bw())  # pre-set the bw theme.
g <- ggplot(res_df, aes(lon, lat, size = log1p(smax), col = log1p(smeanpct))) + 
  #  geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
  labs(subtitle="mpg: Displacement vs City Mileage",
       title="Bubble chart")+
  geom_point()
print(g)

# FIGURE OUT WAS WRONG WITH RESERVOIRS LEVELS - WAY TOO HIGH!
# ADD STATE BOUNDARIES ON TOP
# CHANGE ALL OF THE LEGENDS AND LABELS
# ANIMATE THIS FIGURE


g <- ggplot(gapminder, aes(gdpPercap, lifeExp, size = pop, frame = year)) +
  geom_point() +
  geom_smooth(aes(group = year), 
              method = "lm", 
              show.legend = FALSE) +
  facet_wrap(~continent, scales = "free") +
  scale_x_log10()  # convert to log scale

gganimate(g, interval=0.2)


