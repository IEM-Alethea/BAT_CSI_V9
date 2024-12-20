SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/**********************************************************************************
*                            Modification Log
*                                            
* Ref#  Init   Date     Description           
* ----- ----   -------- -----------------------------------------------------------
* 0000	DMS	   20240504 Modified to support JAX, FRE, VAN, and PASS DB's Dynamically

**********************************************************************************/

ALTER PROCEDURE [dbo].[_IEM_UnitMarginSetSp]

AS

BEGIN

DECLARE	  @StartDate				DATE
		, @EndDate					DATE
		, @RptSessionID				RowPointerType
		, @State					StateType
		, @Country					CountryType
		, @CharIndexSC				TINYINT
		, @SiteName					SiteType
		, @TableResults				VARCHAR(2000)
		, @Counter					INT = 0
		, @Site						SiteType

EXEC dbo.InitSessionContextSp
     @ContextName = '_IEM_Rpt_MarginLtSp'
   , @SessionID   = @RptSessionID OUTPUT
   , @Site        = @Site

SET @EndDate = DATEADD(dd, -1, GETDATE())
SET @StartDate = DATEADD(mm, -6, GETDATE())

IF OBJECT_ID('tempdb..#MarginPctBase') IS NOT NULL DROP TABLE #MarginPctBase

DECLARE @Sites TABLE (
	  ID				INT IDENTITY
	, Site				SiteType
	)
	
INSERT INTO @Sites
	SELECT Site_name FROM Site WHERE Uf_Mfg = 1
		
IF OBJECT_ID('tempdb..#jra') IS NOT NULL DROP TABLE #jra
IF OBJECT_ID('tempdb..#coa') IS NOT NULL DROP TABLE #coa
IF OBJECT_ID('tempdb..#tria') IS NOT NULL DROP TABLE #tria
IF OBJECT_ID('tempdb..#isma') IS NOT NULL DROP TABLE #isma
IF OBJECT_ID('tempdb..#cotra') IS NOT NULL DROP TABLE #cotra
IF OBJECT_ID('tempdb..#obsbomsub') IS NOT NULL DROP TABLE #obsbomsub

SELECT job, suffix, run_hrs_t_lbr INTO #JRA FROM jobroute WHERE 1 = 0
SELECT co_num, end_user_type INTO #coa FROM co WHERE 1 = 0
SELECT * INTO #tria FROM trnitem_mst WHERE 1 = 0
SELECT	  site_ref
		, CAST('' AS NVARCHAR(30)) AS item
		, ref_num AS co_num
		, ref_line_suf AS co_line
		, CAST('' AS NVARCHAR(30)) AS ser_num
		, trans_date
		, track_type
		, CAST(0.0 AS DECIMAL(20,8)) AS cost
	INTO #isma FROM matltrack_mst WHERE 1 = 0

CREATE TABLE #obsbomsub (
	  site_ref				NVARCHAR(8)
	, parentItem			NVARCHAR(30)
	, componentItem			NVARCHAR(30)
	, subItem				NVARCHAR(30)
	)		

