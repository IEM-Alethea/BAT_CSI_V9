SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[_IEM_Rpt_WIPValuationSp]

		  @JobStart					JobType = NULL
		, @JobEnd					JobType = NULL
		, @SuffixStart				SuffixType = NULL
		, @SuffixEnd				SuffixType = NULL
		, @JobSuffixList			NVARCHAR(1000) = NULL
		, @CategoryStart			ProductCodeType = NULL
		, @CategoryEnd				ProductCodeType = NULL
		, @RptSite					SiteType = 'All'
		, @MasterList				ListYesNoType = 1
		, @DetailTabs				ListYesNoType = 0
		, @SummaryTab				ListYesNoType = 0
		, @ShowCosts				ListYesNoType = 1
		, @ShowHours				ListYesNoType = 0
		, @JobVar					NVARCHAR(10) = NULL

AS

BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL

DECLARE
		  @RptSessionID				RowPointerType

EXEC dbo.InitSessionContextSp
     @ContextName = '_IEM_Rpt_WIPValuationSp'
   , @SessionID   = @RptSessionID OUTPUT
   , @Site        = @Site

DECLARE @ReportSet TABLE (

	  job						JobType
	, suffix					SuffixType
	, item						ItemType
	, description				DescriptionType
	, category					ProductCodeType
	, product_code				ProductCodeType
	, PC_description			DescriptionType
	, qty_released				QtyUnitType
	, qty_complete				QtyUnitType
	, Bin_Bulk_Matl				AmountType
	, Purchased_Matl			AmountType
	, SubAssy_Matl				AmountType
	, wip_matl_total			AmountType
	, Eng_labor_amt				AmountType
	, Eng_labor_hrs				TotalHoursType
	, Fab_labor_amt				AmountType
	, Fab_labor_hrs				TotalHoursType
	, Production_labor_amt		AmountType
	, Production_labor_hrs		TotalHoursType
	, wip_labor_total			AmountType
	, wip_total					AmountType
	, wip_complete				AmountType
	, wip_remaining				AmountType
	, Latest_WkCtr				NVARCHAR(100)
	, job_date					DATETIME
	, job_start_date			DATETIME
	, job_end_date				DATETIME
	, lst_trx_date				DATETIME
	)

IF @JobStart		= 'NULL' SET @JobStart = NULL
IF @JobEnd			= 'NULL' SET @JobEnd   = NULL
IF @SuffixStart		= 11111  SET @SuffixStart = NULL
IF @SuffixEnd		= 11111  SET @SuffixEnd = NULL
IF @JobSuffixList	= 'NULL' SET @JobSuffixList = NULL
IF @JobVar			= 'NULL' SET @JobVar = NULL

-- This section establishes all the job / suffix combos to process

IF OBJECT_ID('tempdb.dbo.#JobSuffix', 'U') IS NOT NULL
  DROP TABLE #JobSuffix; 

SELECT job, suffix
	INTO #JobSuffix
		FROM job
			WHERE 1 = 0

INSERT INTO #JobSuffix
	SELECT job, suffix
		FROM job
			WHERE job BETWEEN ISNULL(@JobStart,job) AND ISNULL(@JobEnd,job)
			  AND suffix BETWEEN ISNULL(@SuffixStart,suffix) AND ISNULL(@SuffixEnd,suffix)
			  AND type = 'J' AND stat = 'R' AND wip_total <> 0

-- End #JobSuffix section

DECLARE @WC TABLE ( --Table of work centers and associated assigned categories

	  wc						WcType
	, wc_rank					INT
	, wc_rank2					INT
	, category					ProductCodeType
	)

