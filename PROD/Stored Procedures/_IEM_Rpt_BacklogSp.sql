SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/**********************************************************************************
*                            Modification Log
*                                            
* Ref#  Init   Date     Description           
* ----- ----   -------- -----------------------------------------------------------
* 0001  DBH    20240209 New columns added for PASS site
* 0002	DMS	   20240504 New columnd added for OTD
**********************************************************************************/

ALTER PROCEDURE [dbo].[_IEM_Rpt_BacklogSp]

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

--INSERT INTO _IEM_Debug SELECT 'BLL FA: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

DECLARE @ReportSet TABLE (
	  BT							TINYINT
	, face_site						SiteType
	, assign_site					SiteType
	, aff_site						SiteType
	, co_num						CoNumType
	, co_line						CoLineType
	, item							ItemType
	, due_date						DateType
	, product_code					ProductCodeType
	, extp							AmountType
	, Uf_EngineeringSubmittal		NVARCHAR(10)
	, mfg							ListYesNoType
	, ppb							AmountType
	)

IF OBJECT_ID('tempdb..#RSBacklog') IS NOT NULL DROP TABLE #RSBacklog

SELECT *
	INTO #RSBacklog
		FROM @ReportSet

DECLARE @CRate			DECIMAL(12,7)

SELECT @CRate = ISNULL(buy_rate,1)
	FROM currate
		WHERE CAST(eff_date AS DATE) = CAST((SELECT MAX(eff_date) FROM currate WHERE from_curr_code = 'CAD' AND to_curr_code = 'USD') AS DATE)
			AND from_curr_code = 'CAD' AND to_curr_code = 'USD'

--Recalculate Unit Code Margin Percentages (if not recent enough)
IF DATEDIFF(hh, (SELECT MAX(TimexStamp) FROM _IEM_UnitMargin), GETDATE()) > 24
	BEGIN
		EXEC _IEM_UnitMarginSetSp
	END

PRINT 'Before Backlog1: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

--Backlog1 (All applicable orders and jobs)

IF OBJECT_ID('tempdb..#BacklogPPBa') IS NOT NULL DROP TABLE #BacklogPPBa
IF OBJECT_ID('tempdb..#BacklogActCOLa') IS NOT NULL DROP TABLE #BacklogActCOLa
IF OBJECT_ID('tempdb..#BacklogJobsa') IS NOT NULL DROP TABLE #BacklogJobsa
IF OBJECT_ID('tempdb..#BacklogA1A1a') IS NOT NULL DROP TABLE #BacklogA1A1a
IF OBJECT_ID('tempdb..#BacklogA1A2a') IS NOT NULL DROP TABLE #BacklogA1A2a
IF OBJECT_ID('tempdb..#BacklogA1A3a') IS NOT NULL DROP TABLE #BacklogA1A3a
IF OBJECT_ID('tempdb..#BacklogA1Ra') IS NOT NULL DROP TABLE #BacklogA1Ra

PRINT 'Before BacklogPPB: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT	  iia.co_num
		, iia.co_line
		, SUM (iia.price) AS PPB_Total
	INTO #BacklogPPBa
		FROM inv_item_all iia
			JOIN inv_hdr_all iha
				ON iha.inv_num = iia.inv_num
		WHERE iha.bill_type = 'P'
			GROUP BY iia.co_num, iia.co_line

