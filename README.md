# awx_cont_qc_upload
Workflow to clean, run QC checks, format and upload continuous data to cont schema in awx.

Alexander Towle\
Alexander.Towle@ct.gov\
Last updated: 2026-05-15\
Documentation of Data Pipeline, Cleaning, and Processing



Required packages for cleaning and processing:\
ContDataQC\
(loaded automatically in csv_qc.R.)

Not always required, but useful: Set GitHub credentials in the R environment using gitcreds::gitcreds_set()



File structure required for this program:

home\
└── ContDataQC                                        #https://github.com/ctdeepwatermonitoring/awx_cont_qc_upload \
&emsp;&emsp;    ├── .env\
&emsp;&emsp;    ├── modern_data_workflow\
&emsp;&emsp;    │&emsp;   ├── csv_qc2.R\
&emsp;&emsp;    │&emsp;   ├── migration_prep2.R\
&emsp;&emsp;    │&emsp;   ├── config_deep2.R\
&emsp;&emsp;    │&emsp;   ├── data_to_qc\
&emsp;&emsp;    │&emsp;   ├── qced_data\
&emsp;&emsp;    │&emsp;   ├── raw_data                                  #DEPLOYMENT CSVS GO HERE\
&emsp;&emsp;    │&emsp;   ├── error_files\
&emsp;&emsp;    │&emsp;   │&emsp;   └── error_log\
&emsp;&emsp;    │&emsp;   └── wqx_upload\
&emsp;&emsp;    │&emsp;    &emsp;&emsp;   ├── upload_excel_files\
&emsp;&emsp;    │&emsp;    &emsp;&emsp;   └── wqx_formatting.py\
&emsp;&emsp;    └── TemperatureDB\
&emsp;&emsp;&emsp;&emsp;        └── db\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            ├── cnf\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;   └── user.cnf.txt\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            ├── testFTP\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;   └── Upload\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;&emsp;&emsp;       ├── ContData\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;&emsp;&emsp;       ├── ErrRpts\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;&emsp;&emsp;       └── UploadedRpts\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;&emsp;&emsp;&emsp;&emsp;           └── Temperature\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            │&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;               └── Error\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;            └── db_app\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;                ├── insert_temp_results_windows.py\
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;                └── insert_temp_results_linux.py



## Steps for QC of Modern Data (Documentation of csv_qc2.R)

Step 1: Load ContDataQC and MariaDB\
The code used for this can be found in this GitHub repository: https://github.com/ctdeepwatermonitoring/water_temperature\
It can be installed with the code given in the file or it can be loaded from a local copy using devtools::load_all("/path/to/directory").\
MariaDB is also connected to using the variables in the .env file.\
A .env.example file is included in this repository.\
Site IDs are queried from the database for checks to ensure that site IDs exist and match the file name.

Step 2: Initialize input and output directories\
Once initialized, all csv files are placed into a list and the total amount of files is found to show progress.

Step 3: Correct any known common errors\
Certain errors in formatting are more common than others.\
These errors are usually due to misspellings or punctuation differences.\
Known errors are handled at this stage.\
ex.\
Any file using "ProbID" as a column name will be corrected to "ProbeID".

Step 4: Arrange by Date_Time\
Some files may not have chronologically ordered data.\
The QC flags compare adjacent points in the csv for anomalies such as spikes.\
If data is not ordered chronologically then it is potentially comparing temperatures at radically different times of day or seasons.\
This produces high failure rates.\
To avoid this, files need to be put in chronological order before being written out.

Step 5: Convert datetimes to proper format, add mDate and mTime\
Date, Time, and Datetime are needed to make the QC method work smoothly.\
Datetime usually starts in the format MM/DD/YY.\
This is unexpected by ContDataQC, so this file converts to YYYY-MM-DD.

Step 6: Write out to subfolders\
Subfolders use the naming convention: probeID_staSeq_Water_startdeploymentDate_endDeploymentDate\
This uniquely identifies a deployment.\
ex.\
A folder containing the csv for the deployment of probe 824593 at site 14444 from Oct 13, 2010 to March 31, 2011 would be 824593_14444_Water_20101013_20110331\
File names use the naming convention: staSeq_Water_startDeploymentDate_endDeploymentDate.csv\
This is required for the QC method.\
ex.\
A csv for the deployment of probe 824593 at site 14444 from Oct 13, 2010 to March 31, 2011 would be 14444_Water_20101013_20110331.csv.\
The QC method requires this file name, so we need the subfolders to uniquely identify them.\
The subfolders also speed up runtime.\
The QC method scans every csv in a folder for a matching site and deployment from the file name, so by scanning the subfolder we drastically reduce runtime.

