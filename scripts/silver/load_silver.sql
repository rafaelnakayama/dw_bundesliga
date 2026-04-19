USE dw_hgg_database

---------------------- (silver.groups) --------------------------

BEGIN TRANSACTION

INSERT INTO silver.groups (
    group_name,
    group_order_id,
    group_id
)

SELECT DISTINCT
    groupName,
    groupOrderId,
    groupID

FROM bronze.dataframe
CROSS APPLY OPENJSON([group]) WITH ( -- applies a function to eahc row individually,
    groupName VARCHAR(50), -- for each row in the bronze table , take the group column and pass it to OPENJSONN
    groupOrderId INT,
    groupID INT
)

---------------------- (silver.location) --------------------------

INSERT INTO silver.[location] (
    location_id,
    location_city,
    location_stadium
)

SELECT DISTINCT
    locationID,
    locationCity,
    locationStadium

FROM bronze.dataframe

CROSS APPLY OPENJSON([location]) WITH (
    locationID INT,
    locationCity VARCHAR(50),
    locationStadium VARCHAR(50)
)

---------------------- (silver.teams) --------------------------



COMMIT