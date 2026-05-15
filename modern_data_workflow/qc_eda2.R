#May need to run the following command in the terminal prior to installing RMariaDB:
#sudo apt install libmariadb-dev


#install.packages("dotenv")
#install.packages("RMariaDB")

library(RMariaDB)
library(dotenv)

load_dot_env("/home/deepuser/awx_cont_qc_upload/.env")

mysqlconnection = dbConnect(RMariaDB::MariaDB(),
                            dbname=Sys.getenv("DB_NAME"),
                            host=Sys.getenv("DB_HOST"),
                            port=as.integer(Sys.getenv("DB_PORT")),
                            user=Sys.getenv("DB_USER"),
                            password=Sys.getenv("DB_PASSWORD"))

fileName_vars = c("QC_2238844_14740_Water_20150709_20150724.csv")

quoted = paste(sprintf("'%s'", fileName_vars), collapse = ", ")

#Query to produce highest temperature values with no repeated files:
#SELECT fileName, MAX(temp) FROM temperature GROUP BY fileName ORDER BY MAX(temp) DESC LIMIT 40;

result = dbSendQuery(mysqlconnection, sprintf("SELECT * FROM temperature WHERE fileName IN (%s)", quoted))

initial_data = dbFetch(result, n = Inf)

dbClearResult(result)
dbDisconnect(mysqlconnection)

color_map = c("F" = "red", "S" = "orange", "P" = "black", "X" = "gray")
point_colors = color_map[initial_data$dataFlag]

plot(
  as.POSIXct(initial_data$mDateTime),
  initial_data$temp,
  col = point_colors,
  pch = 16,
  cex = 0.6,
  xlab = "Date-Time",
  ylab = "Temperature (°C)",
  main = paste("Temperature Readings for Site", initial_data$staSeq[1],
               "by Probe", initial_data$probeID[1])
)

legend(
  "topright",
  legend = c("Fail", "Suspect", "Pass", "No Data"),
  col    = c("red", "orange", "black", "gray"),
  pch    = 16
)
