# This repository is ours and it has the latest versions of our packages
repos <- c("predictiveecology.r-universe.dev", getOption("repos"))
# Need the latest version
if (tryCatch(packageVersion("SpaDES.project") < "0.1.1.9009", error = function(x) TRUE))
  install.packages(c("SpaDES.project", "Require"), repos = repos)

out <- SpaDES.project::setupProject(
  Restart = TRUE,
  #useGit = TRUE,
  updateRprofile = TRUE, 
  paths = list(projectPath = "~/SpaDES_FRU", #on scfmLandcoverInit.R param" flammabilityThreshold = 0.05
               cachePath = "cache", 
               inputPath = "inputs",
               outputPath = "outputs/withTwoPolys",
               modulePath = "modules"),
  modules = c("PredictiveEcology/Biomass_borealDataPrep@main",
              "PredictiveEcology/Biomass_core@main",
              "PredictiveEcology/Biomass_regeneration@main",
              file.path("PredictiveEcology/scfm@development/modules",
                        c("scfmLandcoverInit", "scfmRegime", "scfmDriver",
                          "scfmIgnition", "scfmEscape", "scfmSpread",
                          "scfmDiagnostics"))
              #note scfm is a series of modules on a single git repository
  ),
  
  params = list(
    .globals = list(
      dataYear = 2011, #will get kNN 2011 data, and NTEMS 2011 landcover
      sppEquivCol = "LandR",
      .plots = c("png"),
      .useCache = c(".inputObjects")
    ),
    scfmDriver = list(targetN = 3000, #default is 4000 - higher targetN adds time + precision
                      # targetN would ideally be minimum 2000 - mean fire size estimates will be bad with 1000
                      .useParallelFireRegimePolys = TRUE) #assumes parallelization is an otpion
  ),
  options = list(#spades.allowInitDuringSimInit = TRUE,
    spades.allowSequentialCaching = TRUE,
    spades.moduleCodeChecks = FALSE,
    spades.recoveryMode = 1,
    gargle_oauth_email = "parvinkb3@gmail.com",
    gargle_oauth_cache = "~/.secret",
    gargle_oauth_client_type = "web"
  ),
  packages = c('RCurl', 'XML', 'snow', 'googledrive','terra', 'httr2', 'sf', 'dplyr'),
  times = list(start = 2011, end = 3011), 
  studyArea = {
    targetCRS <- paste("+proj=lcc +lat_1=49 +lat_2=77 +lat_0=0 +lon_0=-95 +x_0=0 +y_0=0",
                       "+datum=NAD83 +units=m +no_defs +ellps=GRS80 +towgs84=0,0,0")
    FRUdata <- scfmutils::prepInputsFireRegimePolys(type = "FRU", destinationPath = 'inputs')
    FRU26 <-  FRUdata[ FRUdata$FRU == "26",] # 
    FRU26 <- sf::st_transform(FRU26, targetCRS)
    FRU26 <- terra::vect(FRU26)
    
  },
  studyAreaLarge = {
    terra::buffer(studyArea, 2000)
  },
  rasterToMatchLarge = {
    rtml<- terra::rast(studyAreaLarge, res = c(250, 250))
    rtml[] <- 1
    rtml <- terra::mask(rtml, studyAreaLarge)
  },
  rasterToMatch = {
    rtm <- terra::crop(rasterToMatchLarge, studyArea)
    rtm <- terra::mask(rtm, studyArea)
  },
  rasterToMatchCalibration = rasterToMatchLarge, 
  studyAreaCalibration= studyAreaLarge,
  fireRegimePolysCalibration = sf::st_as_sf(studyAreaCalibration),
  fireRegimePolys = sf::st_as_sf(studyArea),
  sppEquiv = {
    speciesInStudy <- LandR::speciesInStudyArea(studyAreaLarge)
    species <- LandR::equivalentName(speciesInStudy$speciesList, df = LandR::sppEquivalencies_CA, "LandR")
    sppEquiv <- LandR::sppEquivalencies_CA[LandR %in% species]
    sppEquiv <- sppEquiv[KNN != "" & LANDIS_traits != ""] #avoid a bug with shore pine
  }, 
  fireRegimePolysLarge = {
    ecoDistricts <- scfmutils::prepInputsFireRegimePolys(studyArea = studyAreaLarge, 
                                                         type = "ECODISTRICT")
    
    # Assign newPolyID
    ecoDistricts$newPolyID <- 2
    ecoDistricts[ecoDistricts$PolyID < 19 & ecoDistricts$PolyID > 4 & 
                   ecoDistricts$PolyID != 7 | ecoDistricts$PolyID > 40, ]$newPolyID <- 1
    
    # Convert to SpatVector and aggregate
    ecoDistricts <- terra::vect(ecoDistricts)
    ecoDistricts <- terra::aggregate(ecoDistricts, by = "newPolyID", fun = mean)
    # Convert back to sf
    ecoDistricts <- sf::st_as_sf(ecoDistricts)
    
    # Ensure integer attributes
    ecoDistricts$newPolyID <- as.integer(ecoDistricts$newPolyID)
    ecoDistricts$PolyID <- as.integer(ecoDistricts$newPolyID)
    # Return the object
    ecoDistricts
    }
)

outSim <- do.call(SpaDES.core::simInitAndSpades, out)

source("postSim_Analysis.R")