WHILE @Counter < (SELECT MAX(ID) FROM @Sites)
	BEGIN
		SET @Counter += 1
		SET @SiteName = (SELECT site FROM @Sites WHERE ID = @Counter)
		SET @TableResults = 'INSERT INTO #JRA SELECT job, suffix, run_hrs_t_lbr FROM ' + @SiteName + '_App..jobroute_mst'
		EXEC (@TableResults)
		SET @TableResults = 'INSERT INTO #coa SELECT co_num, end_user_type FROM ' + @SiteName + '_App..co_mst'
		EXEC (@TableResults)
		SET @TableResults = 'INSERT INTO #tria SELECT * FROM ' + @SiteName + '_App..trnitem_mst'
		EXEC (@TableResults)
		SET @TableResults = 'INSERT INTO #isma
								SELECT DISTINCT 
									  i.site_ref
									, i.item
									, ser.ref_num
									, ser.ref_line
									, ser.ser_num
									, mtr.trans_date
									, mtr.track_type
									, mt.cost
								FROM ' + @SiteName + '_App..item_mst i
									JOIN ' + @SiteName + '_App..serial_mst ser
										ON ser.item = i.item
									JOIN ' + @SiteName + '_App..ser_track_mst st
										ON st.ser_num = ser.ser_num
									JOIN ' + @SiteName + '_App..matltrack_mst mtr
										ON mtr.track_num = st.track_num
							 		JOIN ' + @SiteName + '_App..matltran_mst mt
										ON	mt.ref_num = mtr.ref_num AND
											mt.ref_line_suf = mtr.ref_line_suf AND
											mt.ref_type = mtr.ref_type AND
											mt.ref_release = mtr.ref_release AND
											mt.qty = mtr.qty AND
											ISNULL(mt.lot, '''') = ISNULL(mtr.lot, '''') AND
											mt.whse = mtr.whse AND
											mt.loc = mtr.loc AND
											mt.item = mtr.item AND
											DATEDIFF(MINUTE, mt.trans_date, mtr.trans_date) = 0'
		EXEC (@TableResults)
		SET @TableResults = 'INSERT INTO #obsbomsub SELECT ''' + @SiteName + ''', parentItem, componentItem, subItem FROM ' + @SiteName + '_App.._IEM_ObsoleteBOMSub'
		EXEC (@TableResults)
	END

SELECT coia.site_ref
	, coia.co_num
	, coia.co_line
	, coia.item
	, tra.from_site
	, tra.to_site
	, cpaf.curr_code AS curr_code_f
	, cpat.curr_code AS curr_code_t
INTO #cotra			
	FROM coitem_all coia
		JOIN trnitem_all tria
			ON tria.site_ref = coia.site_ref AND tria.trn_num = coia.ref_num AND tria.trn_line = coia.ref_line_suf
		JOIN transfer_all tra
			ON coia.site_ref = tra.site_ref AND tra.trn_num = tria.trn_num
		JOIN currparms_all cpat
			ON cpat.site_ref = tra.to_site
		JOIN currparms_all cpaf
			ON cpaf.site_ref = tra.from_site

--ZERO COST LINE BYPASS SECTION

IF OBJECT_ID('tempdb..##iia') IS NOT NULL DROP TABLE ##iia

EXEC _IEM_PMAllSp --
	  'iia'
	, 'inv_item_mst'
	, 'site_ref, inv_num, item, qty_invoiced, cost, co_num, co_line, CreateDate'
	, NULL

IF OBJECT_ID('tempdb..##pra') IS NOT NULL DROP TABLE ##pra

EXEC _IEM_PMAllSp --
	  'pra'
	, 'po_rcpt_mst'
	, 'site_ref, po_num, po_line, po_release, unit_mat_cost, rcvd_date'
	, NULL

IF OBJECT_ID('tempdb..##ICSC') IS NOT NULL DROP TABLE ##ICSC

EXEC _IEM_PMAllSp --
	  'ICSC'
	, '_IEM_coitem_slscom_mst'
	, NULL
	, NULL

IF OBJECT_ID('tempdb..#ZI') IS NOT NULL DROP TABLE #ZI
IF OBJECT_ID('tempdb..#ZP') IS NOT NULL DROP TABLE #ZP
IF OBJECT_ID('tempdb..#ZITEM') IS NOT NULL DROP TABLE #ZITEM

SELECT	  iia.site_ref
		, iia.inv_num
		, iia.item
		, iia.qty_invoiced
		, iia.cost
		, iia.co_num
		, iia.co_line
		, iia.CreateDate
	INTO #ZI
		FROM ##iia iia
			LEFT JOIN inv_hdr_all iha
				ON iha.site_ref = iia.site_ref AND iha.inv_num = iia.inv_num
			WHERE iia.item NOT LIKE 'SOLI%' AND iia.cost = 0 AND iia.item NOT LIKE '$%' AND iia.item NOT LIKE 'KIT%'
				AND iha.bill_type = 'R'
				AND NOT EXISTS (SELECT 1 FROM ##iia iia2 WHERE iia2.co_num = iia.co_num AND iia2.co_line = iia.co_line AND iia2.cost <> 0)

SELECT	  poia.site_ref
		, poia.item
		, IIF(pra.unit_mat_cost = 0 AND poia.unit_mat_cost <> 0, poia.unit_mat_cost, pra.unit_mat_cost) AS unit_mat_cost
		, pra.rcvd_date
		, zi.inv_num
		, zi.co_line
		, ROW_NUMBER() OVER (PARTITION BY zi.inv_num, zi.co_line, zi.CreateDate, poia.item ORDER BY pra.rcvd_date) rn
	INTO #ZP
		FROM ##pra pra
			JOIN poitem_all poia
				ON poia.site_ref = pra.site_ref AND poia.po_num = pra.po_num AND poia.po_line = pra.po_line AND poia.po_release = pra.po_release
			JOIN #ZI ZI
				ON zi.site_ref = poia.site_ref AND zi.item = poia.item
					AND (zi.CreateDate < pra.rcvd_date OR (pra.unit_mat_cost = 0 AND poia.unit_mat_cost <> 0))

SELECT	  zi.site_ref
		, zi.co_num
		, zi.co_line
		, SUM(ABS(zi.qty_invoiced) * IIF(coia.cost_conv = 0, zp.unit_mat_cost, coia.cost_conv)) / SUM(ABS(zi.qty_invoiced)) AS cost
	INTO #ZITEM
		FROM #ZI ZI
			LEFT JOIN coitem_all coia
				ON coia.site_ref = zi.site_ref AND coia.co_num = zi.co_num AND coia.co_line = zi.co_line
			LEFT JOIN #ZP zp
				ON zp.site_ref = zi.site_ref AND zp.inv_num = zi.inv_num AND zp.co_line = zi.co_line AND zp.rn = 1
			WHERE coia.cost_conv <> 0 OR zp.inv_num IS NOT NULL
				GROUP BY zi.site_ref, zi.co_num, zi.co_line, zi.item
					HAVING SUM(ABS(zi.qty_invoiced) * IIF(coia.cost_conv = 0, zp.unit_mat_cost, coia.cost_conv)) / SUM(ABS(zi.qty_invoiced)) <> 0

OPTION (RECOMPILE)

--END ZERO COST LINE BYPASS SECTION

IF OBJECT_ID('tempdb..#ReportSet') IS NOT NULL
    DROP TABLE #ReportSet

IF OBJECT_ID('tempdb..#MJRA') IS NOT NULL DROP TABLE #MJRA

SELECT	  job
		, suffix
		, SUM(run_hrs_t_lbr) AS run_hrs_t_lbr
	INTO #MJRA
		FROM #jra jra
			GROUP BY job, suffix

IF OBJECT_ID('tempdb..#MOBS') IS NOT NULL DROP TABLE #MOBS

SELECT	  j.site_ref
		, j.job
		, j.suffix
		, SUM(jm.qty_issued * (-jm.matl_cost + i.matl_cost * 0.8)) AS obs_adj
	INTO #MOBS
		FROM job_all j
			JOIN jobmatl_all jm
				ON jm.site_ref = j.site_ref AND jm.job = j.job AND jm.suffix = jm.suffix
			JOIN #obsbomsub obs
				ON obs.site_ref = j.site_ref AND obs.parentItem = j.item AND obs.subItem = jm.item
			JOIN item_all i
				ON i.site_ref = obs.site_ref AND i.item = obs.componentItem
			WHERE j.type = 'J'
				GROUP BY j.site_ref, j.job, j.suffix

IF OBJECT_ID('tempdb..#MFRE') IS NOT NULL DROP TABLE #MFRE

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'FRE','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total + ISNULL(obs.obs_adj, 0) AS wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MFRE
		FROM _IEM_job_all ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			LEFT JOIN #MOBS OBS
				ON obs.site_ref = ija.site_ref AND obs.job = ija.job AND obs.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'FRE'

IF OBJECT_ID('tempdb..#MJAX') IS NOT NULL DROP TABLE #MJAX

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'JAX','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total + ISNULL(obs.obs_adj, 0) AS wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MJAX
		FROM _IEM_job_all ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			LEFT JOIN #MOBS OBS
				ON obs.site_ref = ija.site_ref AND obs.job = ija.job AND obs.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'JAX'

IF OBJECT_ID('tempdb..#MVAN') IS NOT NULL DROP TABLE #MVAN

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'VAN','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total + ISNULL(obs.obs_adj, 0) AS wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MVAN
		FROM _IEM_job_all ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			LEFT JOIN #MOBS OBS
				ON obs.site_ref = ija.site_ref AND obs.job = ija.job AND obs.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'VAN'

/*IF OBJECT_ID('tempdb..#MFREu') IS NOT NULL DROP TABLE #MFREu

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'FRE','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MFREu
		FROM (SELECT * FROM _IEM_job_all WHERE item = 'UNPOSTABLEJOBCOSTS') ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'FRE'

IF OBJECT_ID('tempdb..#MJAXu') IS NOT NULL DROP TABLE #MJAXu

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'JAX','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MJAXu
		FROM (SELECT * FROM _IEM_job_all WHERE item = 'UNPOSTABLEJOBCOSTS') ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'JAX'
		
IF OBJECT_ID('tempdb..#MVANu') IS NOT NULL DROP TABLE #MVANu

SELECT	  ija.job AS sub_job
		, REPLACE(ija.job,'VAN','') AS job
		, ija.suffix
		, ija.wip_fovhd_total
		, ija.wip_vovhd_total
		, ija.wip_matl_total
		, ija.stat
		, JRA.run_hrs_t_lbr
	INTO #MVANu
		FROM (SELECT * FROM _IEM_job_all WHERE item = 'UNPOSTABLEJOBCOSTS') ija
			LEFT JOIN #MJRA JRA
				ON JRA.job = ija.job AND JRA.suffix = ija.suffix
			WHERE ija.type = 'J' AND RIGHT(ija.job,3) = 'VAN'
*/

IF OBJECT_ID('tempdb..#MCS') IS NOT NULL DROP TABLE #MCS

SELECT	  ISNULL(cosa.site_ref, coia.site_ref) AS site_ref
		, ISNULL(cosa.co_num,coia.co_num) AS co_num
		, ISNULL(cosa.co_line, coia.co_line) AS co_line
		, IIF(coia.description = 'AVANTE JOB COSTS', SUM(coia.qty_shipped), SUM(ISNULL(cosa.qty_shipped, 0) - ISNULL(cosa.qty_returned, 0))) AS qty_shipped
		, MAX(cosa.ship_date) AS ship_date
	INTO #MCS
		FROM coitem_all coia
			LEFT JOIN co_ship_all cosa
				ON cosa.site_ref = coia.site_ref AND cosa.co_num = coia.co_num AND cosa.co_line = coia.co_line
			GROUP BY ISNULL(cosa.site_ref, coia.site_ref), ISNULL(cosa.co_num,coia.co_num), ISNULL(cosa.co_line, coia.co_line), coia.description

IF OBJECT_ID('tempdb..#MCoTrSer') IS NOT NULL DROP TABLE #MCoTrSer

SELECT	  cotra.co_num
		, cotra.co_line
		, SUM(isma2.cost) AS unit_cost
		, isma2.site_ref
	INTO #MCoTrSer
		FROM #cotra cotra
			JOIN #isma isma
				ON isma.site_ref = cotra.to_site AND isma.item = cotra.item AND isma.co_num = cotra.co_num AND isma.co_line = cotra.co_line
			JOIN #isma isma2
				ON isma2.site_ref = cotra.from_site AND isma2.item = cotra.item AND isma2.ser_num = isma.ser_num
			JOIN currate_all cra
				ON cra.site_ref = cotra.to_site AND CAST(eff_date AS DATE) = CAST(isma.trans_date AS DATE) AND
					cra.from_curr_code = cotra.curr_code_f AND cra.to_curr_code = cotra.curr_code_t
			WHERE isma.track_type = 'R' AND isma2.track_type = 'I'
				GROUP BY cotra.co_num, cotra.co_line, isma2.site_ref

IF OBJECT_ID('tempdb..#MZeroed') IS NOT NULL DROP TABLE #MZeroed

SELECT	  site_ref
		, co_num
		, co_line
		, MAX(activity_date) AS max_ad
	INTO #MZeroed
		FROM coitem_log_all
			GROUP BY site_ref, co_num, co_line
				HAVING SUM(qty_chg) = 0

IF OBJECT_ID('tempdb..#MLastZeroDate') IS NOT NULL DROP TABLE #MLastZeroDate

SELECT	  site_ref
		, co_num
		, MAX(max_ad) AS max_ad
	INTO #MLastZeroDate
		FROM #MZeroed
			GROUP BY site_ref, co_num

IF OBJECT_ID('tempdb..#MLastShip') IS NOT NULL DROP TABLE #MLastShip

SELECT	  site_ref
		, co_num
		, MAX(ship_date) AS ship_date
	INTO #MLastShip
		FROM co_ship_all
			GROUP BY site_ref, co_num

IF OBJECT_ID('tempdb..#MLastActivity') IS NOT NULL DROP TABLE #MLastActivity

SELECT	  ISNULL(lzd.co_num, ls.co_num) AS co_num
		, IIF(ISNULL(lzd.max_ad,'1775-11-10') > ISNULL(ls.ship_date,'1775-11-10'), lzd.max_ad, ls.ship_date) AS lad
	INTO #MLastActivity
		FROM #MLastZeroDate lzd
			FULL JOIN #MLastShip ls
				ON ls.site_ref = lzd.site_ref AND ls.co_num = lzd.co_num

IF OBJECT_ID('tempdb..#MRecentlyClosedCo') IS NOT NULL DROP TABLE #MRecentlyClosedCo

SELECT	  co_num
	INTO #MRecentlyClosedCo
		FROM #MLastActivity
			WHERE CAST(lad AS DATE) BETWEEN @StartDate AND @EndDate

IF OBJECT_ID('tempdb..#MCOLMI') IS NOT NULL DROP TABLE #MCOLMI

SELECT	  iia.site_ref
		, iia.co_num
		, iia.co_line
		, SUM(iia.qty_invoiced * iia.cost) / SUM(iia.qty_invoiced) AS cost
	INTO #MCOLMI
		FROM ##iia iia
			JOIN inv_hdr_all iha
				ON iha.site_ref = iia.site_ref AND iha.inv_num = iia.inv_num
			WHERE iia.qty_invoiced * iia.cost <> 0
					AND iia.item NOT LIKE 'SOLI%' 
					AND iia.item NOT LIKE 'ATSC30%'
					AND iha.bill_type = 'R'
				GROUP BY iia.site_ref, iia.co_num, iia.co_line, iia.item
					HAVING COUNT(*) > 1 AND SUM(iia.qty_invoiced) <> 0

IF OBJECT_ID('tempdb..#MCOLMI2') IS NOT NULL DROP TABLE #MCOLMI2

SELECT	  colmi.site_ref
		, colmi.co_num
		, colmi.co_line
		, colmi.cost
	INTO #MCOLMI2
		FROM #MCOLMI COLMI
			JOIN coitem_all coia
				ON coia.site_ref = colmi.site_ref AND coia.co_num = colmi.co_num AND coia.co_line = colmi.co_line
			WHERE coia.cost / colmi.cost < 0.95 OR coia.cost / colmi.cost > 1.05

IF OBJECT_ID('tempdb..#MKIT') IS NOT NULL DROP TABLE #MKIT

SELECT	  ia.site_ref
		, ia.item AS i_item
		, ja.job
		, jma.item AS jm_item
		, jma.matl_qty_conv
		, ia2.unit_cost AS jma_unit_cost
		, jma.matl_qty_conv * ia2.unit_cost AS jma_ext_cost
	INTO #MKIT
		FROM item_all ia
			JOIN job_all ja
				ON ja.site_ref = ia.site_ref AND ja.item = ia.item
			JOIN jobmatl_all jma
				ON jma.site_ref = ja.site_ref AND jma.job = ja.job AND jma.suffix = ja.suffix
			JOIN item_all ia2
				ON ia2.site_ref = jma.site_ref AND ia2.item = jma.item
			WHERE ia.item LIKE 'KIT%' AND ja.type = 'S'

IF OBJECT_ID('tempdb..#MKIT2') IS NOT NULL DROP TABLE #MKIT2

SELECT	  coia.site_ref
		, coia.co_num
		, coia.co_line
		, kit.i_item
		, SUM(jma_ext_cost) AS cost
	INTO #MKIT2
		FROM coitem_all coia
			JOIN #MKIT KIT
				ON kit.site_ref = coia.site_ref AND kit.i_item = coia.item
			GROUP BY coia.site_ref, coia.co_num, coia.co_line, kit.i_item

IF OBJECT_ID('tempdb..#MCoiaC') IS NOT NULL DROP TABLE #MCoiaC

SELECT	  coia.site_ref
		, coia.co_num
		, coia.co_line
		, COALESCE(z.cost, c2.cost, kit2.cost, coia.cost) AS cost
	INTO #MCoiaC
		FROM coitem_all coia
			LEFT JOIN #ZITEM z
				ON z.site_ref = coia.site_ref AND z.co_num = coia.co_num AND z.co_line = coia.co_line
			LEFT JOIN #MCOLMI2 c2
				ON c2.site_ref = coia.site_ref AND c2.co_num = coia.co_num AND c2.co_line = coia.co_line
			LEFT JOIN #MKIT2 KIT2
				ON kit2.site_ref = coia.site_ref AND kit2.co_num = coia.co_num AND kit2.co_line = coia.co_line

SELECT coia.site_ref
		, coia.Uf_Assign_site
		, RIGHT(' ' + LTRIM(coia.co_num),6) AS co_num
		, coia.co_line
		, coia.item
		, REPLACE(REPLACE(coia.description,CHAR(10),'|'),CHAR(13),'') AS description
		, coia.qty_ordered
		, cs.qty_shipped
		, coia.price AS unit_price
		, ROUND(cs.qty_shipped * IIF(RIGHT(coia.site_ref,3) = 'VAN',coia.price / ISNULL(cr.buy_rate,1), coia.price),2) AS value_shipped_USD
		, ROUND(cs.qty_shipped * IIF(RIGHT(coia.site_ref,3) = 'VAN',coia.price, coia.price * cr.buy_rate),2) AS value_shipped_CAD
		, ISNULL(1 / cr.buy_rate,1) AS "USD : CAD"
		, IIF(coia.description LIKE 'AVANTE%','2016-04-30',cs.ship_date) AS ship_date
		, (ISNULL(FRE.wip_fovhd_total,0) + ISNULL(FRE.wip_vovhd_total,0) +
		  ISNULL(JAX.wip_fovhd_total,0) + ISNULL(JAX.wip_vovhd_total,0) +
		  (ISNULL(VAN.wip_fovhd_total,0) + ISNULL(VAN.wip_vovhd_total,0)) * 1 / ISNULL(cr.buy_rate,1) +
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(FRE.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'FRE',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'FRE',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
				)
		 + 
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(JAX.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'JAX',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'JAX',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  )
		 + 
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(VAN.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'VAN',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'VAN',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  ) * 1 / ISNULL(cr.buy_rate,1)
			) * 1.000		
			AS total_costs_incurred_USD
		, ((ISNULL(FRE.wip_fovhd_total,0) + ISNULL(FRE.wip_vovhd_total,0)) * ISNULL(cr.buy_rate,1) +
		   (ISNULL(JAX.wip_fovhd_total,0) + ISNULL(JAX.wip_vovhd_total,0)) * ISNULL(cr.buy_rate,1) +
		    ISNULL(VAN.wip_fovhd_total,0) + ISNULL(VAN.wip_vovhd_total,0) +
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(FRE.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'FRE',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'FRE',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  )* ISNULL(cr.buy_rate,1)
		 + 
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(JAX.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'JAX',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'JAX',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  ) * ISNULL(cr.buy_rate,1)
		 + 
		  IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(VAN.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'VAN',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'VAN',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			) * 1.000)	
			AS total_costs_incurred_CAD
		, ISNULL(FRE.wip_fovhd_total,0) + ISNULL(FRE.wip_vovhd_total,0) AS FRE_wip_l
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(FRE.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'FRE',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'FRE',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'FRE') = 'FRE',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  )*1.000
				AS FRE_wip_m
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',IIF(ISNULL(FRE.stat,'C') = 'C', 'Y', 'N'),'') AS FRE_stat
		, ISNULL(JAX.wip_fovhd_total,0) + ISNULL(JAX.wip_vovhd_total,0) AS JAX_wip_l
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(JAX.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'JAX',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'JAX',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'JAX') = 'JAX',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  )*1.000
				AS JAX_wip_m
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',IIF(ISNULL(JAX.stat,'C') = 'C', 'Y', 'N'),'') AS JAX_stat
		, ISNULL(VAN.wip_fovhd_total,0) + ISNULL(VAN.wip_vovhd_total,0) AS VAN_wip_l
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',
			ISNULL(VAN.wip_matl_total,0),
			IIF(cts.site_ref IS NOT NULL,
				IIF(RIGHT(cts.site_ref,3) = 'VAN',cts.unit_cost,0),
				ISNULL(IIF(RIGHT(coia.site_ref,3) = 'VAN',
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(cc.cost * cs.qty_shipped,2),
						   0),
					   IIF(ISNULL(RIGHT(coia.Uf_Assign_site,3),'VAN') = 'VAN',
						   ROUND(tria2.unit_cost * cs.qty_shipped,2),
						   0)
					   ),0))
			  )*1.000
				AS VAN_wip_m
		, IIF(coia.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',IIF(ISNULL(VAN.stat,'C') = 'C', 'Y', 'N'),'') AS VAN_stat
		, ISNULL(FRE.run_hrs_t_lbr,0) AS FRE_lbr_hrs
		, ISNULL(FRE.wip_fovhd_total,0) AS FRE_wip_f
		, ISNULL(FRE.wip_vovhd_total,0) AS FRE_wip_v
		, ISNULL(JAX.run_hrs_t_lbr,0) AS JAX_lbr_hrs
		, ISNULL(JAX.wip_fovhd_total,0) AS JAX_wip_f
		, ISNULL(JAX.wip_vovhd_total,0) AS JAX_wip_v
		, ISNULL(VAN.run_hrs_t_lbr,0) AS VAN_lbr_hrs
		, ISNULL(VAN.wip_fovhd_total,0) AS VAN_wip_f
		, ISNULL(VAN.wip_vovhd_total,0) AS VAN_wip_v
		, coa.cust_num
		, cad.name
		, cua.cust_type + ' (' + cst.description + ')' AS cust_type
		, coa.stat
		, ISNULL(csc.slsman, coa.slsman) + ISNULL(' / ' + ISNULL(csc.Uf_Slsman2, coa.Uf_Slsman2),'') 
				+ ISNULL(' / ' + ISNULL(csc.Uf_Slsman3, coa.Uf_Slsman3),'') + ISNULL(' / ' + ISNULL(csc.Uf_Slsman4, coa.Uf_Slsman4),'') AS Salesperson
		, ISNULL(cad.state,cad.country) AS State
		, coa.Uf_JobName
		, coa.Uf_ProjectManager
		, coa2.end_user_type + ' (' + eta.description + ')' AS end_user_type
		, ia.product_code
		, pca.description AS pc_description
		, ROUND((ISNULL(coia.qty_ordered * coia.price * isc1.rate * ISNULL(csc.Uf_CommMult1, coa.Uf_CommMult1) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc2.rate * ISNULL(csc.Uf_CommMult2, coa.Uf_CommMult2) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc3.rate * ISNULL(csc.Uf_CommMult3, coa.Uf_CommMult3) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc4.rate * ISNULL(csc.Uf_CommMult4, coa.Uf_CommMult4) / 100, 0)) *
		  IIF(RIGHT(coia.site_ref,3) = 'VAN', 1 / ISNULL(cr.buy_rate,1),1),2)
			AS commission_USD
		, ROUND((ISNULL(coia.qty_ordered * coia.price * isc1.rate * ISNULL(csc.Uf_CommMult1, coa.Uf_CommMult1) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc2.rate * ISNULL(csc.Uf_CommMult2, coa.Uf_CommMult2) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc3.rate * ISNULL(csc.Uf_CommMult3, coa.Uf_CommMult3) / 100, 0) +
		  ISNULL(coia.qty_ordered * coia.price * isc4.rate * ISNULL(csc.Uf_CommMult4, coa.Uf_CommMult4) / 100, 0)) *
		  IIF(RIGHT(coia.site_ref,3) = 'VAN', 1, ISNULL(cr.buy_rate,1)),2)
			AS commission_CAD
		, CAST(0 AS DECIMAL(23,8)) AS margin_USD
		, CAST(0 AS DECIMAL(23,8)) AS margin_CAD
		, CAST(0 AS DECIMAL(8,4)) AS margin_pct
		, CAST('2999-12-31' AS DATE) AS last_ship_date_from_order
		, ROUND(coia.qty_ordered * coia.price * IIF(RIGHT(coia.site_ref,3) = 'VAN', 1 / ISNULL(cr.buy_rate,1), 1), 2) AS ext_price_USD
		, ROUND(coia.qty_ordered * coia.price * IIF(RIGHT(coia.site_ref,3) = 'VAN', 1, ISNULL(cr.buy_rate,1)), 2) AS ext_price_CAD
		, CASE
			WHEN RIGHT(coia.site_ref,3) = 'VAN' THEN 'CAD'
			ELSE 'USD' END AS curr_code
		, CAST(NULL AS NVARCHAR(12)) AS est_job
		, CAST(0 AS DECIMAL(23,8)) AS ALL_wip_m
		, CAST(0 AS DECIMAL(23,8)) AS ALL_est_m
		, CAST(0 AS DECIMAL(13,4)) AS AVE_matl
		, CAST(0 AS DECIMAL(23,8)) AS ALL_wip_l
		, CAST(0 AS DECIMAL(23,8)) AS ALL_est_l
		, CAST(0 AS DECIMAL(13,4)) AS AVE_labor
		, CAST(0 AS DECIMAL(13,4)) AS AVE_total

INTO #ReportSet

	FROM coitem_all coia
		LEFT JOIN #MCoiaC cc
			ON cc.site_ref = coia.site_ref AND cc.co_num = coia.co_num AND cc.co_line = coia.co_line
		LEFT JOIN (SELECT DISTINCT item FROM coitem_all WHERE qty_ordered != 0) dm
			ON dm.item = coia.item
		LEFT JOIN #MFRE FRE
			--ON FRE.job = LTRIM(coia.co_num) AND FRE.suffix = coia.co_line
			ON 'SOLI' + RIGHT('0' + FRE.job, 6) + RIGHT('000' + CAST(FRE.suffix AS NVARCHAR(4)), 4) = coia.item 
					AND NOT (coia.qty_ordered = 0 AND dm.item IS NOT NULL)
		LEFT JOIN #MJAX JAX
			--ON JAX.job = LTRIM(coia.co_num) AND JAX.suffix = coia.co_line
			ON 'SOLI' + RIGHT('0' + JAX.job, 6) + RIGHT('000' + CAST(JAX.suffix AS NVARCHAR(4)), 4) = coia.item 
					AND NOT (coia.qty_ordered = 0 AND dm.item IS NOT NULL)
		LEFT JOIN #MVAN VAN
			--ON VAN.job = LTRIM(coia.co_num) AND VAN.suffix = coia.co_line
			ON 'SOLI' + RIGHT('0' + VAN.job, 6) + RIGHT('000' + CAST(VAN.suffix AS NVARCHAR(4)), 4) = coia.item 
					AND NOT (coia.qty_ordered = 0 AND dm.item IS NOT NULL)
		LEFT JOIN #MCS cs
			ON cs.site_ref = coia.site_ref AND cs.co_num = coia.co_num AND cs.co_line = coia.co_line
		LEFT JOIN currate cr
			ON CAST(IIF(coia.description = 'AVANTE JOB COSTS','2016-04-30',ISNULL(cs.ship_date,GETDATE())) AS DATE) = cr.eff_date AND from_curr_code = 'CAD' AND to_curr_code = 'USD'
		JOIN co_all coa
			ON coa.co_num = coia.co_num
		LEFT JOIN customer_all cua
			ON cua.site_ref = coa.site_ref AND cua.cust_num = coa.cust_num AND cua.cust_seq = 0
		LEFT JOIN customer_all cua2
			ON cua2.site_ref = coa.site_ref AND cua2.cust_num = coa.cust_num AND cua2.cust_seq = coa.cust_seq
		LEFT JOIN custaddr_mst cad
			ON cad.cust_num = coa.cust_num AND cad.cust_seq = coa.cust_seq
		LEFT JOIN custtype_all cst
			ON cst.site_ref = cua.site_ref AND cst.cust_type = cua.cust_type
		LEFT JOIN #coa coa2
			ON coa2.co_num = coa.co_num
		LEFT JOIN item_all ia
			ON ia.site_ref = coia.site_ref AND ia.item = coia.item
		LEFT JOIN prodcode_all pca
			ON pca.site_ref = ia.site_ref AND pca.product_code = ia.product_code
		LEFT JOIN ##ICSC csc
			ON csc.SiteRef = coia.site_ref AND csc.co_num = coia.co_num AND csc.co_line = coia.co_line
		LEFT JOIN _IEM_SlspsnCommission isc1
			ON isc1.Slspsn = ISNULL(csc.slsman, coa.slsman) AND isc1.UC2 = pca.unit
		LEFT JOIN _IEM_SlspsnCommission isc2
			ON isc2.Slspsn = ISNULL(csc.Uf_Slsman2, coa.Uf_Slsman2) AND isc2.UC2 = pca.unit
		LEFT JOIN _IEM_SlspsnCommission isc3
			ON isc3.Slspsn = ISNULL(csc.Uf_Slsman3, coa.Uf_Slsman3) AND isc3.UC2 = pca.unit
		LEFT JOIN _IEM_SlspsnCommission isc4
			ON isc4.Slspsn = ISNULL(csc.Uf_Slsman4, coa.Uf_Slsman4) AND isc4.UC2 = pca.unit
		LEFT JOIN endtype_all eta
			ON eta.site_ref = coa.site_ref AND eta.end_user_type = coa2.end_user_type
		LEFT JOIN #MCoTrSer cts
			ON cts.co_num = coia.co_num AND cts.co_line = coia.co_line
		LEFT JOIN #tria tria
			ON coia.co_num = tria.to_ref_num AND coia.co_line = tria.to_ref_line_suf
		LEFT JOIN #tria tria2
			ON tria2.from_site = coia.Uf_Assign_site AND tria2.trn_num = tria.trn_num AND tria2.trn_line = tria.trn_line AND tria2.from_site = tria2.site_ref
		JOIN #MRecentlyClosedCo rcc
			ON rcc.co_num = coa.co_num
		WHERE coa.stat = 'C'
	OPTION (RECOMPILE)

UPDATE rs1
	SET margin_USD = rs2.value_shipped_USD - rs2.total_costs_incurred_USD,
		margin_CAD = rs2.value_shipped_CAD - rs2.total_costs_incurred_CAD
		FROM #ReportSet rs1
			JOIN #ReportSet rs2
				ON rs2.Uf_Assign_site = rs1.Uf_Assign_site AND rs2.co_num = rs1.co_num AND rs2.co_line = rs1.co_line
		WHERE rs1.qty_shipped >= rs1.qty_ordered
				AND NOT (rs1.description = 'UNPOSTABLE JOB COSTS' AND rs1.stat <> 'C')

UPDATE rs1
	SET margin_pct = CASE WHEN rs1.qty_shipped <> rs1.qty_ordered OR (rs1.description = 'UNPOSTABLE JOB COSTS' AND rs1.stat <> 'C')
						THEN NULL
						ELSE IIF(rs2.value_shipped_USD = 0, 0, rs2.margin_USD / rs2.value_shipped_USD) END
		FROM #ReportSet rs1
			JOIN #ReportSet rs2
				ON rs2.Uf_Assign_site = rs1.Uf_Assign_site AND rs2.co_num = rs1.co_num AND rs2.co_line = rs1.co_line

; WITH LSDFO
	AS (
		SELECT co_num, MAX(ship_date) AS ship_date
			FROM #ReportSet
				WHERE description <> 'UNPOSTABLE JOB COSTS'
					GROUP BY co_num
		)

UPDATE rs1
	SET last_ship_date_from_order = l.ship_date
		FROM #ReportSet rs1
			LEFT JOIN LSDFO l
				ON l.co_num = rs1.co_num

SELECT rs.*
	, CAST(DATEPART(yy,last_ship_date_from_order) AS NVARCHAR(4)) + '-' +
			RIGHT('0' + CAST(DATEPART(mm,last_ship_date_from_order) AS NVARCHAR(2)),2) AS CompMonth
	, CASE 
		WHEN margin_pct < 0 THEN 'NEG'
		WHEN margin_pct < 1 THEN CAST(FLOOR(margin_pct*10) AS NVARCHAR(1)) + '0.0% - ' + CAST(FLOOR(margin_pct*10) AS NVARCHAR(1)) + '9.9%'
		WHEN margin_pct = 1 THEN '100%'
		WHEN margin_pct IS NULL THEN '<none>'
		ELSE '> 100%'
		END AS margin_pctile
	, CASE	WHEN sls.outside = 0 THEN RIGHT('   ' + coa.slsman,3) + ' - ' + dbo.GetEmployeeName(emp.emp_num)
			ELSE RIGHT('   ' + coa.slsman,3) + ' - ' + va.name
			END AS slsman
	, CONVERT(NVARCHAR(10),@StartDate,121) + ' to ' + CONVERT(NVARCHAR(10),@EndDate,121) AS date_range
INTO #MarginPctBase
	FROM #ReportSet rs
		LEFT JOIN (SELECT site_ref, co_num, slsman FROM co_all WHERE ISNUMERIC(co_num) = 1) coa
			ON CAST(coa.co_num AS INT) = CAST(rs.co_num AS INT)
		LEFT JOIN slsman_all sls
			ON sls.site_ref = coa.site_ref AND sls.slsman = coa.slsman
		LEFT JOIN employee_all emp
			ON emp.site_ref = sls.site_ref AND emp.emp_num = sls.ref_num
		LEFT JOIN vendaddr va
			ON va.vend_num = sls.ref_num
	  WHERE	ISNUMERIC(rs.co_num) = 1
	ORDER BY 3,4,2

DELETE #MarginPctBase WHERE value_shipped_USD = 0

DELETE _IEM_UnitMargin

; WITH CoUnit
	AS (
		SELECT	  pc.unit
				, m.co_num
				, SUM(margin_USD) AS margin_USD
				, SUM(value_shipped_USD) AS value_shipped_USD
				, SUM(margin_USD) / IIF(SUM(value_shipped_USD) = 0, 1, SUM(value_shipped_USD)) AS margin_pct
			FROM #MarginPctBase m
				JOIN prodcode_all pc
					ON pc.site_ref = m.site_ref AND pc.product_code = m.product_code
				GROUP BY pc.unit, m.co_num
					HAVING SUM(value_shipped_USD) <> 0
		)

, UnitSD
	AS (
		SELECT	  unit
				, AVG(margin_pct) AS unit_avg
				, STDEVP(margin_pct) AS unit_sd
			FROM CoUnit
				GROUP BY unit
		)

, Report
	AS (
		SELECT	  c.unit
				, c.co_num
				, c.margin_USD
				, c.value_shipped_USD
				, c.margin_pct
				, u.unit_avg
				, u.unit_sd
				, u.unit_avg - 2 * u.unit_sd AS SD2Low
				, u.unit_avg + 2 * u.unit_sd AS SD2High
				, IIF(c.margin_pct NOT BETWEEN u.unit_avg - 2 * unit_sd AND u.unit_avg + 2 * unit_sd, 1, 0) AS outlier
			FROM CoUnit c
				LEFT JOIN UnitSD u
					ON u.unit = c.unit
		)

/***** SELECT THIS SECTION FOR DETAILED BREAKDOWN OF CUSTOMER ORDER AND UNIT CODE MARGIN DATA

SELECT * FROM Report
	ORDER BY c.unit, c.margin_pct, c.co_num
		OPTION (RECOMPILE)

*****/

INSERT INTO _IEM_UnitMargin (UnitCode2, MarginPct, TimexStamp)
	SELECT	  unit
			, SUM(margin_USD) / SUM(value_shipped_USD) AS margin_pct
			, GETDATE()
		FROM Report
			WHERE outlier = 0
				GROUP BY unit
					ORDER BY unit

-- Site Replication

DECLARE	  @PSite		SiteType
		, @cols			NVARCHAR(1000)
		, @sql			NVARCHAR(2000)

SET @Counter = (SELECT MAX(ID) FROM @Sites)

DELETE @Sites
	
INSERT INTO @Sites
	SELECT Site_name FROM Site WHERE Uf_Mfg = 1 AND app_db_name <> DB_NAME() -- #0000 DMS

SET @pSite = (SELECT Site FROM Site WHERE app_db_name = DB_NAME())

SELECT @cols = master.dbo.group_concat(COLUMN_NAME) 
	FROM INFORMATION_SCHEMA.COLUMNS T 
		WHERE table_name ='_IEM_UnitMargin' 

WHILE @Counter < (SELECT MAX(ID) FROM @Sites)
	BEGIN
		SET @Counter += 1
		SET @SiteName = (SELECT site FROM @Sites WHERE ID = @Counter)
		EXEC dbo.SetSiteSp @SiteName, NULL
		SET @sql = 'DELETE ' + @SiteName + '_App.._IEM_UnitMargin ' +
					'INSERT INTO ' + @SiteName + '_App.._IEM_UnitMargin (' + @cols + ')
						SELECT ' + @cols +
							 ' FROM ' + @pSite + '_App.._IEM_UnitMargin' 
		EXEC (@sql)
	END

EXEC dbo.SetSiteSp @pSite, NULL

END
