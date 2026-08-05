###############################################################################
# GitHub link to the original: https://github.com/USEPA/ContDataQC/tree/main
# GitHub link to CT DEEP's: https://github.com/ctdeepwatermonitoring/awx_cont_qc_upload/tree/main

# Have to run these 2 lines of code in the terminal to get this to run,
# or make sure they're already installed:
# sudo apt install libcurl4-openssl-dev
# sudo apt install libxml2-dev

# reshape2 didn't install automatically so I moved it up here.
# Run it first if not already installed.

#Step 1: Load ContDataQC
if(!require(reshape2)){install.packages("reshape2")}

# Installs remotes if needed
if(!require(remotes)){install.packages("remotes")}
# Installs ContDataQC package from GitHub
remotes::install_github("ctdeepwatermonitoring/awx_cont_qc_upload",
                        force = TRUE,
                        build_vignettes = FALSE)

# Installs non-CRAN packages
remotes::install_github("jasonelaw/iha",
                        force = TRUE,
                        build_vignettes = FALSE)
remotes::install_github("tsangyp/StreamThermal",
                        force = TRUE,
                        build_vignettes = FALSE)

# Load library, dependent libraries, and dotenv file
require("ContDataQC")
library(RMariaDB)
library(dotenv)
load_dot_env("C:/Users/deepuser/Documents/awx_cont_qc_upload/.env")
###############################################################################

mariadbconnection_awqx = dbConnect(RMariaDB::MariaDB(),
                                   dbname=Sys.getenv("DB_NAME2"),
                                   host=Sys.getenv("DB_HOST"),
                                   port=as.integer(Sys.getenv("DB_PORT")),
                                   user=Sys.getenv("DB_USER"),
                                   password=Sys.getenv("DB_PASSWORD"))

valid_sids = dbGetQuery(mariadbconnection_awqx, "SELECT staSeq FROM stations")
dbDisconnect(mariadbconnection_awqx)

#Step 2: Initialize input and output directories
input_main_directory = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/raw_data"
rename_main_directory = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/data_to_qc"
output_main_directory = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/qced_data"
error_directory = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/error_files"
error_log = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/error_files/error_log"
script_name = "csv_qc2.R"