INSERT INTO @WC VALUES

	  ('R&D'   , 0, 0, 'UNS')
	, ('ENGDES', 1, 0, 'ENG')
	, ('ENGDRA', 1, 0, 'ENG')
	, ('ENGPRG', 1, 0, 'ENG')
	, ('ENGSUP', 1, 0, 'ENG')
	, ('ENGTST', 1, 0, 'ENG')
	, ('ENGWIR', 1, 0, 'ENG')
	, ('RWKENG', 1, 0, 'ENG')
	, ('RWKWEN', 1, 0, 'ENG')
	, ('DESBUS', 2, 0, 'ENG')
	, ('DESMET', 2, 0, 'ENG')
	, ('BUSFAB', 3, 3, 'FAB')
	, ('ISUMET', 3, 3, 'FAB')
	, ('MTLFAB', 3, 3, 'FAB')
	, ('PAINTL', 3, 3, 'FAB')
	, ('ISUMAT', 4, 4, 'ISS')
	, ('OUTSID', 4, 4, 'ISS')
	, ('PREREL', 4, 4, 'ISS')
	, ('RWKMAT', 4, 4, 'ISS')
	, ('FRAME' , 5, 4, 'PC' )
	, ('STRUCT', 6, 4, 'PC' )
	, ('DOOR'  , 6, 4, 'PC' )
	, ('LVASSY', 6, 4, 'PC' )
	, ('MVSTD' , 6, 4, 'PC' )
	, ('MVVEST', 6, 4, 'PC' )
	, ('PANELS', 6, 4, 'PC' )
	, ('RWKMFG', 6, 4, 'PC' )
	, ('RWKSUB', 6, 4, 'PC' )
	, ('RWKWFG', 6, 4, 'PC' )
	, ('SHOPMA', 6, 4, 'PC' )
	, ('SUBPL' , 6, 4, 'PC' )
	, ('WIRE'  , 6, 4, 'PC' )
	, ('CLOSUP', 7, 4, 'PC' )
	, ('QC'    , 7, 4, 'PC' )
	, ('STAGE' , 8, 4, 'PC' )
	, ('FSPS'  , 9, 4, 'PC' )
	, ('FSSE'  , 9, 4, 'PC' )
	, ('FSSI'  , 9, 4, 'PC' )
	, ('FSSR'  , 9, 4, 'PC' )
	, ('FSST'  , 9, 4, 'PC' )
	, ('FSSU'  , 9, 4, 'PC' )
	, ('FSWTY' , 9, 4, 'PC' )

; WITH MB
	AS (
		SELECT jm.job, jm.suffix, SUM(jm.a_cost) AS costB
			FROM jobmatl jm
				LEFT JOIN item i
					ON i.item = jm.item
				WHERE LEFT(i.product_code,1) = 'B'
					GROUP BY jm.job, jm.suffix
		)

, MP
	AS (
		SELECT jm.job, jm.suffix, SUM(jm.a_cost) AS costP
			FROM jobmatl jm
				LEFT JOIN item i
					ON i.item = jm.item
				WHERE LEFT(i.product_code,1) = 'P'
					GROUP BY jm.job, jm.suffix
		)

, MO
	AS (
		SELECT jm.job, jm.suffix, SUM(jm.a_cost) AS costO
			FROM jobmatl jm
				LEFT JOIN item i
					ON i.item = jm.item
				WHERE ISNULL(LEFT(i.product_code,1),'') NOT IN ('B','P')
					GROUP BY jm.job, jm.suffix
		)

, LE
	AS (
		SELECT jr.job, jr.suffix, wc_rank2,
				SUM(fixovhd_t_lbr + varovhd_t_lbr) AS labor_amt_E,
				SUM(run_hrs_t_lbr) AS labor_hrs_E
			FROM jobroute jr
				JOIN @WC wc
					ON wc.wc = jr.wc
				WHERE wc_rank2 = 0
					GROUP BY jr.job, jr.suffix, wc_rank2
		)

, LF
	AS (
		SELECT jr.job, jr.suffix, wc_rank2,
				SUM(fixovhd_t_lbr + varovhd_t_lbr) AS labor_amt_F,
				SUM(run_hrs_t_lbr) AS labor_hrs_F
			FROM jobroute jr
				JOIN @WC wc
					ON wc.wc = jr.wc
				WHERE wc_rank2 = 3
					GROUP BY jr.job, jr.suffix, wc_rank2
		)

, LP
	AS (
		SELECT jr.job, jr.suffix, wc_rank2,
				SUM(fixovhd_t_lbr + varovhd_t_lbr) AS labor_amt_P,
				SUM(run_hrs_t_lbr) AS labor_hrs_P
			FROM jobroute jr
				JOIN @WC wc
					ON wc.wc = jr.wc
				WHERE wc_rank2 = 4
					GROUP BY jr.job, jr.suffix, wc_rank2
		)

