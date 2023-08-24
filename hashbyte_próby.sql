use tempdb
go

CREATE TABLE [dbo].[Publisher](
       [PublisherId] INT PRIMARY KEY,
       [PublisherName] [varchar](50) NULL,
       [PublisherProperty] [varchar](50) NULL,
) 
GO
INSERT INTO [dbo].[Publisher] ([PublisherId], [PublisherName], [PublisherProperty])
VALUES
(1, 'SQL Server', '2019'),
(2, 'SAP', '7.3')
GO

SELECT * FROM [dbo].[Publisher]

CREATE TABLE [dbo].[dimPublisher](
       [PublisherId] [int] IDENTITY(1,1) NOT NULL,
       [PublisherSrcKey] int,
       [PublisherName] [varchar](50) NULL,
       [PublisherProperty] [varchar](50) NULL,
       [EffectiveDate] [date] NOT NULL DEFAULT('1900-01-01'),
       [ExpirationDate] [date] NULL,
       [CurrentFlag] [char](1) NOT NULL DEFAULT('Y'),
       CONSTRAINT [PK_dimPublisher] PRIMARY KEY CLUSTERED ([PublisherId] ASC)
) 

--SCD 1 jest proste
MERGE INTO [dbo].[DimPublisher] Dest
USING [dbo].[Publisher] Src
       ON (Dest.[PublisherSrcKey] = Src.[PublisherId])
WHEN MATCHED AND (Dest.[PublisherProperty] != Src.[PublisherProperty])
THEN UPDATE
    SET Dest.[PublisherProperty] = Src.[PublisherProperty]
WHEN NOT MATCHED THEN
INSERT ([PublisherSrcKey],[PublisherName],[PublisherProperty])
VALUES( src.[PublisherId],src.[PublisherName],src.[PublisherProperty]);

SELECT * FROM dbo.dimPublisher;


--SCD 2 jest bardziej skomplikowane
--

INSERT INTO [dbo].[dimPublisher] 
	([PublisherSrcKey], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag])
SELECT [PublisherId], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag]
FROM
(
       MERGE [dbo].[dimPublisher] dest
       USING [dbo].[Publisher] src
              ON (dest.[PublisherSrcKey] = src.[PublisherId])
       -- Nowy wiersz wymiaru
       WHEN NOT MATCHED THEN
              INSERT ([PublisherSrcKey], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag])
              VALUES (src.[PublisherId], src.[PublisherName], src.[PublisherProperty], GETDATE(), NULL, 'Y')
       -- Istniejacy wiersz zostaje oznaczony jako "stary" - SCD Type 2
       WHEN MATCHED AND dest.[CurrentFlag] = 'Y' AND 
					(ISNULL(dest.[PublisherName], '') != ISNULL(src.[PublisherName], '')) THEN
              UPDATE 
					SET dest.[CurrentFlag] = 'N', 
					dest.[ExpirationDate] = GETDATE() - 1  --do kiedy wiersz bedzie wazny
              OUTPUT $Action Op, 
					src.[PublisherId], 
					src.[PublisherName], 
					src.[PublisherProperty], 
					GETDATE() AS [EffectiveDate], 
					NULL AS [ExpirationDate], 
					'Y' AS [CurrentFlag]
)
AS M
WHERE M.Op = 'UPDATE';
GO
SELECT * FROM [dbo].[dimPublisher];
SELECT * FROM dbo.dimPublisher;

--zmieniamy dane

UPDATE [dbo].[Publisher]
SET PublisherName = 'Azure SQLDatabase trytytddddyy'
WHERE PublisherId = 1
GO
SELECT * FROM [dbo].[Publisher]
GO
SELECT * FROM dbo.dimPublisher;

--ALTER TABLE [dbo].[dimPublisher]
--ALTER COLUMN  HASHBYTE nvarchar(16)

DECLARE @datetime datetime;
SET @datetime= getdate();

INSERT INTO [dbo].[dimPublisher] 
	([PublisherSrcKey], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag],[HASHBYTE])
SELECT [PublisherId], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag],[HASHBYTE]
FROM
(
       MERGE [dbo].[dimPublisher] dest
       USING [dbo].[Publisher] src
              ON (dest.[PublisherSrcKey] = src.[PublisherId])
       -- Nowy wiersz wymiaru
       WHEN NOT MATCHED THEN
              INSERT ([PublisherSrcKey], [PublisherName], [PublisherProperty], [EffectiveDate], [ExpirationDate], [CurrentFlag],[HASHBYTE])
              VALUES (src.[PublisherId], src.[PublisherName], src.[PublisherProperty], @datetime, NULL, 'Y',HASHBYTES('md5',CONCAT(src.[PublisherId], src.[PublisherName], src.[PublisherProperty], @datetime, NULL, 'Y')))
       -- Istniejacy wiersz zostaje oznaczony jako "stary" - SCD Type 2
       WHEN MATCHED AND dest.[CurrentFlag] = 'Y' AND 
					(ISNULL(dest.[HASHBYTE], '') != ISNULL(src.[HASHBYTE], '')) THEN
              UPDATE 
					SET dest.[CurrentFlag] = 'N', 
					dest.[ExpirationDate] = @datetime - 1  --do kiedy wiersz bedzie wazny
              OUTPUT $Action Op, 
					src.[PublisherId], 
					src.[PublisherName], 
					src.[PublisherProperty], 
					@datetime AS [EffectiveDate], 
					NULL AS [ExpirationDate], 
					'Y' AS [CurrentFlag],
					[HASHBYTE]
)
AS M
WHERE M.Op = 'UPDATE';
GO

SELECT * FROM [dbo].[dimPublisher];


--DROP TABLE dimPublisher
--DROP TABLE Publisher