flags_directory = "/home/deepuser/awx_cont_qc_upload/modern_data_workflow/qced_data"

all_flagged_csv_files = list.files(
  path = flags_directory,
  pattern = "\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

all_flagged_data = do.call(rbind, lapply(all_flagged_csv_files, function(file) {
  deployment_id = basename(dirname(file))
  df = read.csv(file, colClasses = c(probeID = "character", RAW.probeID = "character"))
  df$deployment_id = deployment_id
  df
}))

daily_counts = aggregate(Temp ~ SID + as.Date(Date_Time, tz = "America/New_York"),
                         data = all_flagged_data, FUN = length)
colnames(daily_counts) = c("staSeq", "date_only", "count")

complete_days = daily_counts[daily_counts$count >= 24, ]

#Calculating daily means
daily_means = all_flagged_data
daily_means$date = as.POSIXct(daily_means$Date_Time)
daily_means$date_only = as.Date(daily_means$date, tz = "America/New_York")
daily_means$year = strftime(daily_means$date, "%Y")
daily_means$month = as.integer(strftime(daily_means$date, "%m"))
daily_means$staSeq = as.character(daily_means$SID)
daily_means = merge(daily_means, complete_days[, c("staSeq", "date_only")],
                    by = c("staSeq", "date_only"),
                    all = FALSE)
daily_means = aggregate(Temp ~ staSeq + date + year + month, data = daily_means,
                        FUN = mean)
colnames(daily_means)[colnames(daily_means) == "Temp"] = "mean_temp"
daily_means$category[daily_means$mean_temp < 18.29] = "Cold"
daily_means$category[daily_means$mean_temp > 21.70] = "Warm"
daily_means$category[daily_means$mean_temp >= 18.29 & daily_means$mean_temp <= 21.70] = "Cool"


#Calculating summer averages
summer_data = subset(daily_means, month %in% 6:8)
summer_avg = aggregate(mean_temp ~ staSeq + year,
                       data = summer_data, FUN = mean)
colnames(summer_avg)[colnames(summer_avg) == "mean_temp"] = "summer_avg_temp"
summer_avg$summer_category[summer_avg$summer_avg_temp < 18.29] = "Cold"
summer_avg$summer_category[summer_avg$summer_avg_temp > 21.70] = "Warm"
summer_avg$summer_category[summer_avg$summer_avg_temp >= 18.29 & summer_avg$summer_avg_temp <= 21.70] = "Cool"

summer_day_counts = aggregate(date ~ staSeq + year,
                              data = subset(daily_means, month %in% 6:8),
                              FUN = function(x) length(unique(as.Date(x, tz = "America/New_York"))))
colnames(summer_day_counts)[colnames(summer_day_counts) == "date"] = "n_days"
summer_avg = merge(summer_avg, summer_day_counts,
                   by = c("staSeq", "year"),
                   all.x = TRUE)

#Flag threshold values
#Gross value
#F: temp is greater than 30 OR
#   temp is less than -2

#S: temp is greater than 25 AND temp is less than 30 OR
#   temp is less than -0.1 AND temp is greater than -2

#P: temp is less than 25 AND temp is greater than -0.1


#Spike
#F: temp increases or decreases by more than 1.5 degrees C from the last reading

#S: temp increases or decreases by more than 1 degree C from the last reading

#P: temp increases or decreases by less than 1 degree C from the last reading


#Rate of Change
#S: temp changes by more than 3 standard deviations compared to the previous value (SD computed over a 25 hour period)

#P: temp changes by less than 3 standard deviations compared to the previous value (SD computed over a 25 hour period)


#Flat-line
#F: temp remains constant for 30 or more consecutive values

#s: temp remains constant for 15 or more consecutive values but less than 30 consecutive values

#P: temp remains constant for less than 15 values


#Overall
#F: If any other flag fails then the overall flag fails

#S: If any other flag is suspect and no flag fails then the overall flag is suspect

#P: If at least one flag passes and the rest either pass or have no data then the overall flag passes.


#Producing overall flag counts and percentages
flag_counts = table(all_flagged_data$Flag.Temp)

flag_percent = prop.table(flag_counts) * 100

flag_summary = data.frame(
  flag=  names(flag_counts),
  count = as.vector(flag_counts),
  percent = round(as.vector(flag_percent), 2)
)

total_flags = sum(flag_counts)
flag_summary = rbind(flag_summary, c("TOTAL", total_flags, 100.00))

#Breaking down flags by causes
get_reason = function(row, level) {
  flags = c("Gross", "Spike", "RoC", "Flat")
  indices = which(row == level)
  if (length(indices) == 0) return(NA_character_)
  paste(sort(flags[indices]), collapse = " + ")
}

subflag_cols = c("Flag.Gross.Temp", "Flag.Spike.Temp", "Flag.RoC.Temp", "Flag.Flat.Temp")

flagged = all_flagged_data
flagged$Fail.Reason    = apply(flagged[, subflag_cols], 1, get_reason, level = "F")
flagged$Suspect.Reason = apply(flagged[, subflag_cols], 1, get_reason, level = "S")
flagged$Pass.Reason    = apply(flagged[, subflag_cols], 1, get_reason, level = "P")
flagged$NoData.Reason  = apply(flagged[, subflag_cols], 1, get_reason, level = "X")

flagged$reason = ifelse(
  flagged$Flag.Temp == "F", flagged$Fail.Reason,
  ifelse(flagged$Flag.Temp == "S", flagged$Suspect.Reason,
         ifelse(flagged$Flag.Temp == "P", flagged$Pass.Reason,
                ifelse(flagged$Flag.Temp == "X", flagged$NoData.Reason, NA_character_)))
)

flagged$n = 1
summary_table = aggregate(n ~ Flag.Temp + reason, data = flagged, FUN = sum)
names(summary_table)[3] = "count"
summary_table$percent = round(100 * summary_table$count / sum(summary_table$count), 2)
summary_table$Flag.Temp = factor(summary_table$Flag.Temp, levels = c("F", "S", "P", "X"))
summary_table = summary_table[order(summary_table$Flag.Temp, -summary_table$count), ]
row.names(summary_table) = NULL

#Showing individual deployments and giving them bins
deployment_summary = do.call(rbind, lapply(
  split(all_flagged_data, all_flagged_data$deployment_id),
  function(grp) {
    total          = nrow(grp)
    fail_count     = sum(grp$Flag.Temp == "F")
    suspect_count  = sum(grp$Flag.Temp == "S")
    fail_percent   = round(100 * fail_count / total, 2)
    suspect_percent = round(100 * suspect_count / total, 2)
    data.frame(
      deployment_id   = grp$deployment_id[1],
      total           = total,
      fail_count      = fail_count,
      suspect_count   = suspect_count,
      fail_percent    = fail_percent,
      suspect_percent = suspect_percent
    )
  }
))

bin_labels = paste0(seq(0, 95, by = 5), "%-", seq(5, 100, by = 5))
bin_breaks = seq(0, 100, by = 5)

deployment_summary$fail_bin = cut(
  deployment_summary$fail_percent,
  breaks = bin_breaks,
  right = FALSE,
  include.lowest = TRUE,
  labels = bin_labels
)

deployment_summary$suspect_bin = cut(
  deployment_summary$suspect_percent,
  breaks = bin_breaks,
  right = FALSE,
  include.lowest = TRUE,
  labels = bin_labels
)

row.names(deployment_summary) = NULL

#Fail bin counts
fail_bin_counts    = as.data.frame(table(fail_bin    = deployment_summary$fail_bin),
                                   responseName = "deployment_count")

#Suspect bin counts
suspect_bin_counts = as.data.frame(table(suspect_bin = deployment_summary$suspect_bin),
                                   responseName = "deployment_count")

#Find specific sites based on bins
high_failure_deployments = deployment_summary[
  !is.na(deployment_summary$fail_bin) & deployment_summary$fail_bin == "15%-20",
  c("deployment_id", "total", "fail_count", "fail_percent")
]

#Producing a visualization of flags for a deployment
target_deployment = "22030694_20925_Water_20240917_20250429"

deployment_data = all_flagged_data[all_flagged_data$deployment_id == target_deployment, ]

color_map = c("F" = "red", "S" = "orange", "P" = "black", "X" = "gray")
point_colors = color_map[deployment_data$Flag.Temp]

plot(
  as.POSIXct(deployment_data$Date_Time),
  deployment_data$Temp,
  col = point_colors,
  pch = 16,
  cex = 0.6,
  xlab = "Date-Time",
  ylab = "Temperature (°C)",
  main = paste("Temperature Readings for Site", deployment_data$SID[1],
               "by Probe", deployment_data$ProbeID[1])
)

legend(
  "topright",
  legend = c("Fail", "Suspect", "Pass", "No Data"),
  col    = c("red", "orange", "black", "gray"),
  pch    = 16
)
