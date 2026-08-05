import mariadb
import pandas as pd
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

#Show all columns in the output
pd.set_option('display.max_columns', None)

#Make the directory for the output files
os.makedirs("upload_excel_files", exist_ok=True)

try:
    connection = mariadb.connect(
        host=os.getenv('DB_HOST'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD')
    )

    if connection:
        print("Connected to MariaDB database")

    #cursor
    cursor = connection.cursor()

    #Select all unique fileName values within the specified date rangefrom the temperature table, fetch and store in a dataframe
    start_upload_date = "2026-07-31 00:00:00"
    end_upload_date = "2026-08-03 23:59:59"
    start_results_date = "2026-07-31 00:00:00"
    end_results_date = "2026-08-03 23:59:59"
    # Set this variable to "upload" to query off the createDate column, or set it to "results" to query off the mDateTime column
    upload_or_results = "upload"
    if upload_or_results == "upload":
        cursor.execute("SELECT DISTINCT fileName FROM temperature WHERE createDate BETWEEN %s AND %s", (start_upload_date, end_upload_date))
    else:
        cursor.execute("SELECT DISTINCT fileName FROM temperature WHERE mDateTime BETWEEN %s AND %s", (start_results_date, end_results_date))
    fileName_results = cursor.fetchall()
    fileName_results_df = pd.DataFrame(fileName_results, columns=['fileName'])
    total_files = len(fileName_results_df)

    #Lists to separate out CTVOLMON sites from CT_DEP01_WQX
    ctvolmon_list = []
    ct_dep01_wqx_list = []
    
    #Current length of the dataframes in each list to be concatenated
    ctvolmon_len = 0
    ct_dep01_wqx_len = 0

    #Current file number for naming
    ctvolmon_file_num = 0
    ct_dep01_wqx_file_num = 0

    #For each fileName, select all data from the temperature table, fetch and store in a dataframe
    for index, row in fileName_results_df.iterrows():
        file_name = row['fileName']
        file_name_no_extension = os.path.splitext(file_name)[0]
        print(f"Processing fileName: {file_name}. File {index + 1} of {total_files}.")
        print(f"Current length of CTVOLMON dataframe: {ctvolmon_len} | Current length of CT_DEP01_WQX dataframe: {ct_dep01_wqx_len}")

        #Select all data from the temperature table, fetch and store in a dataframe
        cursor.execute("SELECT * FROM temperature WHERE fileName = %s", (file_name,))
        temperature_results = cursor.fetchall()
        if temperature_results:
            temperature_results_df = pd.DataFrame(temperature_results, columns=['probeID', 'staSeq', 'mDateTime', 'temp', 'uom', 'collector', 'probeType', 'fileName', 'dataFlag', 'comment', 'createDate', 'createUser', 'lastUpdateDate', 'lastUpdateUser'])

            #Drop unnecessary columns
            temperature_results_df = temperature_results_df.drop(columns=['probeType', 'createDate', 'createUser', 'lastUpdateDate', 'lastUpdateUser'])

            #Extract date for grouping
            temperature_results_df['date'] = temperature_results_df['mDateTime'].dt.date

            # Time intervals vary across probes, so we can't just filter for 24 readings per day.
            # If a probe reads in 15 minute intervals, it could have more than 24 readings and still not be a complete day.
            # Therefore we need to create a check that ensures that the probe has at least 24 readings in each day and also that the readings cover every hour of the day from 00:00 to 23:00.
            # To do this, we can create a pivot table that counts the number of readings for each hour of the day for each probeID and staSeq, and then filter for groups that have at least 1 reading in each hour of the day and at least 24 readings in total.
            hourly_counts = (
                temperature_results_df
                .assign(hour=lambda x: x['mDateTime'].dt.hour)
                .groupby(['probeID', 'staSeq', 'date', 'hour'])
                .size()
                .unstack(fill_value=0)
            )

            #print(hourly_counts)

            #Only include groups that have at least 1 reading in each hour of the day
            complete_hourly_counts = hourly_counts[(hourly_counts > 0).all(axis=1)]

            #Only include groups that have at least 24 readings in total
            complete_hourly_counts = complete_hourly_counts[complete_hourly_counts.sum(axis=1) >= 24]

            #Create a new DataFrame that only contains values for days with at least 1 reading for each hour of the day for each probeID for each staSeq
            complete_days_results_df = temperature_results_df.merge(complete_hourly_counts, on=['probeID', 'staSeq', 'date'], how='inner')
            
            #Skip to the next file if there are no complete days
            if complete_days_results_df.empty:
                print(f"No complete days found for fileName: {file_name}")
                continue
            
            complete_days_results_df = complete_days_results_df.drop(columns=range(0, 24))

            #If comment column is NULL, replace with "None"
            complete_days_results_df['comment'] = complete_days_results_df['comment'].fillna('None')

            #Count the number of each dataFlag for each probeID for each staSeq for each day
            flag_counts = (
                complete_days_results_df
                .groupby(['probeID', 'staSeq', 'date', 'uom', 'collector', 'fileName', 'comment'])['dataFlag']
                .value_counts()
                .unstack(fill_value=0)
                .reset_index()
            )

            #Calculating daily mean temperatures for each probeID for each staSeq
            daily_mean_temps = (
                complete_days_results_df
                .groupby(['probeID', 'staSeq', 'date', 'uom', 'collector', 'fileName', 'comment'])['temp']
                .mean()
                .reset_index(name='daily_mean_temp')
                .merge(flag_counts, on=['probeID', 'staSeq', 'date', 'uom', 'collector', 'fileName', 'comment'], how='left')
            )

            daily_mean_temps['ResultCommentText'] = daily_mean_temps.apply(
                lambda row: (
                    f"Comment: {row['comment']} | Data Flags: P={row.get('P', 0)} "
                    f"X={row.get('X', 0)} F={row.get('F', 0)} S={row.get('S', 0)}"
                ).strip(),
                axis=1
            )

            #Creating dataframe that will be used to upload data to WQX
            wqx_upload_df = pd.DataFrame(columns=['OrganizationID', 'ProjectID', 'ActivityType', 'ActivityMediaName', 'SampleCollectionEquipmentName', 'CharacteristicName', 'ResultUnit', 'ResultStatusID', 'StatisticalBaseCode', 'ResultValueType', 'ResultTimeBasis', 'ActivityID', 'ActivityStartDate', 'ActivityEndDate', 'MonitoringLocationID', 'ResultValue', 'ResultCommentText', 'AnalysisStartDate', 'AnalysisEndDate'])

            #Populating wqx_upload_df with transferable columns from daily_mean_temps and filling in constant values for the other columns
            wqx_upload_df['ResultValue'] = daily_mean_temps['daily_mean_temp']
            if (daily_mean_temps['collector'] == 'ABM').all():
                wqx_upload_df['OrganizationID'] = 'CT_DEP01_WQX'
                wqx_upload_df['ProjectID'] = 'HOBOtemperature'
            elif (daily_mean_temps['collector'] == 'VOL').all():
                wqx_upload_df['OrganizationID'] = 'CTVOLMON'
                wqx_upload_df['ProjectID'] = 'CT-VOLMON-VSTEM'
            wqx_upload_df['ActivityType'] = 'Field Msr/Obs'
            wqx_upload_df['ActivityMediaName'] = 'Water'
            wqx_upload_df['SampleCollectionEquipmentName'] = 'Probe/Sensor'
            wqx_upload_df['CharacteristicName'] = 'Temperature, water'
            wqx_upload_df['ResultUnit'] = daily_mean_temps['uom']
            wqx_upload_df['ResultStatusID'] = 'Final'
            wqx_upload_df['StatisticalBaseCode'] = 'Mean'
            wqx_upload_df['ResultValueType'] = 'Calculated'
            wqx_upload_df['ResultTimeBasis'] = '1 Day'
            wqx_upload_df['ActivityID'] = "_".join([str(daily_mean_temps['probeID'][0]), str(daily_mean_temps['staSeq'][0]), str(daily_mean_temps['date'][0])])
            #Assign ActivityStartDate as the earliest date in the daily_mean_temps dataframe
            wqx_upload_df['ActivityStartDate'] = pd.to_datetime(daily_mean_temps['date']).min().strftime('%m/%d/%Y')
            #Assign ActivityEndDate as the latest date in the daily_mean_temps dataframe
            wqx_upload_df['ActivityEndDate'] = pd.to_datetime(daily_mean_temps['date']).max().strftime('%m/%d/%Y')
            wqx_upload_df['MonitoringLocationID'] = daily_mean_temps['staSeq']
            wqx_upload_df['ResultCommentText'] = daily_mean_temps['ResultCommentText']
            #Make AnalysisStartDate in the format MM/DD/YYYY
            wqx_upload_df['AnalysisStartDate'] = pd.to_datetime(daily_mean_temps['date']).dt.strftime('%m/%d/%Y')
            #Make AnalysisEndDate 1 day after Analysis StartDate
            wqx_upload_df['AnalysisEndDate'] = (pd.to_datetime(daily_mean_temps['date']) + pd.Timedelta(days=1)).dt.strftime('%m/%d/%Y')

            print(wqx_upload_df)

            #Writes out the excel file according to which organization it belongs to
            #A separate file will be written out if the newest addition to the dataframe would cause it to exceed 25000 entries
            wqx_upload_df_len = len(wqx_upload_df)
            if (wqx_upload_df['OrganizationID'] == 'CTVOLMON').all():
                if wqx_upload_df_len + ctvolmon_len > 25000:
                    final_ctvolmon_df = pd.concat(ctvolmon_list)
                    final_ctvolmon_df.to_excel(f'upload_excel_files/wqx_upload_ctvolmon_{ctvolmon_file_num}.xlsx', index=False)
                    ctvolmon_file_num += 1
                    ctvolmon_list = [wqx_upload_df]
                    ctvolmon_len = wqx_upload_df_len
                else:
                    ctvolmon_list.append(wqx_upload_df)
                    ctvolmon_len += wqx_upload_df_len
            elif (wqx_upload_df['OrganizationID'] == 'CT_DEP01_WQX').all():
                if wqx_upload_df_len + ct_dep01_wqx_len > 25000:
                    final_ct_dep01_wqx_df = pd.concat(ct_dep01_wqx_list)
                    final_ct_dep01_wqx_df.to_excel(f'upload_excel_files/wqx_upload_ct_dep01_wqx_{ct_dep01_wqx_file_num}.xlsx', index=False)
                    ct_dep01_wqx_file_num += 1
                    ct_dep01_wqx_list = [wqx_upload_df]
                    ct_dep01_wqx_len = wqx_upload_df_len
                else:
                    ct_dep01_wqx_list.append(wqx_upload_df)
                    ct_dep01_wqx_len += wqx_upload_df_len
    #Write out both the remaining CTVOLMON and CT_DEP01_WQX dataframes after the loop is finished if they are not empty
    if ctvolmon_list:
        final_ctvolmon_df = pd.concat(ctvolmon_list)
        final_ctvolmon_df.to_excel(f'upload_excel_files/wqx_upload_ctvolmon_{ctvolmon_file_num}.xlsx', index=False)
    if ct_dep01_wqx_list:
        final_ct_dep01_wqx_df = pd.concat(ct_dep01_wqx_list)
        final_ct_dep01_wqx_df.to_excel(f'upload_excel_files/wqx_upload_ct_dep01_wqx_{ct_dep01_wqx_file_num}.xlsx', index=False)


except mariadb.Error as e:
    print("Error while connecting to MariaDB", e)
finally:
    if cursor:
        cursor.close()
    if connection:
        connection.close()
    print("MariaDB connection is closed")