SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[_IEM_ImportLaborTransactionsLauncherSp]

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

DECLARE	  @Infobar		InfobarType
		, @Subject		NVARCHAR(100)

SET @Subject = '_IEM_ImportLaborTransactionsSp (' + @Site + ')'

EXEC _IEM_ImportLaborTransactionsSp @Infobar OUTPUT

IF @Infobar <> 'Number of records posted: 0. Number of errors: 0'
	BEGIN
		EXEC  _IEM_SendEMailSp 'Infor <infor@iemfg.com>', 'dan.hulme@iemfg.com', @Subject, @Infobar, 1
	END

END
GO

