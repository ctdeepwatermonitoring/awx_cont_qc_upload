library(readxl)

setwd("/home/mkozlak/Documents/Projects/2020/TemperatureDB/HOBO Data for DB Upload - Spring 2019")

csv_dir <- '/home/mkozlak/Documents/Projects/2020/TemperatureDB/HOBO Data for DB Upload - Spring 2019'
issue_folder <- '/home/mkozlak/Documents/Projects/2020/TemperatureDB/HOBO Data for DB Upload - Spring 2019/FilesWithIssues'
files <- list.files(csv_dir,'*.xlsx'); #only xlsx files extensions

for (i in 1:length(files)){
  
  data<-read_excel(files[i], sheet = 1)
  
  if (dim(data)[2]==7){
    names(data)<- c("Date_Time","Temp","UOM","ProbeID","SID","Collector","ProbeType")
    write.csv(data,paste0("csv/",files[i],".csv"),row.names=FALSE)
  } else {
    file.copy(files[i],issue_folder)
  }
  
}




