#Step 1: Gather all csv files
#Directories
old_directory = "E:/Documents/awx_cont_qc_upload/modern_data_workflow/qced_data"
new_directory = "E:/Documents/awx_cont_qc_upload/TemperatureDB/testFTP/Upload/Cont_Data"
error_directory = "E:/Documents/awx_cont_qc_upload/modern_data_workflow/error_files"
error_log = "E:/Documents/awx_cont_qc_upload/modern_data_workflow/error_files/error_log"
script_name = "migration_prep2.R"

#Check if directory exists and if not, create one
if (!dir.exists(new_directory)) {
  dir.create(new_directory, recursive = TRUE)
}

#Listing all csv files
files_to_prep = list.files(
  path = old_directory,
  pattern = "\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

#Go through all csv files
for (f in files_to_prep) {
  tryCatch({
    #Read data
    data = read.csv(f, stringsAsFactors = FALSE, quote = "\"")

    data_out = data
    data_out$dataFlag = data_out$Flag.Temp
    if (!"comment" %in% names(data_out)) data_out$comment = ""
    data_out = data_out[, c("Date_Time", "Temp", "UOM", "ProbeID", "SID",
                            "Collector", "ProbeType", "dataFlag", "comment")]
    data_out$Date_Time = as.character(data_out$Date_Time)

    folder_name = basename(dirname(f))
    parts = strsplit(folder_name, "_")[[1]]
    probeID = parts[1]

    old_file_name = basename(f)
    new_file_name = sub("^QC_", paste0("QC_", probeID, "_"), old_file_name)

    #Setting directory and writing out
    new_file = file.path(new_directory, new_file_name)
    write.csv(data_out, new_file, row.names = FALSE, na = "", quote = TRUE)
  }, error = function(e) {
    message(paste("Error processing file:", basename(f)))
    message("Error message:", e$message)
    error_file = file.path(
      error_log,
      paste0(tools::file_path_sans_ext(basename(f)), ".txt")
    )

    writeLines(
      c(
        paste("Timestamp:", Sys.time()),
        paste("Script:", script_name),
        paste("File:", basename(f)),
        paste("Error:", conditionMessage(e))
      ),
      con = error_file
    )

    file.rename(f, file.path(error_directory, basename(f)))
  })
}
