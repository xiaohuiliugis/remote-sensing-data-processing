############### SESYNC Research Support: Agbirds project ########## 
## Processing agricultural crop data by week.
## 
##
## DATE CREATED: 08/03/2018
## DATE MODIFIED: 08/20/2018
## AUTHORS: Benoit Parmentier  
## Version: 1
## PROJECT: Agbirds
## ISSUE: 
## TO DO:
##
## COMMIT: initial commit
##

###################################################
#

###### Library used

library(sp) # spatial/geographic objects and functions
library(rgdal) #GDAL/OGR binding for R with functionalities
library(spdep) #spatial analyses operations, functions etc.
library(gtools) # contains mixsort and other useful functions
library(maptools) # tools to manipulate spatial data
library(parallel) # parallel computation, part of base package no
library(rasterVis) # raster visualization operations
library(raster) # raster functionalities
library(forecast) #ARIMA forecasting
library(xts) #extension for time series object and analyses
library(zoo) # time series object and analysis
library(lubridate) # dates functionality
library(colorRamps) #contains matlab.like color palette
library(rgeos) #contains topological operations
library(sphet) #contains spreg, spatial regression modeling
library(BMS) #contains hex2bin and bin2hex, Bayesian methods
library(bitops) # function for bitwise operations
library(foreign) # import datasets from SAS, spss, stata and other sources
library(gdata) #read xls, dbf etc., not recently updated but useful
library(classInt) #methods to generate class limits
library(plyr) #data wrangling: various operations for splitting, combining data
#library(gstat) #spatial interpolation and kriging methods
library(readxl) #functionalities to read in excel type data
library(psych) #pca/eigenvector decomposition functionalities
library(snow)
library(sf)
library(car)

###### Functions used in this script and sourced from other files

create_dir_fun <- function(outDir,out_suffix=NULL){
  #if out_suffix is not null then append out_suffix string
  if(!is.null(out_suffix)){
    out_name <- paste("output_",out_suffix,sep="")
    outDir <- file.path(outDir,out_name)
  }
  #create if does not exists
  if(!file.exists(outDir)){
    dir.create(outDir)
  }
  return(outDir)
}

#Used to load RData object saved within the functions produced.
load_obj <- function(f){
  env <- new.env()
  nm <- load(f, env)[1]
  env[[nm]]
}

#Benoit setup
script_path <- "/nfs/bparmentier-data/Data/projects/agbirds-data/scripts"

#mosaicing_functions <- "weighted_mosaicing_functions_07252018.R"
#source(file.path(script_path,mosaicing_functions))

#########cd ###################################################################
#####  Parameters and argument set up ########### 

#ARGS 1
in_dir <- "/nfs/bparmentier-data/Data/projects/agbirds-data/data"
#ARGS 2
out_dir <- "/nfs/bparmentier-data/Data/projects/agbirds-data/outputs"
#ARGS 3:
#NA_flag <- -999999
NA_flag_val <- NULL
#ARGS 4:
file_format <- ".tif"
#ARGS 5:
create_out_dir_param=TRUE #create a new ouput dir if TRUE
#ARGS 7
out_suffix <-"agbirds_processing_08202018" #output suffix for the files and ouptut folder
#ARGS 8
num_cores <- 2 # number of cores
#ARGS 9
#date_param <- "1982.01.01;1982.12.31" #start date, end date

in_filename <- "Crop_Data_modified.csv"

################# START SCRIPT ###############################

######### PART 0: Set up the output dir ################

options(scipen=999)

#set up the working directory
#Create output directory

if(is.null(out_dir)){
  out_dir <- in_dir #output will be created in the input dir
  
}
#out_dir <- in_dir #output will be created in the input dir

out_suffix_s <- out_suffix #can modify name of output suffix
if(create_out_dir_param==TRUE){
  out_dir <- create_dir_fun(out_dir,out_suffix)
  setwd(out_dir)
}else{
  setwd(out_dir) #use previoulsy defined directory
}

#######################################
### PART 1: Read in DATA #######


data_df <- read.table(file.path(in_dir,in_filename),
                      sep=",",
                      header=T,
                      stringsAsFactors = F)
#View(data_df)
names(data_df)
#[1] "State"         "Crop"          "Plant_Harvest" "X1"            "X2"           
#[6] "X3"            "X4"            "X5"            "X6"            "X7"           
#[11] "X8"            "X9"            "X10"           "X11"           "X12"          
#[16] "X13" 


