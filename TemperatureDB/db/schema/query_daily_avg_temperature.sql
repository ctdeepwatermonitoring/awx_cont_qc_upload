SELECT 
    temperature.staSeq,
    locationName,
	probeID,
    date(mDateTime) AS sampleDay,
    min(mDateTime) AS minSampleDay,
	max(mDateTime) AS maxSampleDay,
    fileName,
    AVG(temp) AS AvgTemp,
    MIN(temp) AS minTemp,
    MAX(temp) AS maxTemp,
    COUNT(temp) AS cntTemp,
    (MAX(temp) - MIN(temp)) AS dMaxMin
FROM
    temperature
        JOIN
    awqx.stations ON stations.staSeq = temperature.staSeq
WHERE temperature.staSeq = 16139 OR temperature.staSeq = 15499 OR temperature.staSeq = 15796
GROUP BY temperature.staSeq , locationName, sampleDay, fileName;
