SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* $Header: /ApplicationDB/Stored Procedures/Rpt_ARInvoiceCreditDebitMemoSp.sp 44    5/25/15 4:52a Cliu $ */
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
--ATTEMPTS TO WRAP THE ORIGINAL FAILED DUE TO NESTING INSERT INTO --DBH 2016/11/07 1513 hrs MST

/* $Archive: /ApplicationDB/Stored Procedures/Rpt_ARInvoiceCreditDebitMemoSp.sp $
 *
 * SL9.00 44 195376 Cliu Mon May 25 04:52:55 2015
 * Amended amount label field does not replace the Sales Tax field in invoice printouts from A/R Invoice Credit Debit Memo Report
 * Issue:195376
 * Add the fields for getting the label of tax amount.
 *
 * SL9.00 43 195376 Cliu Mon May 25 04:28:43 2015
 * Amended amount label field does not replace the Sales Tax field in invoice printouts from A/R Invoice Credit Debit Memo Report
 * Issue:195376
 * Add the fields for getting the label of tax amount.
 *
 * SL9.00 42 193284 Ehe Tue Apr 07 03:38:47 2015
 * Report not printing new Remit To details with Form Type = Simple
 * 193284 Change the sp to get the value of Wire To, Bank Transit Number and Account Number.
 *
 * SL9.00 41 188008 csun Wed Feb 04 03:56:18 2015
 * Associated with RS7090 - Loc - Bank account format
 * Issue#188008
 * RS7090,Add 3 new columns for temp table tt_invoice_draft.
 *
 * SL9.00 40 189181 Igui Wed Dec 24 04:45:04 2014
 * Debit and Credit Memo are not showing "Print Headers on all forms"
 * issue 189181(RS7085)
 * change INNER JOIN artran to LEFT JOIN.
 *
 * SL9.00 39 189181 Igui Wed Dec 24 01:34:31 2014
 * Debit and Credit Memo are not showing "Print Headers on all forms"
 * issue 189181(RS7085)
 * add due_date.
 *
 * SL9.00 38 187906 Igui Fri Dec 12 04:59:34 2014
 * Coding for RS7085
 * RS7085(issue 187906)
 * add report parameter and fields.
 *
 * SL9.00 37 172218 pgross Fri Oct 24 11:53:46 2014
 * restructured to better handle reprinting
 *
 * SL9.00 36 183917 pgross Wed Aug 20 12:11:37 2014
 * PrintInvoiceSp now supports an @Infobar parameter
 *
 * SL9.00 35 176536 Igui Fri Mar 28 02:18:19 2014
 * New Extended Tax value seems to be pulling from wrong place
 * issue 176536(RS6307)
 * Add parameter @ExtendedTax.
 *
 * SL8.04 34 164176 Cajones Fri Jun 28 14:16:40 2013
 * Issue 164176
 * Modified Mexican Localizations code to make it more consistent with SyteLine's External Touch Point Standards
 *
 * SL8.04 33 160420 Ezhang1 Wed May 22 03:45:11 2013
 * Issue#160420
 *
 * SL8.04 32 161353 Tcecere Tue May 14 14:20:20 2013
 * pSite parameter may be missing in parent stored procedures.
 * Added @pSite to Rpt_ files call from Rpt_ files
 *
 * SL8.04 31 157235 Cajones Wed Jan 09 14:00:10 2013
 * When running the A/R Invoice Credit Debit Memo report with APAR 154495 installed, an “Experienced an exception while executing” error is returned to the user.
 * Issue 157235
 * Modified if statement that controls when the Mexican Country Pack program is called.
 *
 * SL8.04 30 RS4615 Lliu Wed Dec 26 04:49:46 2012
 * RS4615: Multi - Add Site within a Site Functionality.
 *
 * SL8.04 29 154495 Cajones Mon Oct 22 16:47:54 2012
 * Mexican Localizations for Rpt_ARInvoiceCreditDebitMemoSp
 * Issue 154495
 * Added touchpoint for Mexican Localizations.
 *
 * SL8.03 28 142040 exia Wed Sep 14 03:01:52 2011
 * The draft section at the bottom of the page is printing too high up on the page.
 * Issue - 142040
 * Purpose: Merge the CoDraft data into this sp.
 * 1.Paramter pVoidOrDraft has been added because it need to be used to call Rpt_CoDDraftISp.
 * 2. According to Rpt_CoDDraftISp, serial variables have been defined.
 * 3.Relatve serial columns have been added on #tt_invoice_credit_debit create sql statements.
 * 4.Temp table #tt_invoice_draft has been added.
 * 5.Call Rpt_CoDDraftISp to get data and insert into #tt_invoice_draft.
 * 6.According to #tt_invoice_draft, #tt_invoice_credit_debit  has been Updated, two tables' relative column is invoice number.
 *
 * SL8.02 27 rs4588 Dahn Thu Mar 04 16:25:26 2010
 * rs4580 copyright header changes
 *
 * SL8.01 26 rs3953 Vlitmano Tue Aug 26 17:14:46 2008
 * RS3953 - Changed a Copyright header?
 *
 * SL8.01 25 rs3953 Vlitmano Mon Aug 18 15:36:56 2008
 * Changed a Copyright header information(RS3959)
 *
 * SL8.00 24 95951 Kkrishna Thu Aug 02 03:21:53 2007
 * Euro total not printed on report
 * 95951 replaced the IF condition after the call to EuroInfoSp to check for
 * IF @EuroExists = 1.
 *
 * SL8.00 23 100470 hcl-tiwasun Sat Apr 21 06:27:57 2007
 * When posting the AR Payment and reprinting in A/R Invoice Credit Debit Memo Report, note does not display.
 * Issue# 100470
 * Modified the Rpt_ARInvoiceCreditDebitMemoSp SP to update the correct DocumentRowPointer in resultset.
 *
 * SL8.00 22 99605 hcl-dbehl Fri Apr 06 01:58:01 2007
 * Applied fix for APAR 106418 and notes display in duplicate on A/R Invoice Credit Debit Memo Report
 * Issue# 99605
 * Roll back the changes of APAR#  106418.
 *
 * SL8.00 21 RS2968 nkaleel Fri Feb 23 04:40:52 2007
 * changing copyright information(RS2968)
 *
 * SL8.00 20 99375 hcl-dbehl Fri Feb 16 06:01:13 2007
 * Add note in A/R Posted Transactions Detail form and when you do reprint in A/R Invoice Credit Debit Memo Report, note you added does not display.
 * Issue# 99375
 * Changed the code so that it will handle the notes from artran table as well as journal table(for distribution notes)
 *
 * SL8.00 19 96533 flagatta Wed Feb 14 17:02:43 2007
 * Mexico stub in Rpt_ARInvoiceCreditDebitMemoSp
 * Removed Mexican stub call.  96533
 *
 * SL8.00 18 RS3339 nvennapu Thu Jan 18 06:58:26 2007
 *
 * SL8.00 17 RS2968 prahaladarao.hs Tue Jul 11 11:16:10 2006
 * RS 2968, Name change CopyRight Update.
 *
 * SL8.00 16 91554 sivaprasad.b Thu Jun 01 03:31:43 2006
 * invoice number over 10 produces error even when length is set to 12
 * 91554
 * a. Changed ISNUMERIC(..) for invoice numbers to dbo.IsInteger(..)
 * b. Changed convert(integer, ...) for invoice numbers to convert(bigint, ... )
 *
 * SL8.00 15 91818 NThurn Mon Jan 09 10:33:36 2006
 * Inserted standard External Touch Point call.  (RS3177)
 *
 * SL7.05 14 89482 hcl-kumanav Tue Oct 11 08:36:09 2005
 * Code cleanup
 * Issue# 49482
 * Remove the commented lines
 * Remove @TeuroTotal, @TaxMode unused variables
 * Make Prefix Dbo.Spname
 * Indent the complete Spcode
 * Changes LowString To LowCharacter and HighString to HighCharacter
 *
 * SL7.05 13 RS2560 Hcl-sharpar Wed Sep 07 07:06:52 2005
 * RS2560
 *
 * SL7.05 12 86510 Hcl-tayamoh Wed Mar 30 07:49:21 2005
 * Stub calls needed for Mexican localization
 * Issue 86510
 * Stub calls for Mexican localization
 *
 * SL7.04 12 86510 Hcl-tayamoh Wed Mar 30 07:43:38 2005
 * Stub calls needed for Mexican localization
 * Issue 86510
 * Stub calls for Mexican localization
 *
 * $NoKeywords: $
 */