Step 7: Read in recently written out data\
The QC method needs to read in csvs, hence why data is written out before being read again.\
Total files are also calculated.

Step 8: Fill default values for deployments with less than 5 entries\
The QC method does not work if there are less than 5 records in a file.\
If this is the case, default values are assigned and data flags are assigned as "X".

Step 9: Call QC method\
For deployments with 5 or more entries, ContDataQC is called with the QCRaw operation using the information parsed from the file name and the config file.\
Files with QC values and data for internal processing are written to the output directory.\
For the modern data, the config_deep2.R file must be used in the QC method call.\
The same subfolders that were used in creating the csvs are also created in the output directory to uniquely identify deployments.\
The QC method produces files with the naming convention: QC_staSeq_Water_startDeploymentDate_endDeploymentDate.csv\
ex.\
A QCed csv for the deployment of probe 824593 at site 14444 from Oct 13, 2010 to March 31, 2011 would be QC_14444_Water_20101013_20110331.csv.\
The QCed csvs will have the same columns as the inital csv in addition to several others, including QC flags and others needed for internal processing.\
ex.
| probeID | staSeq |  mDate |      mTime|       parameter|           temp|    uom|         createDate|  comment| mDateTime|           Month|   Day| Year|    MonthDay|    Flag.Gross.temp| Flag.Spike.temp| Flag.RoC.temp|   Flag.Flat.temp|  Flag.temp|   RAW.mDateTime|       Comment.MOD.mDateTime|   RAW.probeID| Comment.MOD.probeID| RAW.staSeq|  Comment.MOD.staSeq|	RAW.mDate|   Comment.MOD.mDate|	RAW.mTime|   Comment.MOD.mTime|	RAW.parameter|       Comment.MOD.parameter|	RAW.temp|    Comment.MOD.temp|	RAW.uom |Comment.MOD.uom|	RAW.createDate|  Comment.MOD.createDate|	RAW.comment| Comment.MOD.comment |
|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|:------|
| 1298184|	17701|	2011-05-25|	14:11:27|	Water Temperature|	20.198|	Degrees C|	2012-12-07|	None|	2011-05-25 14:11:27|	5|	    25|	2011|	525|	        P|	            F|	            S|	            P|	            F|           2011-05-25 14:11:27|	          |              1298184|	        |                17701|	         |               2011-05-25|	         |           14:11:27|	         |           Water Temperature|	          |              20.198|	    |                    Degrees C|	     |       2012-12-07|	          |                  None|  |

Note: Any errors throughout this process will result in the offending file moved into the folder error_files.\
A log of the error will be created in the subfolder of error_files called error_log.\
Common errors are handled after reading the csv, but procedures may need to be adjusted as new data is acquired.

## Steps for QC EDA (Documentation of qc_eda.R)

Step 1: Gather all QCed data\
The directory where the QCed data was put is initialized, and a list is made of all csv files in the subfolders.\
The deployment_id is reassigned, this time as the subfolder name.\
All data from the csvs are put into one dataframe called all_flagged_data.

Step 2: Calculating daily means\
Daily mean temperatures are calculated, including only days with at least 24 hours of data.\
Temperature categories are assigned as Cold, Cool, and Warm.

Step 3: Calculating summer averages\
Data is filtered to summer months and summer means are determined from the data in step 2.

Step 4: Producing overall flag counts and percentages\
A table is produced that shows each of the four flag types (P - Pass, F - Fail, S - Suspect, X - No Data).\
It shows percentages and how many occurances there are of each flag type.

Step 5: Breaking down flags by causes\
Overall flags are assigned based on four qualities, each given their own flag: flatline, spike, rate of change, and gross value.\
If any one of these fails, the overall flag fails.\
If none fail but any one of them is suspect, the overall flag is suspect.\
If none fail or are suspect, and at least one of them passes, the overall flag is pass.\
If there is no data for all of them, the overall flag is no data.\
A table is produced that totals up and gives percentages for all of the reasons that overall flags were assigned.\
Combined reasons are counted separately (ex. A point that failed both RoC and Spike is counted under the "RoC + Spike" bin rather than counting it twice in the "RoC" bin and the "Spike" bin).

Step 6: Give individual deployments bins\
To gain a better idea of how many points are failing at certain sites, bins are created in 5% increments from 0%-100.\
Each deployment is summarised and sorted into these bins.\
ex.\
A deployment with 100 records where 4 fail and 32 are suspect falls into the 0%-5 fail bin and the 30%-5 suspect bin.

Step 7: Get counts of failure and suspect bins\
The bins are summarised to show how many records fall into each bin.\
Deployments can be filtered by bin to find high failure or suspect sites.

