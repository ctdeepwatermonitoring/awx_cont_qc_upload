import glob
import platform
from db import mysql_connector as msc
from datetime import datetime
import os
import argparse
import pandas as pd
import csv
from pathlib import Path

in_dir = Path("testFTP/")
cf_dir = Path("cnf/user.cnf.txt")

db_scm = "cont"

def read_file(file,errFile):
    if file.suffix.lower() == ".csv":
        try:
            with file.open("r", newline="", encoding="utf-8") as f:
                reader = csv.reader(f)
                raw = [row for row in reader if row]
            return raw
        except FileNotFoundError as e:
            print(e)
    else:
        errFile.append([str(file), "Incorrect File Type"])

def read_xlsx(file, errFile):
    if file.suffix.lower() == ".xlsx":
        try:
            raw_df = pd.read_excel(
                file, sheet_name=0, header=None,
                keep_default_na=False, engine="openpyxl",
                usecols="A:G"
            )
            raw = raw_df.values.tolist()
            while raw and (raw[-1][0] == "" or raw[-1][0] is None):
                raw = raw[:-1]
            return raw
        except FileNotFoundError as e:
            print(e)
    else:
        errFile.append([str(file), "Incorrect File Type"])

def ck_time_format(time):
    try:
        return datetime.strptime(time, '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
    except ValueError:
        if time.endswith('AM'):
            dt = datetime.strptime(time, '%m/%d/%y %I:%M:%S %p').strftime('%Y-%m-%d %H:%M:%S')
        if time.count(':') == 1:
            dt = datetime.strptime(time, '%m/%d/%Y %H:%M').strftime('%Y-%m-%d %H:%M:%S')
        else:
            dt = datetime.strptime(time, '%m/%d/%y %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
        return dt

with cf_dir.open("r") as f:
    s = f.read()
config = [line.split(",") for line in s.splitlines() if line]
config_uid = config[0][1]
config_pw = config[1][1]

ftp = in_dir
folder = "Upload"
insert_type = "Cont_Data"
fdir = list(ftp.glob(f"**/{folder}/{insert_type}/*.csv"))

headerList = ["Date_Time", "Temp", "UOM", "ProbeID", "SID", "Collector", "ProbeType", "dataFlag", "comment"]

SQLinsert = f"""
INSERT INTO {db_scm}.temperature
(mDateTime, temp, uom, probeID, staSeq, collector, probeType, dataFlag, comment, fileName,
createDate, createUser, lastUpdateDate, lastUpdateUser)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);
"""

SQLerrLog = f"INSERT INTO {db_scm}.errlog VALUES (?,?,?,?,?,?,?);"

print(f"found {len(fdir)} files to process: {fdir}")

try:
    for file in fdir:
        db_err = []
        print('processing file=%s' % file)
        uploadDate = datetime.today().strftime('%m%d%Y_%H%M%S_')
        fpath_base = os.path.dirname(os.path.dirname(str(file)))
        fpath_in = file
        fpath_err = os.path.join(fpath_base, 'ErrRpts', uploadDate + os.path.basename(file) + 'QcRpt.txt')
        fpath_out = os.path.join(fpath_base, 'UploadedRpts', 'Temperature', uploadDate + os.path.basename(file))
        fpath_eout = os.path.join(fpath_base, 'UploadedRpts', 'Temperature', 'Error', os.path.basename(file))
        delim = '\t'
        raw = read_file(fpath_in, db_err)
        header = raw[0]  # could use to check header names in the excel file
        raw = raw[1:]

        if raw is not None and header == headerList:
            with msc.MYSQL('localhost', db_scm, 3306, config_uid, config_pw) as dbo:
                insDate = datetime.today().strftime('%Y-%m-%d %H:%M:%S')
                # Insert into the database line by line.  Append DB error if not caught by qc checks.
                for i in range(len(raw)):
                    if type(raw[i][0]) == str:
                        try:
                            s_time = raw[i][0]
                            s_date = ck_time_format(s_time)
                            # p_type = 'HOBO'
                            file_name = os.path.basename(str(file))
                            user_name = os.path.basename(fpath_base)
                            V_insert = [s_date] + raw[i][1:] + [file_name] + \
                                       [insDate] + [user_name] + [insDate] + [user_name]
                            ins = dbo.query(SQLinsert, V_insert)
                            if ins != {}:
                                print('error with file %s on row %s, err=%s' % (file, i, ins[sorted(ins)[0]]))
                                # SQL insert
                                err = [folder[0:-1], insert_type[0:-1], str(file), insDate, i, ins[sorted(ins)[0]],
                                       user_name]
                                dbErr = dbo.query(SQLerrLog, err)
                                table_row = delim.join([str(e) for e in raw[i]])
                                db_err += [[str(file), str(i + 2), ins[sorted(ins)[0]], table_row]]
                            else:
                                print('success with file %s on row %s' % (file, i))
                        except ValueError:
                            try:
                                s_date = datetime.strptime(raw[i][0], '%m/%d/%y %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
                                # p_type = 'HOBO'
                                file_name = file.rsplit('\\')[-1]
                                user_name = fpath_base.rsplit('\\')[-1]
                                V_insert = [s_date] + raw[i][1:] + [file_name] + \
                                           [insDate] + [user_name] + [insDate] + [user_name]
                                ins = dbo.query(SQLinsert, V_insert)
                                if ins != {}:
                                    print('error with file %s on row %s, err=%s' % (file, i, ins[sorted(ins)[0]]))
                                    # SQL insert
                                    err = [folder[0:-1], insert_type[0:-1], str(file), insDate, i, ins[sorted(ins)[0]],
                                           user_name]
                                    dbErr = dbo.query(SQLerrLog, err)
                                    table_row = delim.join([str(e) for e in raw[i]])
                                    db_err += [[str(file), str(i + 2), ins[sorted(ins)[0]], table_row]]
                                else:
                                    print('success with file %s on row %s' % (file, i))
                            except ValueError:
                                print(file, 'incorrect date format')
                                msg = 'Check date format in file %s row %s.' % (str(file), i + 2)
                                db_err += [[msg]]
                                err = [folder[0:-1], insert_type[0:-1], str(file), insDate, i, msg,
                                       user_name]
                                dbErr = dbo.query(SQLerrLog, err)
                                s = '\n'.join([delim.join(row) for row in db_err])
                                with open(fpath_err, 'w') as f:
                                    f.write(s)
                    elif type(raw[i][0]) == datetime:
                        try:
                            s_date = raw[i][0].strftime('%Y-%m-%d %H:%M:%S')
                            # p_type = 'HOBO'
                            file_name = file.rsplit('\\')[-1]
                            user_name = fpath_base.rsplit('\\')[-1]
                            V_insert = [s_date] + raw[i][1:] + [file_name] + \
                                       [insDate] + [user_name] + [insDate] + [user_name]
                            ins = dbo.query(SQLinsert, V_insert)
                            if ins != {}:
                                print('error with file %s on row %s, err=%s' % (file, i, ins[sorted(ins)[0]]))
                                # SQL insert
                                err = [folder[0:-1], insert_type[0:-1], str(file), insDate, i, ins[sorted(ins)[0]],
                                       user_name]
                                dbErr = dbo.query(SQLerrLog, err)
                                table_row = delim.join([str(e) for e in raw[i]])
                                db_err += [[str(file), str(i + 2), ins[sorted(ins)[0]], table_row]]
                            else:
                                print('success with file %s on row %s' % (file, i))
                        except ValueError:
                            print(file, 'incorrect date format')
                            msg = 'Check date format in file %s row %s.' % (file, i + 2)
                            db_err += [[msg]]
                            err = [folder[0:-1], insert_type[0:-1], str(file), insDate, i, msg,
                                   user_name]
                            dbErr = dbo.query(SQLerrLog, err)
                            s = '\n'.join([delim.join(row) for row in db_err])
                            with open(fpath_err, 'w') as f:
                                f.write(s)
                    else:
                        print(file,'incorrect date format')
                        msg = 'Check date format in file %s row %s.' \
                              'All rows below %s not inserted.' % (file,i + 2, i + 2)
                        db_err += [[msg]]
                        s = '\n'.join([delim.join(row) for row in db_err])
                        with open(fpath_err, 'w') as f:
                            f.write(s)
                        raise TypeError


                if len(db_err) < 1:
                    s = 'All rows successfully inserted'
                    os.rename(fpath_in, fpath_out)
                    dbo.commit()
                else:
                    s = '\n'.join([delim.join(row) for row in db_err])
                    os.rename(fpath_in, fpath_eout)
                    dbo.rollback()

                with open(fpath_err, 'w') as f:
                    f.write(s)
        else:
            print('File Error - Not uploaded')
            db_err += [[str(file),'File Error - Not uploaded.  Check file type column ordering and column names']]
            s = '\n'.join([delim.join([str(e) for e in row]) for row in db_err])
            with open(fpath_err, 'w') as f:
                f.write(s)
except FileNotFoundError as e:
    print(e)