PRINT 'Before BacklogAct: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT	  coi.site_ref AS face_site
		, RIGHT(ISNULL(coi.Uf_assign_site, coi.site_ref), 3) AS assign_site
		, CASE cua.cust_type WHEN 9991 THEN 'FRE' WHEN 9992 THEN 'JAX' WHEN 9993 THEN 'VAN' END AS aff_site
		, coi.co_num
		, coi.co_line
		, coi.item
		, coi.due_date
		, i.product_code
		, (coi.qty_ordered - coi.qty_shipped) * IIF(ca.curr_code = 'CAD', coi.price / @CRate, coi.price) AS extp --Updated 2022-05-19 DBH for VAN / USD
		, coa.Uf_EngineeringSubmittal
		, IIF(i.product_code LIKE 'M%' AND coi.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]',1,0) AS mfg
		, ISNULL(IIF(ca.curr_code = 'CAD', ppb.PPB_Total / @CRate, ppb.PPB_Total), 0) AS ppb --Updated 2022-05-19 DBH for VAN / USD
	INTO #BacklogActCOLa
		FROM coitem_all coi
			LEFT JOIN co_all coa
				ON coa.co_num = coi.co_num
			LEFT JOIN item i
				ON coi.item = i.item
			LEFT JOIN customer_all cua
				ON cua.site_ref = coa.site_ref AND cua.cust_num = coa.cust_num AND cua.cust_seq = 0
			LEFT JOIN custaddr ca
				ON ca.cust_num = cua.cust_num AND ca.cust_seq = 0
			LEFT JOIN #BacklogPPBa ppb
				ON ppb.co_num = coi.co_num AND ppb.co_line = coi.co_line
		WHERE qty_ordered > qty_shipped

PRINT 'Before Job: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT	  j.job
		, j.suffix
	INTO #BacklogJobsa
		FROM job_all j
			JOIN jobmatl_all jm
				ON j.job = jm.job AND j.suffix = jm.suffix
			JOIN job_all sj
				ON jm.item = sj.item AND sj.type = 'J'
			WHERE EXISTS (SELECT * FROM jobmatl_all sjm WHERE sjm.job = sj.job AND sjm.suffix = sj.suffix)
				GROUP BY j.job, j.suffix, j.type
					HAVING j.suffix <> 0 AND iemCommon.dbo._IEM_IsStandardJob(j.job) = 0 AND j.type = 'J'

PRINT 'Before BacklogA1: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT ac.*
	INTo #BacklogA1A1a
		FROM #BacklogActCOLa ac
			LEFT JOIN #BacklogJobsa j
				ON ac.co_num = j.job AND ac.co_line = j.suffix
			WHERE due_date >= '1-1-2221'																	--Future Date
				AND (product_code LIKE 'M%' AND product_code NOT IN ('M2400','M2500','M2700'))				--All M product codes except 3
				AND j.job IS NULL																			--No sub-jobs with materials
				AND ac.item LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'					--SOLI items only

