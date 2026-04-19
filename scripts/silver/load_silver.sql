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
CROSS APPLY OPENJSON([group]) WITH (
    groupName VARCHAR(50),
    groupOrderId INT,
    groupID INT
)

COMMIT

---------------------- (silver.groups) --------------------------