ALTER PROCEDURE [dbo].[_IEM_Rpt_ARInvoiceCreditDebitMemoSp] (
    @PrePrint             ListYesNoType = NULL
   ,@DocType              InfobarType   = NULL
   ,@PrintDocTxt          ListYesNoType = NULL
   ,@PrintStdOrderTxt     ListYesNoType = NULL
   ,@PrintCustMstrTxt     ListYesNoType = NULL
   ,@DocDate              DateType      = NULL
   ,@TransDomCurr         ListYesNoType = NULL
   ,@PrintEuroTotal       ListYesNoType = NULL
   ,@StartCustomer        CustNumType   = NULL
   ,@EndCustomer          CustNumType   = NULL
   ,@StartInvoice         InvNumType    = NULL
   ,@EndInvoice           InvNumType    = NULL
   ,@StartChkRef          ArInvSeqType  = NULL
   ,@EndChkRef            ArInvSeqType  = NULL
   ,@StartInvDate         GenericDateType = NULL
   ,@EndInvDate           GenericDateType = NULL
   ,@StartIssueDate       GenericDateType = NULL
   ,@EndIssueDate         GenericDateType = NULL
   ,@StartInvDateOffset   DateOffsetType = NULL
   ,@EndInvDateOffset     DateOffsetType = NULL
   ,@StartIssueDateOffset DateOffsetType = NULL
   ,@EndIssueDateOffset   DateOffsetType = NULL
   ,@DocDateOffset        DateOffsetType = NULL
   ,@ShowInternal         FlagNyType     = NULL
   ,@ShowExternal         FlagNyType     = NULL
   ,@BGSessionId          NVARCHAR(255)  = NULL
   ,@PrintDiscountAmt     ListYesNoType = 0
   ,@pVoidOrDraft         NVARCHAR(1)    = NULL
   ,@PrintHeaderOnAllPages ListYesNoType  = NULL 
   ,@pSite                SiteType       = NULL   
)
AS

