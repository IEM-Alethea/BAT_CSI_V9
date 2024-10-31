SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* $Header: /ApplicationDB/Stored Procedures/CreateItemSp.sp 1     8/22/14 10:33a flagatta $ */
/*
***************************************************************
*                                                             *
*                           NOTICE                            *
*                                                             *
*   THIS SOFTWARE IS THE PROPERTY OF AND CONTAINS             *
*   CONFIDENTIAL INFORMATION OF INFOR AND/OR ITS AFFILIATES   *
*   OR SUBSIDIARIES AND SHALL NOT BE DISCLOSED WITHOUT PRIOR  *
*   WRITTEN PERMISSION. LICENSED CUSTOMERS MAY COPY AND       *
*   ADAPT THIS SOFTWARE FOR THEIR OWN USE IN ACCORDANCE WITH  *
*   THE TERMS OF THEIR SOFTWARE LICENSE AGREEMENT.            *
*   ALL OTHER RIGHTS RESERVED.                                *
*                                                             *
*   (c) COPYRIGHT 2010 INFOR.  ALL RIGHTS RESERVED.           *
*   THE WORD AND DESIGN MARKS SET FORTH HEREIN ARE            *
*   TRADEMARKS AND/OR REGISTERED TRADEMARKS OF INFOR          *
*   AND/OR ITS AFFILIATES AND SUBSIDIARIES. ALL RIGHTS        *
*   RESERVED.  ALL OTHER TRADEMARKS LISTED HEREIN ARE         *
*   THE PROPERTY OF THEIR RESPECTIVE OWNERS.                  *
*                                                             *
***************************************************************
*/

/*
SELECT * 
FROM OPENDATASOURCE('Microsoft.ACE.OLEDB.12.0',
  'Data Source=C:\expenseimport\DFRE\APDataExport-Certify.xlsx;
   Extended Properties=Excel 12.0 Xml')...[APDataExport$];
*/

/* 
-- 1. use below to allow OLE selects
-- 2. spreadsheet must be closed
-- 3. https://www.microsoft.com/en-us/download/details.aspx?id=13255 install on server
USE [master] 

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1 

GO 

EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1 

*/

ALTER PROCEDURE [dbo].[_IEM_ImportBOMSp] (
		  @fileName				NVARCHAR(200) = NULL
		, @COLIitem				ItemType = NULL
) AS

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

IF OBJECT_ID('tempdb..#BOMTable') IS NOT NULL  DROP TABLE #BOMTable
	
CREATE TABLE #BOMTable (
		  WorkCenter			NVARCHAR(6)
		, Item					NVARCHAR(30)
		, BOMQty				DECIMAL(23,8)
	)

DECLARE @errors TABLE (
		  fileName				NVARCHAR(200)
		, errorStr				NVARCHAR(MAX)
	)

DECLARE @BOMTable TABLE (
		  WorkCenter			NVARCHAR(6)
		, Item					NVARCHAR(30)
		, BOMQty				DECIMAL(23,8)
		)

DECLARE	  @CoNum				CoNumType
		, @CoLine				CoLineType
		, @stmt					NVARCHAR(MAX)
		, @folder				NVARCHAR(1000) = 'C:\BatticeBOM\' + @site + '\'
		, @fullPath				NVARCHAR(1000)
		, @excelInit			NVARCHAR(MAX)
		, @fileExists			INT
		, @terr					NVARCHAR(MAX)
		, @Severity				INT
		, @Debug				INT = 1
		, @CurJob				JobType
		, @CurSuffix			SuffixType
		, @CurOper				OperNumType
		, @UM					UMType
		, @BOMQty				QtyUnitNoNegType
		, @BOMQtyOld			QtyUnitNoNegType
		, @Now					DateType
		, @Infobar    			InfobarType
		, @Item					ItemType
		, @WorkCenter			NVARCHAR(6)
		, @JJob					JobType
		, @JSuffix				SuffixType

IF OBJECT_ID('tempdb..#LaborTable') IS NOT NULL  DROP TABLE #LaborTable
	
CREATE TABLE #LaborTable (
		  WorkCenter			NVARCHAR(6)
		, Hrs					DECIMAL(15,8)
	)