INSERT INTO @ReportSet (
	  job				
	, suffix			
	, item				
	, description		
	, category			
	, product_code		
	, PC_description	
	, qty_released		
	, qty_complete		
	, Bin_Bulk_Matl		
	, Purchased_Matl	
	, SubAssy_Matl		
	, wip_matl_total	
	, Eng_labor_amt			
	, Eng_labor_hrs			
	, Fab_labor_amt			
	, Fab_labor_hrs			
	, Production_labor_amt
	, Production_labor_hrs
	, wip_labor_total	
	, wip_total			
	, wip_complete		
	, wip_remaining
	, Latest_WkCtr
	, job_date
	, job_start_date
	, job_end_date
	, lst_trx_date
	)	

	SELECT
	  LTRIM(j.job) AS job
	, j.suffix
	, j.item
	, REPLACE(i.description,CHAR(10),' ')
	, NULL
	, i.product_code, pc.description
	, j.qty_released
	, j.qty_complete
	, ISNULL(mb.costB,0)
	, ISNULL(mp.costP,0)
	, ISNULL(mo.costO,0)
	, j.wip_matl_total
	, ISNULL(le.labor_amt_E,0)
	, ISNULL(le.labor_hrs_E,0)
	, ISNULL(lf.labor_amt_F,0)
	, ISNULL(lf.labor_hrs_F,0)
	, ISNULL(lp.labor_amt_P,0)
	, ISNULL(lp.labor_hrs_P,0)
	, j.wip_fovhd_total + j.wip_vovhd_total
	, j.wip_total
	, j.wip_complete
	, j.wip_total - j.wip_complete
	, NULL
	, j.CreateDate
	, jsch.start_date
	, jsch.end_date
	, j.lst_trx_date
		FROM job j
			LEFT JOIN item i
				ON i.item = j.item
			LEFT JOIN prodcode pc
				ON pc.product_code = i.product_code
			LEFT JOIN MB mb
				ON mb.job = j.job AND mb.suffix = j.suffix
			LEFT JOIN MP mp
				ON mp.job = j.job AND mp.suffix = j.suffix
			LEFT JOIN MO mo
				ON mo.job = j.job AND mo.suffix = j.suffix
			LEFT JOIN LE le
				ON le.job = j.job AND le.suffix = j.suffix
			LEFT JOIN LF lf
				ON lf.job = j.job AND lf.suffix = j.suffix
			LEFT JOIN LP lp
				ON lp.job = j.job AND lp.suffix = j.suffix
			JOIN #JobSuffix js
				ON js.job = j.job AND js.suffix = j.suffix
			JOIN job_sch jsch
				ON jsch.job = j.job AND jsch.suffix = j.suffix

; WITH CAT
	AS (
		SELECT rs.job, rs.suffix, jr.wc, wc.wc_rank, wc.category
			FROM @ReportSet rs
				JOIN jobroute jr
					ON jr.job = rs.job AND jr.suffix = rs.suffix
				JOIN @WC wc
					ON wc.wc = jr.wc
			WHERE jr.wip_amt <> 0
		)
, CATMax
	AS (
		SELECT job, suffix, MAX(wc_rank) AS wc_rank
			FROM CAT
				GROUP BY job, suffix
		)

, CATcat
	AS (
		SELECT DISTINCT cm.job, cm.suffix, c.category
			FROM CATMax cm
				JOIN CAT c
					ON c.job = cm.job AND c.suffix = cm.suffix AND c.wc_rank = cm.wc_rank
		)

, CATwc
	AS (
		SELECT cm.job, cm.suffix, c.wc
			FROM CATMax cm
				JOIN CAT c
					ON c.job = cm.job AND c.suffix = cm.suffix AND c.wc_rank = cm.wc_rank
		)

, CATwc1
	AS (
		SELECT DISTINCT job, suffix, 
			STUFF((
				SELECT ' / ' +	wc
				FROM CATwc cwc2
					WHERE cwc2.job = cwc.job AND cwc2.suffix = cwc.suffix
				ORDER BY cwc2.job, cwc2.suffix
					FOR XML PATH('')), 1, 3, '') AS wc
			FROM CATwc cwc
		)

UPDATE rs
	SET category = CASE
					WHEN cc.category IS NULL OR rs.product_code = 'M9999' THEN 'UNS'
					WHEN cc.category = 'PC' THEN rs.product_code
					ELSE cc.category END,
		Latest_WkCtr = ISNULL(cwc.wc,'')
			FROM @ReportSet rs
				LEFT JOIN CATcat cc
					ON cc.job = rs.job AND cc.suffix = rs.suffix
				LEFT JOIN CATwc1 cwc
					ON cwc.job = rs.job AND cwc.suffix = rs.suffix

SELECT	  rs.*
		, LTRIM(co.co_num) AS co_num
		, co.stat AS co_stat
		, co.cust_num
		, ca.name
		, coi.co_line
		, coi.qty_ordered
		, coi.qty_shipped
		, coi.stat
	FROM @ReportSet rs
		LEFT JOIN co
			ON co.co_num = rs.job
		LEFT JOIN custaddr ca
			ON ca.cust_num = co.cust_num AND ca.cust_seq = 0
		LEFT JOIN coitem coi
			ON coi.co_num = co.co_num AND coi.co_line = rs.suffix
		WHERE category BETWEEN ISNULL(@CategoryStart,category) AND ISNULL(@CategoryEnd,category)
				AND product_code <> 'Z9000' -- Excludes all R&D items
			ORDER BY category, product_code, item

END

GO