DECLARE  @Severity  INT

--  Crystal reports has the habit of setting the isolation level to dirty
-- read, so we'll correct that for this routine now.  Transaction management
-- is also not being provided by Crystal, so a transaction is started here.
BEGIN TRANSACTION
SET XACT_ABORT ON

IF dbo.GetIsolationLevel(N'ARInvoiceCreditDebitMemoReport') = N'COMMITTED'
   SET TRANSACTION ISOLATION LEVEL READ COMMITTED
ELSE
   SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- A session context is created so session variables can be used.
DECLARE
   @RptSessionID RowPointerType
  ,@LowCharacterValue HighLowCharType
  ,@HighCharacterValue HighLowCharType
  ,@TempNoteExistsFlag INT
  ,@TempRowPointer RowPointerType
, @Infobar InfobarType


   EXEC InitSessionContextSp
     @ContextName = 'Rpt_ARInvoiceCreditDebitMemoSp'
   , @SessionID   = @RptSessionID OUTPUT
   , @Site        = @pSite

   EXEC CopySessionVariablesSp
     @SessionID = @BGSessionId

   IF @ShowInternal IS NULL SET @ShowInternal = 0
   IF @ShowExternal IS NULL SET @ShowExternal = 0

   SET @LowCharacterValue = dbo.LowCharacter()
   SET @HighCharacterValue = dbo.HighCharacter()
   SET @PrePrint = ISNULL(@PrePrint,1)
   SET @DocType = ISNULL(@DocType, 'I')
   SET @PrintDocTxt = ISNULL(@PrintDocTxt, 0)
   SET @PrintStdOrderTxt = ISNULL(@PrintStdOrderTxt, 1)
   SET @PrintCustMstrTxt = ISNULL(@PrintCustMstrTxt, 0)
   SET @DocDate = ISNULL(@DocDate, dbo.GetSiteDate(getdate()))
   SET @TransDomCurr = ISNULL(@TransDomCurr, 0)
   SET @PrintEuroTotal = ISNULL(@PrintEuroTotal, 0)
   SET @StartCustomer = ISNULL(dbo.ExpandKyByType('CustNumType', @StartCustomer), @LowCharacterValue)
   SET @EndCustomer = ISNULL(dbo.ExpandKyByType('CustNumType', @EndCustomer), @HighCharacterValue)
   SET @PrintHeaderOnAllPages = ISNULL(@PrintHeaderOnAllPages,0)

   IF NOT(dbo.IsInteger(@StartInvoice) = 1 AND CONVERT(BIGINT, @StartInvoice)<= 0)
      SET @StartInvoice = ISNULL(dbo.ExpandKyByType('InvNumType', @StartInvoice), @LowCharacterValue)


   IF NOT(dbo.IsInteger(@EndInvoice) = 1 AND CONVERT(BIGINT, @EndInvoice) <= 0)
      SET @EndInvoice = ISNULL(dbo.ExpandKyByType('InvNumType', @EndInvoice), @HighCharacterValue)


   SET @StartChkRef = ISNULL(@StartChkRef, dbo.LowInt())
   SET @EndChkRef = ISNULL(@EndChkRef, dbo.HighInt())

   -- Check for existence of Generic External Touch Point routine (this section was generated by SpETPCodeSp and inserted by CallETPs.exe):
   IF OBJECT_ID(N'dbo.EXTGEN_Rpt_ARInvoiceCreditDebitMemoSp') IS NOT NULL
   BEGIN
      DECLARE @EXTGEN_SpName sysname
      SET @EXTGEN_SpName = N'dbo.EXTGEN_Rpt_ARInvoiceCreditDebitMemoSp'
      -- Invoke the ETP routine, passing in (and out) this routine's parameters:
      EXEC @EXTGEN_SpName
         @PrePrint
         , @DocType
         , @PrintDocTxt
         , @PrintStdOrderTxt
         , @PrintCustMstrTxt
         , @DocDate
         , @TransDomCurr
         , @PrintEuroTotal
         , @StartCustomer
         , @EndCustomer
         , @StartInvoice
         , @EndInvoice
         , @StartChkRef
         , @EndChkRef
         , @StartInvDate
         , @EndInvDate
         , @StartIssueDate
         , @EndIssueDate
         , @StartInvDateOffset
         , @EndInvDateOffset
         , @StartIssueDateOffset
         , @EndIssueDateOffset
         , @DocDateOffset
         , @ShowInternal
         , @ShowExternal
         , @BGSessionId
         , @PrintDiscountAmt
         , @pVoidOrDraft
         , @PrintHeaderOnAllPages
         , @pSite         
 
      IF @@TRANCOUNT > 0
         COMMIT TRANSACTION
      EXEC dbo.CloseSessionContextSp @SessionID = @RptSessionID
      -- ETP routine must take over all desired functionality of this standard routine:
      RETURN
   END
   -- End of Generic External Touch Point code.
 
   EXEC dbo.ApplyDateOffsetSp @Date = @DocDate OUTPUT, @Offset = @DocDateOffset, @IsEndDate = NULL

   EXEC dbo.ApplyDateOffsetSp @Date = @StartInvDate OUTPUT, @Offset = @StartInvDateOffset, @IsEndDate = 0
   EXEC dbo.ApplyDateOffsetSp @Date = @EndInvDate OUTPUT, @Offset = @EndInvDateOffset, @IsEndDate = 1

   EXEC dbo.ApplyDateOffsetSp @Date = @StartIssueDate OUTPUT, @Offset = @StartIssueDateOffset, @IsEndDate = 0
   EXEC dbo.ApplyDateOffsetSp @Date = @EndIssueDate OUTPUT, @Offset = @EndIssueDateOffset, @IsEndDate = 1

   DECLARE
       @EuroUser  ListYesNoType
      ,@EuroExists  ListYesNoType
      ,@BaseEuro  ListYesNoType
      ,@EuroCurr  CurrCodeType
      ,@Info  InfobarType
      ,@EPlaces  INT
      ,@ErrType  DescriptionType
      ,@TError  ListYesNoType

   DECLARE
       @ArtranInvSeq ArInvSeqType
      ,@ArtranInvNum  InvNumType
      ,@ArtranCustNum  CustNumType
      ,@ParmsSite SiteType

   DECLARE
       @Rowpointer  RowPointerType
      ,@InvDate  DateType
      ,@SlsmanName  SlsmanType
      ,@TaxNum1  DescriptionType
      ,@TaxNum2  DescriptionType
      ,@CustTaxNum1  DescriptionType
      ,@CustTaxNum2  DescriptionType
      ,@CurrCode  DescriptionType
      ,@CustNum  CustNumType
      ,@CustSeq  NVARCHAR(10)
      ,@FaxNum  PhoneType
      ,@CoNum  CoNumType
      ,@CustPO  DescriptionType
      ,@Pkgs  INT
      ,@Prepaid  DescriptionType
      ,@Weight  DescriptionType
      ,@ShipVia  DescriptionType
      ,@Terms  DescriptionType
      ,@ApplyToInvNum  InvNumType
      ,@SaleAmt  AmountType
      ,@DiscAmt  AmountType
      ,@NetAmt  AmountType
      ,@MiscCharges  AmountType
      ,@Freight  AmountType
      ,@SalesTax  AmountType
      ,@SalesTax2  AmountType
      ,@PrepaidAmt  AmountType
      ,@Total  AmountType
      ,@PrintEuro  ListYesNoType
      ,@EuroTotal  AmountType
      ,@TaxSystem  TaxSystemType
      ,@TaxCodeLabel  TaxCodeLabelType
      ,@TaxCode  TaxCodeType
      ,@TaxCodeELabel  TaxCodeLabelType
      ,@TaxCodeE  TaxCodeType
      ,@TaxRate  TaxRateType
      ,@TaxBasis  AmountType
      ,@ExtendedTax  AmountType
      ,@TaxItemLabel  TaxCodeLabelType
      ,@Addr0  NVARCHAR(245)
      ,@Addr1  NVARCHAR(245)
      ,@Addr2  NVARCHAR(245)
      ,@CustNoteExistsFlag  ListYesNoType
      ,@ArtranNoteExistsFlag  ListYesNoType
      ,@ArtranRowpointer  RowpointerType
      ,@CustRowpointer RowpointerType
      ,@TCoText1  ReportTxtType
      ,@TCoText2  ReportTxtType
      ,@TCoText3  ReportTxtType
      ,@PrintLabel  ListYesNoType
      ,@TFaxNum  PhoneType
      ,@TTaxIDLabel1  TaxCodeLabelType
      ,@TTaxIDLabel2  TaxCodeLabelType
      ,@TCustTaxIDLabel1  TaxCodeLabelType
      ,@TCustTaxIDLabel2  TaxCodeLabelType
      ,@TTaxAmtLabel1  TaxCodeLabelType
      ,@TTaxAmtLabel2  TaxCodeLabelType      
      ,@PrintTaxFooter    ListYesNoType
      ,@AmtTotal          WideTextType
      ,@TermsDiscountAmt  AmountType
      ,@BaseTableFlag     ListYesNoType

      , @TxType              INT
      , @InvHdrInvNum       InvNumType
      , @InvHdrCoNum        CoNumType
      , @RptKey              NCHAR(50)
      , @TParmsCompany       NameType
      , @TParmsAddr1         AddressType
      , @TParmsAddr2         AddressType
      , @TParmsZip           PostalCodeType
      , @TParmsCity1         CityType
      , @TParmsCity2         CityType
      , @TArinvAmount1       AmountType
      , @TArinvAmount2       Amounttype
      , @TArinvInvDate       DateType
      , @TArinvDueDate       DateType
      , @TCustNum            CustNumType
      , @TInvNum             InvNumType
      , @TBankNumber         BankNumberType
      , @TBranchCode         BranchCodeType
      , @TBankAcctNo1        BankAccountType
      , @TBankAcctNo2        BankAccountType
      , @TBankAddr1          AddressType
      , @TBankAddr2          AddressType
      , @TCustAddrName       NameType
      , @TCustAddrAddr1      AddressType
      , @TCustAddrZip        PostalCodeType
      , @TCustAddrCity       CityType
      , @TCustdrftDraftNum   DraftNumType
     
   DECLARE
        @OfficeAddrFooter    LongAddress
      , @URL                 URLType
      , @EmailAddr           EmailType
      , @CurrencyCode        CurrCodeType

   -- Check if the temp table exists