SET @Now = GETDATE()

SET @fullPath = @folder + @filename

IF NOT EXISTS (SELECT 1 FROM coitem WHERE item = @COLIitem)
	BEGIN
		INSERT INTO @errors (errorStr)
			VALUES ('This part number has no corresponding customer order line.')
		--GOTO EXITR --Removed 10SEP2018 by DBH to allow for non-COLI imports
	END

IF NOT EXISTS (SELECT 1 FROM job WHERE item = @COLIitem)
	BEGIN
		INSERT INTO @errors (errorStr)
			VALUES ('This part number has no corresponding job.')
		GOTO EXITR
	END

--Eliminate (manually added) duplicate items from BOM

DECLARE @ZDRowPointers TABLE (
	  RowPointer			RowPointerType
	, job					JobType
	, suffix				SuffixType
	, jmitem				ItemType
	, matl_qty				AmountType
	  )

; WITH ZeroDupe
	AS (
		SELECT	  jm.job
				, jm.suffix
				, jm.oper_num
				, jm.item
				, jm.RowPointer
				, jm.matl_qty
				, ROW_NUMBER() OVER (PARTITION BY jm.job, jm.suffix, jm.item, oper_num
										ORDER BY jm.CreateDate) AS rn
			FROM jobmatl jm
				JOIN job j
					ON j.job = jm.job AND j.suffix = jm.suffix
				WHERE j.item = @COLIitem
					AND j.type = 'S'
		)

INSERT INTO @ZDRowPointers
	SELECT	  RowPointer
			, job
			, suffix
			, item
			, matl_qty
		FROM ZeroDupe
			WHERE rn > 1

UPDATE jm
	SET matl_qty = 0
		FROM jobmatl jm
			JOIN @ZDRowPointers z
				ON z.RowPointer = jm.RowPointer

--END Eliminate (manually added) duplicate items from BOM

SELECT TOP 1
		  @CoNum = co_num
		, @CoLine = co_line
	FROM coitem
		WHERE item = @COLIitem

IF RIGHT(@fileName,5)='.xlsx'
	BEGIN
		SET @excelInit='''Excel 12.0 Xml;Database=' + @folder + @filename+''''
	END
ELSE IF RIGHT(@fileName,4)='.xls'
	BEGIN
		SET @excelInit='''Excel 8.0;Database=' + @folder + @filename+''''
	END
ELSE
	BEGIN
		INSERT INTO @errors (fileName, errorStr) 
			VALUES (@fileName, 'Only .xls and xlsx file are supported')
		GOTO EXITR
	END

EXEC master.dbo.xp_fileexist @fullPath, @fileExists OUTPUT

IF @fileExists = 0
	BEGIN
		INSERT INTO @errors (fileName, errorStr) 
			VALUES (@fileName, 'Import file does not exist (it may have already been processed)')
		GOTO EXITR
	END

SELECT @stmt = 'INSERT INTO #BOMtable SELECT [Work Center], Reference, [Quantity] FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'', ' + @excelInit + ', [BOM$])'

BEGIN TRY
	EXEC dbo.sp_executesql @stmt = @stmt, @params = N''
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 7303
		BEGIN
			SET @terr='Error reading file: the file may be open in excel.'
		END
	ELSE
		BEGIN
			SET @terr='Error reading file: '+ERROR_MESSAGE()+' ['+cast(error_number() as nvarchar(10))+']'
		END
	INSERT INTO @errors (fileName, errorStr) 
		VALUES (@fileName, @terr)
	GOTO EXITR
END CATCH

INSERT INTO @BOMTable
	SELECT	  WorkCenter
			, Item
			, SUM(BOMQty)
		FROM #BOMTable bt
			GROUP BY WorkCenter, Item
				HAVING SUM(BOMQty) <> 0

SELECT TOP 1
		  @CurJob = job
		, @CurSuffix = suffix
	FROM job
		WHERE type = 'S' AND item = @COLIitem

