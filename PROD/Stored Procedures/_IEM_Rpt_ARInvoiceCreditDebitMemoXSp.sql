SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[_IEM_Rpt_ARInvoiceCreditDebitMemoXSp] (

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
) AS

DECLARE @ReportSet TABLE(
		  inv_num					InvNumType
		, inv_seq					InvSeqType
		, inv_site					SiteType
		, inv_date					DateType
		, inv_slsman				SlsmanType
		, inv_tax_num_lbl1			TaxCodeLabelType
		, inv_tax_num1				WideTextType	
		, inv_tax_num_lbl2			TaxCodeLabelType
		, inv_tax_num2				WideTextType	
		, inv_cust_tax_num_lbl1		TaxCodeLabelType
		, inv_cust_tax_num1			WideTextType	
		, inv_cust_tax_num_lbl2		TaxCodeLabelType
		, inv_cust_tax_num2			WideTextType	
		, inv_tax_amt_lbl1			TaxCodeLabelType      
		, inv_tax_amt_lbl2          TaxCodeLabelType
		, inv_curr_code				DescriptionType
		, inv_cust_num				CustNumType
		, inv_cust_seq				NVARCHAR(10)
		, inv_fax_num				PhoneType
		, inv_co_num				CoNumType
		, inv_cust_po				WideTextType
		, inv_pkgs					PackagesType
		, inv_prepaid				DescriptionType
		, inv_weight				DescriptionType
		, inv_shipvia				DescriptionType
		, inv_terms					DescriptionType
		, apply_to_inv_num			InvNumType
		, inv_sale_amt				AmountType
		, inv_disc_amt				AmountType
		, inv_net_amt				AmountType
		, inv_co_text1				ReportTxtType
		, inv_misc_charges			AmountType
		, inv_co_text2				ReportTxtType
		, inv_freight				AmountType
		, inv_co_text3				ReportTxtType
		, inv_sales_tax				AmountType
		, inv_sales_tax2			AmountType
		, inv_prepaid_amt			AmountType
		, inv_total					AmountType
		, inv_print_euro			ListYesNoType
		, inv_euro_total			AmountType
		, inv_addr0					NVARCHAR(245)
		, inv_addr1					NVARCHAR(245)
		, inv_addr2					NVARCHAR(245)
		, tax_system				TaxSystemType
		, tax_code_lbl				TaxCodeLabelType
		, tax_code					TaxCodeType
		, tax_code_e_lbl			TaxCodeLabelType
		, tax_code_e				TaxCodeType
		, tax_rate					TaxRateType
		, tax_basis					AmountType
		, extended_tax 				AmountType
		, DocumentNoteExistsFlag	FlagNyType
		, CustomerNoteExistsFlag	FlagNyType
		, DocumentRowpointer		RowPointerType
		, CustomerRowpointer		RowPointerType
		, rowpointer				RowPointerType
		, PrintTaxFooter			ListYesNoType
		, amt_total					WideTextType
		, TermsDiscountAmt			AmountType
		, BaseTableFlag				ListYesNoType
		, tx_type					INT
		, co_num					CoNumType
		, rpt_key					NCHAR(50)
		, t_parms_company			NameType
		, t_parms_addr1				AddressType
		, t_parms_addr2				AddressType
		, t_parms_zip				PostalCodeType
		, t_parms_city1				CityType
		, t_parms_city2				CityType
		, t_arinv_amount1			AmountType
		, t_arinv_amount2			Amounttype
		, t_arinv_inv_date			DateType
		, t_arinv_due_date			DateType
		, t_cust_num				CustNumType
		, t_inv_num					InvNumType
		, t_bank_number				BankNumberType
		, t_branch_code				BranchCodeType
		, t_bank_acct_no1			BankAccountType
		, t_bank_acct_no2			BankAccountType
		, t_bank_addr1				AddressType
		, t_bank_addr2				AddressType
		, t_custaddr_name			NameType
		, t_custaddr_addr1			AddressType
		, t_custaddr_zip			PostalCodeType
		, t_custaddr_city			CityType
		, t_custdrft_draft_num		DraftNumType
		, office_addr_footer		LongAddress
		, url						URLType
		, email_addr				EmailType
		, currency_code				CurrCodeType
		, due_date					DateType
		, t_bank_name				NameType
		, t_bank_transit_num		BankTransitNumType
		, t_bank_acct_no			BankAccountType
		)

INSERT INTO @ReportSet

EXEC _IEM_Rpt_ARInvoiceCreditDebitMemoSp

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