IF OBJECT_ID('tempdb..#tt_invoice_credit_debit') IS NULL
BEGIN
     SELECT
          @ArtranInvNum  AS  inv_num
         ,@ArtranInvSeq AS inv_seq
         ,@ParmsSite AS inv_site
         ,@InvDate  AS  inv_date
         ,@SlsmanName  AS  inv_slsman
         ,@TTaxIDLabel1  AS inv_tax_num_lbl1
         ,@TaxNum1  AS inv_tax_num1
         ,@TTaxIDLabel2  AS inv_tax_num_lbl2
         ,@TaxNum2  AS inv_tax_num2
         ,@TCustTaxIDLabel1  AS inv_cust_tax_num_lbl1
         ,@CustTaxNum1  AS inv_cust_tax_num1
         ,@TCustTaxIDLabel2  AS inv_cust_tax_num_lbl2
         ,@CustTaxNum2  AS inv_cust_tax_num2
         ,@TTaxAmtLabel1  AS inv_tax_amt_lbl1        
         ,@TTaxAmtLabel2  AS inv_tax_amt_lbl2          
         ,@CurrCode  AS inv_curr_code
         ,@CustNum  AS inv_cust_num
         ,@CustSeq  AS inv_cust_seq
         ,@FaxNum  AS inv_fax_num
         ,@CoNum  AS inv_co_num
         ,@CustPO  AS inv_cust_po
         ,@Pkgs  AS inv_pkgs
         ,@Prepaid  AS inv_prepaid
         ,@Weight  AS inv_weight
         ,@ShipVia  AS inv_shipvia
         ,@Terms  AS inv_terms
         ,@ApplyToInvNum  AS apply_to_inv_num
         ,@SaleAmt  AS inv_sale_amt
         ,@DiscAmt  AS inv_disc_amt
         ,@NetAmt  AS inv_net_amt
         ,@TCoText1  AS inv_co_text1
         ,@MiscCharges  AS inv_misc_charges
         ,@TCoText2  AS inv_co_text2
         ,@Freight  AS inv_freight
         ,@TCoText3  AS inv_co_text3
         ,@SalesTax  AS inv_sales_tax
         ,@SalesTax2  AS inv_sales_tax2
         ,@PrepaidAmt  AS inv_prepaid_amt
         ,@Total  AS inv_total
         ,@PrintEuro  AS inv_print_euro
         ,@EuroTotal  AS inv_euro_total
         ,@Addr0  AS inv_addr0
         ,@Addr1  AS inv_addr1
         ,@Addr2  AS inv_addr2
         ,@TaxSystem AS tax_system
         ,@TaxCodeLabel  AS tax_code_lbl
         ,@TaxCode  AS tax_code
         ,@TaxCodeELabel  AS tax_code_e_lbl
         ,@TaxCodeE  AS tax_code_e
         ,@TaxRate  AS tax_rate
         ,@TaxBasis  AS tax_basis
         ,@ExtendedTax  AS extended_tax 
         ,@ArtranNoteExistsFlag  AS DocumentNoteExistsFlag
         ,@CustNoteExistsFlag  AS CustomerNoteExistsFlag
         ,@ArtranRowpointer AS DocumentRowpointer
         ,@CustRowpointer AS CustomerRowpointer
         ,@Rowpointer  AS rowpointer
         ,@PrintTaxFooter AS PrintTaxFooter
         ,@AmtTotal  AS amt_total
         ,@TermsDiscountAmt  AS TermsDiscountAmt
         ,@BaseTableFlag as BaseTableFlag

		 , @TxType                  As tx_type                              -- TX=(All)
		 --, @InvHdrInvNum            AS inv_num			         -- Tx=(All)
		 , @InvHdrCoNum             AS co_num			         -- Tx=(All)
		 , @RptKey		            AS rpt_key                              -- Tx=(All)
		 , @TParmsCompany           AS t_parms_company                      -- Tx=30
		 , @TParmsAddr1             AS t_parms_addr1                        -- Tx=30
		 , @TParmsAddr2             AS t_parms_addr2                        -- Tx=30
		 , @TParmsZip               AS t_parms_zip                          -- Tx=30
		 , @TParmsCity1             AS t_parms_city1                        -- Tx=30
		 , @TParmsCity2             AS t_parms_city2                        -- Tx=30
		 , @TArinvAmount1           AS t_arinv_amount1                      -- Tx=30
		 , @TArinvAmount2           AS t_arinv_amount2                      -- Tx=30
		 , @TArinvInvDate           AS t_arinv_inv_date                     -- Tx=30
		 , @TArinvDueDate           AS t_arinv_due_date                     -- Tx=30
		 , @TCustNum                AS t_cust_num                           -- Tx=30
		 , @TInvNum                 AS t_inv_num                            -- Tx=30
		 , @TBankNumber             AS t_bank_number                        -- Tx=30
		 , @TBranchCode             AS t_branch_code                        -- Tx=30
		 , @TBankAcctNo1            AS t_bank_acct_no1                      -- Tx=30
		 , @TBankAcctNo2            AS t_bank_acct_no2                      -- Tx=30
		 , @TBankAddr1              AS t_bank_addr1                         -- Tx=30
		 , @TBankAddr2              AS t_bank_addr2                         -- Tx=30
		 , @TCustAddrName           AS t_custaddr_name                      -- Tx=30
		 , @TCustAddrAddr1          AS t_custaddr_addr1                     -- Tx=30
		 , @TCustAddrZip            AS t_custaddr_zip                       -- Tx=30
		 , @TCustAddrCity           AS t_custaddr_city                      -- Tx=30
		 , @TCustdrftDraftNum       AS t_custdrft_draft_num                 -- Tx=30
        INTO #tt_invoice_credit_debit
        WHERE 1=2
