SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[_IEM_Rpt_JobPickListSp] (
   @Job                     JobType             = NULL,          --V(Job)
   @Suffix		            SuffixType          = NULL,          --V(Suffix) CHANGED FROM @Suffix = SuffixType TO ALLOW FOR DISCRETE SELECTION DBH 4/5/16
   @Item                    ItemType            = NULL,          --V(Item)
   @Whse                    WhseType            = NULL,          --V(Warehouse)
   @PostDate                DateType            = NULL,          --V(PostDate)
   @StartingOperNum         GenericIntType      = NULL,          --V(StartingOperNum)
   @EndingOperNum           GenericIntType      = NULL,          --V(EndingOperNum)
   @SortByLoc               ListYesNoType       = NULL,          --V(SortByLoc)
   @IncludeSerialNumbers    ListYesNoType       = NULL,          --V(IncludeSerialNumbers)
   @ReprintPickListItems    ListYesNoType       = NULL,          --V(ReprintPickListItems)
   @PostMaterialIssues		ListYesNoType		= NULL,		
   @PageBetweenOperations   ListYesNoType       = NULL,          --V(PageBetweenOperations)
   @PrintSecondaryLocations INT                 = NULL,          --V(PrintSecondaryLocations)
   @ExtendByScrapFactor     ListYesNoType       = NULL,          --V(ExtendbyScrapFactor)
   @PrintBarCode            ListYesNoType       = NULL,          --V(PrintBarCode)
   @DisplayHeader           ListYesNoType       = NULL,          --V(DisplayHeader)
   @PMessageLanguage        MessageLanguageType = NULL,          --V(MessageLanguage)
   @TaskID                  TasknumType         = NULL,
   @UserID                  TokenType           = NULL,
   @BGSessionId             nvarchar(255)       = NULL,
   @pSite                   SiteType            = NULL

) AS

-- A session context is created so session variables can be used.
DECLARE
  @RptSessionID RowPointerType

EXEC dbo.InitSessionContextSp
  @ContextName = '_IEM_Rpt_JobPickListSp'
, @SessionID   = @RptSessionID OUTPUT
, @Site        = @pSite

EXEC dbo.CopySessionVariablesSp
  @SessionID = @BGSessionId

IF OBJECT_ID('tempdb..#PicklistX') IS NOT NULL DROP TABLE #PicklistX

CREATE TABLE #PickListX (
      hdr_Job                NVARCHAR(30),    --@FormattedJob
      hdr_JobDate            DATETIME,        --@JobJobDate
      hdr_JobStat            NCHAR,           --@JobStat
      hdr_JobStatDesc        NVARCHAR(30),    --@JobStatDesc
      hdr_JobSchEndDate      DATETIME,        --@JobSchEndDate
      hdr_ProdMix            NVARCHAR(7),     --@JobProdMix
      hdr_ProdMixDesc        NVARCHAR(40),    --@ProdmixDescription
      hdr_JobItem            NVARCHAR(30),    --@JobItem
      hdr_JobItemDesc        NVARCHAR(40),    --@JobDescription
      hdr_JobQtyReleased     DECIMAL(19,8),   --@JobQtyReleased
      hdr_JobRevision        NVARCHAR(8),     --@JobRevision
      hdr_JobWhse            NVARCHAR(4),     --@JobWhse
      sub_JobMatlOperNum     INT,             --@lJobmatlOperNum
      sub_JobRouteWC         NVARCHAR(6),     --@JobrouteWc
      sub_WCDecription       NVARCHAR(40),    --@WCDescription
      sub_JrtSchStartDate    DATETIME,        --@JrtSchStartDate
      sub_JrtSchEndDate      DATETIME,        --@JrtSchEndDate
      det_OperNum            INT,             --@OperNum
      det_JobSequence        NVARCHAR(30),    --@lJobmatlSeq
      det_JobMatlItem        NVARCHAR(30),    --@lJobmatlItem
      det_JobMatlDescription NVARCHAR(40),    --@DerItemDescription
      det_JobMatlU_M         NVARCHAR(3),     --@lJobmatlUM
      det_TotalRequired      DECIMAL(19,8),   --@QtuRequired
      det_JobMatlQtyIssued   DECIMAL(19,8),   --@lJobmatlQtyIssued
      det_QtyAvailable       DECIMAL(19,8),   --@QtuRequired
      det_QtyToPick          DECIMAL(19,8),   --@QtuPickQty
      det_Location           NVARCHAR(100),    --@Loc -- needs to be able to hold an error message
      det_LotDescription     NVARCHAR(40),    --@Lot
      det_JobPicked          TINYINT,         --@JobPicked
      det_Reprint            BIT,             --@Reprint Material
      det_QtyRequiredToPick  NVARCHAR(1),     --@Asterisk
      det_Exception          NVARCHAR(100),   --@Exception
      det_SerialNum          NVARCHAR(60),    --@SerialNumber
      suba_CoProdExist       TINYINT,         --@CoProdExist
      coprod_item            NVARCHAR(30),    --@CoProdItem
      coprod_itemdesc        NVARCHAR(40),    --@CoProdItemDescription
      coprod_QtyReleased     DECIMAL(19,8),   --@CoProdQtyReleased
      coprod_U_M             NVARCHAR(3),     --@CoProdUM
      nettable               TINYINT,         --@Nettable
      qty_unit_format        NVARCHAR(60),    --@QtyUnitFormat
      places_qty_unit        TINYINT          --@PlacesQtyUnit
    )

			BEGIN TRY 
				INSERT INTO #PicklistX
					EXEC Rpt_JobPickListSp
						@Job                    
					   ,@Suffix                 
					   ,@Item                   
					   ,@Whse                   
					   ,@PostDate               
					   ,@StartingOperNum        
					   ,@EndingOperNum          
					   ,@SortByLoc              
					   ,@IncludeSerialNumbers   
					   ,@ReprintPickListItems   
					   ,@PostMaterialIssues
					   ,@PageBetweenOperations  
					   ,@PrintSecondaryLocations
					   ,@ExtendByScrapFactor    
					   ,@PrintBarCode           
					   ,@DisplayHeader          
					   ,@PMessageLanguage       
					   ,@TaskID                 
					   ,@UserID                 
					   ,@BGSessionId            
					   ,@pSite       
			END TRY
			BEGIN CATCH
				DECLARE @infobar infobartype
			END CATCH

SELECT	  px.*
		, ISNULL(iw.qty_reorder,0) AS qty_reorder
	FROM #PicklistX px
		LEFT JOIN itemwhse iw
			ON iw.whse = px.hdr_JobWhse AND iw.item = px.det_JobMatlItem