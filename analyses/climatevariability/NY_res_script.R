
# Reservoir maps
map <- map_data("state", region="New York")

#png(paste0('plots/reservoir_map.png'), height = 800, width = 1200)
p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")+
  geom_point(data=resdf_NY, aes(x=lon, y=lat), color='red')+
  ggtitle('NY reservoir map')+
  theme_bw()
print(p)
#dev.off()


p <- ggplot()+
  geom_polygon(data=map, aes(x=long, y=lat, group = group),colour="black", fill="white")

#png(paste0('plots/sd_capture_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf_NY, aes(x=lon, y=lat, colour = log1p(sd_cap), size=log1p(sd_cap)))+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the standard deviation of captures across years')+
  guides(colour=guide_legend(title='Variance across years (log scale)'))+
  guides(size=F)+
  theme_bw()
p1
#dev.off()

#png(paste0('plots/max_capture_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf_NY, aes(x=lon, y=lat, colour = log1p(max_capture)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum capture across years')+
  theme_bw()
p1
#dev.off()

#png(paste0('plots/max_release_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf_NY, aes(x=lon, y=lat, colour = log1p(max_release)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of the maximum release across years')+
  theme_bw()
p1
#dev.off()

which(apply(capture, MARGIN=2, FUN = sum)==max(apply(capture, MARGIN=2, FUN = sum)))
which(apply(release, MARGIN=2, FUN = sum)==min(apply(release, MARGIN=2, FUN = sum)))
resdf$capture2006=capture[,7]
resdf$release2009=capture[,10]

#png(paste0('plots/capture2006_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf_NY, aes(x=lon, y=lat, colour = log1p(capture2006)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of 2006 captures')+
  theme_bw()
p1
#dev.off()

#png(paste0('plots/release2009_map.png'), height = 800, width = 1200)
p1 <- p +
  geom_point(data=resdf_NY, aes(x=lon, y=lat, colour = log1p(release2009)), size=1)+
  scale_colour_gradient(low='blue', high='red')+
  ggtitle('Log1p of 2009 releases')+
  theme_bw()
p1
#dev.off()