END
-- Declare Temp Table for Report
IF OBJECT_ID('tempdb..#tt_invoice_draft') IS NULL
BEGIN
    SELECT
        @TxType                  As tx_type                              -- TX=(All)
      , @InvHdrInvNum            AS inv_num			         -- Tx=(All)
      , @InvHdrCoNum             AS co_num			         -- Tx=(All)
      , @RptKey		         AS rpt_key                              -- Tx=(All)
      , @TParmsCompany           AS t_parms_company                      -- Tx=30
      , @TParmsAddr1             AS t_parms_addr1                        -- Tx=30
      , @TParmsAddr2             AS t_parms_addr2                        -- Tx=30
      , @TParmsZip               AS t_parms_zip                          -- Tx=30
      , @TParmsCity1             AS t_parms_city1                        -- Tx=30
      , @TParmsCity2             AS t_parms_city2                        -- Tx=30
      , @TArinvAmount1           AS t_arinv_amount1                      -- Tx=30
      , @TArinvAmount2           AS t_arinv_amount2                      -- Tx=30
      , @TArinvInvDate           AS t_arinv_inv_date                     -- Tx=30
      , @TArinvDueDate           AS t_arinv_due_date                     -- Tx=30
      , @TCustNum                AS t_cust_num                           -- Tx=30
      , @TInvNum                 AS t_inv_num                            -- Tx=30
      , @TBankNumber             AS t_bank_number                        -- Tx=30
      , @TBranchCode             AS t_branch_code                        -- Tx=30
      , @TBankAcctNo1            AS t_bank_acct_no1                      -- Tx=30
      , @TBankAcctNo2            AS t_bank_acct_no2                      -- Tx=30
      , @TBankAddr1              AS t_bank_addr1                         -- Tx=30
      , @TBankAddr2              AS t_bank_addr2                         -- Tx=30
      , @TCustAddrName           AS t_custaddr_name                      -- Tx=30
      , @TCustAddrAddr1          AS t_custaddr_addr1                     -- Tx=30
      , @TCustAddrZip            AS t_custaddr_zip                       -- Tx=30
      , @TCustAddrCity           AS t_custaddr_city                      -- Tx=30
      , @TCustdrftDraftNum       AS t_custdrft_draft_num                 -- Tx=30
   INTO #tt_invoice_draft
   WHERE 1=2