--This allows for notes added via A/R Posted Transactions Detail to be included
UPDATE rs
	SET rs.DocumentRowpointer = at.Rowpointer, rs.DocumentNoteExistsFlag = 1
		FROM @ReportSet rs
			JOIN artran at
				ON at.inv_num = rs.inv_num AND at.type <> 'P'
			JOIN inv_hdr ih
				ON ih.RowPointer = rs.DocumentRowpointer
			JOIN objectnotes ojn
				ON ojn.RefRowPointer = at.Rowpointer

--Update blank Customer Sequence if order number specified
UPDATE rs1
SET inv_cust_seq = co.cust_seq
	FROM @ReportSet rs1
		LEFT JOIN co
			ON rs1.inv_co_num = co.co_num
		WHERE inv_cust_seq = '' AND co.co_num IS NOT NULL

--Update Invoice-To address to match standard invoice format
UPDATE rs1
SET inv_addr1 = dbo.FormatAddressWithContactSp ( rs2.inv_cust_num, 0, NULL)
	FROM @ReportSet rs1
		LEFT JOIN
			(SELECT	* FROM @ReportSet) rs2
				ON rs1.inv_co_num = rs2.inv_co_num
/*
--Update Deliver-To address to match standard invoice format
UPDATE rs1
SET inv_addr2 = dbo._IEM_FormatAddressWithContactSp ( rs2.inv_cust_num, rs2.inv_cust_seq, NULL)
	FROM @ReportSet rs1
		LEFT JOIN
			(SELECT	* FROM @ReportSet) rs2
				ON rs1.inv_co_num = rs2.inv_co_num
	WHERE rs2.inv_cust_seq <> ''*/

--Update blank Customer Purchase Order if order number specified
UPDATE rs1
SET inv_cust_po = co.cust_po
	FROM @ReportSet rs1
		LEFT JOIN co
			ON rs1.inv_co_num = co.co_num
		WHERE inv_cust_po = '' AND co.co_num IS NOT NULL

--Updates invoice date to match inv_hdr inv_date
UPDATE rs1
SET rs1.inv_date = ih.inv_date
	FROM @ReportSet rs1
		LEFT JOIN inv_hdr ih
			ON ih.inv_num = rs1.inv_num



SELECT	rs.*,
		art.description,
		NULL AS Uf_JobName,
		co.contact AS ocontact,
			CASE WHEN sls.outside = 0
				THEN dbo.GetEmployeeName(emp.emp_num)
				ELSE va.name END
			+ CASE WHEN rs.inv_slsman = ''
				THEN ' (' + ISNULL(co.slsman,ih.slsman) + ')'
				ELSE ' (' + inv_slsman + ')' END
		AS inv_slsname,
		NULL AS Resale_cert
		, LEFT(rs.inv_addr1, CHARINDEX(CHAR(10), rs.inv_addr1) - 1) AS TopLineShipTo
		, RIGHT(rs.inv_addr1, LEN(rs.inv_addr1) - CHARINDEX(CHAR(10), rs.inv_addr1)) AS RemainShipTo
		, LEFT(IIF(rs.inv_addr2 IS NULL OR rs.inv_addr2 = '', rs.inv_addr1, rs.inv_addr2), CHARINDEX(CHAR(10)
				, IIF(rs.inv_addr2 IS NULL OR rs.inv_addr2 = '', rs.inv_addr1, rs.inv_addr2)) - 1) AS TopLineShipTo2
		, RIGHT(IIF(rs.inv_addr2 IS NULL OR rs.inv_addr2 = '', rs.inv_addr1, rs.inv_addr2)
				, LEN(IIF(rs.inv_addr2 IS NULL OR rs.inv_addr2 = '', rs.inv_addr1, rs.inv_addr2)) - CHARINDEX(CHAR(10)
				, IIF(rs.inv_addr2 IS NULL OR rs.inv_addr2 = '', rs.inv_addr1, rs.inv_addr2))) AS RemainShipTo2
		FROM @ReportSet rs
		LEFT JOIN artran art
			ON rs.inv_num = art.inv_num AND art.type <> 'P'
		LEFT JOIN co ON
			co.co_num = rs.inv_co_num
		LEFT JOIN inv_hdr ih
			ON ih.inv_num = rs.inv_num
		LEFT JOIN slsman sls
			ON sls.slsman = CASE WHEN rs.inv_slsman = '' THEN ISNULL(co.slsman,ih.slsman) ELSE inv_slsman END
		LEFT JOIN employee emp
			ON emp.emp_num = sls.ref_num
		LEFT JOIN vendaddr va
			ON va.vend_num = sls.ref_num


GO

