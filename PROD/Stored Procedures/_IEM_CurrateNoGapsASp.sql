SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[_IEM_CurrateNoGapsASp]

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

DECLARE	  @MD						DateType
		, @from_curr_code			NVARCHAR(3) = 'CAD'
		, @to_curr_code				NVARCHAR(3) = 'USD'	
		, @Counter1					INTEGER

DECLARE	  @All		TINYINT = 0
		, @Today	TINYINT = 0
		, @Update	ListYesNoType = 0

SELECT @All = COUNT(*) FROM (SELECT DISTINCT from_curr_code, to_curr_code FROM iemCommon..CRNGA) x
SELECT @Today = COUNT(*) FROM (SELECT DISTINCT from_curr_code, to_curr_code FROM iemCommon..CRNGA WHERE CAST(eff_date AS DATE) = CAST(GETDATE() AS DATE)) x

IF ISNULL(@All, 0) != ISNULL(@Today, 0)
	BEGIN
		SET @Update = 1
	END

IF @Update = 1

BEGIN

DECLARE MDCrs CURSOR LOCAL FORWARD_ONLY FOR
	SELECT DISTINCT from_curr_code, to_curr_code
		FROM currate

	OPEN MDCrs
	
	WHILE 1 = 1
		BEGIN
			
			FETCH NEXT FROM MDCrs INTO @from_curr_code, @to_curr_code
			IF @@FETCH_STATUS <> 0
				BREAK

			SELECT @MD = MIN(eff_date)
				FROM currate
					WHERE from_curr_code = @from_curr_code AND to_curr_code = @to_curr_code

			IF OBJECT_ID('tempdb..#CRCal') IS NOT NULL DROP TABLE #CRCal
			
			; WITH Calendar
				AS (
					SELECT @MD AS CDate
					UNION ALL
					SELECT DATEADD(dd,1,CDate)
						FROM Calendar
							WHERE DATEADD(dd,1,CDate) <=  GETDATE()
					)
			
			SELECT *
				INTO #CRCal
					FROM Calendar
						OPTION (MAXRECURSION 0)
			
			INSERT INTO #CRNGA
				SELECT	  c.CDate
						, @from_curr_code
						, @to_curr_code
						, r.buy_rate
					FROM #CRCal c
						LEFT JOIN currate r
							ON CAST(r.eff_date AS DATE) = c.CDate AND r.from_curr_code = @from_curr_code AND r.to_curr_code = @to_curr_code
						WHERE ISNULL(r.from_curr_code, @from_curr_code) = @from_curr_code AND ISNULL(r.to_curr_code, @to_curr_code) = @to_curr_code
			
			SET @Counter1  = 0
			
			WHILE EXISTS (SELECT 1 FROM #CRNGA WHERE buy_rate IS NULL AND from_curr_code = @from_curr_code AND to_curr_code = @to_curr_code) AND @Counter1 < 100
				BEGIN
			
					SET @Counter1 += 1
			
					; WITH u
						AS (
							SELECT	  CDate
									, from_curr_code
									, to_curr_code
									, LAG(buy_rate) OVER (PARTITION BY from_curr_code, to_curr_code ORDER BY CDate) AS buy_rate
								FROM #CRNGA c
									WHERE from_curr_code = @from_curr_code AND to_curr_code = @to_curr_code
							)
					
					UPDATE c
						SET buy_rate = u.buy_rate
							FROM #CRNGA c
								JOIN u
									ON u.CDate = c.CDate AND u.from_curr_code = c.from_curr_code AND u.to_curr_code = c.to_curr_code
								WHERE c.buy_rate IS NULL AND c.from_curr_code = @from_curr_code AND c.to_curr_code = @to_curr_code
			
				END

		END

		CLOSE MDCrs

	DEALLOCATE MDCrs

	DELETE iemCommon..CRNGA
	INSERT INTO iemCommon..CRNGA
		SELECT * FROM #CRNGA

END

ELSE
	BEGIN
		INSERT INTO #CRNGA SELECT * FROM iemCommon..CRNGA
	END
				
END
GO

