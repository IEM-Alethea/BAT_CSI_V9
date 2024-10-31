SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO


ALTER PROCEDURE [dbo].[_IEM_Rpt_SalesTaxSp] (
	  @StartDate			DATE
	, @EndDate				DATE
)
AS
BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL;

DECLARE	  @XDate					DATE = NULL

IF @StartDate > @EndDate
	BEGIN
		SET @XDate = @StartDate
		SET @StartDate = @EndDate
		SET @EndDate = @XDate
	END

IF @StartDate IS NULL AND @EndDate IS NOT NULL
	BEGIN
		SET @StartDate = DATEADD(dd, 1, EOMONTH(@EndDate, -1))
	END

IF @StartDate IS NOT NULL AND @EndDate IS NULL
	BEGIN
		SET @EndDate = EOMONTH(@StartDate)
	END

IF @StartDate IS NULL AND @EndDate IS NULL
	BEGIN
		SET @StartDate = DATEADD(dd, 1, EOMONTH(GETDATE(), -2))
		SET @EndDate = EOMONTH(GETDATE(), -1)
	END

IF OBJECT_ID('tempdb..#TaxBasis') IS NOT NULL DROP TABLE #TaxBasis
IF OBJECT_ID('tempdb..#TaxBasis2') IS NOT NULL DROP TABLE #TaxBasis2
IF OBJECT_ID('tempdb..#TaxBasisDetail') IS NOT NULL DROP TABLE #TaxBasisDetail
IF OBJECT_ID('tempdb..#TaxBasisDetail') IS NOT NULL DROP TABLE #TaxBasisDetail2
IF OBJECT_ID('tempdb..#TBRepSet') IS NOT NULL DROP TABLE #TBRepSet

CREATE TABLE #TBRepSet (
	  Section						NVARCHAR(10)
	, Amount						DECIMAL(23,8)
	)

DECLARE @RptSet TABLE (

	  Tab							TINYINT
	, StartDate						DateTime
	, EndDate						DateTime
	, Section						NVARCHAR(10)
	, Summary_Amt					DECIMAL(23,8)
	, AR_inv_num					NVARCHAR(12)
	, AR_IC							NVARCHAR(1)
	, AR_ec							NVARCHAR(2)
	, AR_taxcode					NVARCHAR(5)
	, AR_service_total				DECIMAL(23,8)
	, AR_nonservice_total			DECIMAL(23,8)
	, AR_sales_tax					DECIMAL(23,8)
	, AR_total_price				DECIMAL(23,8)
	, IIA00							DECIMAL(23,8)
	, IIB01							DECIMAL(23,8)
	, IIB02							DECIMAL(23,8)
	, IIB03							DECIMAL(23,8)
	, IIC44							DECIMAL(23,8)
	, IID45							DECIMAL(23,8)
	, IIE46							DECIMAL(23,8)
	, IIF47							DECIMAL(23,8)
	, IIG48							DECIMAL(23,8)
	, IIG49							DECIMAL(23,8)
	, IVA54							DECIMAL(23,8)
	, VA64							DECIMAL(23,8)
	, AP_vend_num					VendNumType
	, AP_voucher					INTEGER
	, AP_type						NVARCHAR(1)
	, AP_ec							NVARCHAR(2)
	, AP_Goods						DECIMAL(23,8)
	, AP_Services					DECIMAL(23,8)
	, AP_Assets						DECIMAL(23,8)
	, AP_GSA_Total					DECIMAL(23,8)
	, AP_sales_tax					DECIMAL(23,8)
	, AP_voucher_total				DECIMAL(23,8)
	, AP_CX							DECIMAL(23,8)
	, IIIA81						DECIMAL(23,8)
	, IIIA82						DECIMAL(23,8)
	, IIIA83						DECIMAL(23,8)
	, IIIB84						DECIMAL(23,8)
	, IIIB85						DECIMAL(23,8)
	, IIIC86						DECIMAL(23,8)
	, IIID87						DECIMAL(23,8)
	, IIIE88						DECIMAL(23,8)
	, IVA55							DECIMAL(23,8)
	, IVA56							DECIMAL(23,8)
	, IVD63							DECIMAL(23,8)
	, VA59							DECIMAL(23,8)
	)