END
DECLARE @artran_crs CURSOR
EXEC @Severity = Dbo.EuroInfoSp  @DispMsg=0, @PEuroUser=@EuroUser OUTPUT, @PEuroExists=@EuroExists OUTPUT, @PBaseEuro=@BaseEuro OUTPUT, @PEuroCurr=@EuroCurr OUTPUT, @InfoBar=@Info OUTPUT

IF @EuroExists = 1
BEGIN
     SELECT @EPlaces = places
     FROM currency
     WHERE curr_code = @EuroCurr

     IF @@ROWCOUNT = 0
     SET @EPlaces = 2
END

EXEC dbo.MsgAppSp @Infobar = @ErrType OUTPUT, @BaseMsg = 'E=Invalid' , @Parm1 = '@artran.type'


IF @PrePrint = 0
 BEGIN
 SET @artran_crs = CURSOR LOCAL STATIC FOR
      SELECT
        artran.RowPointer
      , artran.cust_num
      , artran.inv_seq
      , artran.inv_num
      , artran.NoteExistsFlag
      FROM artran
      WHERE (artran.cust_num BETWEEN @StartCustomer AND @EndCustomer)
         AND (artran.inv_num BETWEEN @StartInvoice AND @EndInvoice)
         AND (artran.inv_seq BETWEEN @StartChkRef AND @EndChkRef)
         AND (artran.inv_date BETWEEN @StartInvDate AND @EndInvDate)
         AND (artran.type = @DocType)
         AND (artran.issue_date IS NULL)
         AND (artran.post_from_co = 0)

 END
