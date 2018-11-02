library(ggplot2)
library(PBSmapping)
library(maptools)


shapes <- importShapefile("../../data/mapping/US_county_2000-simple")
polydata <- attributes(shapes)$PolyData
polydata$STATE <- as.numeric(levels(polydata$STATE))[polydata$STATE]
polydata$COUNTY <- as.numeric(levels(polydata$COUNTY))[polydata$COUNTY]
shapes$id <- polydata$STATE[shapes$PID] * 100 + polydata$COUNTY[shapes$PID] / 10;
names(shapes) <- tolower(names(shapes));

stateshapes <- importShapefile("../../data/mapping/tl_2010_us_state00/tl_2010_us_state00-simple")
statespolydata <- attributes(stateshapes)$PolyData
stateshapes$x <- stateshapes$X
stateshapes$y <- stateshapes$Y
stateshapes$id <- stateshapes$PID


mastercounties <- read.csv("../../data/global/counties.csv")
v_FIPS <- mastercounties$fips


mapdata <- function(vartoplot,varname, transtype='identity', breaks='auto', limits=c(min(vartoplot),max(vartoplot))){
  df <- data.frame(v_FIPS,vartoplot)
  names(df) = c("fips","value")
  
  print(varname)
  gplot <- ggplot(df) +
    geom_map(aes(fill=value, map_id=fips), map=shapes) +
    geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
    expand_limits(x=c(-2300000, 2200000), y=c(-1.3e6, 1.5e6)) +
    theme_classic() + theme(legend.justification=c(0.05,0.05), legend.position=c(0.05,0.05)) #+ xlab('') + ylab('')
  
  if(sum(df$value<0, na.rm = T)>0 & sum(df$value>0, na.rm = T)>0){
      gplot <- gplot + scale_fill_gradient2(name=varname, trans=transtype, breaks=breaks, limits = limits)
    }else{
    if(breaks == 'auto'){ if(transtype == 'identity'){
      gplot <- gplot + scale_fill_gradient(name=varname, trans=transtype, breaks=c(0, signif(max(df$value, na.rm = T)*3/10, digits = 2), signif(max(df$value, na.rm = T)*6/10, digits = 2), signif(max(df$value, na.rm = T)*9/10, digits = 2)), limits=limits)
    }else{
      br = c(0, signif(exp(log(max(df$value, na.rm = T))*3/10), digits = 2), signif(exp(log(max(df$value, na.rm = T))*6/10), digits = 2), signif(exp(log(max(df$value, na.rm = T))*9/10), digits = 2))
      gplot <- gplot + scale_fill_gradient(name=varname, trans=transtype, breaks=br, limits=limits)}   
    }else{
      gplot <- gplot + scale_fill_gradient(name=varname, trans=transtype, breaks=breaks, limits=limits)
    }}

  gplot <- gplot+theme(axis.line=element_blank(),axis.text.x=element_blank(),
        axis.text.y=element_blank(),axis.ticks=element_blank(),
        axis.title.x=element_blank(),
        axis.title.y=element_blank(),#legend.position="none",
#        panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
 #       panel.grid.minor=element_blank(),plot.background=element_blank()
plot.margin=unit(c(0,0,0,0),"mm")) + labs(x=NULL, y=NULL) 
    print(gplot)
}


mapstress <- function(vartoplot,varname){
  stoplot <- vartoplot
  stoplot[which(vartoplot>1)] <- 4
  stoplot[which(vartoplot<=1 & vartoplot>0.6)] <- 3
  stoplot[which(vartoplot<=0.6 & vartoplot>0.3)] <- 2
  stoplot[which((vartoplot<=0.3))] <- 1
  df <- data.frame(v_FIPS,stoplot)
  names(df) = c("fips","value")
  
  
  gplot <- ggplot(df)+
    geom_map(aes(fill=value, map_id=fips), map=shapes) +
    geom_map(data=stateshapes, map=stateshapes, aes(map_id=PID), color='gray', fill=NA) +
    expand_limits(x=c(-2500000, 2500000), y=c(-1.4e6, 1.6e6)) +
    theme_bw() + theme(legend.justification=c(0,0), legend.position=c(0,0)) + xlab('') + ylab('')
  
  gplot <- gplot + scale_fill_gradientn(colours = c("green3", "orange", "red", "brown"),
                                        breaks = c(1, 2, 3, 4), name = varname, na.value = "pink", guide = "legend")#breaks = c(0.5, 1.5, 2.5, 3.5, 4.5), name = varname, na.value = "pink", guide = "legend")

  print(gplot)
}




maptime <- function(valeur, valeurname, configname){
  vallim <- valeur
  if(sum(abs(vallim) ==Inf, na.rm = T)>0){
    vallim[which(abs(vallim) == Inf)] <- NaN}
  limi <- round(c(min((vallim), na.rm = T), max((vallim), na.rm = T)))
  br <- signif(seq(min((vallim), na.rm = T), max((vallim), na.rm = T), (max((vallim), na.rm = T)-min((vallim), na.rm = T))/4),3)
  
  for(tt in 1:yearstot){
    mapdata((valeur[,tt]), paste(valeurname,"year",tt), limits = limi, breaks = br)
    if(printplots){dev.print(file=paste0(savingresultspath, configname, valeurname,"_",tt,".png"), device=png, width=widthplots)}
  }
}

mapsumup <- function(valeur, valeurname, configname, ttype='identity'){
  vallim <- valeur
  if(sum(abs(vallim) ==Inf, na.rm = T)>0){
    vallim[which(abs(vallim) == Inf)] <- NaN}
  limi <- round(c(min((vallim), na.rm = T), max((vallim), na.rm = T)))
  br <- signif(seq(min((vallim), na.rm = T), max((vallim), na.rm = T), (max((vallim), na.rm = T)-min((vallim), na.rm = T))/4),3)
  
  
  mapdata((rowMeans(valeur, na.rm = T)), paste(valeurname,"mean"), limits = limi, breaks = br, transtype = ttype)
  if(printplots){dev.print(file=paste0(savingresultspath, configname, valeurname,"mean.png"), device=png, width=widthplots)}
  
  
  mapdata(apply(valeur, 1, sd, na.rm = T), paste(valeurname,"std"), transtype = ttype)
  if(printplots){dev.print(file=paste0(savingresultspath, configname, valeurname,"std.png"), device=png, width=widthplots)}
}


