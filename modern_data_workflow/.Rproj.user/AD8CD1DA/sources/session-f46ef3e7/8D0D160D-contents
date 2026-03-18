# Testing a new config file
# 2025-05-30
# Alexander.Towle@ct.gov

# Renamed columns that were already there
ContData.env$myName.SiteID = "staSeq"
ContData.env$myName.Date = "mDate"
ContData.env$myName.Time = "mTime"
ContData.env$myName.LoggerID.Water = "probeID"
ContData.env$myName.WaterTemp = "temp"

# New columns needed for our database
ContData.env$myName.Parameter = "parameter"
ContData.env$myName.UOM = "uom"
ContData.env$myName.CreateDate = "createDate"
ContData.env$myName.Comment = "comment"

# Columns expected by ContDataQC but not by us
ContData.env$myName.DateTime = "mDateTime"

# Formatting
ContData.env$myFormat.Time = "%H:%M:%S"
ContData.env$myFormat.Result = "%Y-%m-%d %H:%M:%S"

# New data fields
ContData.env$myNames.DataFields = c(ContData.env$myName.LoggerID.Water,
                                    ContData.env$myName.SiteID,
                                    ContData.env$myName.Date,
                                    ContData.env$myName.Time,
                                    ContData.env$myName.Parameter,
                                    ContData.env$myName.WaterTemp,
                                    ContData.env$myName.UOM,
                                    ContData.env$myName.CreateDate,
                                    ContData.env$myName.Comment,
                                    ContData.env$myName.DateTime
                                    )

# New data field labels
ContData.env$myNames.DataFields.Lab = c(ContData.env$myName.LoggerID.Water,
                                        ContData.env$myName.SiteID,
                                        ContData.env$myName.Date,
                                        ContData.env$myName.Time,
                                        ContData.env$myName.Parameter,
                                        ContData.env$myName.WaterTemp,
                                        ContData.env$myName.UOM,
                                        ContData.env$myName.CreateDate,
                                        ContData.env$myName.Comment,
                                        ContData.env$myName.DateTime
                                        )

# New order
ContData.env$myNames.Order = c(ContData.env$myName.LoggerID.Water,
                               ContData.env$myName.SiteID,
                               ContData.env$myName.Date,
                               ContData.env$myName.Time,
                               ContData.env$myName.Parameter,
                               ContData.env$myName.WaterTemp,
                               ContData.env$myName.UOM,
                               ContData.env$myName.CreateDate,
                               ContData.env$myName.Comment,
                               ContData.env$myName.DateTime
                               )