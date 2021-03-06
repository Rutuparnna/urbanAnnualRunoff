# workflow:
# step 0: load scripts
# step 1: build random forest model for image classification and check performance
# step 2: classify image for roofs and streets
# step 3: make overlays for total impervious area, roof and street for each subcatchment
# step 4: compute ABIMO variables PROBAU (%roof), VG (%impervious) and STR_FLGES
# step 5: compute annual climatic values ETP and precipitation
# step 6: use raw code to compute and allocate PROVGU and all other ABIMO variables
# step 7: go to ABIMO and run (could we call it from R?)
# step 8: post-process ABIMO output file -> join it with input shape file for visualization
#         in GIS

#rawdir='Y:/WWT_Department/Projects/KEYS/Data-Work packages/WP2_SUW_pollution_Jinxi/_DataAnalysis/GIS'
#rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataAnalysis/GIS/'
#setwd(rawdir)

# step 0: load scripts
source('C:/Users/rtatmuv/Desktop/R_Development/RScripts/KEYS/imgClass.R')
source('C:/kwb/KEYS/RWorkflows/imgClass.R')
source('C:/kwb/KEYS/RWorkflows/abimo.R')

# step 1: build classification model
buildClassMod(rawdir='Y:/WWT_Department/Projects/KEYS/Data-Work packages/WP2_SUW_pollution_Beijing/_DataAnalysis/GIS',
              image='tz.tif',
              groundTruth='groundtruth2.shp', # column name of surface type in groundTruth must be 'cover'
              spectrSigName='spectrSigTz.Rdata',
              modelName='rForestTz.Rdata',
              overlayExists=TRUE,
              nCores=1,
              mtryGrd=1:3, ntreeGrd=seq(80, 150, by=10),
              nfolds=3, nodesize=1, cvrepeats=2)

# check model performance
load('Y:/WWT_Department/Projects/KEYS/Data-Work packages/WP2_SUW_pollution_Beijing/_DataAnalysis/GIS/rForestTz.Rdata')
caret::confusionMatrix(data=model$finalModel$predicted, 
                       reference=model$trainingData$.outcome, mode='prec_recall')

# step 2: classify image for roofs and streets
predictSurfClass(rawdir='Y:/WWT_Department/Projects/KEYS/Data-Work packages/WP2_SUW_pollution_Beijing/_DataAnalysis/GIS/',
                 modelName='rForestTz.Rdata',
                 image='tz.tif',
                 predName='tzClass.tif',
                 crsEPSG='+init=EPSG:4586')

# step 3: make overlays for total impervious area, roof and street for each subcatchment
makeOverlay(rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataAnalysis/GIS/',
            rasterData='tzClass.img', 
            subcatchmShape='ABIMO_TZ1.shp',
            overlayName='surfType')

# step 4: compute ABIMO variables PROBAU (%roof), VG (%impervious) and STR_FLGES
# 2=roof, 80=impervious (in another raster dataset), 4 = street Jx, 3 = street Tz
computeABIMOvariable(rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Beijing/_DataAnalysis/GIS/',
                     subcatchmShape='ABIMO_TZ1.shp',
                     mask='mask.shp',
                     rasterData='tzClass.img',
                     overlayName='surfType',
                     targetValue=2,
                     outDFname='roofTz.txt',
                     street=TRUE)

# step 5: annual climate variables ETP and rainfall
computeABIMOclimate(rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataAnalysis/climate/',
                    fileName='prec.txt',
                    header=c('date', 'ETP'),
                    outAnnual='Rainannual.txt',
                    outSummer='Rainsummer.txt')

computeABIMOclimate(rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataAnalysis/climate/',
                    fileName='ETP.txt',
                    header=c('date', 'ETP'),
                    outAnnual='ETPannual.txt',
                    outSummer='ETPsummer.txt')