--Add into @BOMTable WorkCenter / item combinations not in spreadsheet but in current job materials (for zeroing)
INSERT INTO @BOMTable
	SELECT	  jr.wc
			, jm.item
			, 0
		FROM jobmatl jm
			JOIN jobroute jr
				ON jr.job = jm.job AND jr.suffix = jm.suffix AND jr.oper_num = jm.oper_num
			WHERE jm.job = @CurJob AND jm.suffix = @CurSuffix
					AND NOT EXISTS (SELECT 1 FROM @BOMTable bt WHERE bt.WorkCenter = jr.wc AND bt.Item = jm.item)			

-- Add / Update BOM

	DECLARE crsSubJob CURSOR FORWARD_ONLY FOR
		SELECT DISTINCT WorkCenter, Item, BOMQty
			FROM @BOMTable

	SET @Severity = 0

	OPEN crsSubJob
	WHILE @Severity = 0
	BEGIN
		FETCH NEXT FROM crsSubJob INTO @WorkCenter, @Item, @BOMQty
		SET @BOMQtyOld = NULL

		IF @@fetch_status <> 0
			BREAK;

		SET @CurOper = NULL
		SET @CurOper = (SELECT TOP 1 oper_num FROM jobroute WHERE job = @CurJob AND suffix = @CurSuffix AND wc = @WorkCenter)

		IF NOT EXISTS (SELECT 1 FROM jobmatl WHERE job = @CurJob AND suffix = @CurSuffix AND item = @Item AND oper_num = @CurOper)
				AND @CurOper IS NOT NULL
			BEGIN
				EXEC @Severity = _IEM_AddItemToBomSp
					  @Item			= @COLIitem
					, @AddItem		= @Item
					, @Oper			= @CurOper
					, @Qty			= @BOMQty
					, @Infobar		= @Infobar OUTPUT

				IF @Severity <> 0
					BEGIN
						INSERT INTO @errors VALUES('Create BOM',@Infobar)
						SET @Severity = 0
					END
				ELSE
					BEGIN
						INSERT INTO @errors VALUES ('Create BOM','BOM for job ' + @CurJob + '-'
											+ RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4)
											+ ' / operation ' + CAST(@CurOper AS NVARCHAR(4))
											+ ' / work center ' + @WorkCenter 
											+ ' / item ' + @Item + ' with quantity ' + CAST(@BOMQty AS NVARCHAR(16)) + ' successfully added.')
					END
			END
		ELSE IF @CurOper IS NULL
			BEGIN
				INSERT INTO @errors VALUES ('Create BOM','No operation exists for job ' + @CurJob + '-' + RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4) 
											+ ' and work center ' + @WorkCenter + '.')
			END
		ELSE IF EXISTS (SELECT 1 FROM jobmatl WHERE job = @CurJob AND suffix = @CurSuffix AND item = @Item AND oper_num = @CurOper)
			BEGIN
				SET @BOMQtyOld = (SELECT TOP 1 matl_qty FROM jobmatl WHERE job = @CurJob AND suffix = @CurSuffix AND item = @Item AND oper_num = @CurOper)
				IF @BOMQtyOld <> @BOMQty
					BEGIN
						UPDATE jobmatl
							SET matl_qty = @BOMQty, matl_qty_conv = @BOMQty
								WHERE job = @CurJob AND suffix = @CurSuffix AND item = @Item AND oper_num = @CurOper
									AND NOT EXISTS (SELECT 1 FROM @ZDRowPointers WHERE RowPointer = jobmatl.RowPointer)
						INSERT INTO @errors VALUES('Create BOM','BOM for Job ' + @CurJob + '-'
													+ RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4)
													+ ' / operation ' + CAST(@CurOper AS NVARCHAR(4))
													+ ' / work center ' + @WorkCenter 
													+ ' / item ' + @Item + ' updated from quantity ' + CAST(@BOMQtyOld AS NVARCHAR(16)) + ' to ' + CAST(@BOMQty AS NVARCHAR(16)) + '.')
					END
				ELSE
					BEGIN
						INSERT INTO @errors VALUES('Create BOM','BOM for COLI Job ' + @CurJob + '-'
											+ RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4)
											+ ' / operation ' + CAST(@CurOper AS NVARCHAR(4))
											+ ' / work center ' + @WorkCenter 
											+ ' / item ' + @Item + ' with quantity ' + CAST(@BOMQty AS NVARCHAR(16)) + ' already exists.')
					END
			END
	END

	CLOSE crsSubJob
	DEALLOCATE crsSubJob

	INSERT INTO @errors
		SELECT	  'Other'
				, 'BOM for ' + job + '-'
					+ RIGHT('0000' + CAST(suffix AS NVARCHAR(4)),4)
					+ ' and item ' + jmitem + ' (RowPointer ' + CAST(RowPointer AS NVARCHAR(36))
					+ ') was a duplicate; updated from quantity ' + CAST(matl_qty AS NVARCHAR(16))
					+ ' to 0.00000000.'
			FROM @ZDRowPointers

