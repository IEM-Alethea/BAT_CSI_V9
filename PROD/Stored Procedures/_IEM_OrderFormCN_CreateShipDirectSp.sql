SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[_IEM_OrderFormCN_CreateShipDirectSp] (
	 @Item				ItemType
	,@Description		DescriptionType
	,@CoNum				CoNumType
	,@CoLine			CoLineType
	,@QtyOrderedConv	QtyUnitType
	,@ItemDesc			DescriptionType
	,@ItemUM			UMType
	,@Whse				WhseType
	,@CustNum			CustNumType
	,@CustSeq			CustSeqType
	,@Vendor			VendNumType
	,@VendorPrice		CostPrcType
	,@DropShipNumber	INT
	,@DueDate			DateType
	,@Infobar			InfobarType OUTPUT
)
AS
BEGIN
	
	DECLARE 
		 @Severity INT = 0
		,@Site SiteType
		,@ToPoNum PoNumType
		,@ToPoLine PoLineType
		,@ToPoRelease PoReleaseType

		IF NOT EXISTS(SELECT * FROM vendor WHERE vend_num = @Vendor)
		BEGIN
			PRINT @Vendor
			PRINT 'Vendor not found.'
			SET @Infobar = 'Invalid vendor ' + ISNULL(@Vendor,'NULL') + ' specified for ship direct item ' + @item + '.'
			SET @Severity = 16
			RETURN @Severity
		END

		PRINT '2'

		set @ToPoNum = NULL

		SELECT TOP 1 @ToPoNum = pi.po_num--, @ToPoLine = pi.po_line
		FROM poitem pi
		INNER JOIN po ON po.po_num = pi.po_num
		WHERE po.vend_num = @Vendor
			AND pi.ref_type = 'O'
			AND pi.ref_num = @CoNum
			--AND pi.ref_line_suf = @CoLine
			AND po.drop_ship_no = @CustNum
			AND po.drop_seq = ISNULL(@DropShipNumber,@CustSeq)
			AND po.stat = 'P' --only add if PO not already placed
			AND po.vend_num <> 'V009999' -- djh 2017-02-07.  do not group unknown vendor POs together


		PRINT 'Updating coitem ref_type to P'
		UPDATE coitem
		SET ref_type = 'P'
		WHERE co_num = @CoNum
			AND co_line = @CoLine
			--AND ref_type <> 'P'

		PRINT 'Creating PO xref'

		DECLARE @poDate DateType
		set @poDate=ISNULL(@DueDate, '2/22/2222')

		EXECUTE @Severity = [dbo].[CoitemXrefSp] 
				@CoNum = @CoNum
			,@CoLine = @CoLine
			,@CoRelease = 0
			,@RefType = 'P'
			,@RefNum = @ToPoNum
			,@RefLineSuf = @ToPoLine
			,@RefRelease = 0
			,@Item = @Item
			,@ItemDescription = @ItemDesc
			,@UM = @ItemUM
			,@CoStat = 'O'
			,@QtyOrdered = @QtyOrderedConv
			,@DueDate = @poDate
			,@Whse = @Whse
			,@FromWhse = @Whse
			,@FromSite = @Site
			,@ToSite = @Site
			,@PoChangeOrd = NULL
			,@MpwxrefDelete = 0
			,@CreateProj = 0
			,@CreateProjtask = 0
			,@CurRefNum = @ToPoNum OUTPUT
			,@CurRefLineSuf = @ToPoLine OUTPUT
			,@CurRefRelease = @ToPoRelease OUTPUT
			,@TrnLoc = NULL
			,@FOBSite = NULL
			,@ItemLocQuestionAsked = NULL --OUTPUT
			,@PromptMsg = NULL --OUTPUT
			,@PromptButtons = NULL --OUTPUT
			,@Infobar = @Infobar OUTPUT
			,@ExportType = 'N'

		UPDATE po
		SET vend_num = @Vendor
			,drop_ship_no = @CustNum
			,drop_seq = ISNULL(@DropShipNumber,@CustSeq)
			,ship_addr = 'C'
		WHERE po_num = @ToPoNum

		UPDATE poitem
		SET item_cost = @VendorPrice, item_cost_conv = @VendorPrice, unit_mat_cost = @VendorPrice, unit_mat_cost_conv = @VendorPrice
		WHERE po_num = @ToPoNum
			AND po_line = @ToPoLine

	
	RETURN @Severity
END
GO