ELSE

 BEGIN
 SET @artran_crs = CURSOR LOCAL STATIC FOR
 select null
 , inv_hdr.cust_num
 , inv_hdr.inv_seq
 , inv_hdr.inv_num
 , inv_hdr.NoteExistsFlag
 from inv_hdr
 where inv_hdr.cust_num between @StartCustomer and @EndCustomer
 and inv_hdr.inv_num between @StartInvoice and @EndInvoice
 and inv_hdr.inv_seq between @StartChkRef and @EndChkRef
 and inv_hdr.inv_date between @StartInvDate and @EndInvDate
 and exists (select 1 from artran where artran.inv_num = inv_hdr.inv_num
         AND (artran.issue_date BETWEEN @StartIssueDate AND @EndIssueDate)
         AND (artran.type = @DocType)
         AND (artran.issue_date IS NOT NULL)
         AND (artran.post_from_co = 0))
ORDER BY inv_hdr.inv_seq
 END

OPEN @artran_crs
WHILE 1=1
BEGIN
  SET @TempNoteExistsFlag = 0
  SET @TempRowPointer = NULL
  FETCH @artran_crs INTO
        @ArtranRowpointer
      , @ArtranCustNum
      , @ArtranInvSeq
      , @ArtranInvNum
      , @TempNoteExistsFlag

     IF @@FETCH_STATUS <> 0 BREAK

     IF @PrePrint = 0
     BEGIN
         UPDATE artran
         SET artran.issue_date = @DocDate
         WHERE artran.RowPointer = @ArtranRowpointer
     END
      -- * RUN PRINT INVOICE
     EXEC dbo.PrintInvoiceSp @CustomerNum = @ArtranCustNum, @InvoiceNum = @ArtranInvNum, @InvoiceSeq = @ArtranInvSeq
               , @EPlaces = @EPlaces, @EuroExists = @EuroExists, @DocType = @DocType, @PrintDocTxt = @PrintDocTxt
               , @PrintStdOrderTxt = @PrintStdOrderTxt, @PrintCustMstrTxt = @PrintCustMstrTxt
               , @TransDomCurr = @TransDomCurr, @PrintEuroTotal = @PrintEuroTotal, @ShowInternal = @ShowInternal
               , @ShowExternal = @ShowExternal,@DocDate=@DocDate, @Error = @TError OUTPUT
               , @Infobar = @Infobar output
               , @PrePrint = @PrePrint

 IF @DocType ='C' and @TempNoteExistsFlag = 0
    SELECT @TempRowPointer=rowpointer from JOURNAL WHERE voucher=@ArtranInvNum and NoteExistsFlag=1

 IF @TempRowPointer IS NOT NULL
    UPDATE #tt_invoice_credit_debit SET DocumentNoteExistsFlag=1, DocumentRowpointer= @TempRowPointer, BaseTableFlag =1
    WHERE Inv_Num=@ArtranInvNum

 Begin
     delete from #tt_invoice_draft

   --  BECAUSE THIS PROCEDURE WRAPS ANOTHER, MY WRAPPER DOES NOT WORK. I HAVE COMMENTED THIS OUT UNTIL I CAN LEARN HOW TO GET AROUND THIS. -- DBH / 2016-11-07
	 /*Insert #tt_invoice_draft 		
		Exec dbo.Rpt_CoDDraftISp @InvCred = @DocType ,@pInvHdrInvNum = @ArtranInvNum,@pInvHdrCoNum = @ArtranCustNum, @pVoidOrDraft = @pVoidOrDraft , @BGSessionId = @BGSessionId, @pSite = @pSite*/
		
	Update #tt_invoice_credit_debit set
	    tx_type = Draft.tx_type
      , co_num = Draft.co_num
      , rpt_key = Draft.rpt_key
      , t_parms_company = Draft.t_parms_company
      , t_parms_addr1 = Draft.t_parms_addr1
      , t_parms_addr2 = Draft.t_parms_addr2
      , t_parms_zip = Draft.t_parms_zip
      , t_parms_city1 = Draft.t_parms_city1
      , t_parms_city2 = Draft.t_parms_city2
      , t_arinv_amount1 = Draft.t_arinv_amount1
      , t_arinv_amount2 = Draft.t_arinv_amount2
      , t_arinv_inv_date = Draft.t_arinv_inv_date
      , t_arinv_due_date = Draft.t_arinv_due_date
      , t_cust_num = Draft.t_cust_num
      , t_inv_num = Draft.t_inv_num
      , t_bank_number = Draft.t_bank_number
      , t_branch_code = Draft.t_branch_code
      , t_bank_acct_no1 = Draft.t_bank_acct_no1
      , t_bank_acct_no2 = Draft.t_bank_acct_no2
      , t_bank_addr1 = Draft.t_bank_addr1
      , t_bank_addr2 = Draft.t_bank_addr2
      , t_custaddr_name = Draft.t_custaddr_name
      , t_custaddr_addr1 = Draft.t_custaddr_addr1
      , t_custaddr_zip = Draft.t_custaddr_zip
      , t_custaddr_city = Draft.t_custaddr_city
      , t_custdrft_draft_num = Draft.t_custdrft_draft_num 
      from #tt_invoice_draft Draft where Draft.inv_num = #tt_invoice_credit_debit.inv_num

 END
