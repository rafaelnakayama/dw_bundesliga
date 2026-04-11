USE dw_hgg_database

TRUNCATE TABLE bronze.dataframe;

BULK INSERT bronze.dataframe

FROM 'C:\Users\Rafae\Projetos\dw_huggingface\datasets'