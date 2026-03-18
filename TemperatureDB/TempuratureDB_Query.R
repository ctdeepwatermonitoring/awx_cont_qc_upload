library(RSQLite)
library(plyr)
library(ggplot2)
library(lubridate)

#open ODBC
db_path <- '/home/mkozlak/Documents/Projects/2020/TemperatureDB/' #linux path
db <- dbConnect(SQLite(), dbname=paste(db_path,"stream.temperature.sqlite",sep=''));

##Query with Field Flags and put into R data.fram and native R types
SELECTflag<- "SELECT probe_temps.ProbeID, probe_temps.SID, probe_temps.Date_Time, probe_temps.Temp, probe_temps.UOM, probe_temps.Collector, probe_temps.ProbeType, fieldflag.DateStart, fieldflag.DateEnd, fieldflag.COMMENT
FROM probe_temps
LEFT JOIN fieldflag ON probe_temps.ProbeID = fieldflag.ProbeID AND probe_temps.SID = fieldflag.SID AND probe_temps.Date_Time >= fieldflag.DateStart AND probe_temps.Date_Time <= fieldflag.DateEnd"

table<- dbGetQuery(db,SELECTflag)

#query/look at data as an R data.frame and native R types<<<<<<<<<<<<<<<<
#look at some data
#names  <- dbListTables(db);                        # The tables in the database
#fields <- dbListFields(db, "probe_temps");    # The columns in a table
#table  <- dbReadTable(db, "probe_temps");  # get the whole table as a data.frame

#Summarize data by day
table$day <- substr(table$Date_Time,6,10)##Add column of data that includes month_day
table$month<- substr(table$Date_Time,6,7)##Add column of data that includes month
table$year<- substr(table$Date_Time,1,4)##Add column of data that includes year
table$date<-ymd_hms(table$Date_Time)


##Write CSV of Avg Day with Flag for all records##
AvgDay <- ddply(table,c("ProbeID","SID","day","month","year","Collector","UOM","COMMENT"),summarize,mean=mean(Temp),min=min(Temp),
                max=max(Temp),maxmin= (max(Temp)-min(Temp)),N=length(Temp))#AvgByDay
AvgDay$Flag [AvgDay$N<24|AvgDay$min<0|AvgDay$maxmin>5|AvgDay$mean>=30]<-1
AvgDay$Flag [!is.na(AvgDay$COMMENT)]<-1
write.csv(AvgDay,"/home/mkozlak/Documents/Projects/2020/TemperatureDB/TempAvgDay.csv",row.names=FALSE)


#Merge AvgDay Flags and Remove Flagged Values for Upload to SHEDS
Flag<- AvgDay[,c(1:5,14)]
SHEDS<- merge(x=table,y=Flag,by=c("ProbeID","SID","day","month","year"),all.x=TRUE)
SHEDS<- SHEDS[is.na(SHEDS[,'Flag']),]
SHEDS<- SHEDS[which(SHEDS$year==2018& SHEDS$Collector=='ABM'),]
SHEDS<- SHEDS[,c(2,6,7)]
SHEDS<-SHEDS[order(SHEDS$SID,SHEDS$Date_Time),]
write.csv(SHEDS,"/home/mkozlak/Documents/Projects/2020/TemperatureDB/TemperatureDataForSHEDS_031820.csv",row.names=FALSE)


##Graphics of Daily Max Min Flux######
windows(title="Daily Temp Flux By Month",5,5)
ggplot(AvgDay,aes(x=month,y=maxmin,fill=month))+
  geom_boxplot()+
  ylim(NA,10)
AvgDayMonth<-subset(AvgDay,month=="10")
quantile(AvgDayMonth$maxmin,c(.25,.50,.75,.90,.99))

##############Calculate Metrics#######################


n<-1

TempMetricsAll<-data.frame(SID=character(),SummerTemp=numeric(),SN=numeric(),TempCatS=character(),JulyTemp=numeric(),JN=numeric(),
                 TempCatJ=character(),MaxD=numeric(),MN=numeric(),TempCatM=character(),
                 Max24.9=numeric(),Max27=numeric(),Flag=numeric(),Year=character(),Collector=character())


SummerMonthCnt<-table[table$month=='06'|table$month=='07'|table$month=='08',]
yrCol<- unique(SummerMonthCnt[,c('year','Collector')])