#List of all csv files
all_csv_files = list.files(
  path = input_main_directory,
  pattern = "\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

#Total files
total_files = length(all_csv_files)

#Loop along all csv files, rename in expected format and save to subfolders
for (i in seq_along(all_csv_files)) {
  df_path = all_csv_files[i]

  tryCatch({
    #Step 3: Correct known common errors
    col_map = c(
      "DATE_TIME"   = "Date_Time",
      "Date Time"   = "Date_Time",
      "Date Time, GMT-04:00" = "Date_Time",
      "TEMP"        = "Temp",
      "Temp, \xb0C (LGR S/N: 10122051, SEN S/N: 10122051)" = "Temp",
      "UOM"         = "UOM",
      "PROBEID"     = "ProbeID",
      "ProbID"      = "ProbeID",
      "Probe ID"    = "ProbeID",
      "ProbeID "    = "ProbeID",
      "Probe_ID"    = "ProbeID",
      "SID"         = "SID",
      "COLLECTOR"   = "Collector",
      "PROBE_TYPE"  = "ProbeType"
    )

    first_line = readLines(df_path, n = 1)
    delim = ifelse(grepl("\t", first_line), "\t", ",")

    df = read.delim(df_path, sep = delim, fileEncoding = "latin1",
                    check.names = FALSE, stringsAsFactors = FALSE)

    df_clean = df

    # Remove unwanted columns
    df_clean = df_clean[, !names(df_clean) %in% c("ShedsID", "SHEDS")]

    # Rename columns using col_map
    for (old in names(col_map)) {
      idx = which(names(df_clean) == old)
      if (length(idx)) names(df_clean)[idx] = col_map[[old]]
    }

    # Strip anything after a comma in Date_Time or Temp column names
    names(df_clean) = sub(",.*", "", names(df_clean))

    # If ProbeType column is missing, add it with "HOBO"
    if (!"ProbeType" %in% names(df_clean)) df_clean$ProbeType = "HOBO"

    raw_times = df_clean$Date_Time

    df_clean$Date_Time = strptime(raw_times, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

    if (all(is.na(df_clean$Date_Time))) {
      df_clean$Date_Time = strptime(raw_times, format = "%m/%d/%y %H:%M:%S", tz = "UTC")
    }

    if (all(is.na(df_clean$Date_Time))) {
      df_clean$Date_Time = strptime(raw_times, format = "%m/%d/%y %H:%M", tz = "UTC")
    }

    if (all(is.na(df_clean$Date_Time))) {
      df_clean$Date_Time = strptime(raw_times, format = "%m/%d/%Y %H:%M:%S", tz = "UTC")
    }

    if (all(is.na(df_clean$Date_Time))) {
      df_clean$Date_Time = strptime(raw_times, format = "%m/%d/%Y %H:%M", tz = "UTC")
    }


    df_clean$ProbeType = ifelse(df_clean$ProbeType == "TIDB", "TIDBIT", df_clean$ProbeType)
    df_clean$Collector = ifelse(df_clean$Collector == " VOL", "VOL", df_clean$Collector)
    df_clean$UOM = ifelse(df_clean$UOM == "degC", "deg C",
                    ifelse(df_clean$UOM == "deg"    & df_clean$Temp < 30, "deg C",
                           ifelse(df_clean$UOM == "Logged" & df_clean$Temp < 30, "deg C", df_clean$UOM)))

    df_clean = df_clean[!is.na(df_clean$Date_Time) & !is.na(df_clean$SID) & !is.na(df_clean$ProbeID), ]
    #Step 4: Order by Date_Time
    df_clean = df_clean[order(df_clean$Date_Time), ]
    df_clean = unique(df_clean)

    # Compute deployment dates
    startDeploymentDate = format(min(df_clean$Date_Time), "%Y%m%d")
    endDeploymentDate   = format(max(df_clean$Date_Time), "%Y%m%d")

    #Step 5: Convert datetimes to proper format, add mDate and mTime
    df_clean$mDate    = format(df_clean$Date_Time, "%m/%d/%Y")
    df_clean$mTime    = format(df_clean$Date_Time, "%H:%M:%S")
    df_clean$Date_Time = format(df_clean$Date_Time, "%Y-%m-%d %H:%M:%S")

    staSeq = unique(df_clean$SID)
    probeID = unique(df_clean$ProbeID)
    if (!staSeq %in% valid_sids$staSeq) {
      stop(sprintf("SID '%s' not found in stations table", staSeq))
    }

    filename_parts = strsplit(tools::file_path_sans_ext(basename(df_path)), "_")[[1]]
    staSeq_from_filename = as.integer(filename_parts[3])
    probeID_from_filename = as.character(filename_parts[1])

    if (staSeq != staSeq_from_filename) {
      stop(sprintf("staSeq mismatch: file contains SID '%s' but filename indicates '%s'",
                   staSeq, staSeq_from_filename))
    }

    if (probeID != probeID_from_filename) {
      stop(sprintf("probeID mismatch: file contains ProbeID '%s' but filename indicates '%s'",
                   probeID, probeID_from_filename))
    }

    #Step 6: Write out to subfolders
    probeID = unique(df_clean$ProbeID)
    out_identifier = paste0(staSeq, "_Water_", startDeploymentDate, "_", endDeploymentDate)
    out_name = paste0(out_identifier, ".csv")
    out_folder = file.path(rename_main_directory, paste0(probeID, "_", out_identifier))
    out_path = file.path(out_folder, out_name)

    dir.create(out_folder, showWarnings = FALSE, recursive = TRUE)
    write.csv(df_clean, out_path, row.names = FALSE)

  }, error = function(e) {
    # On error: print message, log error, and move file to error folder
    message(paste("Error processing file:", df_path))
    message("Error message:", e$message)
    error_file = file.path(
      error_log,
      paste0(tools::file_path_sans_ext(basename(df_path)), ".txt")
    )

    writeLines(
      c(paste("Timestamp:", Sys.time()),
        paste("Script:", script_name),
        paste("File:", basename(df_path)),
        paste("Error:", conditionMessage(e))
      ),
      con = error_file
    )

    file.rename(df_path, file.path(error_directory, basename(df_path)))
  })
}






#QCing data
#Step 7: Read in recently written out data
qc_prep_files = list.files(
  path = rename_main_directory,
  pattern = "\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

#total files
total_qc_prep_files = length(qc_prep_files)

#Loop along csv files, QC them, and save them into their subfolders
for (i in seq_along(qc_prep_files)) {
  file_path = qc_prep_files[i]
  print(paste("Processing", i, "of", total_qc_prep_files, "total files"))
  tryCatch({
    file_name = basename(file_path)
    parts = strsplit(file_name, "_")[[1]]
    site_id = parts[1]
    start_date = parts[3]
    end_date = gsub("\\.csv$", "", parts[4])

    df = read.csv(file_path, stringsAsFactors = FALSE)

    #Step 8: Fill default values for deployments with less than 5 entries
    if (nrow(df) < 5) {
      df_out = df
      df_out$Date_Time = as.character(df$Date_Time)
      dt_parsed    = as.POSIXct(df$Date_Time, format = "%Y-%m-%d %H:%M:%S")
      df_out$Month     = as.integer(format(dt_parsed, "%m"))
      df_out$Day       = as.integer(format(dt_parsed, "%d"))
      df_out$Year      = as.integer(format(dt_parsed, "%Y"))
      df_out$MonthDay  = as.integer(paste0(df_out$Month, df_out$Day))

      df_out$Flag.Gross.temp = "X"
      df_out$Flag.Spike.temp = "X"
      df_out$Flag.RoC.temp   = "X"
      df_out$Flag.Flat.temp  = "X"
      df_out$Flag.temp       = "X"

      for (col in c("Comment.MOD.Date_Time","Comment.MOD.Temp","Comment.MOD.UOM",
                    "Comment.MOD.ProbeID","Comment.MOD.SID","Comment.MOD.Collector",
                    "Comment.MOD.ProbeType","Comment.MOD.mDate","Comment.MOD.mTime",
                    "RAW.Date_Time","RAW.Temp","RAW.UOM","RAW.ProbeID","RAW.SID",
                    "RAW.Collector","RAW.ProbeType","RAW.mDate","RAW.mTime")) {
        df_out[[col]] = ""
      }

      #Writing out with uniquely identifying subfolder names
      myDir.import = dirname(file_path)
      rel_folder = basename(myDir.import)
      myDir.export = file.path(output_main_directory, rel_folder)
      dir.create(myDir.export, showWarnings = TRUE, recursive = TRUE)

      file_out = file.path(myDir.export, paste0("QC_", file_name))
      write.csv(df_out,   file_out,  row.names = FALSE)

      print(paste("Skipped QC (too few rows). Wrote default file for", file_name))

    } else {
      #Step 9: Call QC method
      #Uses config_deep2.R file.
      myData.Operation = "QCRaw"
      myData.SiteID = site_id
      myData.Type = "Water"
      myData.DateRange.Start = paste0(substr(start_date,1,4), "-", substr(start_date,5,6), "-", substr(start_date,7,8))
      myData.DateRange.End = paste0(substr(end_date,1,4), "-", substr(end_date,5,6), "-", substr(end_date,7,8))

      myDir.import = dirname(file_path)
      rel_folder = basename(myDir.import)
      myDir.export = file.path(output_main_directory, rel_folder)
      dir.create(myDir.export, showWarnings = TRUE, recursive = TRUE)

      myReport.format = "html"
      myConfig = "C:/Users/deepuser/Documents/awx_cont_qc_upload/modern_data_workflow/config_deep2.R"

      ContDataQC::ContDataQC(myData.Operation,
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
  }, error = function(e) {
    # On error: print message and move file to error folder
    message(paste("Error processing file:", df_path))
    message("Error message:", e$message)

    error_file = file.path(
      error_log,
      paste0(tools::file_path_sans_ext(basename(df_path)), ".txt")
    )

    writeLines(
      c(paste("Timestamp:", Sys.time()),
        paste("Script:", script_name),
        paste("File:", basename(df_path)),
        paste("Error:", conditionMessage(e))
      ),
      con = error_file
    )

    file.rename(df_path, file.path(error_directory, basename(df_path)))
  })
}
