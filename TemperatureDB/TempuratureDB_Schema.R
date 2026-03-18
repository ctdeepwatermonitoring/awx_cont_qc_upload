#[1] Build the schema
library('RSQLite')

#set the path and connect to the driver
#db_path <- 'C:\\Users\\tjb09009\\Desktop\\'; #on windows like this...
db_path <- 'S:/M_Kozlak/Temperature/TemperatureDB/' #on mac/unix like this
db <- dbConnect(SQLite(), dbname=paste(db_path,"stream.temperature.sqlite",sep=''));

#table generation-----------------------------------------------------
#schema => probe_temps( ProbeID, SID, Date_Time, Temp, UOM, Collector )
SQL <- "CREATE TABLE probe_temps
             (
             	ProbeID text not null,
             	SID text not null,
             	Date_Time datetime not null, 
             	Temp real,
             	UOM text,
             	Collector text,
              ProbeType text,
              CreateDate text,
             	primary key (ProbeID,SID,Date_Time)
             );"
dbSendQuery(conn=db,SQL);
#table generation-----------------------------------------------------

#close connection000000000000000000000000000000000000
#delete the table
#dbRemoveTable(db, "probe_temps");   # Drop/Remove the table.     
dbDisconnect(db); #no more ODBC or variable db...
#rm(list = c("names","fields","table")); #remove from workspace
#close connection000000000000000000000000000000000000