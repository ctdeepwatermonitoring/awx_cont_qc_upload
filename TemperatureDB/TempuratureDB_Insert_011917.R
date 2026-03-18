library('RSQLite')
library('stringr')

#use if date time uses /.  Comment out function in loop if formatted correctly.
#yields a datetime ISO8601 string = YYYY-MM-DD HH:MM:SS.SSS
csv_to_db_datetime<-function(Date_Time){
	#comes in in the form: "M||M/DD/YYYY HH:MM" -> YYYY-MM-DD HH:MM:SS
	csv_datetime <- as.character(Date_Time);
	csv_datetime <- strsplit(csv_datetime,' '); # first split by the whitespace between YYYY and HH
	csv_date  <- csv_datetime[[1]][1];
	csv_date  <- strsplit(csv_date,'/'); #now split by / for D/M/Y
	dates <- c(csv_date[[1]][3],csv_date[[1]][1],csv_date[[1]][2]);
	dates <- str_pad(dates,2,pad='0');
	csv_time   <- csv_datetime[[1]][2];
	csv_time   <- strsplit(csv_time,':'); #now split
	times <- c(csv_time[[1]][1],csv_time[[1]][2]);
	times <- str_pad(times,2,pad='0');
	sql_date_time <- paste(paste(dates[1],dates[2],dates[3],sep='-'),paste(times[1],times[2],sep=':'));
	sql_date_time <- paste(sql_date_time,':00',sep='');
	sql_date_time #return YY-MM-DD HH:MM:SS
}

#open ODBC
db_path <- '/home/mkozlak/Documents/Projects/2020/TemperatureDB/' 
db <- dbConnect(SQLite(), dbname=paste(db_path,"stream.temperature.sqlite",sep=''));

#Identify and Cnt the Rows Before Upload of Unique Launch by Site##############
SQL<- "SELECT ProbeID, SID,min(Date_Time) as Date_Time,max(Date_Time) as Date_Time
              FROM probe_temps
              GROUP BY ProbeID,SID;"
rows.bfupld <- dbGetQuery(conn=db,SQL); #returns data.frame
rows.bfupld.cnt <-dim(rows.bfupld)
rows.bfupld.cnt[1]



#insert data into the DB=====================================
#test a static insert, checks out and enforces all at once version of PK constriants!!!
#[2] Instert .csv rows into with 'all rows or no rows' constraint from PK violations
csv_dir <- '/home/mkozlak/Documents/Projects/2020/TemperatureDB/HOBO Data for DB Upload - Fall 2019/csv/'
files <- list.files(csv_dir,'*.csv'); #only csv files extensions
m <- length(files);
count=0
for(j in 1:m){ #for each csv files in the directory
	data <- read.table(paste(csv_dir,files[j],sep=''),sep=',',header=T, stringsAsFactors=F,
	                   na.strings=c("","NA"));
	data <- data[!is.na(data[,'SID']),]
	data<-data[,1:7]
  names(data)<- c("Date_Time","Temp","UOM","ProbeID","SID","Collector","ProbeType")
	# n <- dim(data)[1] # number of rows in the csv file
	# for (i in 1:n){
	# 	data[i,'Date_Time'] <- csv_to_db_datetime(data[i,'Date_Time']);
	# }	
	#reorder by column name for insert to match the SQLite DB
	data <- data[c("ProbeID", "SID", "Date_Time","Temp","UOM","Collector","ProbeType")]
	
	data$CreateDate<-Sys.time()

	#return TRUE is all rows were entered, Error otherwise, ALL OR NOTHING
	if (length(unique(data$ProbeID))==1){
	  dbWriteTable(db,'probe_temps', data, append=T);
	} else {print(unique(data[c("ProbeID","SID")]))[1]}
	 #all or nothing append!!!
	#insert data into the DB=====================================
  count=count+1
}
#If Error - Identify File####
files[count+1]#File with Error
files[1:count]#Files that were successfully uploaded


#query/look at data as an R data.frame and native R types<<<<<<<<<<<<<<<<
#look at some data
names  <- dbListTables(db);                        # The tables in the database
fields <- dbListFields(db, "probe_temps");    # The columns in a table
table  <- dbReadTable(db, "probe_temps");  # get the whole table as a data.frame

#Identify and Cnt the Rows After Upload##############
SQL<- "SELECT ProbeID, SID,min(Date_Time) as Date_Time,max(Date_Time) as Date_Time
              FROM probe_temps
GROUP BY ProbeID,SID;"
rows.afupld <- dbGetQuery(conn=db,SQL); #returns data.frame
rows.afupld.cnt <-dim(rows.afupld)
rows.afupld.cnt[1]

#Standard Select of a Database Example.  
SQL <- "SELECT ProbeID, SID,min(Date_Time) as Date_Time,max(Date_Time) as Date_Time
            FROM probe_temps
            WHERE ProbeID == '10324586'"
response <- dbGetQuery(conn=db,SQL); #returns data.frame

#query/look at data as an R data.frame and native R types<<<<<<<<<<<<<<<<

#close ODBC
dbDisconnect(db)