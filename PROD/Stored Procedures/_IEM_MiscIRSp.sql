SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[_IEM_MiscIRSp]

		  @TrxType							NVARCHAR(1)
		, @ReasonCode						ReasonCodeType
		, @ReasonClass						ReasonClassType
		, @TransQty							QtyUnitType
		, @Whse								WhseType
		, @Item								ItemType
		, @Loc								LocType
		, @Lot								LotType
		, @Infobar							InfobarType	OUTPUT

AS

BEGIN

DECLARE	  @RC								INT							    = NULL
		, @SET								ProcessIndType				    = NULL
		, @TransDate						DateType					    = NULL
		, @Acct								AcctType					    = NULL
		, @AcctUnit1						UnitCode1Type				    = NULL
		, @AcctUnit2						UnitCode2Type				    = NULL
		, @AcctUnit3						UnitCode3Type				    = NULL
		, @AcctUnit4						UnitCode4Type				    = NULL
		, @FromSite							SiteType					    = NULL
		, @ToSite							SiteType					    = NULL
		, @TrnNum							TrnNumType					    = NULL
		, @TrnLine							TrnLineType					    = NULL
		, @TransNum							HugeTransNumType			    = NULL
		, @RsvdNum							RsvdNumType					    = NULL
		, @SerialStat						SerialStatusType			    = NULL
		, @Workkey							NVARCHAR(80)				    = NULL
		, @Override							ListYesNoType				    = NULL
		, @MatlCost							CostPrcType					    = NULL
		, @LbrCost							CostPrcType					    = NULL
		, @FovhdCost						CostPrcType					    = NULL
		, @VovhdCost						CostPrcType					    = NULL
		, @OutCost							CostPrcType					    = NULL
		, @TotalCost						CostPrcType					    = NULL
		, @ProfitMarkup						CostPrcType					    = NULL
		, @ToWhse							WhseType					    = NULL
		, @ToLoc							LocType						    = NULL
		, @ToLot							LotType						    = NULL
		, @TransferTrxType					NVARCHAR(1)					    = NULL
		, @TmpSerId							RowPointerType				    = NULL
		, @UseExistingSerials				ListYesNoType				    = NULL
		, @SerialPrefix						SerialPrefixType			    = NULL
		, @RemoteSiteLot					ListExistingCreateBothType	    = NULL
		, @DocumentNum						DocumentNumType				    = NULL
		, @ImportDocId						ImportDocIdType				    = NULL
		, @MoveZeroCostItem					ListYesNoType				    = NULL
		, @EmpNum							EmpNumType					    = NULL
		, @SkipItemlocDelete				ListYesNoType				    = NULL
		, @description						DescriptionType					= NULL
		, @accessUnit1						UnitCodeAccessType				= NULL
		, @accessUnit2						UnitCodeAccessType				= NULL
		, @accessUnit3						UnitCodeAccessType				= NULL
		, @accessUnit4						UnitCodeAccessType				= NULL
		, @RptSessionID						RowPointerType					= NULL
		, @pSite							SiteType						= NULL

EXEC dbo.InitSessionContextSp
     @ContextName = '_IEM_MiscIRSp'
   , @SessionID   = @RptSessionID OUTPUT
   , @Site        = @pSite

SET	@TransDate = GETDATE()

EXECUTE ReasonGetInvAdjAcctSp 
	  @ReasonCode		= @ReasonCode
	, @ReasonClass		= @ReasonClass
	, @Item				= @item
	, @Acct				= @acct         OUTPUT
	, @AcctUnit1		= @acctUnit1    OUTPUT
	, @AcctUnit2		= @acctUnit2    OUTPUT
	, @AcctUnit3		= @acctUnit3    OUTPUT
	, @AcctUnit4		= @acctUnit4    OUTPUT
	, @AccessUnit1		= @accessUnit1  OUTPUT
	, @AccessUnit2		= @accessUnit2  OUTPUT
	, @AccessUnit3		= @accessUnit3  OUTPUT
	, @AccessUnit4		= @accessUnit4  OUTPUT
	, @Description		= @description  OUTPUT
	, @Infobar			= @Infobar      OUTPUT
	, @ByContainer		= 0
	, @AcctIsControl	= NULL

EXECUTE @RC = [dbo].[IaPostSetVarsSp] 
	  @SET				= 'S'
	, @TrxType          = @TrxType
	, @TransDate        = @TransDate
	, @Acct             = @Acct
	, @AcctUnit1        = @acctUnit1
	, @AcctUnit2        = @acctUnit2
	, @AcctUnit3        = @acctUnit3
	, @AcctUnit4        = @acctUnit4
	, @TransQty         = @TransQty
	, @Whse             = @Whse
	, @Item             = @Item
	, @Loc              = @Loc
	, @ReasonCode       = @ReasonCode
	, @MatlCost         = @MatlCost	    OUTPUT
	, @LbrCost          = @LbrCost	    OUTPUT
	, @FovhdCost        = @FovhdCost    OUTPUT
	, @VovhdCost        = @VovhdCost    OUTPUT
	, @OutCost          = @OutCost      OUTPUT
	, @TotalCost        = @TotalCost    OUTPUT
	, @ProfitMarkup     = @ProfitMarkup OUTPUT
	, @Infobar          = @Infobar      OUTPUT

BEGIN TRANSACTION

EXECUTE @RC = [dbo].[IaPostSp] 
	  @TrxType
	, @TransDate
	, @Acct
	, @AcctUnit1
	, @AcctUnit2
	, @AcctUnit3
	, @AcctUnit4
	, @TransQty
	, @Whse
	, @Item
	, @Loc
	, @Lot
	, @FromSite
	, @ToSite
	, @ReasonCode
	, @TrnNum
	, @TrnLine
	, @TransNum
	, @RsvdNum
	, @SerialStat
	, @Workkey
	, @Override
	, @MatlCost							OUTPUT
	, @LbrCost							OUTPUT
	, @FovhdCost						OUTPUT
	, @VovhdCost						OUTPUT
	, @OutCost							OUTPUT
	, @TotalCost						OUTPUT
	, @ProfitMarkup						OUTPUT
	, @Infobar							OUTPUT
	, @ToWhse
	, @ToLoc
	, @ToLot
	, @TransferTrxType
	, @TmpSerId
	, @UseExistingSerials
	, @SerialPrefix
	, @RemoteSiteLot
	, @DocumentNum
	, @ImportDocId
	, @MoveZeroCostItem
	, @EmpNum
	, @SkipItemlocDelete

COMMIT TRANSACTION

PRINT @Infobar

RETURN @RC

END


GO