--Labor hours

SELECT @stmt = 'INSERT INTO #LaborTable SELECT [Work Center], [Labour Hours] FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'', ' + @excelInit + ', [LABOUR$])'

BEGIN TRY
	EXEC dbo.sp_executesql @stmt = @stmt, @params = N''
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 7303
		BEGIN
			SET @terr='Error reading file: the file may be open in excel.'
		END
	ELSE
		BEGIN
			SET @terr='Error reading file: '+ERROR_MESSAGE()+' ['+cast(error_number() as nvarchar(10))+']'
		END
	INSERT INTO @errors (fileName, errorStr) 
		VALUES (@fileName, @terr)
	GOTO EXITR
END CATCH

DELETE #LaborTable WHERE WorkCenter IS NULL --Eliminates dummy records caused by notes on table

INSERT INTO @errors
	SELECT	  'Labor Hours'
			, 'Labor Hours for job ' + @CurJob  + '-' + RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4) + 
				' / Work Center ' + lt.WorkCenter +
				' updated from ' + CAST(js.run_lbr_hrs AS NVARCHAR(20)) + ' hours to ' + CAST(lt.Hrs AS NVARCHAR(20)) + ' hours.'
		FROM jrt_sch js
			JOIN jobroute jr
				ON jr.job = js.job AND jr.suffix = js.suffix AND jr.oper_num = js.oper_num
			JOIN #LaborTable lt
				ON lt.WorkCenter = jr.wc
			WHERE js.job = @CurJob AND js.suffix = @CurSuffix AND js.run_lbr_hrs <> lt.Hrs

UPDATE js
	SET	  run_lbr_hrs = lt.Hrs
		, run_ticks_lbr = lt.Hrs * 100
		, pcs_per_lbr_hr = IIF(lt.Hrs = 0, 0, 1.00000000 / IIF(lt.Hrs = 0, 1, lt.Hrs))
		FROM jrt_sch js
			JOIN jobroute jr
				ON jr.job = js.job AND jr.suffix = js.suffix AND jr.oper_num = js.oper_num
			JOIN #LaborTable lt
				ON lt.WorkCenter = jr.wc
			WHERE js.job = @CurJob AND js.suffix = @CurSuffix AND js.run_lbr_hrs <> lt.Hrs

INSERT INTO @errors
	SELECT	  'Labor Hours'
			, 'Work center ' + lt.WorkCenter + ' does not exist for job '
					+ @CurJob + '-' + RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4) + '.'
		FROM #LaborTable lt
			LEFT JOIN jobroute jr
				ON jr.job = @CurJob AND jr.suffix = @CurSuffix AND jr.wc = lt.WorkCenter
			WHERE jr.wc IS NULL

--End Labor Hours

--Sync job material records to item table

INSERT INTO @errors
	SELECT	  'Sync Job Materials to Items'
			, 'Item ' + jm.item + ' material type updated from ' + jm.matl_type + ' to ' + i.matl_type
					+ ' for job ' + @CurJob + '-' + RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4) + '.'
		FROM jobmatl jm
			JOIN item i
				ON i.item = jm.item
			WHERE jm.job = @CurJob AND jm.suffix = @CurSuffix AND jm.matl_type <> i.matl_type