Step 8: Producing a visualization of flags for deployment\
Specifying a deployment_id can create a visualization of that deployment.\
It shows the records of water temperature over the course of the deployment.\
Points are color-coded with black for passing points, orange for suspect points, red for failing points, and gray for no data.

## Steps for QC EDA of a Specific Site (Documentation of qc_eda2.R)

Step 1: Connect to MariaDB\
This script first connects to MariaDB using the credentials found in the .env file.

Step 2: Specify a file name and send query\
A file name can be specified in fileName_vars.\
A query to gather all data belonging to this file name is sent to the database.

Step 3: Produce visualization\
A scatterplot is created showing the temperature readings over time.\
The points are color coded based on their flag.

## Steps to prepare modern data for migration into the modern database (Documentation of migration_prep2.R)

Step 1: Gather all csv files\
Input and output directories are specified.\
All csv files in the input directory are put into a list.

Step 2: Loop through the data, modify, and write out a new csv\
Each file is read, then modified to the expected format.\
Some columns are renamed and some do not exist in the old data and are added in.\
Added columns: comment (set to "" by default).\
Renamed columns: Flag.temp -> dataFlag.\
Date_Time, Temp, UOM, ProbeID, SID, Collector, and ProbeType get carried over.\
Everything else gets left out.\
ex.
|Date_Time|Temp  |  UOM  |   ProbeID| SID|     Collector|   ProbeType|   dataFlag|    comment|
|:------|:------|:------|:------|:------|:------|:------|:------|:------|
|2011-05-25 14:11:27| 20.198|  deg C|   1298184|	17701|   ABM|         HOBO|	    P|           None|

New csv files are placed in the output directory without subfolders and use the naming convention: QC_probeID_staSeq_Water_startDeploymentDate_endDeploymentDate.csv\
ex.\
A csv for the deployment of probe 824593 at site 14444 from Oct 13, 2010 to March 31, 2011 would be QC_824593_14444_Water_20101013_20110331.csv\
The files are written out and will use the insert_temp_results_windows.py or insert_temp_results_linux.py script to be taken into the database.

Note: Any errors throughout this process will result in the offending file moved into the folder error_files.\
A log of the error will be created in the subfolder of error_files called error_log.

## Steps for Getting Summaries by Querying the Database (Documentation of db_connect_summaries.R)

Step 1: Connect to the cont and awqx databases\
Using the credentials in the .env file, both databases are connected to.\
staSeq_vars is a comma-separated list of site IDs of interest that can be entered by the user.\
The awqx database is queried to gather the staSeq and locationName from the sites in staSeq_vars.\
The cont database is queired to gather all temperature data from the list of sites.

Step 2: Compute number of complete days\
Only days on sites with at least 24 hours of data are to be considered.\
Any day for a site with less is filtered out and not included in the count per site.

Step 3: Calculate daily means\
The mean temperature id calculated for each site for each day.\
The number of complete days is merged in, site names are added, and thermal classifications are assigned.

Step 4: Calculate summer data, July data, number of days, and max daily mean\
The daily_means are filtered to only summer months.\
The mean of them is taken for each site each year and thermal classifications are assigned.\
The complete number of days for the summer is calculated.\
The process is repeated for the month of July.\
The maximum daily mean is calculated for the summer months at each site for each year.\
This is also given a thermal classification.

Step 5: Heatmap of thermal classifications\
A heatmap is created of the mean summer temperatures over the years using the thermal classifications for the specified sites.\
This serves as a timeline to determine how sites thermal classifications changed over the years.\

## Process for formatting data for upload to WQX (Documentation of wqx_formatting.py)

To begin, change the directory to awx_cont_qc_upload/modern_data_workflow/wqx_upload.

Install the requirements using pip install -r requirements.txt.

Run the python script wqx_formatting.py.

The script begins by loading the .env file located in awx_cont_qc_upload.

The database is then connected to via mysql-connector.

Once a connection is established, a query is made to pull every fileName from the database.\
These fileNames are how we can specify unique deployments.

The total files are counted and stored to track progress.

When uploading to WQX, the OrganizationID value from the first row will be taken to represent the whole dataset.
Because of this, two lists (ctvolmon_list and ct_dep01_wqx_list) are created to store the dataframes for each collector.
WQX also recommends file lengths of no more than 25000 rows.
For this reason, the sum of the dataframe lengths in each list are tracked.
Numbers for file naming starting at 0 are also tracked.

Each fileName is iterated through and all data from the temperature table with the matching fileName is selected.\
The data is placed into a dataframe with the following columns:\
'probeID', 'staSeq', 'mDateTime', 'temp', 'uom', 'collector', 'probeType', 'fileName', 'dataFlag', 'comment', 'createDate', 'createUser', 'lastUpdateDate', 'lastUpdateUser'

