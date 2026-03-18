DROP TABLE IF EXISTS luCollector;
CREATE TABLE cont.lucCollector(
	`collector` char(5),
    `collectorDescip` char(100),
    primary key(collector)
);

DROP TABLE IF EXISTS luProbeType;
CREATE TABLE cont.luProbeType(
	`probeType` char(25),
    `probeTypeDescip` char(100),
    primary key(probeType)
);

DROP TABLE IF EXISTS luUOM;
CREATE TABLE cont.luUOM(
	`uom` char(25),
    `uomDescip` char(100),
    primary key(uom)
);

DROP TABLE IF EXISTS temperature;
CREATE TABLE cont.temperature(
	`probeID` char(25) NOT NULL,
    `staSeq` int NOT NULL,
    `mDateTime` datetime NOT NULL,
    `temp` decimal(9,6),
    `uom` char(25),
    `collector` char(5),
    `probeType` char(25),
    `fileName` char(200),
    `dataFlag` char(1),
    `comment` char(255),
    `createDate` datetime NOT NULL,
    `createUser` char(50),
    `lastUpdateDate` datetime NOT NULL,
    `lastUpdateUser` char(50),
    primary key(probeID,staSeq,mDateTime),
    constraint collector foreign key (collector) REFERENCES cont.luccollector(collector),
    constraint probetype foreign key (probeType) REFERENCES luprobetype(probeType),
    constraint uom foreign key (uom) REFERENCES luuom(uom)
);