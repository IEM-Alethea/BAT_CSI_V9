SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Dan Hulme
-- Create date: 
-- Description:	
-- =============================================
/*
exec setsitesp 'P1BEL',null
exec _IEM_CLM_FileListing 'c:\batticebom\{SITE}', '%.xlsx'
*/
ALTER PROCEDURE [dbo].[_IEM_CLM_FileListing] 
	@folder nvarchar(1000),
	@mask nvarchar(100),
	@depth int = 1
AS
BEGIN
  IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
    DROP TABLE #DirTree

	CREATE TABLE #DirTree (
		Id int identity(1,1),
		FileName nvarchar(255),
		Depth smallint,
		FileFlag bit,
		ParentDirectoryID int
	)

	declare @site sitetype
	SET @Site = dbo.ParmsSite()
	if @site is null
		SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()

	set @folder=replace(@folder, '{SITE}', @site)

	INSERT INTO #DirTree (FileName, Depth, FileFlag)
	EXEC master..xp_dirtree @folder, 2, 1

	select FileName from #DirTree where FileName like isnull(@mask,'') and FileFlag = 1 and depth <= @depth
END
		
GO

