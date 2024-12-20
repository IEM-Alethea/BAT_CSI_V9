SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/**********************************************************************************
*                            Modification Log
*                                            
* Ref#  Init   Date     Description           
* ----- ----   -------- -----------------------------------------------------------
* 0001	DMS	   20242304 New columns added for OTD and support for Revenue Sites
**********************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_Rpt_Shipping_ReportSp]

	  @sraa_InputDateS					DATE = NULL
	, @sraa_InputDateE					DATE = NULL
	, @sraa_ReportType					NVARCHAR(50)
	, @sraa_IncludeShipped				BIT = 0
	, @site								NVARCHAR(50) = 'All'
	, @ProdCode							NVARCHAR(50)
	, @ProdCodeList						NVARCHAR(1000)
	, @sraa_IncludeAffiliated			BIT = 0
	, @sraa_IncludeJobs					BIT = 0
	, @LoadTempTable                    BIT = 0

AS

DECLARE	  @sraa_StartDate				DATE
		, @sraa_EndDate					DATE
		, @sraa_InputDateX				DATE
		, @sraa_ReportRange				NVARCHAR(45)
		, @pSite						SiteType
		, @RptSessionID					RowPointerType
		, @PCL							NVARCHAR(1000)
		, @BarLoc						INT
		, @ExchEffDate			DATE
		, @ExchRate				AmountType

DECLARE @PCLTable TABLE (
		  ProdCode						ProductCodeType
		  )

DECLARE @PCLGroupTable TABLE (
		  ProdCode						ProductCodeType
		, ProdCodeGroup					NVARCHAR(100)
		  )

   EXEC dbo.InitSessionContextSp
     @ContextName = '_IEM_Rpt_Shipping_ReportSp'
   , @SessionID   = @RptSessionID OUTPUT
   , @Site        = @pSite


IF OBJECT_ID('tempdb..#ResultSet') IS NULL  BEGIN

	CREATE TABLE #ResultSet
	(
		  [Start Date] DATE
		, [End Date] DATE
		, [site_ref] NVARCHAR(8)
		, [Uf_assign_site] NVARCHAR(8)
		, [Ext Price] DECIMAL(23,8)
		, [Ship Date] DATE
		, [Date Type] VARCHAR(3)
		, [Promised] DATE
		, [Requested] DATE
		, [Due] DATE
		, [Shipped] DATE
		, [Order ID] NVARCHAR(10)
		, [Order Line] SMALLINT
		, [Customer] NVARCHAR(22)
		, [Item ID] NVARCHAR(30)
		, [Qty] DECIMAL(23,8)
		, [Price] DECIMAL(23,8)
		, [product_code] NVARCHAR(10)
		, [ProdCodeGroup] NVARCHAR(100)
		, [exch_rate] DECIMAL(23,8)
		, [exch_eff_date] DATE
		, [SectionCount] INTEGER -- 0001 DMS	 
		, [ItemCategory] NVARCHAR(100) -- 0001 DMS
	)
END


BEGIN

	IF @site = 'All' OR @site IS NULL
		BEGIN
			SET @site = (SELECT TOP 1
							STUFF((SELECT '' + s2.site
								FROM site s2
									WHERE Uf_mfg = 1 OR Uf_Revenue = 1 -- 0001 DMS 
										FOR XML PATH('')), 1, 0, '') AS s
							FROM site s1)
		END

SET @PCL = @ProdCodeList

IF @ProdCodeList IS NOT NULL AND @ProdCodeList <> '' AND @ProdCode = 'User Selection'
	BEGIN
		WHILE @PCL <> ''
			BEGIN
				SET @BarLoc = CHARINDEX('|',@PCL)
					INSERT INTO @PCLTable
							SELECT LEFT(@PCL,@BarLoc-1)
				SET @PCL = RIGHT(@PCL,LEN(@PCL)-@BarLoc)	
			END
	END
ELSE IF @ProdCode IS NULL OR @ProdCode = 'User Selection'
	BEGIN
		INSERT INTO @PCLTable
			SELECT DISTINCT product_code
				FROM prodcode_all
	END
ELSE 
	BEGIN
		INSERT INTO @PCLGroupTable
			EXEC [_IEM_CLM_ProductCodeGroupingsSp] 'ShippingReportPcodeGroupMap', @ProdCode
		INSERT INTO @PCLTable
			SELECT ProdCode
				FROM @PCLGroupTable
					WHERE ProdCodeGroup = @ProdCode
	END

DELETE @PCLGroupTable
INSERT INTO @PCLGroupTable
	EXEC [_IEM_CLM_ProductCodeGroupingsSp] 'ShippingReportPcodeGroupMap', @ProdCode

	IF @sraa_InputDateS IS NULL SET @sraa_InputDateS = GETDATE()
	IF @sraa_InputDateE IS NULL SET @sraa_InputDateE = GETDATE()
	
	SET @sraa_ReportRange = RIGHT(@sraa_ReportType,LEN(@sraa_ReportType)-CHARINDEX('-',@sraa_ReportType)-1)

	IF @sraa_InputDateS > @sraa_InputDateE
		BEGIN
			SET @sraa_InputDateX = @sraa_InputDateE
			SET @sraa_InputDateE = @sraa_InputDateS
			SET @sraa_InputDateS = @sraa_InputDateX
		END

	SET @sraa_StartDate =
	CASE
		WHEN @sraa_ReportRange = 'Date Range'
			THEN @sraa_InputDateS
		WHEN @sraa_ReportRange = 'Prior Week'
			THEN DATEADD(DAY,(-6-DATEPART(Dw,@sraa_InputDateS)),@sraa_InputDateS)
		WHEN @sraa_ReportRange = 'Current Week'
			THEN DATEADD(DAY,(1-DATEPART(Dw,@sraa_InputDateS)),@sraa_InputDateS)
		WHEN @sraa_ReportRange = 'Prior Month'
			THEN DATEADD(DAY,1,EOMONTH(@sraa_InputDateS,-2))
		WHEN @sraa_ReportRange = 'Current Month'
			THEN DATEADD(DAY,1,EOMONTH(@sraa_InputDateS,-1))
		WHEN @sraa_ReportRange = '(Partial) Last Week Prior Month'
			THEN DATEADD(DAY,1-DATEPART(Dw,EOMONTH(@sraa_InputDateS,-1)),EOMONTH(@sraa_InputDateS,-1))
		WHEN @sraa_ReportRange = '(Partial) First Week Current Month'
			THEN DATEADD(DAY,1,EOMONTH(@sraa_InputDateS,-1))
		WHEN @sraa_ReportRange = '(Partial) Last Week Current Month'
			THEN DATEADD(DAY,1-DATEPART(Dw,EOMONTH(@sraa_InputDateS)),EOMONTH(@sraa_InputDateS))
		WHEN @sraa_ReportRange = 'Today'
			THEN GETDATE()
		WHEN @sraa_ReportRange = 'Tomorrow'
			THEN DATEADD(DAY,1,GETDATE())
		ELSE @sraa_InputDateS
	END
	   
	SET @sraa_EndDate = 
		CASE
			WHEN @sraa_ReportRange = 'Date Range'
				THEN @sraa_InputDateE
			WHEN @sraa_ReportRange = 'Prior Week'
				THEN DATEADD(DAY,(-DATEPART(Dw,@sraa_InputDateS)),@sraa_InputDateS)
			WHEN @sraa_ReportRange = 'Current Week'
				THEN DATEADD(DAY,(7-DATEPART(Dw,@sraa_InputDateS)),@sraa_InputDateS)
			WHEN @sraa_ReportRange = 'Prior Month'
				THEN EOMONTH(@sraa_InputDateS,-1)
			WHEN @sraa_ReportRange = 'Current Month'
				THEN EOMONTH(@sraa_InputDateS)
			WHEN @sraa_ReportRange = '(Partial) Last Week Prior Month'
				THEN EOMONTH(@sraa_InputDateS,-1)
			WHEN @sraa_ReportRange = '(Partial) First Week Current Month'
				THEN DATEADD(DAY,8-DATEPART(Dw,DATEADD(DAY,1,EOMONTH(@sraa_InputDateS,-1))),EOMONTH(@sraa_InputDateS,-1))
			WHEN @sraa_ReportRange = '(Partial) Last Week Current Month'
				THEN EOMONTH(@sraa_InputDateS)
			WHEN @sraa_ReportRange = 'Today'
				THEN GETDATE()
			WHEN @sraa_ReportRange = 'Tomorrow'
				THEN CASE
					WHEN DATEPART(Dw,GETDATE()) = 6 THEN DATEADD(DAY,3,GETDATE())
					WHEN DATEPART(Dw,GETDATE()) = 7 THEN DATEADD(DAY,2,GETDATE())
					ELSE DATEADD(DAY,1,GETDATE())
				END
			ELSE @sraa_InputDateE
		END

SELECT	  @ExchRate = buy_rate
		, @ExchEffDate = eff_date
	FROM currate
		WHERE	from_curr_code = 'USD'
				AND to_curr_code = 'CAD'
				AND eff_date = (SELECT MAX(eff_date) FROM currate WHERE from_curr_code = 'USD' AND to_curr_code = 'CAD'
								AND eff_date <= @sraa_EndDate)

  IF LEFT(@sraa_ReportType,3) = 'Act'  --Determining actual (vs projected) -- Begin comment out portion 1 to refresh dataset

  BEGIN
    
	IF EXISTS(SELECT * FROM co_ship_all csa
					JOIN coitem_all coia ON coia.co_num = csa.co_num AND coia.co_line = csa.co_line
					JOIN item_all i ON i.site_ref = csa.site_ref AND i.item = coia.item
					JOIN @PCLTable pclt ON pclt.ProdCode = i.product_code
				WHERE csa.Ship_Date >= @sraa_StartDate
				AND CAST(csa.Ship_Date AS DATE) <= @sraa_EndDate) --CHECKING FOR ZERO RECORDS
	   
 	BEGIN --  -- End comment out portion 1 to refresh dataset

	  
	  insert #ResultSet
	  SELECT 
	     @sraa_StartDate AS 'Start Date',
         @sraa_EndDate AS 'End Date',
		 csa.site_ref,
		 ISNULL(coia.Uf_assign_site,csa.site_ref) AS Uf_assign_site,
  	     csa.qty_shipped * coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.000000) AS "Ext Price",
	     CAST(csa.Ship_Date AS DATE) AS "Ship Date",
	     'ACT' AS "Date Type",
	     CAST(coia.Uf_PromiseDate AS DATE) AS "Promised",
		 CAST(coia.promise_date AS DATE) AS "Requested",
		 CAST(coia.due_date AS DATE) AS "Due",
  		 CAST(coia.Ship_Date AS DATE) AS "Shipped",
	     ltrim(csa.co_num) AS "Order ID",
	     csa.co_line AS "Order Line",
	     CONCAT(ca.cust_num, ' / ', LEFT(ca.name,12)) AS "Customer",
	     coia.item AS "Item ID",
	     csa.qty_shipped * 1.000 AS "Qty",
	     coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.000000) AS "Price",
		 ia.product_code,
		 pclgt.ProdCodeGroup,
		 @ExchRate AS exch_rate,
		 @ExchEffDate AS exch_eff_date,
		 ISNULL(coia.Uf_numSections,0) AS "SectionCount", -- 0001 DMS 'section_count'
		 (SELECT TOP 1 ici.item_category FROM item_category_item ici
										JOIN item_category ic ON ic.item_category = ici.item_category 
										WHERE ic.active = 1 
											AND ici.item = coia.item
										ORDER BY ici.CreateDate Desc) AS "item_category"-- 0001 DMS 'item_category'
	  FROM co_ship_all as csa
		LEFT JOIN coitem_all coia
		  ON csa.site_ref = coia.site_ref AND coia.co_num = csa.co_num AND coia.co_line = csa.co_line
		LEFT JOIN co_all coa
		  ON csa.site_ref = coa.site_ref AND csa.co_num = coa.co_num
		LEFT JOIN custaddr AS ca
		  ON coa.cust_num = ca.cust_num AND coa.cust_seq = ca.cust_seq
		LEFT JOIN customer_all cua
		  ON coa.site_ref = cua.site_ref AND coa.cust_num = cua.cust_num AND cua.cust_seq = 0
		LEFT JOIN item_all ia
		  ON ia.site_ref = coia.site_ref AND ia.item = coia.item
		JOIN @PCLTable pclt
			ON pclt.ProdCode = ia.product_code
		LEFT JOIN @PCLGroupTable pclgt
			ON pclgt.ProdCode = ia.product_code

	  WHERE csa.Ship_Date >= @sraa_StartDate
	        AND CAST(csa.Ship_Date AS DATE) <= @sraa_EndDate
			AND CHARINDEX(ISNULL(coia.Uf_assign_site,csa.site_ref),@site) > 0
			AND (ISNULL(cua.cust_type,'') NOT BETWEEN 9990 AND 9998 OR @sraa_IncludeAffiliated = 1)

--	    ORDER BY ISNULL(coia.Uf_assign_site,coia.site_ref), ISNULL(coia.Due_Date,coia.Promise_Date), CAST(coia.co_num AS INT), coia.co_line


		if @LoadTempTable = 0
			select * from #ResultSet
			ORDER BY Uf_assign_site, ISNULL(Due,Promised), CAST(IIF(ISNUMERIC("Order ID") = 1, "Order ID", 0) AS INT), "Order Line"

    END   -- Begin comment out portion 2 to refresh dataset

	ELSE
	
      SELECT @sraa_StartDate AS 'Start Date',
             @sraa_EndDate AS 'End Date'

	END
	
  ELSE --Determining projected (vs actual)

  BEGIN

	IF ISNULL(@sraa_IncludeShipped,0) = 0
	    --0 --> do not include sales projected within the date range that have shipped complete
		
	BEGIN
		  
  	  IF EXISTS(SELECT * FROM coitem_all coia
						JOIN item_all i ON i.site_ref = coia.site_ref AND i.item = coia.item
						JOIN @PCLTable pclt ON pclt.ProdCode = i.product_code					
				  WHERE COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) >= @sraa_StartDate
	          AND CAST(COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) <= @sraa_EndDate 
			  AND coia.qty_ordered > coia.qty_shipped) --CHECKING FOR ZERO RECORDS

	  BEGIN
	
	    insert #ResultSet
		SELECT * FROM (  
	    SELECT 
	       @sraa_StartDate AS 'Start Date',
           @sraa_EndDate AS 'End Date',
		   coia.site_ref,
		   ISNULL(coia.Uf_assign_site,coia.site_ref) AS Uf_assign_site,
	       coia.qty_ordered * coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.000000) AS "Ext Price",
	       CAST(COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) AS "Ship Date",
	       CASE WHEN coia.Due_date IS NULL THEN
		     CASE WHEN coia.Uf_PromiseDate IS NULL THEN 'REQ' ELSE 'PRM' END
			 ELSE 'DUE'
	       END AS "Date Type",
 	       CAST(coia.Uf_PromiseDate AS DATE) AS "Promised",
		   CAST(coia.promise_date AS DATE) AS "Requested",
		   CAST(coia.due_date AS DATE) AS "Due",
  		   CASE WHEN coia.qty_ordered > coia.qty_shipped AND coia.qty_shipped > 0 THEN  CAST('1775-11-10' AS DATE)
		                                                                   --REPORT WILL TRANSLATE THIS DATE AS "PARTIAL"
			 ELSE CAST(coia.Ship_Date AS DATE)
			 END AS "Shipped",
	       CAST(LTRIM(coia.co_num) AS NVARCHAR(10)) AS "Order ID",
	       coia.co_line AS "Order Line",
	       CONCAT(ca.cust_num, ' / ', LEFT(ca.name,12)) AS "Customer",
	       coia.item AS "Item ID",
	       coia.qty_ordered * 1.000 AS "Qty",
	       coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.000000) AS "Price",
		   ia.product_code,
		   pclgt.ProdCodeGroup,
		   @ExchRate AS exch_rate,
		   @ExchEffDate AS exch_eff_date,
		   ISNULL(coia.Uf_numSections,0) AS "SectionCount", -- 0001 DMS 'section_count'
		   (SELECT TOP 1 ici.item_category FROM item_category_item ici
										JOIN item_category ic ON ic.item_category = ici.item_category 
										WHERE ic.active = 1 
											AND ici.item = coia.item
										ORDER BY ici.CreateDate Desc) AS "item_category" -- 0001 DMS 'item_category'
	   
	    FROM coitem_all coia
		  LEFT JOIN co_all coa
		    ON coia.site_ref = coa.site_ref AND coia.co_num = coa.co_num
		  LEFT JOIN custaddr ca
		    ON ca.cust_num = coa.cust_num AND ca.cust_seq = coa.cust_seq
		  LEFT JOIN customer_all cua
			ON coa.site_ref = cua.site_ref AND coa.cust_num = cua.cust_num AND cua.cust_seq = 0
		  LEFT JOIN item_all ia
			ON ia.site_ref = coia.site_ref AND ia.item = coia.item
	   	  JOIN @PCLTable pclt
			ON pclt.ProdCode = ia.product_code
		  LEFT JOIN @PCLGroupTable pclgt
			ON pclgt.ProdCode = ia.product_code

	    WHERE COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) >= @sraa_StartDate
		      AND CAST(COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) <= @sraa_EndDate
			  AND (coia.qty_ordered > coia.qty_shipped OR (coia.qty_ordered = 0 AND coia.Ship_Date IS NULL))
			  AND CHARINDEX(ISNULL(coia.Uf_assign_site,coia.site_ref),@site) > 0
			  AND (ISNULL(cua.cust_type,'') NOT BETWEEN 9990 AND 9998 OR @sraa_IncludeAffiliated = 1)

	  UNION

		SELECT    @sraa_StartDate AS 'Start Date'
				, @sraa_EndDate AS 'End Date'
				, jsa.site_ref
				, RIGHT(jsa.job,3) AS Uf_assign_site
				, NULL AS "Ext Price"
				, jsa.end_date AS "Ship Date"
				, 'JOB' AS "Date_Type"
				, NULL AS "Promised"
				, NULL AS "Requested"
				, NULL AS "Due"
				, NULL AS "Shipped"
				, jsa.job AS "Order ID"
				, jsa.suffix AS "Order Line"
				, CONCAT(coa.cust_num, ' / ', LEFT(ca.name,12)) AS "Customer"
				, coia.item AS "Item ID"
				, coia.qty_ordered * 1.000 AS "Qty"
				, NULL AS "Price"
				, ia.product_code
				, ISNULL(ja.Uf_SchedGroup,pclgt.ProdCodeGroup)
				, @ExchRate AS exch_rate
				, @ExchEffDate AS exch_eff_date
				, ISNULL(coia.Uf_numSections,0) AS "SectionCount" -- 0001 DMS 'section_count'
				, (SELECT TOP 1 ici.item_category FROM item_category_item ici
										JOIN item_category ic ON ic.item_category = ici.item_category 
										WHERE ic.active = 1 
											AND ici.item = coia.item
										ORDER BY ici.CreateDate Desc) AS "item_category"-- 0001 DMS 'item_category'
	  
	  	FROM job_sch_all jsa
	  		LEFT JOIN coitem_all coia
	  			ON LTRIM(coia.co_num) = REPLACE(REPLACE(REPLACE(jsa.job,'FRE',''),'JAX',''),'VAN','') AND coia.co_line = jsa.suffix
	  		LEFT JOIN co_all coa
	  			ON coa.co_num = coia.co_num
	  		LEFT JOIN custaddr ca
	  			ON ca.cust_num = coa.cust_num AND ca.cust_seq = coa.cust_seq
			LEFT JOIN customer_all cua
				ON coa.site_ref = cua.site_ref AND coa.cust_num = cua.cust_num AND cua.cust_seq = 0
	  		LEFT JOIN item_all ia
	  			ON ia.item = coia.item
			LEFT JOIN job_all ja
				ON ja.job = jsa.job AND ja.suffix = jsa.suffix
	   	    LEFT JOIN @PCLTable pclt
			  ON pclt.ProdCode = ia.product_code
			LEFT JOIN @PCLGroupTable pclgt
			  ON pclgt.ProdCode = ia.product_code

	  		WHERE jsa.end_date >= @sraa_StartDate
				AND CAST(jsa.end_date AS DATE) <= @sraa_EndDate
				AND RIGHT(jsa.job,3) IN ('FRE','JAX','VAN')
				AND RIGHT(coia.Uf_assign_site,3) <> RIGHT(jsa.job,3)
				AND ja.stat = 'R'
				AND CHARINDEX(jsa.site_ref,@site) > 0
				AND (ISNULL(cua.cust_type,'') NOT BETWEEN 9990 AND 9998 OR @sraa_IncludeAffiliated = 1)
				AND (pclt.ProdCode IS NOT NULL OR ja.Uf_SchedGroup = @ProdCode)
				AND @sraa_IncludeJobs = 1) r

--	  ORDER BY ISNULL(Uf_assign_site,site_ref), site_ref, ISNULL("Due","Promised")
--			, CAST(REPLACE(REPLACE(REPLACE("Order ID",'FRE',''),'JAX',''),'VAN','') AS INT), "Order Line"

		if @LoadTempTable = 0
			select * from #ResultSet
			  ORDER BY ISNULL(Uf_assign_site,site_ref), site_ref, ISNULL("Due","Promised")
					, CAST(REPLACE(REPLACE(REPLACE("Order ID",'FRE',''),'JAX',''),'VAN','') AS INT), "Order Line"
	  END
  
      ELSE
	
        SELECT @sraa_StartDate AS 'Start Date',
               @sraa_EndDate AS 'End Date'
  
      END	  

	  ELSE --1 --> do include sales projected within the date range that have shipped complete

  	  BEGIN
	  
	    IF EXISTS(SELECT * FROM coitem_all coia
							JOIN item_all i ON i.site_ref = coia.site_ref AND i.item = coia.item
							JOIN @PCLTable pclt ON pclt.ProdCode = i.product_code
				WHERE COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) >= @sraa_StartDate
	          AND CAST(COALESCE(coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) <= @sraa_EndDate) --CHECKING FOR ZERO RECORDS

	    BEGIN
     	  insert #ResultSet
		  SELECT * FROM (  	  
	      SELECT 
	         @sraa_StartDate AS 'Start Date',
             @sraa_EndDate AS 'End Date',
			 coia.site_ref,
		     ISNULL(coia.Uf_assign_site,coia.site_ref) AS Uf_assign_site,
	         coia.qty_ordered * coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.00000) AS "Ext Price",
	         CAST(COALESCE(coia.ship_date,coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) AS "Ship Date",
	         CASE WHEN coia.qty_ordered = coia.qty_shipped AND coia.qty_shipped > 0 THEN 'SHP'
    		     ELSE CASE WHEN coia.Due_date IS NULL THEN
					CASE WHEN coia.Uf_PromiseDate IS NULL THEN 'REQ' ELSE 'PRM' END
					ELSE 'DUE' END
             END AS "Date Type",
 	         CAST(coia.Uf_PromiseDate AS DATE) AS "Promised",
		     CAST(coia.promise_date AS DATE) AS "Requested",
		     CAST(coia.due_date AS DATE) AS "Due",
  		     CASE WHEN coia.qty_ordered > coia.qty_shipped AND coia.qty_shipped > 0 THEN  CAST('1775-11-10' AS DATE)
		                                                                   --REPORT WILL TRANSLATE THIS DATE AS "PARTIAL"
			 ELSE CAST(coia.Ship_Date AS DATE)
			 END AS "Shipped",
	         ltrim(coia.co_num) AS "Order ID",
	         coia.co_line AS "Order Line",
	         CONCAT(ca.cust_num, ' / ', LEFT(ca.name,12)) AS "Customer",
	         coia.item AS "Item ID",
	         coia.qty_ordered * 1.000 AS "Qty",
	         coia.price * IIF(ca.curr_code = 'CAD', @ExchRate, 1.000000) AS "Price",
			 ia.product_code,
			 pclgt.ProdCodeGroup,
	 		 @ExchRate AS exch_rate,
			 @ExchEffDate AS exch_eff_date,
			 ISNULL(coia.Uf_numSections,0) AS "SectionCount", -- 0001 DMS 'section_count'
			 (SELECT TOP 1 ici.item_category FROM item_category_item ici
										JOIN item_category ic ON ic.item_category = ici.item_category 
										WHERE ic.active = 1 
											AND ici.item = coia.item
										ORDER BY ici.CreateDate Desc) AS "item_category" -- 0001 DMS 'item_category'
	   
	      FROM coitem_all coia
		    LEFT JOIN co_all coa
		      ON coia.site_ref = coa.site_ref AND coia.co_num = coa.co_num
		    LEFT JOIN custaddr ca
		      ON ca.cust_num = coa.cust_num AND ca.cust_seq = coa.cust_seq
	   	    LEFT JOIN customer_all cua
			  ON coa.site_ref = cua.site_ref AND coa.cust_num = cua.cust_num AND cua.cust_seq = 0
			LEFT JOIN item_all ia
			  ON ia.site_ref = coia.site_ref AND ia.item = coia.item
		    JOIN @PCLTable pclt
			  ON pclt.ProdCode = ia.product_code
			LEFT JOIN @PCLGroupTable pclgt
			  ON pclgt.ProdCode = ia.product_code

	      WHERE CAST(COALESCE(coia.ship_date,coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) >= @sraa_StartDate
		        AND CAST(COALESCE(coia.ship_date,coia.Due_Date,coia.Uf_PromiseDate,coia.Promise_Date) AS DATE) <= @sraa_EndDate
			    AND CHARINDEX(ISNULL(coia.Uf_assign_site,coia.site_ref),@site) > 0
				AND (ISNULL(cua.cust_type,'') NOT BETWEEN 9990 AND 9998 OR @sraa_IncludeAffiliated = 1)

	  UNION

		SELECT    @sraa_StartDate AS 'Start Date'
				, @sraa_EndDate AS 'End Date'
				, jsa.site_ref
				, RIGHT(jsa.job,3) AS Uf_assign_site
				, NULL AS "Ext Price"
				, jsa.end_date AS "Ship Date"
				, 'JOB' AS "Date_Type"
				, NULL AS "Promised"
				, NULL AS "Requested"
				, NULL AS "Due"
				, NULL AS "Shipped"
				, jsa.job AS "Order ID"
				, jsa.suffix AS "Order Line"
				, CONCAT(coa.cust_num, ' / ', LEFT(ca.name,12)) AS "Customer"
				, coia.item AS "Item ID"
				, coia.qty_ordered * 1.000 AS "Qty"
				, NULL AS "Price"
				, ia.product_code
				, ISNULL(ja.Uf_SchedGroup,pclgt.ProdCodeGroup)
				, @ExchRate AS exch_rate
				, @ExchEffDate AS exch_eff_date
				, ISNULL(coia.Uf_numSections,0) AS "SectionCount"-- 0001 DMS 
				, (SELECT TOP 1 ici.item_category FROM item_category_item ici
										JOIN item_category ic ON ic.item_category = ici.item_category 
										WHERE ic.active = 1 
											AND ici.item = coia.item
										ORDER BY ici.CreateDate Desc) AS "item_category"-- 0001 DMS 
	  
	  	FROM job_sch_all jsa
	  		LEFT JOIN coitem_all coia
	  			ON LTRIM(coia.co_num) = REPLACE(REPLACE(REPLACE(jsa.job,'FRE',''),'JAX',''),'VAN','') AND coia.co_line = jsa.suffix
	  		LEFT JOIN co_all coa
	  			ON coa.co_num = coia.co_num
	  		LEFT JOIN custaddr ca
	  			ON ca.cust_num = coa.cust_num AND ca.cust_seq = coa.cust_seq
			LEFT JOIN customer_all cua
				ON coa.site_ref = cua.site_ref AND coa.cust_num = cua.cust_num AND cua.cust_seq = 0
	  		LEFT JOIN item_all ia
	  			ON ia.item = coia.item
			LEFT JOIN job_all ja
				ON ja.job = jsa.job AND ja.suffix = jsa.suffix
	   	    LEFT JOIN @PCLTable pclt
			  ON pclt.ProdCode = ia.product_code
			LEFT JOIN @PCLGroupTable pclgt
			  ON pclgt.ProdCode = ia.product_code

	  		WHERE jsa.end_date >= @sraa_StartDate
				AND CAST(jsa.end_date AS DATE) <= @sraa_EndDate
				AND RIGHT(jsa.job,3) IN ('FRE','JAX','VAN')
				AND RIGHT(coia.Uf_assign_site,3) <> RIGHT(jsa.job,3)
				AND CHARINDEX(jsa.site_ref,@site) > 0
				AND (ISNULL(cua.cust_type,'') NOT BETWEEN 9990 AND 9998 OR @sraa_IncludeAffiliated = 1)
				AND (pclt.ProdCode IS NOT NULL OR ja.Uf_SchedGroup = @ProdCode)
				AND @sraa_IncludeJobs = 1) r

--		ORDER BY ISNULL(Uf_assign_site,site_ref), site_ref, ISNULL("Due","Promised")
--			, CAST(REPLACE(REPLACE(REPLACE("Order ID",'FRE',''),'JAX',''),'VAN','') AS INT), "Order Line"

		if @LoadTempTable = 0
			select * from #ResultSet
			ORDER BY ISNULL(Uf_assign_site,site_ref), site_ref, ISNULL("Due","Promised")
				, CAST(REPLACE(REPLACE(REPLACE(IIF(ISNUMERIC("Order ID") = 1, "Order ID", 0),'FRE',''),'JAX',''),'VAN','') AS INT), "Order Line"

	  END

        ELSE
	
        SELECT @sraa_StartDate AS 'Start Date',
             @sraa_EndDate AS 'End Date'
	 END

   END -- End comment out portion 2 to refresh dataset

END