END
CLOSE @artran_crs
DEALLOCATE @artran_crs

SET @OfficeAddrFooter = dbo.DisplayAddressForReportFooter()

SELECT  
   @URL = parms.url
FROM parms (READUNCOMMITTED) 
WHERE parm_key = 0

SELECT
   @EmailAddr = arparms.email_addr
FROM arparms WITH (READUNCOMMITTED)

SELECT
   @CurrencyCode = currparms.curr_code
FROM currparms WITH (READUNCOMMITTED)

SELECT #tt_invoice_credit_debit.*,
@OfficeAddrFooter AS office_addr_footer,
@URL AS url,
@EmailAddr AS email_addr,
@CurrencyCode AS currency_code,
artran.due_date As due_date,
bank_hdr.name AS t_bank_name,
bank_hdr.bank_transit_num AS t_bank_transit_num,
customer.bank_acct_no AS t_bank_acct_no
FROM #tt_invoice_credit_debit
LEFT JOIN artran ON artran.inv_num = #tt_invoice_credit_debit.inv_num AND artran.type = 'I' -- DBH 11/15/16 prevents duplicate records
LEFT JOIN customer ON customer.cust_num = artran.cust_num AND customer.cust_seq = 0
LEFT JOIN bank_hdr ON customer.cust_bank = bank_hdr.bank_code

COMMIT TRANSACTION

--Added to call Mexican Country Pack program
IF OBJECT_ID(N'dbo.ZMX_CFDGenSp') IS NOT NULL
BEGIN
	SET @EXTGEN_SpName = N'dbo.ZMX_CFDGenSp'
	EXEC @EXTGEN_SpName
		 @InvCred				 = @DocType ,
		 @PrintEuro				 = @PrintEuroTotal ,
		 @PrintStandardOrderText = @PrintStdOrderTxt ,
		 @PrintDiscountAmt		 = @PrintDiscountAmt ,
		 @TransToDomCurr		 = @TransDomCurr ,
		 @PrintCustomerNotes	 = @PrintCustMstrTxt ,
		 @PrintInvNotes			 = @PrintDocTxt ,
		 @PrintInternalNotes	 = @ShowInternal ,
		 @PrintExternalNotes	 = @ShowExternal ,
		 @TableName				 = 'arinvoice'
END

EXEC dbo.CloseSessionContextSp @SessionID = @RptSessionID
RETURN @Severity
GO

