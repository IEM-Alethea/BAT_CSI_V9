SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Guide - Tim Parsons
-- Create date: 10/08/2015
-- Description:	:	MOD 101 Sync Prouction Jobs FROM Current Updates
-- BEL version created 11/10/17 by DBH. ECN AND SyncBom eliminated.

ALTER PROCEDURE [dbo].[_IEM_UpdateJobsSp] (
	@Item				ItemType
    ,@Infobar			InfobarType = NULL OUTPUT
	,@CallFromSite		SiteType = NULL
	,@UserName          UserNameType = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	--SET XACT_ABORT ON;
	DECLARE 
		@RptSessionID		RowPointerType
        ,@Severity			INT
		,@Site				SiteType
		,@SQL				nvarchar(max)
		,@AppDbName			OSLocationType
		,@BadJobs           nvarchar(max) = NULL

	if @UserName IS null set @username = dbo.UserNameSp()

	EXEC dbo.InitSessionContextWithUserSp
        @ContextName = '_IEM_UpdateJobsSp'
        ,@SessionID  = @RptSessionID OUTPUT
        , @Site      = @Site
        , @UserName  = @UserName


	SELECT
		@Severity = 0

	select @Site = dbo.parmssite()

	--print @Site

	DECLARE
		@Job					JobType,
		@Suffix					SuffixType,
		@OperNum				OperNumType,
		@Sequence				SequenceType,
		@MatlItem				ItemType,
		@MatlQty				QtyPerType,
		@Units					nchar(1),
		@RefType				nchar(1),
		@RefNum					nvarchar(10),
		@RefLineSuf				smallint,
		@RefRelease				smallint,
		@UM						nvarchar(3),
		@MatlQtyConv			QtyPerType,
		@ItemUM					nvarchar(3),
		@ConvFactor				QtyPerType,
		@NewQtyConv				QtyPerType,
		@JobmatlItem            ItemType,
		@JobmatlOperNum			OperNumType,
		@JobmatlSequence        JobmatlSequenceType,
		@TDescription           DescriptionType,
		@JobmatlMatlType        MatlTypeType,
		@JobmatlMatlQtyConv     QtyPerType,
		@JobmatlUM              UMType,
		@JobmatlUnits           JobmatlUnitsType,
		@TcCpr_unit_cost        AmountType,
		@JobmatlEffectDate      DateType,
		@JobmatlObsDate         DateType,
		@TcCprExtCost           AmountType,
		@j_Revision               RevisionType,
		@JobRefRefSeq			JobmatlSequenceType,
		@JobRefRefDes           RefDesignatorType,
		@JobRefBubble           BubbleType,
		@JobRefAssySeq          AssemblySeqType,
		@MOBomAlternateId       MO_BOMAlternateType,
		@BomSeq                 EcnBomSeqType,
		@MaxSeq					smallint
		,@ScrapFact					ScrapFactorType
		,@j_Backflush					ListYesNoType
		,@BflushLoc					LocType
		,@j_Fmatlovhd					OverheadRateType
		,@j_Vmatlovhd					OverheadRateType
		,@j_Cost						CostPrcType 
		,@MatlCost					CostPrcType
		,@LbrCost					CostPrcType				
		,@FovhdCost					CostPrcType
		,@VovhdCost					CostPrcType
		,@OutCost					CostPrcType
		,@CostConv					CostPrcType
		,@MatlCostConv				CostPrcType
		,@LbrCostConv				CostPrcType
		,@FovhdCostConv				CostPrcType
		,@VovhdCostConv				CostPrcType
		,@OutCostConv				CostPrcType
		,@AltGroupRank				JobMatlRankType
		,@ManufacturerId			nvarchar(7)
		,@ManufacturerItem  		nvarchar(30)
		,@ChgMatlQty				QtyPerType
		,@ChgMatlQtyConv			QtyPerType
		,@FirstMatlSeq				Int
		,@FirstOper 				OperNumType
		,@TotalNewQtyConv			QtyPerType
		,@istopseq                  int

	DECLARE
		@item_item					ItemType
		,@item_description          DescriptionType
		,@item_revision             RevisionType
		,@item_unit_cost            CostPrcType
		,@jobmatl_item              ItemType
		,@jobmatl_oper_num          OperNumType
		,@jobmatl_sequence          JobmatlSequenceType
		,@t_description             DescriptionType
		,@jobmatl_matl_type         MatlTypeType
		,@jobmatl_matl_qty_conv     QtyPerType
		,@jobmatl_u_m               UMType
		,@jobmatl_units             JobmatlUnitsType
		,@tc_cpr_unit_cost          AmountType
		,@jobmatl_effect_date       DateType
		,@jobmatl_obs_date          DateType
		,@tc_cpr_ext_cost           AmountType
		,@revision                  RevisionType
		,@job_ref_ref_seq           JobmatlSequenceType
		,@job_ref_ref_des           RefDesignatorType
		,@job_ref_bubble            BubbleType
		,@job_ref_assy_seq          AssemblySeqType
		,@MO_bom_alternate_id       MO_BOMAlternateType
		,@bom_seq                   EcnBomSeqType
		,@QtyPerFormat				InputMaskType
		,@PlacesQtyPer				DecimalPlacesType
		,@scrap_fact					ScrapFactorType
		,@backflush					ListYesNoType
		,@bflush_loc					LocType
		,@fmatlovhd					OverheadRateType
		,@vmatlovhd					OverheadRateType
		,@cost						CostPrcType 
		,@matl_cost					CostPrcType
		,@lbr_cost					CostPrcType				
		,@fovhd_cost					CostPrcType
		,@vovhd_cost					CostPrcType
		,@out_cost					CostPrcType
		,@cost_conv					CostPrcType
		,@matl_cost_conv				CostPrcType
		,@lbr_cost_conv				CostPrcType
		,@fovhd_cost_conv			CostPrcType
		,@vovhd_cost_conv			CostPrcType
		,@out_cost_conv				CostPrcType
		,@alt_group_rank				JobMatlRankType
		,@manufacturer_id			nvarchar(7)
		,@manufacturer_item  		nvarchar(30)

		,@RouteOperNum					OperNumType
		,@RouteWC						WCType
		,@TInfo                     InfobarType


	DECLARE @JobTable TABLE
		(job					JobType
		,suffix					SuffixType)

	if exists(select 1 FROM job WHERE job.item = @Item AND job.type = 'J' AND job.stat <> 'R')
		begin
			select @BadJobs = master.dbo.GROUP_CONCAT(job+'-'+cast(suffix as nvarchar(4))) FROM job j WHERE j.item = @Item AND j.type = 'J' AND j.stat <> 'R' group by job, suffix
		end
		
	if NOT exists(select 1 FROM job WHERE job.item = @Item AND job.type = 'J' AND (job.stat = 'R' or job.stat = 'F')
				AND job.qty_complete + job.qty_scrapped = 0)
		begin
			GOTO END_IT
		end

	IF(OBJECT_ID('tempdb..#JobRptset') IS null)
	BEGIN
		SELECT
			@item_item					AS item_item					
			,@item_description			AS item_description
			,@item_revision				AS item_revision             
			,@item_unit_cost			AS item_unit_cost            
			,@jobmatl_item				AS jobmatl_item
			,@jobmatl_oper_num			AS jobmatl_oper_num
			,@jobmatl_sequence			AS jobmatl_sequence          
			,@t_description				AS t_description
			,@jobmatl_matl_type			AS jobmatl_matl_type
			,@jobmatl_matl_qty_conv		AS jobmatl_matl_qty_conv
			,@jobmatl_u_m				AS jobmatl_u_m               
			,@jobmatl_units				AS jobmatl_units
			,@tc_cpr_unit_cost			AS tc_cpr_unit_cost
			,@jobmatl_effect_date		AS jobmatl_effect_date       
			,@jobmatl_obs_date			AS jobmatl_obs_date
			,@tc_cpr_ext_cost           AS tc_cpr_ext_cost
			,@revision                  AS revision                  
			,@job_ref_ref_seq           AS job_ref_ref_seq           
			,@job_ref_ref_des           AS job_ref_ref_des           
			,@job_ref_bubble            AS job_ref_bubble            
			,@job_ref_assy_seq          AS job_ref_assy_seq          
			,@MO_bom_alternate_id       AS MO_bom_alternate_id       
			,@bom_seq                   AS bom_seq                   
			,@QtyPerFormat				AS QtyPerFormat				
			,@PlacesQtyPer				AS PlacesQtyPer				
			,@scrap_fact				AS scrap_fact				
			,@backflush					AS backflush	
			,@bflush_loc				AS bflush_loc
			,@fmatlovhd					AS fmatlovhd	
			,@vmatlovhd					AS vmatlovhd	
			,@cost						AS cost
			,@matl_cost					AS matl_cost	
			,@lbr_cost					AS lbr_cost		
			,@fovhd_cost				AS fovhd_cost
			,@vovhd_cost				AS vovhd_cost
			,@out_cost					AS out_cost	
			,@cost_conv					AS cost_conv					
			,@matl_cost_conv			AS matl_cost_conv				
			,@lbr_cost_conv				AS lbr_cost_conv			
			,@fovhd_cost_conv			AS fovhd_cost_conv			
			,@vovhd_cost_conv			AS vovhd_cost_conv			
			,@out_cost_conv				AS out_cost_conv				
			,@alt_group_rank			AS alt_group_rank				
			,@manufacturer_id			AS manufacturer_id
			,@manufacturer_item			AS manufacturer_item		
		INTO #JobRptset 
		WHERE 1=2
	END

	IF(OBJECT_ID('tempdb..#JobRouteset') IS null)
	BEGIN
		SELECT
			@item_item						AS item_item					
			,@RouteOperNum					as oper_num
			,@RouteWC						as wc
		INTO #JobRouteset 
		WHERE 1=2
	END

	IF @CallFromSite IS null
	BEGIN
		insert into #JobRouteset
			(item_item
			,oper_num
			,wc)
		SELECT
			i.item
			,jr.oper_num
			,jr.wc
		FROM item i inner JOIN jobroute jr on i.job = jr.job AND i.suffix = jr.suffix
		WHERE i.item = @item
		AND jr.wc NOT IN ('ISUMET','RSHORT') -- djh 2017-01-18. should NOT be on BOM, but ignore anyway to avoid any conflict with job ISUMET

		INSERT INTO #JobRptset
			(  item_item                 
			, item_description          
			, item_revision             
			, item_unit_cost            
			, jobmatl_item              
			, jobmatl_oper_num          
			, jobmatl_sequence          
			, t_description             
			, jobmatl_matl_type         
			, jobmatl_matl_qty_conv     
			, jobmatl_u_m               
			, jobmatl_units             
			, tc_cpr_unit_cost          
			, jobmatl_effect_date       
			, jobmatl_obs_date          
			, tc_cpr_ext_cost           
			, revision                  
			, job_ref_ref_seq           
			, job_ref_ref_des           
			, job_ref_bubble            
			, job_ref_assy_seq          
			, MO_bom_alternate_id       
			, bom_seq                   
			, QtyPerFormat				
			, PlacesQtyPer
			)
		EXEC dbo.Rpt_SingleLevelCurrentBillOfMaterialSp
			@ItemStarting					= @item,
			@ItemEnding						= @item,
			@ProductCodeStarting			= NULL,
			@ProductCodeEnding				= NULL,
			@AlternateIDStarting			= NULL,
			@AlternateIDEnding				= NULL,
			@MaterialType                   = 'MFTO',
			@Source                         = 'PMT',
			@Shocked                        = 'B',
			@ABCCode                        = 'ABC',
			@ShowCost						= NULL,
			@DisplayReferenceFields			= NULL,
			@PageBetweenItems				= NULL,
			@PrintAlternate					= NULL,
			@DisplayHeader					= NULL,
			@pSite							= NULL

		Update rs
		set scrap_fact			= jm.scrap_fact			
			,backflush			= jm.backflush
			,bflush_loc			= jm.bflush_loc
			,fmatlovhd			= jm.fmatlovhd
			,vmatlovhd			= jm.vmatlovhd		
			,cost				= jm.cost		 
			,matl_cost			= jm.matl_cost
			,lbr_cost			= jm.lbr_cost
			,fovhd_cost			= jm.fovhd_cost		
			,vovhd_cost			= jm.vovhd_cost
			,out_cost			= jm.out_cost		
			,cost_conv			= jm.cost_conv		
			,matl_cost_conv		= jm.matl_cost_conv		
			,lbr_cost_conv		= jm.lbr_cost_conv		
			,fovhd_cost_conv	= jm.fovhd_cost_conv		
			,vovhd_cost_conv	= jm.vovhd_cost_conv
			,out_cost_conv		= jm.out_cost_conv
			,alt_group_rank		= jm.alt_group_rank		
			,manufacturer_id	= jm.manufacturer_id
			,manufacturer_item  = jm.manufacturer_item
		FROM #JobRptset rs inner JOIN item i on rs.item_item = i.item
		inner JOIN jobmatl jm on i.job = jm.job AND i.suffix = jm.suffix AND rs.jobmatl_oper_num = jm.oper_num
		AND rs.jobmatl_item = jm.item AND rs.jobmatl_sequence = jm.sequence

		insert into #JobRptset
		(  item_item                 
			, item_description          
			, item_revision             
			, item_unit_cost            
			, jobmatl_item              
			, jobmatl_oper_num          
			, jobmatl_sequence          
			, t_description             
			, jobmatl_matl_type         
			, jobmatl_matl_qty_conv     
			, jobmatl_u_m               
			, jobmatl_units             
			, tc_cpr_unit_cost          
			, jobmatl_effect_date       
			, jobmatl_obs_date          
			, tc_cpr_ext_cost           
			, revision                  
			, job_ref_ref_seq           
			, job_ref_ref_des           
			, job_ref_bubble            
			, job_ref_assy_seq          
			, MO_bom_alternate_id       
			, bom_seq                   
			, QtyPerFormat				
			, PlacesQtyPer
			,scrap_fact					
			,backflush					
			,bflush_loc					
			,fmatlovhd					
			,vmatlovhd					
			,cost						 
			,matl_cost					
			,lbr_cost									
			,fovhd_cost					
			,vovhd_cost					
			,out_cost					
			,cost_conv					
			,matl_cost_conv				
			,lbr_cost_conv				
			,fovhd_cost_conv			
			,vovhd_cost_conv			
			,out_cost_conv				
			,alt_group_rank				
			,manufacturer_id			
			,manufacturer_item  		
			)
		SELECT 
			item_item                 
			,item_description          
			,item_revision             
			,item_unit_cost          
			,jm.item			
			,jobmatl_oper_num	
			,0					
			,ji.description		
			,jm.matl_type		
			,CASE WHEN jm.units = 'U' then jobmatl_matl_qty_conv * jm.matl_qty_conv ELSE jm.matl_qty_conv END	
			,jm.u_m				
			,jm.units			
			,0					--, tc_cpr_unit_cost          
			,jm.effect_date		--, jobmatl_effect_date       
			,jm.obs_date		--, jobmatl_obs_date          
			,0					--, tc_cpr_ext_cost           
			,ji.revision		--, revision                  
			,job_ref_ref_seq	--, job_ref_ref_seq           
			,job_ref_ref_des		--, job_ref_ref_des           
			,job_ref_bubble		--, job_ref_bubble            
			,job_ref_assy_seq		--, job_ref_assy_seq          
			,''					--, MO_bom_alternate_id       
			,0					--, bom_seq                   
			, QtyPerFormat				
			, PlacesQtyPer
			, jm.scrap_fact			
			, jm.backflush
			, jm.bflush_loc
			, jm.fmatlovhd
			, jm.vmatlovhd		
			, jm.cost		 
			, jm.matl_cost
			, jm.lbr_cost
			, jm.fovhd_cost		
			, jm.vovhd_cost
			, jm.out_cost		
			, jm.cost_conv		
			, jm.matl_cost_conv		
			, jm.lbr_cost_conv		
			, jm.fovhd_cost_conv		
			, jm.vovhd_cost_conv
			, jm.out_cost_conv
			, jm.alt_group_rank		
			, jm.manufacturer_id
			, jm.manufacturer_item
		FROM #JobRptset rs
		inner JOIN item i on rs.jobmatl_item = i.item
		inner JOIN jobmatl jm on i.job = jm.job AND i.suffix = jm.suffix AND i.item = jm.item AND i.phantom_flag = 1
		inner JOIN item ji on jm.item = ji.item

		delete FROM rs
		FROM #JobRptset rs inner JOIN item i on rs.jobmatl_item = i.item AND i.phantom_flag = 1

	EXEC dbo.InitSessionContextWithUserSp --restore username to use on jobmatl updates djh 2016-8-15
        @ContextName = '_IEM_UpdateJobsSp'
        ,@SessionID  = NULL
        , @Site      = @Site
        , @UserName  = @UserName

	END -- @callsite IS null
	
	DECLARE jobcursor CURSOR READ_ONLY FOR
	SELECT	  j.job
			, j.suffix
		FROM job j 
			WHERE j.item = @Item AND j.type = 'J' AND j.stat IN ('R','F') AND j.qty_complete + j.qty_scrapped = 0
	OPEN jobcursor
	WHILE 1 = 1
	BEGIN

		FETCH NEXT FROM jobcursor INTO @Job, @Suffix

		IF @@FETCH_STATUS <> 0
			BREAK

		DECLARE jobmatlcursor CURSOR READ_ONLY FOR
		SELECT	  jm.oper_num
				, jr.wc
				, jm.sequence
				, jm.item
				, jm.matl_qty
				, jm.units
				, jm.ref_type
				, jm.ref_num
				, jm.ref_line_suf
				, jm.ref_release
				, jm.u_m
				, jm.matl_qty_conv
				, i.u_m
		FROM job j
			JOIN jobroute jr
				ON jr.job = j.job AND jr.suffix = j.suffix
			JOIN jobmatl jm
				ON jm.job = j.job AND jm.suffix = j.suffix AND jm.oper_num = jr.oper_num
			JOIN item i
				ON jm.item = i.item
			WHERE j.job = @job AND j.suffix = @suffix
				ORDER BY jm.oper_num, jm.sequence

		OPEN jobmatlcursor
		WHILE 1=1
		BEGIN
			FETCH NEXT FROM jobmatlcursor INTO
				  @OperNum
				, @RouteWC
				, @Sequence
				, @MatlItem
				, @MatlQty
				, @Units
				, @RefType
				, @RefNum
				, @RefLineSuf
				, @RefRelease
				, @UM
				, @MatlQtyConv
				, @ItemUM

			IF @@FETCH_STATUS <> 0
				BREAK

			-- Identify the first occurence of the item on the job bill, we only want to update that one with the total quantity
			SET @FirstMatlSeq = NULL; SET @firstoper = NULL

			SELECT TOP 1 @FirstMatlSeq = jm.sequence, @FirstOper = jr.oper_num
				FROM job j --djh 2016-11-21.  only the first route with matching wc will be used (allowing oper_nums to differ between job/bom)
					JOIN jobroute jr
						ON jr.job = j.job AND jr.suffix = j.suffix
							AND jr.oper_num = (SELECT TOP 1 tjr.oper_num
													FROM jobroute tjr
														WHERE tjr.job = jr.job
																AND tjr.suffix = jr.suffix
																AND tjr.wc = jr.wc
																ORDER BY oper_num)
					JOIN jobmatl jm
						ON jm.job = jr.job AND jm.suffix = jr.suffix AND jm.oper_num = jr.oper_num
					WHERE j.job = @job AND j.suffix = @suffix AND jr.wc = @RouteWC AND jm.item = @MatlItem
						ORDER BY jr.oper_num, jm.sequence ASC

			set @istopseq = isnull(case when @Sequence = @FirstMatlSeq AND @OperNum = @FirstOper then 1 else 0 end,0)

			--Also eliminate the requirement if there's nothing on the current BOM for that item
			IF NOT EXISTS (SELECT 1 FROM job j JOIN jobmatl jm ON jm.job = j.job AND jm.suffix = j.suffix AND j.item = @Item
								AND j.type = 'S' AND jm.item = @MatlItem) SET @istopseq = 0

			IF (@istopseq = 0 or
				NOT exists(select 1 FROM #JobRptset Rs 
				JOIN #JobRouteset jrs ON jrs.item_item=rs.item_item AND jrs.oper_num = rs.jobmatl_oper_num 
				WHERE Rs.jobmatl_item = @MatlItem
				AND jrs.wc = @RouteWC) )
			AND ISNULL(@MatlQty,0) <> 0
				BEGIN
					UPDATE jm
							SET jm.matl_qty_conv = 0,
								jm.matl_qty = 0
							FROM jobmatl jm
							WHERE jm.job = @Job AND jm.suffix = @Suffix AND jm.oper_num = @OperNum
								AND jm.sequence = @Sequence;

				END

			DELETE #JobRptSet
				WHERE jobmatl_item = @MatlItem AND jobmatl_oper_num = @OperNum AND @istopseq = 0

			If EXISTS(SELECT 1 FROM #JobRptset Rs JOIN #JobRouteset jrs on jrs.item_item=rs.item_item AND jrs.oper_num=rs.jobmatl_oper_num
						WHERE Rs.jobmatl_item = @MatlItem
						AND jrs.wc = @RouteWC)
			BEGIN
				-- Need to Update Material Quantity because it's changed
				EXEC @Severity = dbo.GetumcfSp
					@OtherUM = @UM
				  , @Item = @Item
				  , @VendNum = NULL
				  , @Area = NULL
				  , @ConvFactor = @ConvFactor output
				  , @Infobar = @Infobar output
				  , @Site = @Site

				-- Get the total Qty for the material for that operation (in case it IS on the bill twice) 
				SELECT top 1
					@TotalNewQtyConv = sum(jobmatl_matl_qty_conv)
				FROM #JobRptset Rs JOIN #JobRouteset jrs on jrs.item_item=rs.item_item AND jrs.oper_num=rs.jobmatl_oper_num
				WHERE Rs.jobmatl_item = @MatlItem
				AND jrs.wc = @RouteWC

				IF (@MatlQtyConv <> @TotalNewQtyConv AND @istopseq = 1 )
				OR (@istopseq <> 1 AND @MatlQtyConv <> 0)
				BEGIN
					-- Check to see if the item IS on the operation twice, the 2nd occurence gets updated to 0
					IF @istopseq <> 1 AND @MatlQtyConv <> 0
						SET @TotalNewQtyConv = 0
					Update jm
					SET 
						jm.matl_qty_conv = @TotalNewQtyConv,
						jm.matl_qty = @TotalNewQtyConv * dbo.UomConvQty (1, @ConvFactor, 'To Base')
					FROM jobmatl jm
					WHERE jm.job = @Job AND jm.suffix = @Suffix AND jm.oper_num = @OperNum
						AND jm.sequence = @Sequence

				END
			END
		END
		Close jobmatlcursor
		Deallocate jobmatlcursor

		-- We can check to see if any operations are on the job that do NOT exist on the current
		-- delete them if there are no job transactions

		IF exists(select 1 FROM jobroute jr
		LEFT JOIN #JobRouteset jrs on jr.wc = jrs.wc
		LEFT JOIN jobtran jt on jr.job = jt.job AND jr.suffix = jt.suffix AND jr.oper_num = jt.oper_num
		WHERE jr.job = @Job AND jr.suffix = @Suffix
		AND isnull(jrs.wc,'') = '' AND isnull(jt.job,'') = '' )
		BEGIN

			--DECLARE jobroute_cursor cursor READ_ONLY for
			--SELECT
			--	jr.oper_num
			--FROM jobroute jr
			--WHERE jr.job = @Job AND jr.suffix = @Suffix
			--AND jr.qty_received = 0 AND jr.qty_complete = 0 AND jr.qty_moved = 0 AND jr.qty_scrapped = 0 --djh 2016-9-7, avoid "Quantities/Costs have been posted to Job Operation"
			----AND NOT exists (select * FROM _IEM_SchGroupings isg WHERE jr.wc=isg.wc) --djh 2016-11-01 protect scheduler wcs
			--AND NOT exists (select * FROM jobmatl jm WHERE jr.job=jm.job AND jr.suffix=jm.suffix AND jr.oper_num=jm.oper_num AND isnull(jm.qty_issued,0)<>0)
			--AND NOT exists (select * FROM jobtran jt WHERE jr.job = jt.job AND jr.suffix = jt.suffix AND jr.oper_num = jt.oper_num)
			----djh 2016-11-21. wc either doesn't exist or IS a duplicate
			--AND ( NOT exists (select * FROM #JobRouteset jrs WHERE jr.wc = jrs.wc) or jr.oper_num <> (select top 1 tjr.oper_num FROM jobroute tjr WHERE tjr.job = jr.job AND tjr.suffix = jr.suffix AND tjr.wc = jr.wc order by oper_num) )


			delete jr
			FROM jobroute jr
			WHERE jr.job = @Job AND jr.suffix = @Suffix
			AND jr.qty_received = 0 AND jr.qty_complete = 0 AND jr.qty_moved = 0 AND jr.qty_scrapped = 0 --djh 2016-9-7, avoid "Quantities/Costs have been posted to Job Operation"
			--AND NOT exists (select * FROM _IEM_SchGroupings isg WHERE jr.wc=isg.wc) --djh 2016-11-01 protect scheduler wcs
			AND NOT exists (select * FROM jobmatl jm WHERE jr.job=jm.job AND jr.suffix=jm.suffix AND jr.oper_num=jm.oper_num AND isnull(jm.qty_issued,0)<>0)
			AND NOT exists (select * FROM jobtran jt WHERE jr.job = jt.job AND jr.suffix = jt.suffix AND jr.oper_num = jt.oper_num)
			--djh 2016-11-21. wc either doesn't exist or IS a duplicate
			AND ( NOT exists (select * FROM #JobRouteset jrs WHERE jr.wc = jrs.wc) or jr.oper_num <> (select top 1 tjr.oper_num FROM jobroute tjr WHERE tjr.job = jr.job AND tjr.suffix = jr.suffix AND tjr.wc = jr.wc order by oper_num) )
		END 

		-- At this point we should now be able to add any new items to the released jobs bill
		DECLARE NewItems Cursor
		For SELECT
			  rs.jobmatl_item              
			, rs.jobmatl_oper_num
			, jrs.wc          
			, rs.jobmatl_sequence          
			, rs.t_description             
			, rs.jobmatl_matl_type         
			, rs.jobmatl_matl_qty_conv     
			, rs.jobmatl_u_m               
			, rs.jobmatl_units             
			, rs.tc_cpr_unit_cost          
			, rs.jobmatl_effect_date       
			, rs.jobmatl_obs_date          
			, rs.tc_cpr_ext_cost           
			, rs.revision                  
			, rs.job_ref_ref_seq           
			, rs.job_ref_ref_des           
			, rs.job_ref_bubble            
			, rs.job_ref_assy_seq          
			, rs.MO_bom_alternate_id  
			, rs.scrap_fact					
			, rs.backflush					
			, rs.bflush_loc					
			, rs.fmatlovhd					
			, rs.vmatlovhd					
			, rs.cost						 
			, rs.matl_cost					
			, rs.lbr_cost									
			, rs.fovhd_cost					
			, rs.vovhd_cost					
			, rs.out_cost					
			, rs.cost_conv					
			, rs.matl_cost_conv				
			, rs.lbr_cost_conv				
			, rs.fovhd_cost_conv			
			, rs.vovhd_cost_conv			
			, rs.out_cost_conv				
			, rs.alt_group_rank				
			, rs.manufacturer_id			
			, rs.manufacturer_item  	
		FROM #JobRptset rs 
		JOIN #JobRouteset jrs on jrs.item_item=rs.item_item AND jrs.oper_num=rs.jobmatl_oper_num
		LEFT JOIN jobroute jr on jr.job = @Job AND jr.suffix = @Suffix AND jr.wc = jrs.wc
		LEFT JOIN jobmatl jm on jm.job = jr.job AND jm.suffix = jr.suffix AND jm.oper_num = jr.oper_num AND rs.jobmatl_item = jm.item
		WHERE (jm.item IS null)
		AND jrs.wc NOT IN ('ISUMET','RSHORT') -- djh 2017-01-18. ignore on BOM if there to avoid conflict
		order by rs.jobmatl_oper_num, rs.jobmatl_sequence  

		Open NewItems
		While 1 = 1
		BEGIN	
			Fetch Next FROM NewItems into 
				@JobmatlItem        
				,@JobmatlOperNum
				,@RouteWC		
				,@JobmatlSequence    
				,@TDescription       
				,@JobmatlMatlType    
				,@JobmatlMatlQtyConv 
				,@JobmatlUM          
				,@JobmatlUnits       
				,@TcCpr_unit_cost    
				,@JobmatlEffectDate  
				,@JobmatlObsDate     
				,@TcCprExtCost       
				,@j_Revision           
				,@JobRefRefSeq		
				,@JobRefRefDes       
				,@JobRefBubble       
				,@JobRefAssySeq      
				,@MOBomAlternateId   
				,@ScrapFact					
				,@j_Backflush					
				,@BflushLoc					
				,@j_Fmatlovhd					
				,@j_Vmatlovhd					
				,@j_Cost						 
				,@MatlCost					
				,@LbrCost									
				,@FovhdCost					
				,@VovhdCost					
				,@OutCost					
				,@CostConv					
				,@MatlCostConv				
				,@LbrCostConv				
				,@FovhdCostConv				
				,@VovhdCostConv				
				,@OutCostConv				
				,@AltGroupRank				
				,@ManufacturerId			
				,@ManufacturerItem 
			if @@FETCH_STATUS <> 0 
				BREAK
			
			if NOT exists(select 1 FROM jobroute jr WHERE jr.job = @Job AND jr.suffix = @Suffix 
							AND jr.wc = @RouteWC)
			BEGIN

				BEGIN TRANSACTION
				EXEC @Severity = _IEM_CreateJobOperationSp
					@Job = @Job
					,@Suffix = @Suffix
					,@WorkCenter = @RouteWC
					,@LaborHours = 0
					,@OperNum = @JobmatlOperNum OUTPUT
					,@Infobar = @Infobar OUTPUT

				COMMIT TRANSACTION

				if @Severity <> 0 
					BREAK

			END

			--djh 2016-11-21 should exist now that we have created it previous step (or already did)
			select top 1 @JobmatlOperNum = oper_num FROM jobroute jr WHERE jr.job = @Job AND jr.suffix = @Suffix AND jr.wc = @RouteWC

			if exists(select 1 FROM jobroute jr
				JOIN jobmatl jm on jm.job=jr.job AND jm.suffix=jr.suffix AND jm.oper_num=jr.oper_num 
				WHERE jr.job = @Job AND jr.suffix = @Suffix AND jm.item = @JobmatlItem AND jr.oper_num = @JobmatlOperNum)
					continue --djh 2016-11-21.  if it already exists we must have created it. 2017-01-05: use jobmatlopernum instead of @routewc to verify it IS the top 1 AND NOT a second one

			SELECT top 1
				@TotalNewQtyConv = ISNULL(sum(jobmatl_matl_qty_conv),0)
			FROM #JobRptset Rs JOIN #JobRouteset jrs on jrs.item_item=rs.item_item AND jrs.oper_num=rs.jobmatl_oper_num
			WHERE Rs.jobmatl_item = @JobMatlItem
			AND jrs.wc = @RouteWC

			set @JobmatlMatlQtyConv = @TotalNewQtyConv --djh 2016-11-21.  put total first time

			SELECT
				@MaxSeq = max(jm.sequence)
			FROM jobmatl jm
			WHERE jm.job = @Job AND jm.suffix = @Suffix AND jm.oper_num = @JobmatlOperNum

			SELECT
				@MaxSeq = isnull(@MaxSeq,0) + 1

			SELECT 
				@RefType = CASE WHEN i.stocked = 1
								THEN 'I'
							ELSE
								CASE i.p_m_t_code 
									WHEN 'P' THEN 'P'
									WHEN 'J' THEN 'J'
									WHEN 'T' THEN 'T'
									ELSE 'I'
								END
							END
			FROM item i WHERE i.item = @JobmatlItem

			SET @RefType = isnull(@RefType,'I')
			SET @ConvFactor = 1
			
			-- Need to Update Material Quantity because it's changed
			exec @Severity = dbo.GetumcfSp
				@OtherUM = @JobmatlUM
				, @Item = @JobmatlItem
				, @VendNum = NULL
				, @Area = NULL
				, @ConvFactor = @ConvFactor output
				, @Infobar = @Infobar output
				, @Site = @Site

			-- At this point we can add the job material
			 insert into Jobmatl
				(job, 
				suffix, 
				oper_num, 
				sequence,
				matl_type,
				item, 
				ref_type, 
				units,
				scrap_fact, 
				matl_qty, 
				matl_qty_conv, 
				bom_seq,  
				u_m, 
				description,
				backflush, 
				bflush_loc, 
				fmatlovhd, 
				vmatlovhd, 
				cost, 
				matl_cost, 
				lbr_cost, 
				fovhd_cost, 
				vovhd_cost, 
				out_cost, 
				cost_conv, 
				matl_cost_conv, 
				lbr_cost_conv, 
				fovhd_cost_conv, 
				vovhd_cost_conv, 
				out_cost_conv, 
				alt_group, 
				alt_group_rank, 
				effect_date, 
				obs_date, 
				manufacturer_id, 
				manufacturer_item       
				)
			select 
				@Job
				,@Suffix
				,@JobmatlOperNum
				,@MaxSeq
				,@JobmatlMatlType 
				,@JobmatlItem
				,@RefType
				,@JobmatlUnits
				,@ScrapFact	
				,@JobmatlMatlQtyConv * dbo.UomConvQty (1, @ConvFactor, 'To Base')
				,@JobmatlMatlQtyConv
				,NULL	--@MaxSeq
				,@JobmatlUM
				,@TDescription
				,@j_Backflush
				,@BflushLoc
				,@j_Fmatlovhd
				,@j_Vmatlovhd
				,@j_Cost
				,@MatlCost
				,@LbrCost
				,@FovhdCost
				,@VovhdCost
				,@OutCost
				,@CostConv
				,@Matlcostconv			--matl_cost_conv
				,@LbrCostConv			--lbr_cost_con 
				,@FovhdCostConv			--fovhd_cost_conv 
				,@VovhdCostConv			--vovhd_cost_conv 
				,@OutCostConv			--out_cost_conv 
				,@MaxSeq				--alt_group 
				,@AltGroupRank			--alt_group_rank
				,@JobmatlEffectDate		--effect_date
				,@JobmatlObsDate		--obs_date
				,@ManufacturerId		--manufacturer_id
				,@ManufacturerItem		--manufacturer_item 

		END
		Close NewItems
		Deallocate NewItems

	END
	Close jobcursor
	Deallocate jobcursor

	IF @CallFromSite IS null
	BEGIN
		DECLARE
			@JobSite		SiteType
		DECLARE site_cursor cursor for
		select distinct site_ref FROM job_all job WHERE job.item = @Item AND job.type = 'J' AND (job.stat = 'R' or job.stat = 'F')
				AND job.qty_complete + job.qty_scrapped = 0 AND site_ref <> @Site
		open site_cursor
		While 1 = 1
		BEGIN
			Fetch next FROM site_cursor into @JobSite

			IF @@FETCH_STATUS <> 0
				BREAK

			SELECT
				@AppDbName = app_db_name
			FROM site WHERE site = @JobSite 		

			Set @Sql = @AppDbName + '.._IEM_UpdateJobsSp'
			--print @SQL

			exec @Severity = @Sql
				@Item		= @Item
				,@Infobar	= @TInfo OUTPUT
				,@CallFromSite = @Site
				,@UserName  = @UserName
			
		END
		Close site_cursor
		Deallocate site_cursor
	END

--Update jrt_sch with labor / machine hours as necessary
; WITH JS
	AS (
		SELECT js.*
			FROM jrt_sch js
				JOIN job j
					ON j.job = js.job AND j.suffix = js.suffix
				WHERE j.type = 'S' AND j.item = @Item
					AND (SELECT COUNT(*) FROM job WHERE item = @Item AND type = 'S') = 1
		)

UPDATE jsx
	SET	  jsx.run_ticks_lbr  = js.run_ticks_lbr
		, jsx.run_ticks_mch  = js.run_ticks_mch
		, jsx.pcs_per_lbr_hr = js.pcs_per_lbr_hr
		, jsx.pcs_per_mch_hr = js.pcs_per_mch_hr
		, jsx.setup_hrs      = js.setup_hrs
		, jsx.run_lbr_hrs    = js.run_lbr_hrs
		, jsx.run_mch_hrs    = js.run_mch_hrs
	FROM jrt_sch jsx
		JOIN JS
			ON js.oper_num = jsx.oper_num
		WHERE jsx.job = @Job AND jsx.suffix = @Suffix
				AND (jsx.run_ticks_lbr  <> js.run_ticks_lbr		OR
					 jsx.run_ticks_mch  <> js.run_ticks_mch		OR
					 jsx.pcs_per_lbr_hr <> js.pcs_per_lbr_hr	OR
					 jsx.pcs_per_mch_hr <> js.pcs_per_mch_hr	OR
					 jsx.setup_hrs      <> js.setup_hrs			OR
					 jsx.run_lbr_hrs    <> js.run_lbr_hrs		OR
					 jsx.run_mch_hrs    <> js.run_mch_hrs)

	END_IT:		
		if @BadJobs IS NOT null begin
			set @Infobar = 'The following Job Orders were NOT updated for item ' + @Item+': '+@BadJobs+'.  The job(s) may already be complete.'
			set @Severity=-17
		end else begin
			set @Infobar = NULL
		end
		EXEC dbo.CloseSessionContextSp @SessionID = @RptSessionID
		Return @Severity
END


