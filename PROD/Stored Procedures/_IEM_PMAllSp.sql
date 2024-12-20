SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*--------------------------------------------------------------------------------------------*\

	     File: _IEM_PMAllSp
  Description: 

  Change Log:
  Date        Ref #   Author        Description\Comments
  ---------  ------  -----------  -------------------------------------------------------------
  2023/11     0001  Jason Tira	   Added UET Uf_Revenue the UET is used for PASS Revenue sites

\*--------------------------------------------------------------------------------------------*/

ALTER PROCEDURE [dbo].[_IEM_PMAllSp](
	 @TempTableName					VARCHAR(100)
   , @TableName						VARCHAR(100)
   , @Columns						NVARCHAR(MAX)
   , @Filter						NVARCHAR(MAX)
   )

AS

DECLARE   @SiteName					OSLocationType
		, @TableResults				VARCHAR(2000)
		, @Counter					INT = 0

DECLARE @Sites TABLE (
	  ID				INT IDENTITY
	, Site				SiteType
	, app_db_name		OSLocationType
	)
	
INSERT INTO @Sites
	SELECT Site, app_db_name FROM Site WHERE Uf_Mfg = 1 OR Uf_Revenue = 1			--- 0001

declare @pound nvarchar(2)='##'
if left(@TempTableName,1)='#' begin
	set @pound='' --djh 2018-06-14 allow user to specify global or local temp table
end else begin		
	SET @TableResults = 'IF OBJECT_ID(''tempdb..##' + @TempTableName +''') IS NOT NULL DROP TABLE ##' + @TempTableName
	EXEC (@TableResults)
end


SET @SiteName = (SELECT TOP 1 app_db_name FROM @Sites)

SET @TableResults = 'SELECT ' + ISNULL(@Columns,'*') + ' INTO '+@pound + @TempTableName + ' FROM ' + @SiteName + '..' + @TableName + ' WHERE 1 = 0;'

EXEC (@TableResults)

WHILE @Counter < (SELECT MAX(ID) FROM @Sites)
	BEGIN
		SET @Counter += 1
		SET @SiteName = (SELECT app_db_name FROM @Sites WHERE ID = @Counter)
		SET @TableResults = 'INSERT INTO '+@pound + @TempTableName + ' SELECT ' + ISNULL(@Columns,'*') + ' FROM ' + @SiteName + '..' + @TableName + ' ' + ISNULL(@Filter,'')
		EXEC (@TableResults)
	END