# Please find attached the crop table. Within this table each crop type is separated
#by state and condition, either planting or harvesting. 
# Within this table we are hoping to combine the planting and harvesting row 
#for each crop type, by state. Currently planting and harvesting are coded 
#as 0, 1, or 2 for each of the 52 weeks of the year. 
#We want to change the harvesting values of 1 and 2 to 3 and 4, and
#then merge the planting and harvesting rows for each crop and each state. 
#There should not be overlap between the planting and harvesting, but using xtab 
#to find errors will be useful.
# 
# For the next step, we are hoping to convert this table into a spatial dataset. 
#The final product should be 52 rasters (1 for each week) for each crop type 
#(18 crop types listed in table) which includes cell values that represent 
#the crop condition (0,1,2,3,4) which will vary by state.
# 
# To test the following steps, we placed the CDL data for the state of Alabama in the agbirds-data folder under cdl_alabama. We placed a READ ME file with download information if helpful.
# 
# The steps we discussed during our meeting are the following, but we are open to following a different work plan based on your recommendations:
#   1) Clip USDA CDL layer into states
# 
# 2) Extract each crop type from state layers created in step 1 (keep only those crops listed in the table)
# 
# 3) Duplicate crop type into 52 rasters
# 
# 4) Assign crop condition code (0,1,2,3 or 4) to each raster for each crop type (presence of crop)/state
# 
# 5) Merge crops by state into national layer. Final product will be crop layer for U.S.; value within a state will be 0-4 based on crop condition (no action 0, planting active 1, planting intense 2, harvesting active 3, harvesting intense 4).
# 
# 6) Combine all crop layers to have 52 rasters (1 for each week) with cells that have 2 values: crop type and crop condition.
# 
# 7) Create virtual raster table.

names(data_df)
table(data_df$State)
test <- subset(data_df,State=="California")
dim(test)
View(test)
names(data_df$State)
xtabs(test$Plant_Harvest)

table(test$Plant_Harvest)
dim(test)

table(data_df$Plant_Harvest)

### first recode Harvest to harvesting

test$Plant_Harvest[test$Plant_Harvest=="Harvest"] <- "Harvesting"
data_df$Plant_Harvest[data_df$Plant_Harvest=="Harvest"] <- "Harvesting"  
table(data_df$Plant_Harvest) #ok same number

data_processed <- data_df

data_Harvesting <- subset(data_processed,Plant_Harvest=="Harvesting")  
dim(data_Harvesting)
ncol(data_Harvesting)
n_selected <- 4:ncol(data_Harvesting)
data_m <- t(data_Harvesting[n_selected])

dim(data_m)
View(data_m)
# Recode grade 5 to grade 6 and grade 6 to grade 7
test$Grade<-recode(SchoolData$Grade,"5=6;6=7")

dim(subset(data_df,Plant_Harvest=="Harvesting"))
dim(data_df)
table(data_df$Plant_Harvest)

test$Grade<-recode(SchoolData$Grade,"5=6;6=7")

library(dplyr)
mutate(x, b = ifelse(a %in% c(1, 2, 3, 6, 7), 1, 0))

table(test$Crop)
test2 <- subset(test,test$Crop=="Winter_Wheat")

xtabs(test2$Plant_Harvest)
table(test2$Plant_Harvest)

matrix_weeks <- test2[4:ncol(test2)]
range(matrix_weeks[1,]+matrix_weeks[2,])

data_in <- data_df
state_val <- "California"
screen_for_crop_status <- function(data_in,state_val){
  ##
  ##
  
  data_subset <- subset(data_in,State==state_val)
  #dim(data_subset)
  crop_type <- unique(data_subset$Crop)
   
  ## check for coding error
  xtabs(test2$Plant_Harvest)
  table(test2$Plant_Harvest)
  
  debug(recode_crop)
  recode_crop(crop_type=crop_type[1],data_crop=data_subset)
  
  recode_crop <- function(crop_type,data_crop){
    ##
    ##
    
    data_tmp <- subset(data_crop,data_crop$Crop==crop_type)
    names(data_tmp)
    selected_col <- grepl("X", names(data_tmp))
    
    row.names(data_tmp) <- data_tmp$Plant_Harvest
    
    #df[ , grepl( "ABC" , names( df ) ) ]
    
    weeks_df <- as.data.frame(t(data_tmp[,selected_col]))
    
    #test <- (data_tmp[,-selected_col])
    
    dim(weeks_df)
    names(weeks_df)
    #names(weeks_df) <- 
    val_range <- range(weeks_df[,1]+weeks_df[,2])

    val_tabs <- table(weeks_df[,1],weeks_df[,2])
    
    range_df <- data.frame(min=val_range[1],max=val_range[2])
    range_df$crop <- crop_type
    weeks_df$Harvesting
    weeks_df$Harvesting <-recode(weeks_df$Harvesting,"1=3;2=4")
    
    data_out <- as.data.frame(t(weeks_df))
    
    data_out <- cbind(data_tmp[,!selected_col],data_out)
    dim(data_out)
    
    if(range_df$max > 2){
      data_out$flag <- 1
    }
    
    obj <- list(val_tabs,range_df,data_out)
    
    return(obj)
  }
  
  

}

##################  End of script #########