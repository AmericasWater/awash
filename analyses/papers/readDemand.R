### DEMAND
# total demand volume annual
usgsdem <- read.csv("../../../data/counties/extraction/USGS-2010.csv", header = T)
usgsdem[,8:31] <- usgsdem[,8:31] * 1383./ttperyy
if(screenplots){
  if(tokm3){
    mapdata(usgsdem$TO_To/1e6, "demand [km3/yr]")
  }else{
    mapdata(usgsdem$TO_To, "demand [1000 m3/yr]")
  }
  if(printplots){dev.print(file=paste0(savingresultspath, "demtot.png"), device=png, width=widthplots)}
  
  if(tokm3){
    mapdata(usgsdem$TO_To/1e6, "demand [km3/yr]", transtype = "log1p")
    if(printplots){dev.print(file=paste0(savingresultspath, "demtot.png"), device=png, width=widthplots)}
  }
}

# sectoral demand map %
dem_do <- usgsdem$DO_To
dem_ps <- usgsdem$PS_To
dem_ur <- (dem_do+dem_ps)/dem
dem_ur[which(dem==0)] <- 0
dem_in <- usgsdem$IN_To
dem_ir <- usgsdem$IR_To
dem_li <- usgsdem$LI_To
dem_ag <- (dem_ir+dem_li)/dem
dem_ag[which(dem==0)] <- 0
dem_th <- usgsdem$PT_To
dem_en <- (dem_th)/dem
dem_en[which(dem==0)] <- 0
dem_ec <- (dem_in)/dem
dem_ec[which(dem==0)] <- 0

if(screenplots){
  mapdata(dem_ag*100, "% agriculture")
  if(printplots){dev.print(file=paste0(savingresultspath, "demagprop.png"), device=png, width=widthplots)}
  mapdata(dem_ur*100, "% urban")
  if(printplots){dev.print(file=paste0(savingresultspath, "demurprop.png"), device=png, width=widthplots)}
  mapdata(dem_en*100, "% energy")
  if(printplots){dev.print(file=paste0(savingresultspath, "demenprop.png"), device=png, width=widthplots)}
  mapdata(dem_ec*100, "% industry")
  if(printplots){dev.print(file=paste0(savingresultspath, "deminprop.png"), device=png, width=widthplots)}
}