PRINT 'Before BacklogA2: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT ac.*
	INTO #BacklogA1A2a
		FROM #BacklogActCOLa ac
			LEFT JOIN #BacklogJobsa j
				ON ac.co_num = j.job AND ac.co_line = j.suffix
			WHERE due_date >= '1-1-2221'																	--Future Date
				AND (product_code NOT LIKE 'M%'																--All except in A1
					 OR product_code IN ('M2400','M2500','M2700')											
					 OR j.job IS NOT NULL																	
					 OR ac.item NOT LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
				AND ISNULL(ac.Uf_EngineeringSubmittal,'') = 'APPROVAL' 							 			--Approval Engineering submittal only

PRINT 'Before BacklogA3: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT ac.*
	INTO #BacklogA1A3a
		FROM #BacklogActCOLa ac
			LEFT JOIN #BacklogJobsa j
				ON ac.co_num = j.job AND ac.co_line = j.suffix
		WHERE due_date >= '1-1-2221'																	--Future Date
			AND (product_code NOT LIKE 'M%'																--All except in A1
				 OR product_code IN ('M2400','M2500','M2700')											
				 OR j.job IS NOT NULL																	
				 OR ac.item NOT LIKE 'SOLI[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
			AND ISNULL(ac.Uf_EngineeringSubmittal,'') <> 'APPROVAL' 							 		--Non-Approval Engineering submittal only

PRINT 'Before BacklogR: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

SELECT ac.*
	INTO #BacklogA1Ra
		FROM #BacklogActCOLa ac
			WHERE due_date < '1-1-2221'																	--Current Date

PRINT 'Before BacklogRS: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

INSERT INTO #RSBacklog
	SELECT 1, A1.*
		FROM #BacklogA1A1a A1

	UNION

	SELECT 2, A2.*
		FROM #BacklogA1A2a A2

	UNION

	SELECT 3, A3.*
		FROM #BacklogA1A3a A3

	UNION

	SELECT 3, R.*
		FROM #BacklogA1Ra R

PRINT 'After Backlog1: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

/*
; WITH AllOrders
	AS (
		SELECT co_num, co_line
			FROM #RSBacklog
		)

, A1F*/

SELECT 
	  rs.co_num
	, rs.co_line
	, rs.item
	, REPLACE(ia.description,CHAR(10),'|') AS item_desc
	, rs.product_code
	, pc.description AS pc_desc
	, rs.due_date
	, rs.Uf_EngineeringSubmittal
	, face_site
	, assign_site
	, aff_site
	, coa.cust_num
	, ca.name
	, coa.Uf_JobName
	, extp
	, ROUND(ISNULL(mu.MarginPct, 0) * IIF(aff_site IS NULL, extp, 0), 2) AS est_margin
	, (IIF(BT = 1 AND assign_site = 'FRE',extp,0) - IIF(BT = 1 AND aff_site = 'FRE',extp,0))					AS A1FREu
	, (IIF(BT = 1 AND assign_site = 'JAX',extp,0) - IIF(BT = 1 AND aff_site = 'JAX',extp,0))					AS A1JAXu
	, (IIF(BT = 1 AND assign_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0)) * @CRate			AS A1VANc
	, (IIF(BT = 1 AND assign_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0))					AS A1VANu
	, (IIF(BT = 1 AND assign_site = 'PASS',extp,0) - IIF(BT = 1 AND aff_site = 'PASS',extp,0))					AS A1PASu -- 0001
	, (IIF(BT = 2 AND assign_site = 'FRE',extp,0) - IIF(BT = 2 AND aff_site = 'FRE',extp,0))					AS A2FREu
	, (IIF(BT = 2 AND assign_site = 'JAX',extp,0) - IIF(BT = 2 AND aff_site = 'JAX',extp,0))					AS A2JAXu
	, (IIF(BT = 2 AND assign_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0)) * @CRate			AS A2VANc
	, (IIF(BT = 2 AND assign_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0))					AS A2VANu
	, (IIF(BT = 2 AND assign_site = 'PASS',extp,0) - IIF(BT = 2 AND aff_site = 'PASS',extp,0))					AS A2PASu -- 0001
	, (IIF(BT = 3 AND assign_site = 'FRE',extp,0) - IIF(BT = 3 AND aff_site = 'FRE',extp,0))					AS A3FREu
	, (IIF(BT = 3 AND assign_site = 'JAX',extp,0) - IIF(BT = 3 AND aff_site = 'JAX',extp,0))					AS A3JAXu
	, (IIF(BT = 3 AND assign_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0)) * @CRate			AS A3VANc	
	, (IIF(BT = 3 AND assign_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0))					AS A3VANu
	, (IIF(BT = 3 AND assign_site = 'PASS',extp,0) - IIF(BT = 3 AND aff_site = 'PASS',extp,0))					AS A3PASu -- 0001

	, (IIF(BT = 1 AND assign_site = 'FRE',extp,0) - IIF(BT = 1 AND aff_site = 'FRE',extp,0)) * mfg				AS B1FREu
	, (IIF(BT = 1 AND assign_site = 'JAX',extp,0) - IIF(BT = 1 AND aff_site = 'JAX',extp,0)) * mfg				AS B1JAXu
	, (IIF(BT = 1 AND assign_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0)) * mfg * @CRate		AS B1VANc
	, (IIF(BT = 1 AND assign_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0)) * mfg				AS B1VANu
	, (IIF(BT = 1 AND assign_site = 'PASS',extp,0) - IIF(BT = 1 AND aff_site = 'PASS',extp,0)) * mfg			AS B1PASu -- 0001
	, (IIF(BT = 2 AND assign_site = 'FRE',extp,0) - IIF(BT = 2 AND aff_site = 'FRE',extp,0)) * mfg				AS B2FREu
	, (IIF(BT = 2 AND assign_site = 'JAX',extp,0) - IIF(BT = 2 AND aff_site = 'JAX',extp,0)) * mfg				AS B2JAXu
	, (IIF(BT = 2 AND assign_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0)) * mfg * @CRate		AS B2VANc
	, (IIF(BT = 2 AND assign_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0)) * mfg				AS B2VANu
	, (IIF(BT = 2 AND assign_site = 'PASS',extp,0) - IIF(BT = 2 AND aff_site = 'PASS',extp,0)) * mfg			AS B2PASu -- 0001
	, (IIF(BT = 3 AND assign_site = 'FRE',extp,0) - IIF(BT = 3 AND aff_site = 'FRE',extp,0)) * mfg				AS B3FREu
	, (IIF(BT = 3 AND assign_site = 'JAX',extp,0) - IIF(BT = 3 AND aff_site = 'JAX',extp,0)) * mfg				AS B3JAXu
	, (IIF(BT = 3 AND assign_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0)) * mfg * @CRate		AS B3VANc 
	, (IIF(BT = 3 AND assign_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0)) * mfg				AS B3VANu 
	, (IIF(BT = 3 AND assign_site = 'PASS',extp,0) - IIF(BT = 3 AND aff_site = 'PASS',extp,0)) * mfg			AS B3PASu  -- 0001

	, (IIF(BT = 1 AND face_site = 'FRE',extp,0) - IIF(BT = 1 AND aff_site = 'FRE',extp,0))						AS C1FREu
	, (IIF(BT = 1 AND face_site = 'JAX',extp,0) - IIF(BT = 1 AND aff_site = 'JAX',extp,0))						AS C1JAXu
	, (IIF(BT = 1 AND face_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0)) * @CRate				AS C1VANc
	, (IIF(BT = 1 AND face_site = 'VAN',extp,0) - IIF(BT = 1 AND aff_site = 'VAN',extp,0))						AS C1VANu
	, (IIF(BT = 1 AND face_site = 'PASS',extp,0) - IIF(BT = 1 AND aff_site = 'PASS',extp,0))					AS C1PASu -- 0001
	, (IIF(BT = 2 AND face_site = 'FRE',extp,0) - IIF(BT = 2 AND aff_site = 'FRE',extp,0))						AS C2FREu
	, (IIF(BT = 2 AND face_site = 'JAX',extp,0) - IIF(BT = 2 AND aff_site = 'JAX',extp,0))						AS C2JAXu
	, (IIF(BT = 2 AND face_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0)) * @CRate				AS C2VANc
	, (IIF(BT = 2 AND face_site = 'VAN',extp,0) - IIF(BT = 2 AND aff_site = 'VAN',extp,0))						AS C2VANu
	, (IIF(BT = 2 AND face_site = 'PASS',extp,0) - IIF(BT = 2 AND aff_site = 'PASS',extp,0))					AS C2PASu -- 0001
	, (IIF(BT = 3 AND face_site = 'FRE',extp,0) - IIF(BT = 3 AND aff_site = 'FRE',extp,0))						AS C3FREu
	, (IIF(BT = 3 AND face_site = 'JAX',extp,0) - IIF(BT = 3 AND aff_site = 'JAX',extp,0))						AS C3JAXu
	, (IIF(BT = 3 AND face_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0)) * @CRate				AS C3VANc	
	, (IIF(BT = 3 AND face_site = 'VAN',extp,0) - IIF(BT = 3 AND aff_site = 'VAN',extp,0))						AS C3VANu
	, (IIF(BT = 3 AND face_site = 'PASS',extp,0) - IIF(BT = 3 AND aff_site = 'PASS',extp,0))					AS C3PASu -- 0001

	, (IIF(BT = 1 AND face_site = 'FRE',extp-ppb,0) - IIF(BT = 1 AND aff_site = 'FRE',extp-ppb,0))				AS D1FREu
	, (IIF(BT = 1 AND face_site = 'JAX',extp-ppb,0) - IIF(BT = 1 AND aff_site = 'JAX',extp-ppb,0))				AS D1JAXu
	, (IIF(BT = 1 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 1 AND aff_site = 'VAN',extp-ppb,0)) * @CRate		AS D1VANc
	, (IIF(BT = 1 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 1 AND aff_site = 'VAN',extp-ppb,0))				AS D1VANu
	, (IIF(BT = 1 AND face_site = 'PASS',extp-ppb,0) - IIF(BT = 1 AND aff_site = 'PASS',extp-ppb,0))			AS D1PASu -- 0001
	, (IIF(BT = 2 AND face_site = 'FRE',extp-ppb,0) - IIF(BT = 2 AND aff_site = 'FRE',extp-ppb,0))				AS D2FREu
	, (IIF(BT = 2 AND face_site = 'JAX',extp-ppb,0) - IIF(BT = 2 AND aff_site = 'JAX',extp-ppb,0))				AS D2JAXu
	, (IIF(BT = 2 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 2 AND aff_site = 'VAN',extp-ppb,0)) * @CRate		AS D2VANc
	, (IIF(BT = 2 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 2 AND aff_site = 'VAN',extp-ppb,0))				AS D2VANu
	, (IIF(BT = 2 AND face_site = 'PASS',extp-ppb,0) - IIF(BT = 2 AND aff_site = 'PASS',extp-ppb,0))			AS D2PASu -- 0001
	, (IIF(BT = 3 AND face_site = 'FRE',extp-ppb,0) - IIF(BT = 3 AND aff_site = 'FRE',extp-ppb,0))				AS D3FREu
	, (IIF(BT = 3 AND face_site = 'JAX',extp-ppb,0) - IIF(BT = 3 AND aff_site = 'JAX',extp-ppb,0))				AS D3JAXu
	, (IIF(BT = 3 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 3 AND aff_site = 'VAN',extp-ppb,0)) * @CRate		AS D3VANc	
	, (IIF(BT = 3 AND face_site = 'VAN',extp-ppb,0) - IIF(BT = 3 AND aff_site = 'VAN',extp-ppb,0))				AS D3VANu
	, (IIF(BT = 3 AND face_site = 'PASS',extp-ppb,0) - IIF(BT = 3 AND aff_site = 'PASS',extp-ppb,0))			AS D3PASu -- 0001
-- #0002 DMS BEGIN	
	, coi.Uf_PromiseDate 
	, js.end_date 'sch_last_ship_date'
-- #0002 DMS END
	FROM #RSBacklog rs
		LEFT JOIN prodcode_all pc
			ON pc.site_ref = rs.face_site AND pc.product_code = rs.product_code
		LEFT JOIN _IEM_UnitMargin mu
			ON mu.UnitCode2 = pc.unit
		LEFT JOIN item_all ia
			ON ia.site_ref = rs.face_site AND ia.item = rs.item
		LEFT JOIN co_all coa
			ON coa.co_num = rs.co_num
		LEFT JOIN custaddr ca
			ON ca.cust_num = coa.cust_num AND ca.cust_seq = 0
-- #0002 DMS BEGIN
		LEFT JOIN coitem_all coi
			ON coi.co_num  = rs.co_num AND coi.co_line = rs.co_line AND coi.co_release = 0  
		LEFT JOIN job_mst j 
			ON j.ord_num = coi.co_num AND j.ord_line = coi.co_line AND j.ord_release = coi.co_release and ord_type = 'O'
        LEFT JOIN job_sch_mst js 
			ON js.job = j.job AND js.suffix = j.suffix
-- #0002 DMS END
		WHERE ISNULL(rs.extp,0) - ISNULL(rs.ppb,0) <> 0 OR ISNULL(rs.extp,0) <> 0
			ORDER BY co_num, co_line

--INSERT INTO _IEM_Debug SELECT 'BLL FB: ' + CONVERT(NVARCHAR(23), GETDATE(), 121)

END

GO