; WITH custLoc
	AS (
		SELECT	  ca.cust_num
				, CASE WHEN c.ec_code IS NULL THEN 'NA'
					   WHEN c.ec_code = 'BE' THEN 'BE'
					   ELSE 'EU' END AS ec
			FROM custaddr ca
				JOIN country c
					ON c.country = ca.country
				WHERE ca.cust_seq = 0
		)

, InvoiceCredit
	AS (
		SELECT	  inv_num
				, CASE
					WHEN LEFT(inv_num,1) = 'C' THEN 'C'
					WHEN LEFT(inv_num,1) = 'D' THEN 'I'
					WHEN LEFT(inv_num,1) = 'I' AND price < 0 THEN 'C'
					ELSE 'I' END AS IC
				, bill_type
			FROM inv_hdr
				WHERE CAST(inv_date AS DATE) BETWEEN @StartDate AND @EndDate
		)

, ServiceTaxTotal
	AS (
		SELECT	  ii.inv_num
				, SUM(IIF(ih.bill_type = 'P', ii.price, ii.price * ii.qty_invoiced) * tc.tax_rate / 100) price
			FROM inv_item ii
				JOIN InvoiceCredit ih
					ON ih.inv_num = ii.inv_num
				JOIN taxcode tc
					ON tc.tax_code = ii.tax_code1
				JOIN item i
					ON i.item = ii.item
				WHERE i.product_code LIKE 'S%'
					GROUP BY ii.inv_num
		)

, InvItemTaxTotal
	AS (
		SELECT	  ii.inv_num
				, SUM(IIF(ih.bill_type = 'P', ii.price, ii.price * ii.qty_invoiced) * tc.tax_rate / 100) price
			FROM inv_item ii
				JOIN InvoiceCredit ih
					ON ih.inv_num = ii.inv_num
				JOIN taxcode tc
					ON tc.tax_code = ii.tax_code1
				GROUP BY ii.inv_num
		)

, SNSTaxBasis
	AS (
		SELECT	  isx.inv_num
				, isx.tax_basis * (IIF(ISNULL(iitt.price,0) = 0
									, 0
									, ISNULL(sst.price, 0) / IIF(ISNULL(iitt.price,0) = 0, 1, ISNULL(iitt.price,0)))) AS service_tax_basis
				, isx.tax_basis * (1 -(IIF(ISNULL(iitt.price,0) = 0
									, 0
									, ISNULL(sst.price, 0) / IIF(ISNULL(iitt.price, 0) = 0, 1, ISNULL(iitt.price, 0))))) AS nonservice_tax_basis
				, isx.sales_tax
			FROM inv_stax isx
				LEFT JOIN ServiceTaxTotal sst
					ON sst.inv_num = isx.inv_num
				LEFT JOIN InvItemTaxTotal iitt
					ON iitt.inv_num = isx.inv_num
		) 
		
SELECT	  ic.inv_num
		, ic.IC
		, cl.ec
		, ISNULL(ih.tax_code1,isx.tax_code) AS tax_code1
		, ISNULL(s.service_tax_basis, 0) AS service_tax_basis
		, ISNULL(s.nonservice_tax_basis, 0) AS nonservice_tax_basis
		, s.sales_tax
	INTO #TaxBasis
		FROM InvoiceCredit ic
			LEFT JOIN inv_hdr ih
				ON ih.inv_num = ic.inv_num
			LEFT JOIN inv_stax isx
				ON isx.inv_num = ic.inv_num
			LEFT JOIN custLoc cl
				ON cl.cust_num = ih.cust_num
			LEFT JOIN SNSTaxBasis s
				ON s.inv_num = ic.inv_num
		WHERE ISNULL(ih.tax_code1,isx.tax_code) IS NOT NULL

