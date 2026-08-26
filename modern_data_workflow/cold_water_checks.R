library(RMariaDB)
library(dotenv)

load_dot_env(".env")

mariadbconnection_cont = dbConnect(RMariaDB::MariaDB(),
                                   dbname=Sys.getenv("DB_NAME"),
                                   host=Sys.getenv("DB_HOST"),
                                   port=as.integer(Sys.getenv("DB_PORT")),
                                   user=Sys.getenv("DB_USER"),
                                   password=Sys.getenv("DB_PASSWORD"))

result = dbSendQuery(mariadbconnection_cont, 
                     "SELECT staSeq, mDateTime, temp 
                     FROM temperature 
                     WHERE collector = 'VOL' AND YEAR(mDateTime) BETWEEN 2022 AND 2025 
                     AND MONTH(mDateTime) BETWEEN 6 AND 8")
initial_data = dbFetch(result, n = Inf)
dbClearResult(result)
dbDisconnect(mariadbconnection_cont)

initial_data$year = as.integer(format(initial_data$mDateTime, "%Y"))
initial_data$month = as.integer(format(initial_data$mDateTime, "%m"))
initial_data$day = as.Date(initial_data$mDateTime)
initial_data$hour = as.integer(format(initial_data$mDateTime, "%H"))

# Get counts of how many readings there are across each hour for each day for each year for each site
hour_counts = aggregate(temp ~ staSeq + year + day + hour, data = initial_data, FUN = length)
names(hour_counts)[names(hour_counts) == "temp"] = "n_readings"

# For each site each year each day, check if all 24 hours are present and if counts are equal across all hours
day_check = aggregate(n_readings ~ staSeq + year + day, data = hour_counts,
                      FUN = function(x) c(n_hours = length(x),
                                          all_equal = length(unique(x)) == 1))

day_check = do.call(data.frame, day_check)
names(day_check)[names(day_check) == "n_readings.n_hours"] = "n_hours"
names(day_check)[names(day_check) == "n_readings.all_equal"] = "all_equal"

day_check$is_complete = day_check$n_hours == 24 & day_check$all_equal == 1

# Get hourly averages and then daily averages
hourly = aggregate(temp ~ staSeq + year + day + hour, data = initial_data, FUN = mean)
day_avg = aggregate(temp ~ staSeq + year + day, data = hourly, FUN = mean)
names(day_avg)[names(day_avg) == "temp"] = "day_avg_temp"

# Combine and keep only complete days
daily = merge(day_avg, day_check[, c("staSeq", "year", "day", "is_complete")],
              by = c("staSeq", "year", "day"))
daily_complete = daily[daily$is_complete, ]

# Calculate summer averages
summer_avg = aggregate(day_avg_temp ~ staSeq + year, data = daily_complete, FUN = mean)
names(summer_avg)[names(summer_avg) == "day_avg_temp"] = "summer_avg_temp"

n_days = aggregate(day ~ staSeq + year, data = daily_complete, FUN = length)
names(n_days)[names(n_days) == "day"] = "n_days"

summer_avg_n_days = merge(summer_avg, n_days, by = c("staSeq", "year"))
summer_avg_n_days = summer_avg_n_days[order(summer_avg_n_days$staSeq, summer_avg_n_days$year), ]

# Assign thermal classification
summer_avg_n_days$summer_category = ifelse(summer_avg_n_days$summer_avg_temp < 18.29, "Cold",
                                           ifelse(summer_avg_n_days$summer_avg_temp > 21.70, "Warm", "Cool"))

# Filter to only cold water sites
cold_summer_avg = summer_avg_n_days[summer_avg_n_days$summer_category == "Cold", ]
rownames(cold_summer_avg) = NULL

# Write out to csv
write.csv(cold_summer_avg, "cold_volunteer_22-25_temp_metrics.csv")
