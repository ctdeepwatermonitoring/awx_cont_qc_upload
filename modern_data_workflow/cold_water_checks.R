library(RMariaDB)
library(dotenv)

load_dot_env(".env")

mariadbconnection_cont = dbConnect(RMariaDB::MariaDB(),
                                   dbname=Sys.getenv("DB_NAME"),
                                   host=Sys.getenv("DB_HOST"),
                                   port=as.integer(Sys.getenv("DB_PORT")),
                                   user=Sys.getenv("DB_USER"),
                                   password=Sys.getenv("DB_PASSWORD"))
first_create_date = '2026-08-21 00:00:00'
second_create_date = '2026-08-21 23:59:59'
result = dbSendQuery(mariadbconnection_cont, sprintf("SELECT * FROM temperature WHERE createDate BETWEEN '%s' AND '%s'",
                     first_create_date, second_create_date))
initial_data = dbFetch(result, n = Inf)
dbClearResult(result)
dbDisconnect(mariadbconnection_cont)
