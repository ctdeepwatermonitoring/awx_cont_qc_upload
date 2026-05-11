#May need to run the following command in the terminal prior to installing RMariaDB:
#sudo apt install libmariadb-dev


#install.packages("dotenv")
#install.packages("RMariaDB")

library(RMariaDB)
library(dotenv)

load_dot_env("/home/deepuser/awx_cont_qc_upload/.env")

mariadbconnection_cont = dbConnect(RMariaDB::MariaDB(),
                            dbname=Sys.getenv("DB_NAME"),
                            host=Sys.getenv("DB_HOST"),
                            port=as.integer(Sys.getenv("DB_PORT")),
                            user=Sys.getenv("DB_USER"),
                            password=Sys.getenv("DB_PASSWORD"))

mariadbconnection_awqx = dbConnect(RMariaDB::MariaDB(),
                                 dbname=Sys.getenv("DB_NAME2"),
                                 host=Sys.getenv("DB_HOST"),
                                 port=as.integer(Sys.getenv("DB_PORT")),
                                 user=Sys.getenv("DB_USER"),
                                 password=Sys.getenv("DB_PASSWORD"))

staSeq_vars = c(17300, 14390)

result1 = dbSendQuery(mariadbconnection_awqx, sprintf("SELECT staSeq, locationName FROM stations WHERE staSeq IN (%s)",
                                                    paste(staSeq_vars, collapse = ", ")))

sites_clean = dbFetch(result1, n = Inf)

dbClearResult(result1)
dbDisconnect(mariadbconnection_awqx)

result2 = dbSendQuery(mariadbconnection_cont, sprintf("SELECT * FROM temperature WHERE staSeq IN (%s)",
                                              paste(staSeq_vars, collapse = ", ")))

initial_data = dbFetch(result2, n = Inf)

initial_data$mDateTime = as.POSIXct(format(initial_data$mDateTime, tz = "UTC"), tz = "America/New_York")

initial_data$hour = format(initial_data$mDateTime, format = "%H")

initial_data$date_only = as.Date(initial_data$mDateTime, tz = "America/New_York")

hourly_coverage = aggregate(hour ~ probeID + staSeq + date_only, data = initial_data, function(x) length(unique(x)))
colnames(hourly_coverage)[colnames(hourly_coverage) == "hour"] = "n_hours"

complete_probe_days = hourly_coverage[hourly_coverage$n_hours == 24, ]

complete_days = unique(complete_probe_days[, c("staSeq", "date_only")])

dbClearResult(result2)
dbDisconnect(mariadbconnection_cont)

#Calculating daily means
daily_means = initial_data
daily_means$year = strftime(daily_means$mDateTime, "%Y", tz = "America/New_York")
daily_means$month = as.integer(strftime(daily_means$mDateTime, "%m", tz = "America/New_York"))
daily_means = merge(daily_means, complete_days[, c("staSeq", "date_only")],
                    by = c("staSeq", "date_only"),
                    all = FALSE)
daily_means = aggregate(temp ~ staSeq + date_only + year + month, data = daily_means,
                        FUN = mean)
colnames(daily_means)[colnames(daily_means) == "temp"] = "mean_temp"
daily_means = merge(daily_means, sites_clean,
                    by = "staSeq",
                    all.x = TRUE)
daily_means$locationName[is.na(daily_means$locationName)] = "Unknown"
daily_means$staSeq_waterbodyName = paste(daily_means$staSeq, "-", daily_means$locationName)
daily_means$category[daily_means$mean_temp < 18.29] = "Cold"
daily_means$category[daily_means$mean_temp > 21.70] = "Warm"
daily_means$category[daily_means$mean_temp >= 18.29 & daily_means$mean_temp <= 21.70] = "Cool"


#Calculating summer averages
summer_data = subset(daily_means, month %in% 6:8)
summer_avg = aggregate(mean_temp ~ staSeq + year + locationName + staSeq_waterbodyName,
                       data = summer_data, FUN = mean)
colnames(summer_avg)[colnames(summer_avg) == "mean_temp"] = "summer_avg_temp"
summer_avg$summer_category[summer_avg$summer_avg_temp < 18.29] = "Cold"
summer_avg$summer_category[summer_avg$summer_avg_temp > 21.70] = "Warm"
summer_avg$summer_category[summer_avg$summer_avg_temp >= 18.29 & summer_avg$summer_avg_temp <= 21.70] = "Cool"