SELECT	  tb.inv_num
		, tb.IC
		, tb.ec
		, tb.tax_code1
		, tb.service_tax_basis
		, tb.nonservice_tax_basis
		, tb.sales_tax
		, ih.price
		, IIF(ec = 'BE' AND tb.tax_code1 = 'EX'		AND ic = 'I',	service_tax_basis + nonservice_tax_basis, 0)	AS IIA00
		, IIF(ec = 'BE' AND tb.tax_code1 = '06'		AND ic = 'I',	service_tax_basis + nonservice_tax_basis, 0)	AS IIB01
		, IIF(ec = 'BE' AND tb.tax_code1 = '12'		AND ic = 'I',	service_tax_basis + nonservice_tax_basis, 0)	AS IIB02
		, IIF(ec = 'BE' AND tb.tax_code1 = '21'		AND ic = 'I',	service_tax_basis + nonservice_tax_basis, 0)	AS IIB03
		, IIF(ec = 'EU' AND tb.tax_code1 <> 'SCX'	AND ic = 'I',	service_tax_basis, 0)							AS IIC44
		, IIF(ec = 'BE' AND tb.tax_code1 = 'SCX'	AND ic = 'I',	service_tax_basis + nonservice_tax_basis, 0)	AS IID45
		, IIF(ec = 'EU' AND tb.tax_code1 <> 'SCX'	AND ic = 'I',	nonservice_tax_basis, 0)						AS IIE46
		, IIF((ec = 'NA' AND ic = 'I')
			OR (ec = 'EU' AND ic = 'I' AND tb.tax_code1 = 'SCX'),	service_tax_basis + nonservice_tax_basis, 0)	AS IIF47
		, IIF(ec = 'EU' AND ic = 'C',								service_tax_basis + nonservice_tax_basis, 0)	AS IIG48
		, IIF(ec IN ('BE','NA') AND ic = 'C',						service_tax_basis + nonservice_tax_basis, 0)	AS IIG49
		, IIF(ec IN ('BE','EU')								,		sales_tax, 0)								    AS IVA54
		, IIF(ec = 'BE' AND ic = 'C', (service_tax_basis + nonservice_tax_basis) * 0.21, 0)							AS VA64

	INTO #TaxBasisDetail
		FROM #TaxBasis tb
			JOIN inv_hdr ih
				ON ih.inv_num = tb.inv_num
		
