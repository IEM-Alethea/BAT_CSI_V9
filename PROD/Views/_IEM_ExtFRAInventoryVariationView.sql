DROP VIEW [dbo].[_IEM_ExtFRAInventoryVariationView]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





/*$Header: /ApplicationDB/Views/ExtFRAInventoryVariationView.sql 1    10/10/17 2:12p pauodi $ */
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
*   (c) COPYRIGHT 2008 INFOR.  ALL RIGHTS RESERVED.           *
*   THE WORD AND DESIGN MARKS SET FORTH HEREIN ARE            *
*   TRADEMARKS AND/OR REGISTERED TRADEMARKS OF INFOR          *
*   AND/OR ITS AFFILIATES AND SUBSIDIARIES. ALL RIGHTS        *
*   RESERVED.  ALL OTHER TRADEMARKS LISTED HEREIN ARE         *
*   THE PROPERTY OF THEIR RESPECTIVE OWNERS.                  *
*                                                             *
***************************************************************
*/

/* $Archive: /ApplicationDB/Views/ExtFRAInventoryVariationView.sql $
 *
 * SL9.01.00 1 Initial pauodi 10 Oct 2017 2:12pm
 *
 * $NoKeywords: $
 */

CREATE VIEW [dbo].[_IEM_ExtFRAInventoryVariationView] 
AS 

SELECT 
  N'AnaLedger'                          AS 'Source'
, CASE WHEN a.acct LIKE '97%' 
   THEN dbo.GetLabel('@ZFRInvVarType2')
   ELSE dbo.GetLabel('@ZFRInvVarType1') 
  END                                   AS 'StockDepr'
, a.control_site                        AS 'Site'
, a.control_prefix                      AS 'Prefix'
, a.control_year                        AS 'Year'
, a.control_period                      AS 'Period'
, a.control_number                      AS 'Number'
, a.from_id                             AS 'FromId'
, dbo.MidnightOf(a.trans_date)          AS 'JrnlTransDate'
, a.acct                                AS 'Acct'
, c.description                         AS 'Description'
, a.acct_unit1                          AS 'AcctUnit1'
, a.acct_unit2                          AS 'AcctUnit2'
, a.acct_unit3                          AS 'AcctUnit3'
, a.acct_unit4                          AS 'AcctUnit4'
, a.dom_amount                          AS 'DomAmount'
, a.for_amount                          AS 'ForAmount'
, a.curr_code                           AS 'CurrCode'
, a.exch_rate                           AS 'ExchRate'
, a.ref                                 AS 'Reference'
, m.item                                AS 'MatlItem'
, ISNULL(i.product_code,n.product_code) AS 'MatlProductCode'
, m.type                                AS 'MatlTransType'
, m.qty                                 AS 'MatlQty'
, dbo.MidnightOf(t.CreateDate)          AS 'MatlCreateDate'
, m.UserCode							AS 'UserCode'
, m.WC									AS 'WorkCenter'
FROM ana_ledger a
INNER JOIN chart c ON c.acct = a.acct
LEFT OUTER JOIN MaterialTransactionsView m ON m.trans_num = a.matl_trans_num
LEFT OUTER JOIN matltran t ON t.trans_num = m.Trans_Num
LEFT OUTER JOIN item i ON i.item = m.item
LEFT OUTER JOIN non_inventory_item n ON n.item = m.item
WHERE a.acct_unit4 IS NOT NULL

GO