# step 8: post-process ABIMO output file -> join it with input shape file for visualization
#         in GIS
postProcessABIMO(rawdir='c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataAnalysis/ABIMO/',
                 nameABIMOin='ABIMO_Jinxi_v1.shp',
                 nameABIMOout='ABIMO_Jinxi_v1out.dbf',
                 ABIMOjoinedName='ABIMO_Jinxi_v1outJoined.dbf')

# step 6: use raw code to compute and allocate PROVGU and all other ABIMO variables
# raw code ------------------------------------------------------------------------------

# % other impervious areas = total impervious % (VG, from global data set) 
# - %roof (PROBAU)
subc@data$PROVGU <- ifelse((subc@data$VG - subc@data$PROBAU) > 0,
                           subc@data$VG - subc@data$PROBAU,
                           0)

# % imperviousness streets
subc@data$VGSTRASSE <- 100

# %cover types in other imperv. areas (PROVGU)
subc@data$BELAG1 <- 100
subc@data$BELAG2 <- 0
subc@data$BELAG3 <- 0
subc@data$BELAG4 <- 0

# %cover types in street areas
subc@data$STR_BELAG1 <- 100
subc@data$STR_BELAG2 <- 0
subc@data$STR_BELAG3 <- 0
subc@data$STR_BELAG4 <- 0

# identifiers
subc@data$BEZIRK <- 1
subc@data$STAGEB <- 1
subc@data$BLOCK <- 1
subc@data$TEILBLOCK <- 1
subc@data$NUTZUNG <- 21
subc@data$TYP <- 21

subc@data$REGENJA <- 800
subc@data$REGENSO <- 500

subc@data$KANAL<- 1
subc@data$KAN_BEB<- 100
subc@data$KAN_VGU<- 100
subc@data$KAN_STR<- 100

subc@data$FELD_30 <- 15
subc@data$FELD_150 <- 15
subc@data$FLUR <- 1

# select required columns and write out new shapefile
requiredCols <- c('CODE', 'BEZIRK', 'STAGEB', 'BLOCK', 'TEILBLOCK','NUTZUNG', 'TYP',
                  'FLGES', 'STR_FLGES',
                  'PROBAU', 'PROVGU', 'VGSTRASSE',
                  'BELAG1', 'BELAG2', 'BELAG3', 'BELAG4',
                  'STR_BELAG1', 'STR_BELAG2', 'STR_BELAG3', 'STR_BELAG4',
                  'KAN_BEB', 'KAN_VGU', 'KAN_STR',
                  'REGENJA', 'REGENSO',
                  'FELD_30', 'FELD_150', 'FLUR')
subc@data <- subc@data[, requiredCols]

# # change decimal separator to point
subc@data <- as.data.frame(apply(X=apply(X=subc@data,
                                         c(1, 2),
                                         FUN=as.character),
                                 c(1, 2),
                                 FUN=gsub,
                                 pattern="\\.",
                                 replacement=","),
                           stringsAsFactors = FALSE)

# write ABIMO input table
raster::shapefile(x=subc, filename='../ABIMO/ABIMO_Jinxi_v1.shp', overwrite=TRUE)


setwd('c:/kwb/KEYS/WP2_SUW_pollution_Jinxi/_DataHIT/')
soil <- readxl::read_xls(path='translate_soil_data.xls',
                         sheet = "111",
                         skip = 1,
                         col_names=T,
                         na=c("","na"),
                         trim_ws = TRUE,
                         .name_repair = "minimal")

soil$`Irrigated Conditions`
soil$Drainage
t(t(unique(soil$`Texture Configuration`)))
# "轻壤" -> 'light soil'
# "中壤" -> 'middle soil'
# "重壤" -> 'heavy earth'
# "砂质轻壤" -> 'sandy light soil'
# "粘质中壤" -> 'clay medium soil'
# "砂质中壤" -> 'sandy medium soil'
# "砂壤" -> 'sand soil'
# "轻粘土" -> 'light clay'