INSERT INTO #TBRepSet
SELECT	  'IIA00'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'BE' AND tax_code1 ='EX' AND ic = 'I'
UNION
SELECT	  'IIB01'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'BE' AND tax_code1 ='06' AND ic = 'I'
UNION
SELECT	  'IIB02'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'BE' AND tax_code1 ='12' AND ic = 'I'
UNION
SELECT	  'IIB03'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'BE' AND tax_code1 ='21' AND ic = 'I'
UNION
SELECT	  'IIC44'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'EU' AND ic = 'I' AND tax_code1 <> 'SCX'
UNION
SELECT	  'IID45'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'BE' AND tax_code1 ='SCX' AND ic = 'I'
UNION
SELECT	  'IIE46'
		, ISNULL(SUM(ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'EU' AND ic = 'I' AND tax_code1 <> 'SCX'
UNION
SELECT	  'IIF47'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE (ec = 'NA' AND ic = 'I') OR (ec = 'EU' AND ic = 'I' AND tax_code1 = 'SCX')
UNION
SELECT	  'IIG48'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec = 'EU' AND ic = 'C'
UNION
SELECT	  'IIG49'
		, ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)
	FROM #TaxBasis
		WHERE ec IN ('BE','NA') AND ic = 'C'

; WITH vendLoc
	AS (
		SELECT	  va.vend_num
				, CASE WHEN c.ec_code IS NULL THEN 'NA'
					   WHEN c.ec_code = 'BE' THEN 'BE'
					   ELSE 'EU' END AS ec
			FROM vendaddr va
				JOIN country c
					ON c.country = va.country
		)

, VoucherCredit
	AS (
		SELECT	  voucher
				, IIF(inv_amt >= 0, 'V', 'C') AS type
			FROM vch_hdr
		)

, CXVI
	AS (
		SELECT	  voucher
				, SUM(qty_voucher * cost) AS ext_cost
			FROM vch_item
				WHERE tax_code1 = 'CX'
					GROUP BY voucher
		)

, CXST
	AS (
		SELECT	  voucher
				, SUM(tax_basis) AS ext_cost
			FROM vch_stax
				WHERE tax_system = 1 AND tax_code = 'CX'
					GROUP BY voucher
		)

, VchPo
	AS (
		SELECT	  voucher
				, ISNULL(pc.inv_pur_acct, vi.non_inv_acct) AS acct
				, SUM(vi.qty_voucher * vi.cost / IIF(po.include_tax_in_cost = 1, (1 + ISNULL(tax_rate / 100, 0.21)), 1)) AS amt
			FROM vch_item vi
				LEFT JOIN item i
					ON i.item = vi.item
				LEFT JOIN poitem poi
					ON poi.po_num = vi.po_num AND poi.po_line = vi.po_line
				LEFT JOIN po
					ON po.po_num = poi.po_num
				LEFT JOIN prodcode pc
					ON pc.product_code = i.product_code
				LEFT JOIN taxcode tc
					ON tc.tax_code = vi.tax_code1
				GROUP BY voucher, ISNULL(pc.inv_pur_acct, vi.non_inv_acct)
		)

, VchNoPo
	AS (
		SELECT	  vd.voucher
				, vd.acct
				, SUM(vd.amt) AS amt
			FROM vch_dist vd
				LEFT JOIN VchPo vp
					ON vp.voucher = vd.voucher AND vp.acct = vd.acct
				WHERE vd.acct <> '411100' AND vp.acct IS NULL
					GROUP BY vd.voucher, vd.acct
		)
		
, VchAcctClass
	AS (
		SELECT	  vp.voucher
				, CASE 
					WHEN LEFT(vp.acct,2) = '60' THEN 'G'
					WHEN LEFT(vp.acct,2) IN ('61','62') THEN 'S'
					WHEN LEFT(vp.acct,1) = '2' THEN 'A'
					END AS 'GSA'
				, SUM(amt) AS amt
				FROM (SELECT * FROM VchNoPo UNION SELECT * FROM VchPo) vp
					GROUP BY voucher, CASE 
											WHEN LEFT(vp.acct,2) = '60' THEN 'G'
											WHEN LEFT(vp.acct,2) IN ('61','62') THEN 'S'
											WHEN LEFT(vp.acct,1) = '2' THEN 'A'
											END
		)

, VchItem
	AS (
		SELECT	  voucher
				, SUM(cost * qty_voucher) AS ext_cost
			FROM vch_item vi
				GROUP BY voucher
		)

, VchDate
	AS (
		SELECT	  voucher
				, MAX(control_year) AS control_year
				, MAX(control_period) AS control_period
				, CAST(CAST(MAX(control_year) AS NVARCHAR(4)) + '-' + RIGHT('0' + CAST(MAX(control_period) AS NVARCHAR(2)),2) + '-01' AS DATE) AS inv_date
			FROM (SELECT voucher, control_year, control_period FROM ledger WHERE from_id = 'AP Dist'
				  UNION
				  SELECT voucher, control_year, control_period FROM journal WHERE id = 'AP Dist') gl
				GROUP BY voucher
		)

SELECT    vh.voucher
		, vh.vend_num
		, vc.type
		, vl.ec
		, vs.sales_tax
		, ROUND(ISNULL(vcg.amt,0), 2) AS Goods
		, ROUND(ISNULL(vcs.amt,0), 2) AS 'Services'
		, ROUND(ISNULL(vca.amt,0), 2) AS Assets
		, ROUND(ISNULL(vcg.amt,0) + ISNULL(vcs.amt,0) + ISNULL(vca.amt,0), 2) AS GSA_Total
		, ROUND(COALESCE(cxvi.ext_cost, cxst.ext_cost, 0), 2) AS CX
		, vd.control_year
		, vd.control_period
		, vd.inv_date AS inv_period_start
		, vh.inv_date
	INTO #TaxBasis2		
		FROM vch_hdr vh
			LEFT JOIN VoucherCredit vc
				ON vc.voucher = vh.voucher
			LEFT JOIN (SELECT voucher, SUM(sales_tax) AS sales_tax, SUM(tax_basis) AS tax_basis FROM vch_stax GROUP BY voucher) vs
				ON vs.voucher = vh.voucher
			LEFT JOIN VchItem vi
				ON vi.voucher = vh.voucher
			LEFT JOIN (SELECT voucher, SUM(item_cost * qty_vouchered) AS ext_cost FROM po_vch WHERE type = 'V' GROUP BY voucher) pv
				ON pv.voucher = vh.voucher
			LEFT JOIN VchAcctClass vcg
				ON vcg.voucher = vh.voucher AND vcg.GSA = 'G'
			LEFT JOIN VchAcctClass vcs
				ON vcs.voucher = vh.voucher AND vcs.GSA = 'S'
			LEFT JOIN VchAcctClass vca
				ON vca.voucher = vh.voucher AND vca.GSA = 'A'
			LEFT JOIN CXVI
				ON cxvi.voucher = vh.voucher
			LEFT JOIN CXST
				ON cxst.voucher = vh.voucher
			JOIN vendloc vl
				ON vl.vend_num = vh.vend_num
			LEFT JOIN VchDate vd
				ON vd.voucher = vh.voucher
			WHERE IIF(ISNULL(vh.inv_date, CAST(vh.inv_date AS DATE)) > CAST(vh.inv_date AS DATE)
					, ISNULL(vd.inv_date, CAST(vh.inv_date AS DATE))
					, CAST(vh.inv_date AS DATE)) BETWEEN @StartDate AND @EndDate

SELECT	  tb.vend_num
		, tb.voucher
		, tb.type
		, tb.ec
		, tb.Goods
		, tb.[Services]
		, tb.Assets
		, tb.GSA_Total
		, tb.sales_tax
		, tb.GSA_Total + tb.sales_tax AS voucher_total
		, tb.CX
		, tb.Goods																AS IIIA81
		, tb.[Services]															AS IIIA82
		, tb.Assets																AS IIIA83
		, IIF(tb.type = 'C' AND tb.ec = 'EU', GSA_Total, 0)						AS IIIB84
		, IIF(tb.type = 'C' AND tb.ec IN ('BE','NA'), tb.GSA_Total, 0)			AS IIIB85
		, IIF(tb.type = 'V' AND tb.ec = 'EU', tb.Goods + tb.Assets, 0)			AS IIIC86
		, IIF(tb.type = 'V' AND tb.ec IN ('BE','EU'), tb.CX, 0)					AS IIID87
		, IIF(tb.type = 'V' AND tb.ec = 'EU', tb.[Services], 0)					AS IIIE88
		, IIF(tb.type = 'V' AND tb.ec = 'EU', tb.GSA_Total * 0.21, 0)			AS IVA55
		, IIF(tb.type = 'V' AND tb.ec IN ('BE','EU'), tb.CX * 0.21, 0)			AS IVA56
		, IIF(tb.type = 'C' AND tb.ec = 'BE', tb.GSA_Total, 0)					AS IVD63
		, IIF(					tb.ec <> 'NA', ISNULL(tb.sales_tax, 0), 0)		AS VA59
	INTO #TaxBasisDetail2
		FROM #TaxBasis2 tb

INSERT INTO #TBRepSet
SELECT	  'IIIA81'
		, ISNULL(SUM(Goods),0)
	FROM #TaxBasis2
UNION
SELECT	  'IIIA82'
		, ISNULL(SUM([Services]),0)
	FROM #TaxBasis2
UNION
SELECT	  'IIIA83'
		, ISNULL(SUM(Assets),0)
	FROM #TaxBasis2
UNION
SELECT	  'IIIB84'
		, ISNULL(SUM(GSA_Total), 0)
	FROM #TaxBasis2
		WHERE type = 'C' AND ec = 'EU'
UNION
SELECT	  'IIIB85'
		, ISNULL(SUM(GSA_Total), 0)
	FROM #TaxBasis2
		WHERE type = 'C' AND ec IN ('BE','NA')
UNION
SELECT	  'IIIC86'
		, ISNULL(SUM(Goods), 0) + ISNULL(SUM(Assets), 0)
	FROM #TaxBasis2
		WHERE type = 'V' AND ec = 'EU'
UNION
SELECT	  'IIID87'
		, ISNULL(SUM(CX), 0)
	FROM #TaxBasis2
		WHERE type = 'V' AND ec IN ('BE','EU')
UNION
SELECT	  'IIIE88'
		, ISNULL(SUM([Services]), 0)
	FROM #TaxBasis2
		WHERE type = 'V' AND ec = 'EU'

INSERT INTO #TBRepSet
SELECT	  'IVA54'
		,	(SELECT Amount FROM #TBRepSet WHERE Section = 'IIB01') * 0.06
		  + (SELECT Amount FROM #TBRepSet WHERE Section = 'IIB02') * 0.12
		  + (SELECT Amount FROM #TBRepSet WHERE Section = 'IIB03') * 0.21

INSERT INTO #TBRepSet
SELECT	  'IVA55'
		,	(SELECT SUM(Amount) FROM #TBRepSet WHERE Section IN('IIIC86','IIIE88')) * 0.21

INSERT INTO #TBRepSet
SELECT	  'IVA56'
		,	(SELECT Amount FROM #TBRepSet WHERE Section = 'IIID87') * 0.21

INSERT INTO #TBRepSet
SELECT	  'IVD63' 
		, ISNULL(SUM(GSA_Total), 0) * 0.21
	FROM #TaxBasis2
		WHERE type = 'C' AND ec = 'BE'

INSERT INTO #TBRepSet
SELECT	  'VA59' 
		, ISNULL(SUM(sales_tax), 0)
	FROM #TaxBasis2
		WHERE ec IN ('BE','EU')

INSERT INTO #TBRepSet
SELECT	  'VC64'
		, (ISNULL(SUM(ISNULL(service_tax_basis, 0) + ISNULL(nonservice_tax_basis, 0)),0)) * 0.21
	FROM #TaxBasis
		WHERE ec = 'BE' AND ic = 'C'

INSERT INTO @RptSet (
		  Tab
		, StartDate
		, EndDate
		, Section
		, Summary_Amt)
	SELECT	  1
			, @StartDate AS StartDate
			, @EndDate AS EndDate
			, rs.Section
			, rs.Amount
		FROM #TBRepSet rs

INSERT INTO @RptSet (
		  Tab					
		, StartDate				
		, EndDate				
		, AR_inv_num			
		, AR_IC					
		, AR_ec					
		, AR_taxcode			
		, AR_service_total		
		, AR_nonservice_total	
		, AR_sales_tax			
		, AR_total_price		
		, IIA00					
		, IIB01					
		, IIB02
		, IIB03					
		, IIC44					
		, IID45					
		, IIE46					
		, IIF47					
		, IIG48					
		, IIG49					
		, IVA54					
		, VA64
		)
	SELECT 	  2
			, @StartDate
			, @EndDate
			, tbd.*
		FROM #TaxBasisDetail tbd
		
INSERT INTO @RptSet (
		  Tab					
		, StartDate				
		, EndDate				
		, AP_vend_num		
		, AP_voucher		
		, AP_type			
		, AP_ec				
		, AP_Goods			
		, AP_Services		
		, AP_Assets			
		, AP_GSA_Total		
		, AP_sales_tax		
		, AP_voucher_total	
		, AP_CX				
		, IIIA81			
		, IIIA82			
		, IIIA83			
		, IIIB84			
		, IIIB85			
		, IIIC86			
		, IIID87			
		, IIIE88			
		, IVA55				
		, IVA56				
		, IVD63				
		, VA59
		)
	SELECT	  3	
			, @StartDate
			, @EndDate
			, tbd.*
		FROM #TaxBasisDetail2 tbd

SELECT *
	FROM @RptSet
		ORDER BY Tab, Section, AR_inv_num, AP_voucher
					
END
GO

