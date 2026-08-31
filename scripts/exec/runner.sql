USE dw_hgg_database;

PRINT '';
PRINT '=================== (bronze) ====================';
PRINT '';

EXEC bronze.init_bronze

PRINT '';
PRINT '=================== (silver) ====================';
PRINT '';

EXEC silver.load_silver