INSERT INTO @errors
	SELECT	  'Sync Job Materials to Items'
			, 'Item ' + jm.item + ' reference type updated from ' + jm.ref_type + ' to '
					+ CASE
						WHEN i.stocked = 1 THEN 'I'
						WHEN i.p_m_t_code = 'P' THEN 'P'
						WHEN i.p_m_t_code = 'M' THEN 'J'
						END
					+ ' for job ' + @CurJob + '-' + RIGHT('0000' + CAST(@CurSuffix AS NVARCHAR(4)),4) + '.'
		FROM jobmatl jm
			JOIN item i
				ON i.item = jm.item
			WHERE jm.job = @CurJob AND jm.suffix = @CurSuffix AND jm.ref_type <>	CASE
																	WHEN i.stocked = 1 THEN 'I'
																	WHEN i.p_m_t_code = 'P' THEN 'P'
																	WHEN i.p_m_t_code = 'M' THEN 'J'
																	END

UPDATE jm
	SET	  matl_type = i.matl_type
		, ref_type = CASE
						WHEN i.stocked = 1 THEN 'I'
						WHEN i.p_m_t_code = 'P' THEN 'P'
						WHEN i.p_m_t_code = 'M' THEN 'J'
						END
		FROM jobmatl jm
			JOIN item i
				ON i.item = jm.item
			WHERE jm.job = @CurJob AND jm.suffix = @CurSuffix AND 
					(jm.matl_type <> i.matl_type OR jm.ref_type <>	CASE
																	WHEN i.stocked = 1 THEN 'I'
																	WHEN i.p_m_t_code = 'P' THEN 'P'
																	WHEN i.p_m_t_code = 'M' THEN 'J'
																	END
					)

--End Sync job material records to item table

SELECT TOP 1 @JJob = job, @JSuffix = suffix FROM job WHERE type = 'J' AND item = @COLIItem

--Add J-Job operations to jobroute table

INSERT INTO jobroute (
		  job
		, suffix
		, oper_num
		, wc
		, setup_hrs_t
		, setup_cost_t
		, complete
		, setup_hrs_v
		, wip_amt
		, qty_scrapped
		, qty_received
		, qty_moved
		, qty_complete
		, effect_date
		, obs_date
		, bflush_type
		, run_basis_lbr
		, run_basis_mch
		, fixovhd_t_lbr
		, fixovhd_t_mch
		, varovhd_t_lbr
		, varovhd_t_mch
		, run_hrs_t_lbr
		, run_hrs_t_mch
		, run_hrs_v_lbr
		, run_hrs_v_mch
		, run_cost_t_lbr
		, cntrl_point
		, setup_rate
		, efficiency
		, fovhd_rate_mch
		, vovhd_rate_mch
		, run_rate_lbr
		, varovhd_rate
		, fixovhd_rate
		, wip_matl_amt
		, wip_lbr_amt
		, wip_fovhd_amt
		, wip_vovhd_amt
		, wip_out_amt
		, NoteExistsFlag
		, InWorkFlow
		, yield
		, opm_consec_oper
		, MO_shared
		, MO_seconds_per_cycle
		, MO_formula_matl_weight
		, MO_formula_matl_weight_units
		)
	
SELECT	  @JJob
		, @JSuffix
		, jrc.oper_num
		, jrc.wc
		, jrc.setup_hrs_t
		, jrc.setup_cost_t
		, jrc.complete
		, jrc.setup_hrs_v
		, jrc.wip_amt
		, jrc.qty_scrapped
		, jrc.qty_received
		, jrc.qty_moved
		, jrc.qty_complete
		, jrc.effect_date
		, jrc.obs_date
		, jrc.bflush_type
		, jrc.run_basis_lbr
		, jrc.run_basis_mch
		, jrc.fixovhd_t_lbr
		, jrc.fixovhd_t_mch
		, jrc.varovhd_t_lbr
		, jrc.varovhd_t_mch
		, jrc.run_hrs_t_lbr
		, jrc.run_hrs_t_mch
		, jrc.run_hrs_v_lbr
		, jrc.run_hrs_v_mch
		, jrc.run_cost_t_lbr
		, jrc.cntrl_point
		, jrc.setup_rate
		, jrc.efficiency
		, jrc.fovhd_rate_mch
		, jrc.vovhd_rate_mch
		, jrc.run_rate_lbr
		, jrc.varovhd_rate
		, jrc.fixovhd_rate
		, jrc.wip_matl_amt
		, jrc.wip_lbr_amt
		, jrc.wip_fovhd_amt
		, jrc.wip_vovhd_amt
		, jrc.wip_out_amt
		, jrc.NoteExistsFlag
		, jrc.InWorkFlow
		, jrc.yield
		, jrc.opm_consec_oper
		, jrc.MO_shared
		, jrc.MO_seconds_per_cycle
		, jrc.MO_formula_matl_weight
		, jrc.MO_formula_matl_weight_units
	FROM jobroute jrc
		WHERE jrc.job = @CurJob AND @CurSuffix = 0
			AND NOT EXISTS (SELECT 1 FROM jobroute jrj WHERE jrj.job = @JJob AND jrj.suffix = @JSuffix
								AND jrj.oper_num = jrc.oper_num AND jrj.wc = jrc.wc)
			AND @JJob IS NOT NULL

