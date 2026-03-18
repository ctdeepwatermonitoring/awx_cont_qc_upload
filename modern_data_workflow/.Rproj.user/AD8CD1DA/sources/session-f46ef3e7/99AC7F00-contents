###############################################################################
# GitHub link to the original: https://github.com/USEPA/ContDataQC/tree/main
# GitHub link to CT DEEP's: https://github.com/ctdeepwatermonitoring/water_temperature/tree/main

# Have to run these 2 lines of code in the terminal to get this to run, 
# or make sure they're already installed:
# sudo apt install libcurl4-openssl-dev
# sudo apt install libxml2-dev

# reshape2 didn't install automatically so I moved it up here. 
# Run it first if not already installed.
if(!require(reshape2)){install.packages("reshape2")}

# Installs remotes if needed
if(!require(remotes)){install.packages("remotes")}
# Installs ContDataQC package from GitHub
remotes::install_github("ctdeepwatermonitoring/water_temperature", 
                        force = TRUE, 
                        build_vignettes = FALSE)

# Installs non-CRAN packages
remotes::install_github("jasonelaw/iha", 
                        force = TRUE, 
                        build_vignettes = FALSE)
remotes::install_github("tsangyp/StreamThermal", 
                        force = TRUE, 
                        build_vignettes = FALSE)

# Load library and dependent libraries
require("ContDataQC")

###############################################################################
# Parameters
Selection.Operation <- c("GetGageData"
                         , "QCRaw"
                         , "Aggregate"
                         , "SummaryStats")
Selection.Type      <- c("Air","Water","AW","Gage","AWG","AG","WG")
Selection.SUB <- c("Data0_Original"
                   , "Data1_RAW"
                   , "Data2_QC"
                   , "Data3_Aggregated"
                   , "Data4_Stats")

csv_files = list.files(
  "/home/deepuser/Documents/historic_temperature_project/testing_csvs",
  pattern = "*.csv",
  full.names = TRUE
)

for (file_path in csv_files) {
  print(file_path)
  file_name = basename(file_path)
  parts = strsplit(file_name, "_")[[1]]
  site_id = parts[1]
  year_part = parts[3]
  year = substr(year_part, 1, 4)
  
  myData.Operation = "QCRaw" #Selection.Operation[2]
  myData.SiteID = site_id
  myData.Type = Selection.Type[2] #"Water"
  myData.DateRange.Start = paste0(year, "-01-01")
  myData.DateRange.End = paste0(year, "-12-31")
  myDir.import = "testing_csvs"
  myDir.export = "testing_csvs_output"
  myReport.format = "html"
  myConfig = "config_test.R"
  
  ContDataQC(myData.Operation,
             myData.SiteID,
             myData.Type,
             myData.DateRange.Start,
             myData.DateRange.End,
             myDir.import,
             myDir.export,
             fun.myConfig = myConfig,
             fun.myReport.format = myReport.format,
             fun.AddDeployCol = FALSE)
}
