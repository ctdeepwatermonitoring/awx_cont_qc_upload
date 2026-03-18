SELECT 
    COUNT(mDateTime) AS CntSample,
    MIN(mDateTime) AS minSampleDate,
    MAX(mDateTime) AS maxSampleDate,
    temperature.staSeq,
    locationName,
    fileName
FROM
    temperature
        JOIN
    awqx.stations ON stations.staSeq = temperature.staSeq
GROUP BY fileName , temperature.staSeq , locationName