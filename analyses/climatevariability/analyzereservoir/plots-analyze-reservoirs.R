# Script to analyze the reservoirs results
captures <- as.matrix(read.csv("captures.csv", header = F))
storage <- as.matrix(read.csv("storage.csv", header = F))
smax <- matrix(as.matrix(read.csv("storagecapmax.csv", header = F)), nrow = dim(captures)[1], ncol = dim(captures)[2])#*(1-0.05)^12
failuresin <- read.csv("failuresin.csv", header = F)
failurecon <- read.csv("failurecon.csv", header = F)


# prep
release <- captures
release[which(release > 0)] <- 0
proprel <- release/smax
proprel[which(smax == 0)] <- 0
hist(rowSums(proprel), breaks = 1000)
#rowSums(proprel)

capture <- captures
capture[which(capture < 0)] <- 0
propcapture <- capture/smax
propcapture[which(smax == 0)] <- 0
hist(propcapture, breaks = 100)
sum(rowMeans(propcapture)<0.01)/length(rowMeans(propcapture))*100
mpctcap <- 100*rowMeans(propcapture)

# plotting reservoir curves
plot(storage[1,]/smax[1,], ylim = c(0, 1.1), type = "l", xlab = "month", ylab = "proportion storage")
for(tt in 2:2671){lines(storage[tt,]/smax[tt,])}
plot(colSums(storage/smax))
plot(captures[1,]/smax[1,], ylim = c(-1.1, 1.1), type = "l", xlab = "month", ylab = "proportion capture")
for(tt in 2:2671){lines(captures[tt,]/smax[tt,])}


resdf <- read.csv("../../../data/counties/reservoirs/allreservoirs.csv")
plot(resdf$lon, resdf$lat)
smx <- smax[,1]
res_df <- cbind(resdf, mpctcap, smx)
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
ggplot(res_df, aes(lon, lat, size = log1p(smx), col = mpctcap)) + 
  #  geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='#2166ac', fill=NA) +
  labs(subtitle="One year",
       title="Bubble chart")+
  geom_point()

plot(log1p(smx), mpctcap)
hist(mpctcap, breaks = 50)