#Calculating complete summer days
summer_day_counts = aggregate(date_only ~ staSeq + year,
                               data = subset(daily_means, month %in% 6:8),
                               FUN = function(x) length(unique(as.Date(x, tz = "America/New_York"))))
colnames(summer_day_counts)[colnames(summer_day_counts) == "date_only"] = "n_days_summer"

july_day_counts = aggregate(date_only ~ staSeq + year,
                              data = subset(daily_means, month == 7),
                              FUN = function(x) length(unique(as.Date(x, tz = "America/New_York"))))
colnames(july_day_counts)[colnames(july_day_counts) == "date_only"] = "n_days_july"

#Calculating July means
july_data = subset(daily_means, month == 7)
july_avg = aggregate(mean_temp ~ staSeq + year + locationName + staSeq_waterbodyName,
                     data = july_data, FUN = mean)
colnames(july_avg)[colnames(july_avg) == "mean_temp"] = "july_avg_temp"
july_avg$july_category[july_avg$july_avg_temp < 18.29] = "Cold"
july_avg$july_category[july_avg$july_avg_temp > 21.70] = "Warm"
july_avg$july_category[july_avg$july_avg_temp >= 18.29 & july_avg$july_avg_temp <= 21.70] = "Cool"

#Max daily mean for summer
summer_max = aggregate(mean_temp ~ staSeq + year + locationName + staSeq_waterbodyName,
                       data = summer_data, FUN = max)
colnames(summer_max)[colnames(summer_max) == "mean_temp"] = "max_daily_mean"
summer_max$max_category[summer_max$max_daily_mean < 18.29] = "Cold"
summer_max$max_category[summer_max$max_daily_mean > 21.70] = "Warm"
summer_max$max_category[summer_max$max_daily_mean >= 18.29 & summer_max$max_daily_mean <= 21.70] = "Cool"


#Merge july avg, max daily avg, and summer day counts with summer avg
summer_avg = merge(summer_avg, july_avg,
                   by = c("staSeq", "year", "locationName", "staSeq_waterbodyName"),
                   all.x = TRUE)
summer_avg = merge(summer_avg, summer_max,
                   by = c("staSeq", "year", "locationName", "staSeq_waterbodyName"),
                   all.x = TRUE)
summer_avg = merge(summer_avg, summer_day_counts,
                   by = c("staSeq", "year"),
                   all.x = TRUE)
summer_avg = merge(summer_avg, july_day_counts,
                   by = c("staSeq", "year"),
                   all.x = TRUE)




#Temperature heatmap
#sites = levels(factor(summer_avg$staSeq_waterbodyName))
all_sites_clean = sites_clean[sites_clean$staSeq %in% as.character(staSeq_vars), ]
all_sites_clean$staSeq_waterbodyName = paste(all_sites_clean$staSeq, "-", all_sites_clean$locationName)
sites = all_sites_clean$staSeq_waterbodyName
years = sort(unique(as.integer(summer_avg$year)))

color_map = c("Cold" = "blue", "Cool" = "cornflowerblue", "Warm" = "red")
fill_colors = color_map[summer_avg$summer_category]

x_pos = as.integer(summer_avg$year)
y_pos = match(summer_avg$staSeq_waterbodyName, sites)

par(mar = c(4, 10, 3, 8), xpd = TRUE)
plot(NULL,
     xlim = c(min(years) - 0.5, max(years) + 0.5),
     ylim = c(0.5, length(sites) + 0.5),
     xlab = "Year",
     ylab = "",
     main = "Summer Mean Water Temperatures (June-August)",
     xaxt = "n",
     yaxt = "n"
)
title(ylab = "Site (Waterbody)", line = 8)

rect(
  xleft   = x_pos - 0.5,
  xright  = x_pos + 0.5,
  ybottom = y_pos - 0.4,
  ytop    = y_pos + 0.4,
  col     = fill_colors,
  border  = NA
)

all_years = seq(min(years), max(years))
axis(1, at = all_years, labels = all_years)
axis(2, at = seq_along(sites), labels = sites, las = 2, cex.axis = 0.6)

legend(x = par("usr")[2] + 0.5, y = mean(par("usr")[3:4]),
       legend = names(color_map),
       fill = color_map,
       border = NA,
       bty = "n",
       xjust = 0,
       yjust = 0.5)
