USE dw_hgg_database

DECLARE @json NVARCHAR(MAX); -- TRANSFORM THE .CSV FILE INTO A HUGE STRING

SELECT @json = BulkColumn

FROM OPENROWSET (
    BULK 'C:\Users\Rafae\Projetos\dw_huggingface\datasets\dataframe.json',
    SINGLE_CLOB
) AS src;

