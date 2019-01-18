library(maps)
library(PBSmapping)

counties <- map("county", plot=F, fill=T)

data(county.fips)

infos <- read.csv("../../data/counties/county-info.csv")
infos$FIPS <- as.numeric(as.character(infos$FIPS))
infos$elevation <- as.numeric(as.character(infos$Elevation_ft)) * .3048 # convert to m

counties$x <- c(counties$x, NA)
counties$y <- c(counties$y, NA)

nas <- which(is.na(counties$x))
startii <- 1

info <- data.frame(name=c(), fips=c(), cent.x=c(), cent.y=c(), elevation=c())
for (nai in 1:length(nas)) {
  print(nai/length(nas))
  shape <- data.frame(PID=1, X=counties$x[startii:(nas[nai]-1)], Y=counties$y[startii:(nas[nai]-1)])

  if (nrow(shape) == 1)
    centroid <- shape
  else if (nrow(shape) == 2)
    centroid <- data.frame(X=mean(shape$X), Y=mean(shape$Y))
  else {
    shape$POS <- 1:nrow(shape)
    centroid <- calcCentroid(shape, 1)
  }

  fips <- county.fips$fips[county.fips$polyname == counties$names[nai] & !is.na(counties$names[nai])]
  if (length(fips) == 0) {
    fips <- NA
    elevation <- NA
  } else {
    elevation <- infos$elevation[infos$FIPS == fips]
  }

  info <- rbind(info, data.frame(name=counties$names[nai], fips=fips, cent.x=centroid$X, cent.y=centroid$Y, elevation=elevation))

  startii <- nas[nai] + 1
}