--End Add J-Job operations to jobroute table


IF @JJob IS NULL
	BEGIN
		INSERT INTO @errors
			SELECT	  'Sync BOM'
					, 'No J-job exists for item ' + @COLIItem + '.'
	END
ELSE
	BEGIN
		DELETE @BOMTable
		INSERT INTO @BOMTable
			SELECT	  jr.wc
					, jm.item
					, jm.matl_qty
				FROM jobmatl jm
					JOIN jobroute jr
						ON jr.job = jm.job AND jr.suffix = jm.suffix AND jr.oper_num = jm.oper_num
					WHERE jm.job = @JJob AND jm.suffix = @JSuffix

		DELETE #LaborTable
		INSERT INTO #LaborTable
			SELECT	  jr.wc
					, js.run_lbr_hrs
				FROM jrt_sch js
					JOIN jobroute jr
						ON jr.job = js.job AND jr.suffix = js.suffix AND jr.oper_num = js.oper_num
					WHERE js.job = @JJob AND js.suffix = @JSuffix

		EXEC _IEM_Rpt_BOMSyncSp @COLIItem, NULL, 0

		INSERT INTO @errors
			SELECT	  'Sync BOM'
					,'BOM for job ' + @JJob + '-'
						+ RIGHT('0000' + CAST(@JSuffix AS NVARCHAR(4)),4)
						+ ' / operation ' + CAST(jm.oper_num AS NVARCHAR(4))
						+ ' / work center ' + jr.wc 
						+ ' / item ' + jm.item
						+ IIF(bt.item IS NULL,
								' with quantity ' + CAST(jm.matl_qty AS NVARCHAR(16)) + ' successfully added.',
								' successfully updated from quantity ' + CAST(bt.BOMQty AS NVARCHAR(16))
									+ ' to quantity ' + CAST(jm.matl_qty AS NVARCHAR(16)) + '.')
				FROM jobmatl jm
					JOIN jobroute jr
						ON jr.job = jm.job AND jr.suffix = jm.suffix AND jr.oper_num = jm.oper_num
					LEFT JOIN @BOMTable bt
						ON bt.WorkCenter = jr.wc AND bt.Item = jm.item
					WHERE jm.job = @JJob AND jm.suffix = @JSuffix
						AND jm.matl_qty <> ISNULL(bt.BOMQty,0)

		INSERT INTO @errors
			SELECT	  'Sync Labor'
					, 'Labor Hours for job ' + @JJob  + '-' + RIGHT('0000' + CAST(@JSuffix AS NVARCHAR(4)),4) + 
						' / Work Center ' + jr.wc +
						' updated from ' + CAST(ISNULL(lt.Hrs,0) AS NVARCHAR(20)) + ' hours to ' + CAST(js.run_lbr_hrs AS NVARCHAR(20)) + ' hours.'
				FROM jrt_sch js
					JOIN jobroute jr
						ON jr.job = js.job AND jr.suffix = js.suffix AND jr.oper_num = js.oper_num
					LEFT JOIN #LaborTable lt
						ON lt.WorkCenter = jr.wc
					WHERE js.job = @JJob AND js.suffix = @JSuffix AND js.run_lbr_hrs <> ISNULL(lt.Hrs,0)
	END

EXITR:
	IF EXISTS (SELECT 1 FROM @errors)
		BEGIN
			SELECT * FROM @errors ORDER BY fileName, errorStr
		END
	ELSE SELECT 'Create BOMS' AS fileName,'No errors encountered' AS errorStr
GO