for (n in 1:dim(yrCol)[1]){

temp <- table[which(table$Collector==yrCol[n,2] & table$year==yrCol[n,1]),]##Subset by Year and Collector

AvgDay <- ddply(temp,c("SID","day","month","year"),summarize,mean=mean(Temp),N=length(Temp))#AvgByDay
AvgDay$day<-as.numeric(substr(AvgDay$day,4,5))

MaxDay<- ddply(temp,c("SID","day","month","year"),summarize,max=max(Temp),N=length(Temp))#MaxOnAGivenDay
MaxDay$d<-as.numeric(substr(MaxDay$day,4,5))

##Avg Summer Temp##
SummerMonths <- AvgDay[AvgDay$month=='06'|AvgDay$month=='07'|AvgDay$month=='08'&AvgDay$N>=24,]
AvgSummerTemp <- ddply(SummerMonths,"SID",summarize,SummerTemp=mean(mean),SN=length(mean))#Summer Temp Month
AvgSummerTemp$TempCatS <- AvgSummerTemp$SummerTemp
AvgSummerTemp$TempCatS<- as.character(AvgSummerTemp$TempCat)
AvgSummerTemp$TempCatS[AvgSummerTemp$SummerTemp<18.29]<-"Cold"
AvgSummerTemp$TempCatS[AvgSummerTemp$SummerTemp>21.7]<-"Warm"
AvgSummerTemp$TempCatS[AvgSummerTemp$SummerTemp>=18.29&AvgSummerTemp$SummerTemp<=21.7]<-"Cool"

##Avg July Temp##
July<- AvgDay[AvgDay$month=='07'& AvgDay$N>=24,]
AvgJulyTemp <- ddply(July,"SID",summarize,JulyTemp=mean(mean),JN=length(mean))#Summer Temp Month
AvgJulyTemp$TempCatJ <- AvgJulyTemp$JulyTemp
AvgJulyTemp$TempCatJ<- as.character(AvgJulyTemp$TempCat)
AvgJulyTemp$TempCatJ[AvgJulyTemp$JulyTemp<18.45]<-"Cold"
AvgJulyTemp$TempCatJ[AvgJulyTemp$JulyTemp>22.30]<-"Warm"
AvgJulyTemp$TempCatJ[AvgJulyTemp$JulyTemp>=18.45&AvgJulyTemp$JulyTemp<=22.30]<-"Cool"

##Max Daily Mean##
MaxDailyTemp <- ddply(AvgDay,"SID",summarize,MaxD = max(mean),MN=length(mean))
MaxDailyTemp$TempCatM <- MaxDailyTemp$MaxD
MaxDailyTemp$TempCatM <- as.character(MaxDailyTemp$MaxD)
MaxDailyTemp$TempCatM [MaxDailyTemp$MaxD<22.4]<- "Cold"
MaxDailyTemp$TempCatM [MaxDailyTemp$MaxD>26.3]<- "Warm"
MaxDailyTemp$TempCatM [MaxDailyTemp$MaxD>=22.4&MaxDailyTemp$MaxD<=26.3]<- "Cool"

##N Days >= 24.9 degree C and N Days >= 27 May 1 - Sept 15##
MaxDates<- MaxDay[MaxDay$month=='05'|MaxDay$month=='06'|MaxDay$month=='07'|MaxDay$month=='08'|
                    (MaxDay$month=='09' & MaxDay$d<=15),]
MaxDates$MaxTemp24.9<- ifelse(MaxDates$max>=24.9,1,0)
MaxDates$MaxTemp27<- ifelse(MaxDates$max>=27,1,0)
MaxGreaterThanTemp<-ddply(MaxDates,"SID",summarize,Max24.9=sum(MaxTemp24.9),Max27=sum(MaxTemp27))


##Combine and Export Metrics By Year
TempMetrics <- merge(AvgSummerTemp,AvgJulyTemp,by="SID")
TempMetrics <-merge(TempMetrics,MaxDailyTemp,by="SID")
TempMetrics <-merge(TempMetrics,MaxGreaterThanTemp,by="SID")
TempMetrics$Flag [TempMetrics$SN<92|TempMetrics$JN <31] <- 1
TempMetrics$Year<-yrCol[n,1]
TempMetrics$Collector<-yrCol[n,2]

TempMetricsAll<-rbind(TempMetricsAll,TempMetrics)

write.csv(TempMetrics,"/home/mkozlak/Documents/Projects/2020/TemperatureDB/MetricCalcs/TempMetrics031820.csv",append=TRUE,row.names=FALSE)
write.csv(TempMetrics,paste0("/home/mkozlak/Documents/Projects/2020/TemperatureDB/MetricCalcs/TempMetrics070219_",yrCol[n,2],yrCol[n,1],".csv"),row.names=FALSE)
}



#######################################################################################################

########Query to Update Incorrect Data################

Update <- "UPDATE probe_temps
                  SET SID='15240'
                  WHERE SID = '15420'"
dbGetQuery (db,Update)

Update <- "UPDATE probe_temps SET ProbeID='10332632', SID='14609' WHERE ProbeID = '14609' and SID = '10332632'"
dbGetQuery (db,Update)

#Query Data By SID to get Date_Times collected##
SID <- "SELECT  ProbeID, SID, Date_Time
              FROM probe_temps
             WHERE SID == '15420'"

SIDresponse <- dbGetQuery(conn=db,SID)

#Standard Select of a Database
#example get the average Temp for a given site on a given day
SQL <- "SELECT ProbeID,SID,date(Date_Time),avg(Temp)
			 FROM probe_temps
			 WHERE ProbeID like '9937177' and SID like '14819'
			 GROUP BY date(Date_Time)"
			
response <- dbGetQuery(conn=db,SQL); #returns data.frame

SQL <- "SELECT * FROM probe_temps
           WHERE ProbeID = '10777328' and SID = '16110' and Date_Time > 9/15/2016 "

response <- dbGetQuery(conn=db,SQL)
#query/look at data as an R data.frame and native R types<<<<<<<<<<<<<<<<


#close ODBC
dbDisconnect(db);