Unnecessary columns are dropped.\
These include:\
'probeType', 'createDate', 'createUser', 'lastUpdateDate', 'lastUpdateUser'

The date from the mDateTime column is then extracted for grouping.

Time intervals vary across probes, so we can't just filter for 24 readings per day.\
If a probe reads in 15 minute intervals, it could have more than 24 readings and still not be a complete day.\
Therefore we need to create a check that ensures that the probe has at least 24 readings in each day and also that the readings cover every hour of the day from 00:00 to 23:00.\
To do this, we can create a pivot table called hourly_counts that counts the number of readings for each hour of the day for each probeID and staSeq, and then filter for groups that have at least 1 reading in each hour of the day and at least 24 readings in total.\
The filtered data is stored as complete_hourly_counts.\
A new dataframe is created called complete_days_results_df which is the result of an inner merge of temperature_results_df and complete_hourly_counts on probeID, staSeq, and date, thus filtering out incomplete days.

If there are no complete days, the program will skip to the next file.

The hour counts are then dropped from the dataframe as they are no longer needed.

If the comment column is null it will be replaced with "None" as a null value will crash the program.

complete_days_results_gf is then grouped by the 'probeID', 'staSeq', 'date', 'uom', 'collector', 'fileName', and 'comment' columns.\
Each type of dataFlag value is counted and stored in flag_counts for each probeID for each staSeq for each day.

Daily mean temperatures are then calculated from complete_day_results_df and stored in the dataframe daily_mean_temps.\
flag_counts is merged in so that the counts of each flag type are available.

daily_mean_temps has a new column created called 'ResultCommentText' which contains any comments present in the data as well as the totals of each dataFlag.

wqx_upload_df is a dataframe that is created to store the values necessary for upload to WQX.\
It contains the following columns:\
'OrganizationID', 'ProjectID', 'ActivityType', 'ActivityMediaName', 'SampleCollectionEquipmentName', 'CharacteristicName', 'ResultUnit', 'ResultStatusID', 'StatisticalBaseCode', 'ResultValueType', 'ResultTimeBasis', 'ActivityID', 'ActivityStartDate', 'ActivityEndDate', 'MonitoringLocationID', 'ResultValue', 'ResultCommentText', 'AnalysisStartDate', 'AnalysisEndDate'

'ResultValue' is filled in as the daily_mean_temps 'daily_mean_temp' column.\
If the 'collector' column for daily_mean_temps is 'ABM', 'OrganizationID' will be filled in as 'CT_DEP01_WQX' and 'ProjectID' will be filled in as 'HOBOtemperature'.\
If the 'collector' column for daily_mean_temps is 'VOL', 'OrganizationID' will be filled in as 'CTVOLMON' and 'ProjectID' will be filled in as 'CT-VOLMON-VSTEM'.\
'ActivityType' is filled in as 'FieldMsr/Obs'.\
'ActivityMediaName' is filled in as 'Water'.\
'SampleCollectionEquipmentName' is filled in as 'Probe/Sensor'.\
'CharacteristicName' is filled in as 'Temperature, water'.\
'ResultUnit' is filled in as the daily_mean_temps 'uom' column.\
'ResultStatusID' is filled in as 'Final'.\
'StatisticalBaseCode' is filled in as 'Mean'.\
'ResultValueType' is filled in as 'Calculated'.\
'ResultTimeBasis' is filled in as '1 Day'.\
'ActivityID' is filled out as the fileName minus the extension.\
'ActivityStartDate' is filled out as the earliest date in the daily_mean_temps dataframe.\
'ActivityEndDate' is filled out as the latest date in the daily_mean_temps dataframe.\
'MonitoringLocationID' is filled out as the daily_mean_temps 'staSeq' column.\
'ResultCommentText' is filled out as the daily_mean_temps 'ResultCommentText' column.\
'AnalysisStartDate' is the date of the daily mean.\
'AnalysisEndDate' is the date 1 day after 'AnalysisStartDate'.\
All dates are in the format MM/DD/YYYY.

Depending on which OrganizationID wqx_upload_df uses, the dataframe will be appended to that OrganizationID's list, and the sum of the length of all dataframes in that list is updated.
However, if appending the dataframe to the list would cause the sum of the dataframe lengths to exceed 25000, the current list of dataframes is concatenated and written out to an Excel file using the file number for naming.
The file number is increased by 1, the list is reset to just wqx_upload_df, and the length tracker for that list is set to the length of wqx_upload_df.
Upon the loop's conclusion, the final lists of dataframes for both OrganizationIDs are concatenated and written out to Excel files using the file numbers for naming.