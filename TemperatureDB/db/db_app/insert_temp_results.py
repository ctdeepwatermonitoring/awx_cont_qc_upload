import glob
from db import mysql_connector as msc
from datetime import datetime
import os
import argparse
import pandas as pd

# des = """
# ------------------------------------------------------------------------------------------
# Import High Frequency Temperature Data into
# Ambient Water Monitoring Data Exchange water quality database (awqX)
# Mary Becker - Last Updated 2022-01-15
# ------------------------------------------------------------------------------------------
# Given input directory of csv template spreadsheets with new temperature results data,
# automatically checks for constraints with the database schema and produces an
# error report for tuples that do not meet the constraints.  Tuples that do meet
# requirements are inserted into the temperature table """
#
# parser = argparse.ArgumentParser(description=des.lstrip(" "), formatter_class=argparse.RawTextHelpFormatter)
# parser.add_argument('-i', '--in_dir', type=str, help='input directory of ftp\t[None]')
# parser.add_argument('-c', '--cf_dir', type=str, help='input directory of config file')
# parser.add_argument('-d', '--db_scm', type=str, help='input database schema name')
# args = parser.parse_args()
#
# # build args into params...
# if args.in_dir is not None:
#     in_dir = args.in_dir
# else:
#     raise IOError
#
# if args.cf_dir is not None:
#     cf_dir = args.cf_dir
# else:
#     raise IOError
#
# if args.db_scm is not None:
#     db_scm = args.db_scm
# else:
#     raise IOError

###FOR TESTING#####################################

in_dir = 'C:\\Users\\deepuser\\Documents\\testFTP\\'  #Input directory
cf_dir = 'C:\\Users\\deepuser\\Documents\\cnf\\user.cnf.txt' #Config file directory
db_scm = 'cont' #Specify DB Schema

###################################################
# function to read in csv file
def read_file(file, errFile):
    if file.endswith(".csv"):
        try:
            with open(file, 'r') as f:
                # low memory slower than list comp
                # raw,trash,temps = [],[],set([])
                # for line in f:
                #     row = [e.replace('"','') for e in line.rsplit(',')]
                #     temps.add(row[2])
                #     if len(row)!=7: trash += [row]
                #     else:           raw   += [row]

                s = f.read()
                f.close()
            raw = [[e.replace('"','') for e in line.rsplit(',')] for line in s.rsplit('\n')]  # chop up the text by the newline='\n and the delim
            while raw[-1][0] == '' or raw[-1][0] is None: raw = raw[:-1]
            return raw
        except FileNotFoundError as e:
            print(e)
    else:
        errFile += [[file, 'Incorrect File Type']]

def read_Xlsx(file, errFile):
    if file.endswith(".xlsx"):
        try:
            raw_df = pd.read_excel(file, sheet_name=0, header=None, keep_default_na=False, engine="openpyxl",
                                   usecols = "A:G")
            raw = raw_df.values.tolist()
            while raw[-1][0] == '' or raw[-1][0] is None: raw = raw[:-1]
            return raw
        except FileNotFoundError as e:
            print(e)
    else:
        errFile += [[file, 'Incorrect File Type']]

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


# get data from config file
with open(cf_dir, 'r') as f:
    s = f.read()
    f.close()
config = [line.rsplit(',') for line in s.rsplit('\n')]  # chop up the text by the newline='\n and the delim
config_uid = config[0][1]
config_pw = config[1][1]

# insert data from excel into table one line at a time.  generate an error rpt
ftp = in_dir
folder = 'Upload/'
insert_type = 'Cont_Data/'
fdir = glob.glob(ftp + '**/' + folder + insert_type + '**.csv')
# fdir = glob.glob(ftp + '**/' + folder + insert_type + '**.xlsx')

headerList = ['Date_Time','Temp','UOM','ProbeID','SID','Collector','ProbeType']

# headerList = ['Date Time', 'Temp, °C', 'UOM', 'Probe ID', 'SID', 'Collector', 'Probe Type']


SQLinsert = 'INSERT INTO ' + db_scm + '.temperature' \
            '(mDateTime, temp, uom, probeID, staSeq, collector, probeType, fileName,' \
            'createDate, createUser, lastUpdateDate, lastUpdateUser) ' \
            'VALUES (?,?,?,?,?,?,?,?,?,?,?,?);'
SQLerrLog = 'INSERT INTO ' + db_scm + '.errlog VALUES (?,?,?,?,?,?,?);'

print('found %s files to process: %s' % (len(fdir), fdir))

try:
    for file in fdir:
        db_err = []
        print('processing file=%s' % file)
        uploadDate = datetime.today().strftime('%m%d%Y_%H%M%S_')
        fpath_base = file.rsplit('\\', 3)[0]
        fpath_in = file
        fpath_err = fpath_base + '\\ErrRpts\\' + uploadDate + file.rsplit('\\')[-1] + 'QcRpt.txt'
        fpath_out = fpath_base + '\\UploadedRpts\\Temperature\\' + uploadDate + file.rsplit('\\')[-1]
        fpath_eout = fpath_base + '\\UploadedRpts\\Temperature\\Error\\' + file.rsplit('\\')[-1]
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
                            file_name = file.rsplit('\\')[-1]
                            user_name = fpath_base.rsplit('\\')[-1]
                            V_insert = [s_date] + raw[i][1:] + [file_name] + \
                                       [insDate] + [user_name] + [insDate] + [user_name]
                            ins = dbo.query(SQLinsert, V_insert)
                            if ins != {}:
                                print('error with file %s on row %s, err=%s' % (file, i, ins[sorted(ins)[0]]))
                                # SQL insert
                                err = [folder[0:-1], insert_type[0:-1], file, insDate, i, ins[sorted(ins)[0]],
                                       user_name]
                                dbErr = dbo.query(SQLerrLog, err)
                                table_row = delim.join([str(e) for e in raw[i]])
                                db_err += [[file, str(i + 2), ins[sorted(ins)[0]], table_row]]
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
                                    err = [folder[0:-1], insert_type[0:-1], file, insDate, i, ins[sorted(ins)[0]],
                                           user_name]
                                    dbErr = dbo.query(SQLerrLog, err)
                                    table_row = delim.join([str(e) for e in raw[i]])
                                    db_err += [[file, str(i + 2), ins[sorted(ins)[0]], table_row]]
                                else:
                                    print('success with file %s on row %s' % (file, i))
                            except ValueError:
                                print(file, 'incorrect date format')
                                msg = 'Check date format in file %s row %s.' % (file, i + 2)
                                db_err += [[msg]]
                                err = [folder[0:-1], insert_type[0:-1], file, insDate, i, msg,
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
                                err = [folder[0:-1], insert_type[0:-1], file, insDate, i, ins[sorted(ins)[0]],
                                       user_name]
                                dbErr = dbo.query(SQLerrLog, err)
                                table_row = delim.join([str(e) for e in raw[i]])
                                db_err += [[file, str(i + 2), ins[sorted(ins)[0]], table_row]]
                            else:
                                print('success with file %s on row %s' % (file, i))
                        except ValueError:
                            print(file, 'incorrect date format')
                            msg = 'Check date format in file %s row %s.' % (file, i + 2)
                            db_err += [[msg]]
                            err = [folder[0:-1], insert_type[0:-1], file, insDate, i, msg,
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
            db_err += [[file,'File Error - Not uploaded.  Check file type column ordering and column names']]
            s = '\n'.join([delim.join([str(e) for e in row]) for row in db_err])
            with open(fpath_err, 'w') as f:
                f.write(s)
except FileNotFoundError as e:
    print(e)
