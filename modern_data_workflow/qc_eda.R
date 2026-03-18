library(RSQLite)
library(tidyverse)

flags_directory = "/home/deepuser/ContDataQC/modern_data_workflow/qced_data"

all_flagged_csv_files = list.files(
  path = flags_directory,
  pattern = "\\.csv$",
  recursive = TRUE,
  full.names = TRUE
)

all_flagged_data = all_flagged_csv_files %>%
  lapply(function(file) {
    deployment_id = basename(dirname(file))
    df = read.csv(file, colClasses = c(probeID = "character", RAW.probeID = "character"))
    df$deployment_id = deployment_id
    df
    }) %>%
  bind_rows(.id = "source_file")

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
flag_counts = table(all_flagged_data$Flag.temp)

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

subflag_cols = c("Flag.Gross.temp", "Flag.Spike.temp", "Flag.RoC.temp", "Flag.Flat.temp")

flagged = all_flagged_data %>%
  mutate(
    Fail.Reason    = apply(select(., all_of(subflag_cols)), 1, get_reason, level = "F"),
    Suspect.Reason = apply(select(., all_of(subflag_cols)), 1, get_reason, level = "S"),
    Pass.Reason    = apply(select(., all_of(subflag_cols)), 1, get_reason, level = "P"),
    NoData.Reason  = apply(select(., all_of(subflag_cols)), 1, get_reason, level = "X")
  )

summary_table = flagged %>%
  mutate(
    reason = case_when(
      Flag.temp == "F" ~ Fail.Reason,
      Flag.temp == "S" ~ Suspect.Reason,
      Flag.temp == "P" ~ Pass.Reason,
      Flag.temp == "X" ~ NoData.Reason,
      TRUE ~ NA_character_
    )
  ) %>%
  group_by(Flag.temp, reason) %>%
  summarise(count = n(), .groups = "drop") %>%
  mutate(percent = round(100 * count / sum(count), 2)) %>%
  arrange(factor(Flag.temp, levels = c("F", "S", "P", "X")), desc(count))


#Showing individual deployments and giving them bins
deployment_summary = all_flagged_data %>%
  group_by(deployment_id) %>%
  summarise(
    total = n(),
    fail_count = sum(Flag.temp == "F"),
    suspect_count = sum(Flag.temp == "S"),
    fail_percent = round(100 * fail_count / total, 2),
    suspect_percent = round(100 * suspect_count / total, 2),
    .groups = "drop"
  ) %>%
  mutate(
    fail_bin = cut(
      fail_percent,
      breaks=  seq(0, 100, by = 5),
      right = FALSE,
      include.lowest = TRUE,
      labels = paste0(seq(0, 95, by = 5), "%-", seq(5, 100, by = 5))
    ),
    suspect_bin = cut(
      suspect_percent,
      breaks = seq(0, 100, by = 5),
      right = FALSE,
      include.lowest = TRUE,
      labels = paste0(seq(0, 95, by = 5), "%-", seq(5, 100, by = 5))
    )
  )


#Fail bin counts
fail_bin_counts = deployment_summary %>%
  count(fail_bin, name = "deployment_count") %>%
  arrange(fail_bin)

#Suspect bin counts
suspect_bin_counts = deployment_summary %>%
  count(suspect_bin, name = "deployment_count") %>%
  arrange(suspect_bin)

#Find specific sites based on bins
high_failure_deployments = deployment_summary %>%
  filter(fail_bin == "15%-20") %>%
  select(deployment_id, total, fail_count, fail_percent)

#Producing a visualization of flags for a deployment
target_deployment = "1183814_14584_Water_20081104_20090513"

deployment_data = all_flagged_data %>%
  filter(deployment_id == target_deployment)

ggplot(deployment_data, aes(x = as.POSIXct(paste(mDate, mTime)), y = temp)) + 
  geom_point(aes(color = Flag.temp)) + 
  scale_color_manual(
    values = c("F" = "red", "S" = "orange", "P" = "black", "X" = "gray"),
    breaks = c("F", "S", "P", "X"),
    labels = c("Fail", "Suspect", "Pass", "No Data"),
    name = "Flag Status"
  ) + 
  labs(
    title = paste("Temperature Readings for Site", deployment_data$staSeq, "by probe", deployment_data$probeID),
    x = "Date-Time",
    y = "Temperature (°C)"
  ) + 
  theme_minimal()