# Config file for modern data
# 2025-09-12
# Alexander.Towle@ct.gov

# Columns that were already there
ContData.env$myName.SiteID = "SID"
ContData.env$myName.LoggerID.Water = "ProbeID"
ContData.env$myName.WaterTemp = "Temp"
ContData.env$myName.DateTime = "Date_Time"
ContData.env$myName.UOM = "UOM"

#UOM label already matches

# New columns needed for our database
ContData.env$myName.Collector = "Collector"
ContData.env$myName.ProbeType = "ProbeType"

# Columns expected by ContDataQC but not by us
ContData.env$myName.Date = "mDate"
ContData.env$myName.Time = "mTime"

# Formatting
ContData.env$myFormat.Time = "%H:%M:%S"
ContData.env$myFormat.Result = "%m/%d/%y %H:%M:%S"

# New data fields
ContData.env$myNames.DataFields = c(ContData.env$myName.DateTime,
                                    ContData.env$myName.WaterTemp,
                                    ContData.env$myName.UOM,
                                    ContData.env$myName.LoggerID.Water,
                                    ContData.env$myName.SiteID,
                                    ContData.env$myName.Collector,
                                    ContData.env$myName.ProbeType,
                                    ContData.env$myName.Date,
                                    ContData.env$myName.Time
)

# New data field labels
ContData.env$myNames.DataFields.Lab = c(ContData.env$myName.DateTime,
                                        ContData.env$myName.WaterTemp,
                                        ContData.env$myName.UOM,
                                        ContData.env$myName.LoggerID.Water,
                                        ContData.env$myName.SiteID,
                                        ContData.env$myName.Collector,
                                        ContData.env$myName.ProbeType,
                                        ContData.env$myName.Date,
                                        ContData.env$myName.Time
)

# New order
ContData.env$myNames.Order = c(ContData.env$myName.DateTime,
                               ContData.env$myName.WaterTemp,
                               ContData.env$myName.UOM,
                               ContData.env$myName.LoggerID.Water,
                               ContData.env$myName.SiteID,
                               ContData.env$myName.Collector,
                               ContData.env$myName.ProbeType,
                               ContData.env$myName.Date,
                               ContData.env$myName.Time
)