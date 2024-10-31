SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO


/**************************************************************************
*								ProgCode Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
***************************************************************************/

-- New custom file
-- IO Mode - For Append = 8, for read = 1, for write = 2
ALTER PROCEDURE [dbo].[_IEM_GetCalDate] (
	@StartDate DateType,
	@DayDiff int,
	@ReturnDate DateType OUTPUT
)
AS
BEGIN

	DECLARE 
		@Severity int,
		@MDayNum int,
		@Site SiteType, 
		@Infobar InfobarType

	SELECT TOP 1 @Site = site
	FROM site
	WHERE app_db_name = DB_NAME()

	EXEC dbo.SetSiteSp @Site, @Infobar OUTPUT


	SET @Severity = 0

	SELECT top 1 
	@MDayNum = mcal.mday_num 
	from mcal where m_date < @StartDate order by m_date DESC

	Select @ReturnDate = mcal.m_date
	From mcal where mday_num = @MDayNum + @DayDiff + 1

	IF @ReturnDate IS NULL 
		SET @ReturnDate = DATEADD(day, CEILING(7*(@DayDiff)/5), GetDate())


	RETURN @Severity	
END






GO

