SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/*-------------------------------------------------------------------------------------
File: _IEM_CLM_SchLoadSchedulerFastSp
Description: 

Change Log:
Date			Ref#				Author				Description\Comments
------------	------				----------------	--------------------------------------------------------------------------
03/25/2024		0000 OTD Project	David Simpson		Adding coitem._Uf_NumSections, and the ci.Uf_EngLeadTime
														to the dataset. 
														Near Line: 1145 - Put the union query inside a CTE (RPT_CTE). This allows
														the coitem table to be joined to the union select statement.					
----------------------------------------------------------------------------------------------------------------------------------*/

-- =============================================
-- Author:		Guide - Tim Parsons
-- Create date: 02/15/2016
-- Description:	: 
-- =============================================    
/*
	DECLARE
		@PIncludeCrossSite		ListYesNoType
		,@Infobar			InfobarType
		,@severity			int
		,@PCoNum				CoNumType 
		,@PCoLine				CoLineType 

	Select 
		@PCoNum =  '     98666'
		,@PCoLine = null

	exec @Severity = _IEM_CLM_SchLoadSchedulerFastSp
		@PIncludeCrossSite			= 1
		,@PCoNum			= @PCoNum
		,@Infobar		= @Infobar		OUTPUT
		,@PCoLine		= @PCoLine
		,@PIncludeUnApproved = 1
		,@POnlyTentative = 1

	--exec @Severity = [DFRE_APP].dbo._IEM_CLM_SchLoadSchedulerFastSp
	--	@PIncludeCrossSite			= 0
	--	,@PCoNum			= @PCoNum
	--	,@Infobar		= @Infobar		OUTPUT
	--	,@PCoLine		= @PCoLine

	--select ijrs.job, ijrs.suffix, sum(ijrs.groupsequence) from _IEM_JobrouteScheduler_mst ijrs
	--inner join job_mst j on ijrs.job = j.job and ijrs.suffix = j.suffix
	--where j.type = 'J' and j.stat <> 'C' and j.qty_complete < j.qty_released
	--group by ijrs.job, ijrs.suffix
	

	select * from _IEM_JobrouteScheduler_mst where co_num = '     98551' and groupsequence = 7
	--delete from _IEM_JobrouteScheduler_mst where co_num = '     98551' and groupsequence = 7
*/

ALTER PROCEDURE [dbo].[_IEM_CLM_SchLoadSchedulerFastSp] (
	@PIncludeCrossSite		ListYesNoType = NULL
	,@PCallSite				SiteType = NULL
	,@PCoNum				CoNumType = NULL
	,@Infobar				InfobarType	= NULL		OUTPUT
	,@PCoLine				CoLineType = NULL
	,@PJobsLoadedSince      DateTimeType = NULL
	,@PIncludeUnApproved    ListYesNoType = NULL
	,@PSelectDateType       NVARCHAR(30) = NULL
	,@PSelectStartDate      DateTimeType = NULL
	,@PSelectEndDate        DateTimeType = NULL
	,@UserName              UserNameType = NULL
	,@POnlyTentative		ListYesNoType = NULL
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE 
		@RptSessionID		RowPointerType
        ,@Severity			INT
		,@Site				SiteType
		,@SQL				nvarchar(3000)
		,@PDestPrefix		nvarchar(20)	
		,@GroupMechanical	ListYesNoType
		,@SubAssyTransitDays	Smallint
		,@SetSiteInfobar		InfobarType

	If @UserName is null
		set @UserName = dbo.UserNameSp()

	SET @Severity	= 0
	SET @PIncludeCrossSite = isnull(@PIncludeCrossSite,0)

	If isnull(@PCoNum,'') <> ''
		SELECT @PCoNum = dbo.ExpandKy(10,@PCoNum)

	if @PSelectEndDate is null set @PSelectEndDate = '9000-01-01'
	if @PSelectStartDate is null set @PSelectStartDate = '1800-01-01'

    EXEC dbo.InitSessionContextWithUserSp
        @ContextName = '_IEM_CLM_SchLoadSchedulerFastSp'
		,@UserName = @UserName
        ,@SessionID  = @RptSessionID OUTPUT
        ,@Site        = null 

	SET @Site = dbo.ParmsSite()

	IF isnull(@PCallSite,'') = ''
		SET @PCallSite = @Site

	SELECT
		@GroupMechanical = Uf_group_mechanical
		,@SubAssyTransitDays = Uf_subassy_trndays
	from parms

	DECLARE	@RptSet TABLE(
		[sub_assy_site] [SiteType],
		[site_assignment] [SiteType],
		[last_group] [nvarchar](40),
		[co_num] [CoNumType],
		[co_line] [CoLineType] ,
		[co_release] [CoReleaseType] ,
		[last_group_seq] [int],
		[job_qty] [QtyUnitType]  ,
		[job] [JobType]  ,
		[suffix] [smallint]  ,
		[material_cushion] [smallint]  ,
		[group_hrs1] [SchedHoursType] ,
		[num_workers1] [smallint] ,
		[group_hrs2] [SchedHoursType] ,
		[num_workers2] [smallint] ,
		[group_hrs3] [SchedHoursType] ,
		[num_workers3] [smallint] ,
		[group_hrs4] [SchedHoursType] ,
		[num_workers4] [smallint] ,
		[group_hrs5] [SchedHoursType] ,
		[num_workers5] [smallint] ,
		[group_hrs6] [SchedHoursType] ,
		[num_workers6] [smallint] ,
		[group_hrs7] [SchedHoursType] ,
		[num_workers7] [smallint] ,
		[group_hrs8] [SchedHoursType] ,
		[num_workers8] [smallint] ,
		[group_hrs9] [SchedHoursType] ,
		[num_workers9] [smallint] ,
		[group_hrs10] [SchedHoursType] ,
		[num_workers10] [smallint] ,
		[group_hrs11] [SchedHoursType] ,
		[num_workers11] [smallint] ,
		[group_hrs12] [SchedHoursType] ,
		[num_workers12] [smallint] ,
		[group_hrs13] [SchedHoursType] ,
		[num_workers13] [smallint] ,
		[group_hrs14] [SchedHoursType] ,
		[num_workers14] [smallint] ,
		[group_hrs15] [SchedHoursType] ,
		[num_workers15] [smallint] ,
		[mech_hrs] [SchedHoursType] ,
		[mech_num_workers] [smallint] ,
		[sub_assy_transit] [smallint] ,
		[prod_cycle_days] [smallint] ,
		[sch_subassy_ship_date] [DateType] ,
		[req_subassy_arr_date] [DateType] ,
		[sch_final_ship_date] [DateType] ,
		[cust_req_ship_date] [DateType] ,
		[prom_ship_date] [DateType] ,
		[start_date] [DateType] ,
		[assy_start_date] [DateType] ,
		[job_type] [JobTypeType] ,
		[groupexists1] [smallint] ,
		[groupexists2] [smallint] ,
		[groupexists3] [smallint] ,
		[groupexists4] [smallint] ,
		[groupexists5] [smallint] ,
		[groupexists6] [smallint] ,
		[groupexists7] [smallint] ,
		[groupexists8] [smallint] ,
		[groupexists9] [smallint] ,
		[groupexists10] [smallint] ,
		[groupexists11] [smallint] ,
		[groupexists12] [smallint] ,
		[groupexists13] [smallint] ,
		[groupexists14] [smallint] ,
		[groupexists15] [smallint] ,
		[groupseq1] [smallint] ,
		[groupseq2] [smallint] ,
		[groupseq3] [smallint] ,
		[groupseq4] [smallint] ,
		[groupseq5] [smallint] ,
		[groupseq6] [smallint] ,
		[groupseq7] [smallint] ,
		[groupseq8] [smallint] ,
		[groupseq9] [smallint] ,
		[groupseq10] [smallint] ,
		[groupseq11] [smallint] ,
		[groupseq12] [smallint] ,
		[groupseq13] [smallint] ,
		[groupseq14] [smallint] ,
		[groupseq15] [smallint] ,
		[firstopseq] [smallint] ,
		[act_hrs1] [SchedHoursType] ,
		[act_hrs2] [SchedHoursType] ,
		[act_hrs3] [SchedHoursType] ,
		[act_hrs4] [SchedHoursType] ,
		[act_hrs5] [SchedHoursType] ,
		[act_hrs6] [SchedHoursType] ,
		[act_hrs7] [SchedHoursType] ,
		[act_hrs8] [SchedHoursType] ,
		[act_hrs9] [SchedHoursType] ,
		[act_hrs10] [SchedHoursType] ,
		[act_hrs11] [SchedHoursType] ,
		[act_hrs12] [SchedHoursType] ,
		[act_hrs13] [SchedHoursType] ,
		[act_hrs14] [SchedHoursType] ,
		[act_hrs15] [SchedHoursType] ,
		[act_mech_hrs] [SchedHoursType],
		[jobDesc] [DescriptionType]  ,
		[UbHot] [TinyInt]  ,
		tentative_date DateType, 
		[calc_subassy_arr_date] [DateType],
		[NumSections] [int], -- Ref# 0000 OTD Added
		[EngLeadTime] [int] -- Ref# 0000 OTD Added
	)

	Declare @CrossSiteTable TABLE (	
		[sub_assy_site] [SiteType],
		[site_assignment] [SiteType],
		[last_group] [nvarchar](40),
		[last_group_seq] [int],
		[co_num] [CoNumType],
		[co_line] [CoLineType] ,
		[co_release] [CoReleaseType] ,
		[job_qty] [QtyUnitType]  ,
		[job] [JobType]  ,
		[suffix] [smallint]  ,
		[job_type] [JobTypeType] ,
		[material_cushion] [smallint]  ,
		[groupexists1] [smallint] ,
		[group_hrs1] [SchedHoursType] ,
		[num_workers1] [smallint] ,
		group1comb nvarchar(25),
		[groupexists2] [smallint] ,
		[group_hrs2] [SchedHoursType] ,
		[num_workers2] [smallint] ,
		group2comb nvarchar(25),
		[groupexists3] [smallint] ,
		[group_hrs3] [SchedHoursType] ,
		[num_workers3] [smallint] ,
		group3comb nvarchar(25),
		[groupexists4] [smallint] ,
		[group_hrs4] [SchedHoursType] ,
		[num_workers4] [smallint] ,
		group4comb nvarchar(25),
		[groupexists5] [smallint] ,
		[group_hrs5] [SchedHoursType] ,
		[num_workers5] [smallint] ,
		group5comb nvarchar(25),
		[groupexists6] [smallint] ,
		[group_hrs6] [SchedHoursType] ,
		[num_workers6] [smallint] ,
		group6comb nvarchar(25),
		[groupexists7] [smallint] ,
		[group_hrs7] [SchedHoursType] ,
		[num_workers7] [smallint] ,
		group7comb nvarchar(25),
		[groupexists8] [smallint] ,
		[group_hrs8] [SchedHoursType] ,
		[num_workers8] [smallint] ,
		group8comb nvarchar(25),
		[groupexists9] [smallint] ,
		[group_hrs9] [SchedHoursType] ,
		[num_workers9] [smallint] ,
		group9comb nvarchar(25),
		[groupexists10] [smallint] ,
		[group_hrs10] [SchedHoursType] ,
		[num_workers10] [smallint] ,
		group10comb nvarchar(25),
		[groupexists11] [smallint] ,
		[group_hrs11] [SchedHoursType] ,
		[num_workers11] [smallint] ,
		group11comb nvarchar(25),
		[groupexists12] [smallint] ,
		[group_hrs12] [SchedHoursType] ,
		[num_workers12] [smallint] ,
		group12comb nvarchar(25),
		[groupexists13] [smallint] ,
		[group_hrs13] [SchedHoursType] ,
		[num_workers13] [smallint] ,
		group13comb nvarchar(25),
		[groupexists14] [smallint] ,
		[group_hrs14] [SchedHoursType] ,
		[num_workers14] [smallint] ,
		group14comb nvarchar(25),
		[groupexists15] [smallint] ,
		[group_hrs15] [SchedHoursType] ,
		[num_workers15] [smallint] ,
		group15comb nvarchar(25),
		[mech_hrs] [SchedHoursType] ,
		[mech_num_workers] [smallint] ,
		mechanicalcomb nvarchar(25),
		[sub_assy_transit] [smallint] ,
		[prod_cycle_days] [smallint] ,
		[sch_subassy_ship_date] [DateType] ,
		[req_subassy_arr_date] [DateType] ,
		[sch_final_ship_date] [DateType] ,
		[cust_req_ship_date] [DateType] ,
		[prom_ship_date] [DateType] ,
		[start_date] [DateType] ,
		[assy_start_date] [DateType] ,
		first_op_seq smallint,
		[act_hrs1] [SchedHoursType] ,
		[act_hrs2] [SchedHoursType] ,
		[act_hrs3] [SchedHoursType] ,
		[act_hrs4] [SchedHoursType] ,
		[act_hrs5] [SchedHoursType] ,
		[act_hrs6] [SchedHoursType] ,
		[act_hrs7] [SchedHoursType] ,
		[act_hrs8] [SchedHoursType] ,
		[act_hrs9] [SchedHoursType] ,
		[act_hrs10] [SchedHoursType] ,
		[act_hrs11] [SchedHoursType] ,
		[act_hrs12] [SchedHoursType] ,
		[act_hrs13] [SchedHoursType] ,
		[act_hrs14] [SchedHoursType] ,
		[act_hrs15] [SchedHoursType] ,
		[act_mech_hrs] [SchedHoursType] ,
		[groupseq1] [smallint] ,
		[groupseq2] [smallint] ,
		[groupseq3] [smallint] ,
		[groupseq4] [smallint] ,
		[groupseq5] [smallint] ,
		[groupseq6] [smallint] ,
		[groupseq7] [smallint] ,
		[groupseq8] [smallint] ,
		[groupseq9] [smallint] ,
		[groupseq10] [smallint] ,
		[groupseq11] [smallint] ,
		[groupseq12] [smallint] ,
		[groupseq13] [smallint] ,
		[groupseq14] [smallint] ,
		[groupseq15] [smallint] ,
		[jobDesc] [DescriptionType]  ,
		[calc_subassy_arr_date] [DateType],
		[UbHot] [TinyInt]  ,
		tentative_date DateType, 
		[orig_ship_date] [DateType], -- never used, always a derived column, but needed for crossSite table to function
		[NumSections] [int], -- Ref# 0000 OTD Added
		[EngLeadTime] [int] -- Ref# 0000 OTD Added
	)

	DECLARE @GroupTable TABLE
		(GroupID		INT identity(1,1)
		,GroupName		nvarchar(40)
		,GroupSeq		Int
		,WC				WCType
		,MechanicalGroup		ListYesNoType
		)

	SET @Severity = 0
	
	Insert into @GroupTable
	(GroupName
	 ,GroupSeq
	 ,WC
	 ,MechanicalGroup)
	SELECT
		GroupName
		,GroupSequence
		,WC
		,MechanicalGroup
	From _IEM_SchGroupings order by GroupSequence		

	--select * from @GroupTable


	insert into @RptSet
		([sub_assy_site],
		[co_num],
		[co_line],
		[co_release],
		[job_qty],
		[job],
		[suffix], 
		[jobDesc],
		[sub_assy_transit],
		[sch_final_ship_date],
		tentative_date,
		[UbHot],
		[NumSections], -- Ref# 0000 OTD Added
		[EngLeadTime] -- Ref# 0000 OTD Added
		)
	SELECT
		@Site,
		ijrs.co_num,
		ijrs.co_line,
		ijrs.co_release,
		j.qty_released,
		ijrs.job,	
		ijrs.suffix,
		j.description,
		@SubAssyTransitDays,
		js.end_date,
		jtsd.tentative_date,
		j.Uf_hot,
		ci.Uf_numSections, -- Ref# 0000 OTD Added
		ci.Uf_EngLeadTime -- Ref# 0000 OTD Added
	FROM _IEM_JobRouteScheduler ijrs
	inner join job j on ijrs.job = j.job and ijrs.suffix = j.suffix
	left join job_sch js on j.job = js.job and j.suffix = js.suffix
	left join item on j.item = item.item
	left join coitem_all ci on ci.co_num=ijrs.co_num and ci.co_line=ijrs.co_line
	left join co_all co on co.co_num = ci.co_num
	left join _IEM_JobTentativeSchedDate jtsd on jtsd.job = j.job and jtsd.suffix = j.suffix
	where 
	ijrs.InWorkflow = 1
	and j.type = 'J' and ( (j.stat <> 'C' and j.qty_complete < j.qty_released) or exists (select 1 from co where co_num=@PCoNum))
	and isnull(ijrs.co_num,'') = (CASE WHEN isnull(@PCoNum,'') = '' THEN isnull(ijrs.co_num,'') ELSE @PCoNum END)
	and isnull(ijrs.co_line,0) = (CASE WHEN isnull(@PCoLine,0) = 0 THEN isnull(ijrs.co_line,0) ELSE @PCoLine END)
	and exists (select 1 from _IEM_SchPcodeUser pu where pu.Scheduler = @UserName and item.product_code = pu.ProductCode and pu.DisplayInScheduler=1)
	and exists (select 1 from _IEM_JobRouteScheduler ijrs2 where ijrs.job=ijrs2.job and ijrs.suffix=ijrs2.suffix and ijrs.CreateDate > isnull(@PJobsLoadedSince,'1900-01-09'))
	and (ISNULL(co.Uf_EngineeringSubmittal,'')<>'APPROVAL' or ci.Uf_DrawingApprDate is not null or @PIncludeUnApproved = 1)
	and (isnull(@POnlyTentative,0)=0 or jtsd.tentative_date is not null)
	and 
	( @PSelectDateType is null
	  or @PSelectDateType='Schedule Date' and js.end_date >= @PSelectStartDate and js.end_date <= @PSelectEndDate
	  or @PSelectDateType='Promise Date' and ci.Uf_PromiseDate >= @PSelectStartDate and ci.Uf_PromiseDate <= @PSelectEndDate
	  or @PSelectDateType='Request Date' and ci.promise_date >= @PSelectStartDate and ci.promise_date <= @PSelectEndDate
	) 
	group by ijrs.job, ijrs.suffix, j.description, j.Uf_hot, j.qty_released, ijrs.co_num, ijrs.co_line, ijrs.co_release, js.end_date, jtsd.tentative_date
	,ci.Uf_numSections,ci.Uf_EngLeadTime -- Ref# 0000 OTD Added

	IF @PCallSite <> @Site
	BEGIN
		Delete from @RptSet where isnull(co_num,'') = ''
	END

	Update rs
	SET rs.site_assignment = isnull(ci.uf_assign_site,ci.site_ref)
	From @RptSet rs 
	inner join coitem_all ci on rs.co_line = ci.co_line and rs.co_num = ci.co_num and rs.co_release = ci.co_release
	where ci.ship_site = ci.site_ref

	Update rs
	Set rs.site_assignment = dbo.parmssite()
	from @RptSet rs
	where isnull(rs.site_assignment,'') = ''

	-- remove records if called from another site, only pull jobs x-ref'd to orders where ship site = call site
	IF @PCallSite <> @Site
	BEGIN
		Delete from @RptSet where isnull(co_num,'') = ''
		-- djh 2016-10-24, must select other sites to get requested subassembly arrival date in the table
		--Delete from @RptSet where site_assignment <> @PCallSite
	END


	;with jrs as (select ijrs.*,isg.GroupName as iGroupName,isg.GroupSequence as iGroupSequence,isg.MechanicalGroup,isg.ConcurrentID as iConcurrentID from _IEM_JobRouteScheduler ijrs 
	join _IEM_SchGroupings isg on isg.wc = ijrs.wc)
	Update rs
	SET
		rs.group_hrs1 = js.group_hrs1
		,rs.num_workers1 = js.num_workers1
		,rs.groupexists1 = js.group_exists1
		,rs.act_hrs1 = js.act_hrs1

		,rs.group_hrs2 = js.group_hrs2
		,rs.num_workers2 = js.num_workers2
		,rs.groupexists2 = js.group_exists2
		,rs.act_hrs2 = js.act_hrs2

		,rs.group_hrs3 = js.group_hrs3
		,rs.num_workers3 = js.num_workers3
		,rs.groupexists3 = js.group_exists3
		,rs.act_hrs3 = js.act_hrs3

		,rs.group_hrs4 = js.group_hrs4
		,rs.num_workers4 = js.num_workers4
		,rs.groupexists4 = js.group_exists4
		,rs.act_hrs4 = js.act_hrs4

		,rs.group_hrs5 = js.group_hrs5
		,rs.num_workers5 = js.num_workers5
		,rs.groupexists5 = js.group_exists5
		,rs.act_hrs5 = js.act_hrs5

		,rs.group_hrs6 = js.group_hrs6
		,rs.num_workers6 = js.num_workers6
		,rs.groupexists6 = js.group_exists6
		,rs.act_hrs6 = js.act_hrs6

		,rs.group_hrs7 = js.group_hrs7
		,rs.num_workers7 = js.num_workers7
		,rs.groupexists7 = js.group_exists7
		,rs.act_hrs7 = js.act_hrs7

		,rs.group_hrs8 = js.group_hrs8
		,rs.num_workers8 = js.num_workers8
		,rs.groupexists8 = js.group_exists8
		,rs.act_hrs8 = js.act_hrs8

		,rs.group_hrs9 = js.group_hrs9
		,rs.num_workers9 = js.num_workers9
		,rs.groupexists9 = js.group_exists9
		,rs.act_hrs9 = js.act_hrs9

		,rs.group_hrs10 = js.group_hrs10
		,rs.num_workers10 = js.num_workers10
		,rs.groupexists10 = js.group_exists10
		,rs.act_hrs10 = js.act_hrs10

		,rs.group_hrs11 = js.group_hrs11
		,rs.num_workers11 = js.num_workers11
		,rs.groupexists11 = js.group_exists11
		,rs.act_hrs11 = js.act_hrs11

		,rs.group_hrs12 = js.group_hrs12
		,rs.num_workers12 = js.num_workers12
		,rs.groupexists12 = js.group_exists12
		,rs.act_hrs12 = js.act_hrs12

		,rs.group_hrs13 = js.group_hrs13
		,rs.num_workers13 = js.num_workers13
		,rs.groupexists13 = js.group_exists13
		,rs.act_hrs13 = js.act_hrs13

		,rs.group_hrs14 = js.group_hrs14
		,rs.num_workers14 = js.num_workers14
		,rs.groupexists14 = js.group_exists14
		,rs.act_hrs14 = js.act_hrs14

		,rs.group_hrs15 = js.group_hrs15
		,rs.num_workers15 = js.num_workers15
		,rs.groupexists15 = js.group_exists15
		,rs.act_hrs15 = js.act_hrs15
	from @RptSet rs inner join 
	(SELECT 
		jrs.job
		,jrs.suffix 
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 1 then jrs.sched_hrs else 0 END) as group_hrs1
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 1 then jrs.NumWorkers else 0 END) as num_workers1
		,SUM(CASE WHEN isnull(gt.groupID,0) = 1 THEN 1 else 0 END) as group_exists1
		,SUM(CASE WHEN isnull(gt.groupID,0) = 1 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs1

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 2 then jrs.sched_hrs else 0 END) as group_hrs2
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 2 then jrs.NumWorkers else 0 END) as num_workers2
		,SUM(CASE WHEN isnull(gt.groupID,0) = 2 THEN 1 else 0 END) as group_exists2 
		,SUM(CASE WHEN isnull(gt.groupID,0) = 2 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs2

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 3 then jrs.sched_hrs else 0 END) as group_hrs3
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 3 then jrs.NumWorkers else 0 END) as num_workers3
		,SUM(CASE WHEN isnull(gt.groupID,0) = 3 THEN 1 else 0 END) as group_exists3 
		,SUM(CASE WHEN isnull(gt.groupID,0) = 3 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs3

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 4 then jrs.sched_hrs else 0 END) as group_hrs4
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 4 then jrs.NumWorkers else 0 END) as num_workers4
		,SUM(CASE WHEN isnull(gt.groupID,0) = 4 THEN 1 else 0 END) as group_exists4
		,SUM(CASE WHEN isnull(gt.groupID,0) = 4 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs4

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 5 then jrs.sched_hrs else 0 END) as group_hrs5
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 5 then jrs.NumWorkers else 0 END) as num_workers5
		,SUM(CASE WHEN isnull(gt.groupID,0) = 5 THEN 1 else 0 END) as group_exists5
		,SUM(CASE WHEN isnull(gt.groupID,0) = 5 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs5

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 6 then jrs.sched_hrs else 0 END) as group_hrs6
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 6 then jrs.NumWorkers else 0 END) as num_workers6
		,SUM(CASE WHEN isnull(gt.groupID,0) = 6 THEN 1 else 0 END) as group_exists6
		,SUM(CASE WHEN isnull(gt.groupID,0) = 6 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs6

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 7 then jrs.sched_hrs else 0 END) as group_hrs7
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 7 then jrs.NumWorkers else 0 END) as num_workers7
		,SUM(CASE WHEN isnull(gt.groupID,0) = 7 THEN 1 else 0 END) as group_exists7
		,SUM(CASE WHEN isnull(gt.groupID,0) = 7 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs7

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 8 then jrs.sched_hrs else 0 END) as group_hrs8
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 8 then jrs.NumWorkers else 0 END) as num_workers8
		,SUM(CASE WHEN isnull(gt.groupID,0) = 8 THEN 1 else 0 END) as group_exists8
		,SUM(CASE WHEN isnull(gt.groupID,0) = 8 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs8

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 9 then jrs.sched_hrs else 0 END) as group_hrs9
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 9 then jrs.NumWorkers else 0 END) as num_workers9
		,SUM(CASE WHEN isnull(gt.groupID,0) = 9 THEN 1 else 0 END) as group_exists9
		,SUM(CASE WHEN isnull(gt.groupID,0) = 9 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs9

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 10 then jrs.sched_hrs else 0 END) as group_hrs10
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 10 then jrs.NumWorkers else 0 END) as num_workers10
		,SUM(CASE WHEN isnull(gt.groupID,0) = 10 THEN 1 else 0 END) as group_exists10
		,SUM(CASE WHEN isnull(gt.groupID,0) = 10 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs10

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 11 then jrs.sched_hrs else 0 END) as group_hrs11
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 11 then jrs.NumWorkers else 0 END) as num_workers11
		,SUM(CASE WHEN isnull(gt.groupID,0) = 11 THEN 1 else 0 END) as group_exists11
		,SUM(CASE WHEN isnull(gt.groupID,0) = 11 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs11

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 12 then jrs.sched_hrs else 0 END) as group_hrs12
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 12 then jrs.NumWorkers else 0 END) as num_workers12
		,SUM(CASE WHEN isnull(gt.groupID,0) = 12 THEN 1 else 0 END) as group_exists12
		,SUM(CASE WHEN isnull(gt.groupID,0) = 12 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs12

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 13 then jrs.sched_hrs else 0 END) as group_hrs13
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 13 then jrs.NumWorkers else 0 END) as num_workers13
		,SUM(CASE WHEN isnull(gt.groupID,0) = 13 THEN 1 else 0 END) as group_exists13
		,SUM(CASE WHEN isnull(gt.groupID,0) = 13 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs13

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 14 then jrs.sched_hrs else 0 END) as group_hrs14
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 14 then jrs.NumWorkers else 0 END) as num_workers14
		,SUM(CASE WHEN isnull(gt.groupID,0) = 14 THEN 1 else 0 END) as group_exists14
		,SUM(CASE WHEN isnull(gt.groupID,0) = 14 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs14

		,SUM(CASE WHEN isnull(gt.GroupID,0) = 15 then jrs.sched_hrs else 0 END) as group_hrs15
		,SUM(CASE WHEN isnull(gt.GroupID,0) = 15 then jrs.NumWorkers else 0 END) as num_workers15
		,SUM(CASE WHEN isnull(gt.groupID,0) = 15 THEN 1 else 0 END) as group_exists15
		,SUM(CASE WHEN isnull(gt.groupID,0) = 15 THEN isnull(jr.run_hrs_t_lbr,0) else 0 END) as act_hrs15
	from jrs 
	LEFT join @GroupTable gt on jrs.iGroupSequence = gt.GroupSeq 
	inner join job j on jrs.job = j.job and jrs.suffix = j.suffix
	left join jobroute jr on jrs.job = jr.job and jrs.suffix = jr.suffix and jrs.wc = jr.wc and jr.oper_num = (select top 1 tjr.oper_num from jobroute tjr where tjr.job = jr.job and tjr.suffix = jr.suffix and tjr.wc = jr.wc order by oper_num)
	where j.type = 'J' and (j.stat <> 'C' or j.qty_complete < j.qty_released)
	group by jrs.job, jrs.suffix) js on rs.job = js.job and rs.suffix = js.suffix

	--select * from @RptSet

	update rs
	SET 
		rs.groupseq1 = (SELECT GroupSeq from @GroupTable where GroupID = 1)
		,rs.groupseq2 = (SELECT GroupSeq from @GroupTable where GroupID = 2)
		,rs.groupseq3 = (SELECT GroupSeq from @GroupTable where GroupID = 3)
		,rs.groupseq4 = (SELECT GroupSeq from @GroupTable where GroupID = 4)
		,rs.groupseq5 = (SELECT GroupSeq from @GroupTable where GroupID = 5)
		,rs.groupseq6 = (SELECT GroupSeq from @GroupTable where GroupID = 6)
		,rs.groupseq7 = (SELECT GroupSeq from @GroupTable where GroupID = 7)
		,rs.groupseq8 = (SELECT GroupSeq from @GroupTable where GroupID = 8)
		,rs.groupseq9 = (SELECT GroupSeq from @GroupTable where GroupID = 9)
		,rs.groupseq10 = (SELECT GroupSeq from @GroupTable where GroupID = 10)
		,rs.groupseq11 = (SELECT GroupSeq from @GroupTable where GroupID = 11)
		,rs.groupseq12 = (SELECT GroupSeq from @GroupTable where GroupID = 12)
		,rs.groupseq13 = (SELECT GroupSeq from @GroupTable where GroupID = 13)
		,rs.groupseq14 = (SELECT GroupSeq from @GroupTable where GroupID = 14)
		,rs.groupseq15 = (SELECT GroupSeq from @GroupTable where GroupID = 15)
	from @RptSet rs

	Update rs
	Set
		rs.num_workers1 = CASE WHEN rs.group_hrs1 > 0 and rs.num_workers1 = 0 then 1 else rs.num_workers1 END
		,rs.num_workers2 = CASE WHEN rs.group_hrs2 > 0 and rs.num_workers2 = 0 then 1 else rs.num_workers2 END
		,rs.num_workers3 = CASE WHEN rs.group_hrs3 > 0 and rs.num_workers3 = 0 then 1 else rs.num_workers3 END
		,rs.num_workers4 = CASE WHEN rs.group_hrs4 > 0 and rs.num_workers4 = 0 then 1 else rs.num_workers4 END
		,rs.num_workers5 = CASE WHEN rs.group_hrs5 > 0 and rs.num_workers5 = 0 then 1 else rs.num_workers5 END
		,rs.num_workers6 = CASE WHEN rs.group_hrs6 > 0 and rs.num_workers6 = 0 then 1 else rs.num_workers6 END
		,rs.num_workers7 = CASE WHEN rs.group_hrs7 > 0 and rs.num_workers7 = 0 then 1 else rs.num_workers7 END
		,rs.num_workers8 = CASE WHEN rs.group_hrs8 > 0 and rs.num_workers8 = 0 then 1 else rs.num_workers8 END
		,rs.num_workers9 = CASE WHEN rs.group_hrs9 > 0 and rs.num_workers9 = 0 then 1 else rs.num_workers9 END
		,rs.num_workers10 = CASE WHEN rs.group_hrs10 > 0 and rs.num_workers10 = 0 then 1 else rs.num_workers10 END
		,rs.num_workers11 = CASE WHEN rs.group_hrs11 > 0 and rs.num_workers11 = 0 then 1 else rs.num_workers11 END
		,rs.num_workers12 = CASE WHEN rs.group_hrs12 > 0 and rs.num_workers12 = 0 then 1 else rs.num_workers12 END
		,rs.num_workers13 = CASE WHEN rs.group_hrs13 > 0 and rs.num_workers13 = 0 then 1 else rs.num_workers13 END
		,rs.num_workers14 = CASE WHEN rs.group_hrs14 > 0 and rs.num_workers14 = 0 then 1 else rs.num_workers14 END
		,rs.num_workers15 = CASE WHEN rs.group_hrs15 > 0 and rs.num_workers15 = 0 then 1 else rs.num_workers15 END
	From @RptSet rs

	update rs
		SET rs.firstopseq = CASE
								WHEN groupexists1 = 1 then rs.groupseq1
								WHEN groupexists2 = 1 then rs.groupseq2
								WHEN groupexists3 = 1 then rs.groupseq3
								WHEN groupexists4 = 1 then rs.groupseq4
								WHEN groupexists5 = 1 then rs.groupseq5
								WHEN groupexists6 = 1 then rs.groupseq6
								WHEN groupexists7 = 1 then rs.groupseq7
								WHEN groupexists8 = 1 then rs.groupseq8
								WHEN groupexists9 = 1 then rs.groupseq9
								WHEN groupexists10 = 1 then rs.groupseq10
								WHEN groupexists11 = 1 then rs.groupseq11
								WHEN groupexists12 = 1 then rs.groupseq12
								WHEN groupexists13 = 1 then rs.groupseq13
								WHEN groupexists14 = 1 then rs.groupseq14
								WHEN groupexists15 = 1 then rs.groupseq15


								ELSE rs.Groupseq15
							END
			,rs.last_group_seq = CASE WHEN groupexists15 = 1 THEN rs.Groupseq15
								WHEN groupexists14 = 1 THEN rs.Groupseq14
								WHEN groupexists13 = 1 THEN rs.Groupseq13
								WHEN groupexists12 = 1 THEN rs.Groupseq12
								WHEN groupexists11 = 1 THEN rs.Groupseq11
								WHEN groupexists10 = 1 THEN rs.Groupseq10
								WHEN groupexists9 = 1 THEN rs.Groupseq9
								WHEN groupexists8 = 1 THEN rs.Groupseq8
								WHEN groupexists7 = 1 THEN rs.Groupseq7
								WHEN groupexists6 = 1 THEN rs.Groupseq6
								WHEN groupexists5 = 1 THEN rs.Groupseq5
								WHEN groupexists4 = 1 THEN rs.Groupseq4
								WHEN groupexists3 = 1 THEN rs.Groupseq3
								WHEN groupexists2 = 1 THEN rs.Groupseq2
								ELSE rs.Groupseq1
							END
	from @RptSet rs

	Update rs
		Set rs.last_group = gt.GroupName
	from @RptSet rs inner join @GroupTable gt on rs.last_group_seq = gt.GroupSeq

	-- Mechanical Update
	BEGIN
		DECLARE
			@MechGroup1			ListYesNoType
			,@MechGroup2		ListYesNoType
			,@MechGroup3		ListYesNoType
			,@MechGroup4		ListYesNoType
			,@MechGroup5		ListYesNoType
			,@MechGroup6		ListYesNoType
			,@MechGroup7		ListYesNoType
			,@MechGroup8		ListYesNoType
			,@MechGroup9		ListYesNoType
			,@MechGroup10		ListYesNoType
			,@MechGroup11		ListYesNoType
			,@MechGroup12		ListYesNoType
			,@MechGroup13		ListYesNoType
			,@MechGroup14		ListYesNoType
			,@MechGroup15		ListYesNoType

		SELECT
			@MechGroup1		= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 1),0)
			,@MechGroup2	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 2),0)		
			,@MechGroup3	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 3),0)
			,@MechGroup4	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 4),0)
			,@MechGroup5	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 5),0)
			,@MechGroup6	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 6),0)
			,@MechGroup7	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 7),0)
			,@MechGroup8	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 8),0)
			,@MechGroup9	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 9),0)
			,@MechGroup10	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 10),0)
			,@MechGroup11	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 11),0)
			,@MechGroup12	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 12),0)
			,@MechGroup13	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 13),0)
			,@MechGroup14	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 14),0)
			,@MechGroup15	= isnull((Select top 1 MechanicalGroup from @GroupTable where GroupID = 15),0)

		update rs
		set rs.mech_hrs = CASE WHEN @MechGroup1 = 1 THEN group_hrs1 ELSE 0 END
							+ 	CASE WHEN @MechGroup2 = 1 THEN group_hrs2 ELSE 0 END
							+ 	CASE WHEN @MechGroup3 = 1 THEN group_hrs3 ELSE 0 END
							+ 	CASE WHEN @MechGroup4 = 1 THEN group_hrs4 ELSE 0 END
							+ 	CASE WHEN @MechGroup5 = 1 THEN group_hrs5 ELSE 0 END
							+ 	CASE WHEN @MechGroup6 = 1 THEN group_hrs6 ELSE 0 END
							+ 	CASE WHEN @MechGroup7 = 1 THEN group_hrs7 ELSE 0 END
							+ 	CASE WHEN @MechGroup8 = 1 THEN group_hrs8 ELSE 0 END
							+ 	CASE WHEN @MechGroup9 = 1 THEN group_hrs9 ELSE 0 END
							+ 	CASE WHEN @MechGroup10 = 1 THEN group_hrs10 ELSE 0 END
							+ 	CASE WHEN @MechGroup11 = 1 THEN group_hrs11 ELSE 0 END
							+ 	CASE WHEN @MechGroup12 = 1 THEN group_hrs12 ELSE 0 END
							+ 	CASE WHEN @MechGroup13 = 1 THEN group_hrs13 ELSE 0 END
							+ 	CASE WHEN @MechGroup14 = 1 THEN group_hrs14 ELSE 0 END
							+ 	CASE WHEN @MechGroup15 = 1 THEN group_hrs15 ELSE 0 END

			,rs.mech_num_workers = (select MAX(workers) from (values (CASE WHEN @MechGroup1 = 1 AND group_hrs1 > 0 THEN num_workers1 ELSE 0 END)
							,(	CASE WHEN @MechGroup2 = 1 AND group_hrs2 > 0 THEN num_workers2 ELSE 0 END)
							,(	CASE WHEN @MechGroup3 = 1 AND group_hrs3 > 0 THEN num_workers3 ELSE 0 END)
							,(	CASE WHEN @MechGroup4 = 1 AND group_hrs4 > 0 THEN num_workers4 ELSE 0 END)
							,(	CASE WHEN @MechGroup5 = 1 AND group_hrs5 > 0 THEN num_workers5 ELSE 0 END)
							,(	CASE WHEN @MechGroup6 = 1 AND group_hrs6 > 0 THEN num_workers6 ELSE 0 END)
							,(	CASE WHEN @MechGroup7 = 1 AND group_hrs7 > 0 THEN num_workers7 ELSE 0 END)
							,(	CASE WHEN @MechGroup8 = 1 AND group_hrs8 > 0 THEN num_workers8 ELSE 0 END)
							,(	CASE WHEN @MechGroup9 = 1 AND group_hrs9 > 0 THEN num_workers9 ELSE 0 END)
							,(	CASE WHEN @MechGroup10 = 1 AND group_hrs10 > 0 THEN num_workers10 ELSE 0 END)
							,(	CASE WHEN @MechGroup11 = 1 AND group_hrs11 > 0 THEN num_workers11 ELSE 0 END)
							,(	CASE WHEN @MechGroup12 = 1 AND group_hrs12 > 0 THEN num_workers12 ELSE 0 END)
							,(	CASE WHEN @MechGroup13 = 1 AND group_hrs13 > 0 THEN num_workers13 ELSE 0 END)
							,(	CASE WHEN @MechGroup14 = 1 AND group_hrs14 > 0 THEN num_workers14 ELSE 0 END)
							,(	CASE WHEN @MechGroup15 = 1 AND group_hrs15 > 0 THEN num_workers15 ELSE 0 END)) as allworkers(workers))

			,rs.act_mech_hrs = CASE WHEN @MechGroup1 = 1 THEN act_hrs1 ELSE 0 END
							+ 	CASE WHEN @MechGroup2 = 1 THEN act_hrs2 ELSE 0 END
							+ 	CASE WHEN @MechGroup3 = 1 THEN act_hrs3 ELSE 0 END
							+ 	CASE WHEN @MechGroup4 = 1 THEN act_hrs4 ELSE 0 END
							+ 	CASE WHEN @MechGroup5 = 1 THEN act_hrs5 ELSE 0 END
							+ 	CASE WHEN @MechGroup6 = 1 THEN act_hrs6 ELSE 0 END
							+ 	CASE WHEN @MechGroup7 = 1 THEN act_hrs7 ELSE 0 END
							+ 	CASE WHEN @MechGroup8 = 1 THEN act_hrs8 ELSE 0 END
							+ 	CASE WHEN @MechGroup9 = 1 THEN act_hrs9 ELSE 0 END
							+ 	CASE WHEN @MechGroup10 = 1 THEN act_hrs10 ELSE 0 END
							+ 	CASE WHEN @MechGroup11 = 1 THEN act_hrs11 ELSE 0 END
							+ 	CASE WHEN @MechGroup12 = 1 THEN act_hrs12 ELSE 0 END
							+ 	CASE WHEN @MechGroup13 = 1 THEN act_hrs13 ELSE 0 END
							+ 	CASE WHEN @MechGroup14 = 1 THEN act_hrs14 ELSE 0 END
							+ 	CASE WHEN @MechGroup15 = 1 THEN act_hrs15 ELSE 0 END
		from @RptSet rs

	END

	IF --@PIncludeCrossSite = 1 AND 
	@PCallSite = @Site
	BEGIN
		Declare site_cursor Cursor FOR
		SELECT
			distinct(app_db_name)
		from site where site <> @Site
		and isnull(uf_mfg,0) = 1
		and type = 'S'

		Open site_cursor

		While 1=1
		BEGIN
			FETCH Next from site_cursor into @PDestPrefix


			IF @@Fetch_status <> 0
			BREAK
			Print @Site

			select @SQL = @PDestPrefix + '.._IEM_CLM_SchLoadSchedulerFastSp'
			print @Sql
			INSERT INTO @CrossSiteTable
			EXEC @Severity = @SQL	
			--exec @Severity = _IEM_GetCrossSiteToShipSp
				@PIncludeCrossSite	= 0
				,@PCallSite			= @Site
				,@PCoNum			= @PCoNum
				,@Infobar			= @Infobar		OUTPUT
				,@PCoLine			= @PCoLine
				,@PJobsLoadedSince  = @PJobsLoadedSince
				,@UserName          = @UserName
				,@PIncludeUnApproved = @PIncludeUnApproved
				,@PSelectDateType = NULL -- do not filter sub jobs or we will lose joined information
				,@PSelectStartDate = @PSelectStartDate
				,@PSelectEndDate = @PSelectEndDate
				,@POnlyTentative = @POnlyTentative
				--@PIncludeCrossSite		ListYesNoType = NULL
				--,@PCallSite				SiteType = NULL
				--,@PCoNum				CoNumType = NULL
				--,@Infobar				InfobarType	= NULL		OUTPUT
				--,@PCoLine				CoLineType = NULL

			EXEC [dbo].[SetSiteSp] @Site, @SetSiteInfobar OUTPUT
		END
		close site_cursor
		deallocate site_cursor
	END

	;with ijrs as (select ijrs.*,isg.GroupName as iGroupName,isg.GroupSequence as iGroupSequence,isg.MechanicalGroup,isg.ConcurrentID as iConcurrentID from _IEM_JobRouteScheduler ijrs 
	join _IEM_SchGroupings isg on isg.wc = ijrs.wc and ijrs.InWorkflow=1)
	Update rs
	set rs.start_date = (Select start_date from job_sch where job = rs.job and suffix = rs.suffix)
							--CASE WHEN isnull(rs.co_num,'') > ''
							--	THEN 
							--		(select top 1 sched_date from _IEM_JobRouteScheduler ijrs where ijrs.co_num = rs.co_num and ijrs.co_line = rs.co_line and ijrs.co_release = rs.co_release
							--				and not ijrs.sched_date is null
							--				order by sched_date ASC)
							--	ELSE (select top 1 sched_date from _IEM_JobRouteScheduler ijrs where ijrs.job = rs.job and ijrs.suffix = rs.suffix and not ijrs.sched_date is null
							--				order by sched_date ASC)	
							--END
		,rs.assy_start_date = CASE WHEN isnull(rs.co_num,'') > ''
								THEN (select top 1 sched_date from ijrs
										 where ijrs.co_num = rs.co_num and ijrs.co_line = rs.co_line and ijrs.co_release = rs.co_release
											and not ijrs.sched_date is null
											and ijrs.MechanicalGroup = 1
											order by ijrs.iGroupSequence asc)
								ELSE (select top 1 sched_date from ijrs
										where ijrs.job = rs.job and ijrs.suffix = rs.suffix and ijrs.MechanicalGroup = 1
											and not ijrs.sched_date is null
											order by ijrs.iGroupSequence asc)	
							END
		,rs.cust_req_ship_date = cia.promise_date
		--,rs.sch_final_ship_date = cia.due_date
		,rs.prom_ship_date = cia.Uf_PromiseDate 
	from @RptSet rs left join coitem_all cia on rs.co_num = cia.co_num and rs.co_line = cia.co_line and rs.co_release = cia.co_release
	and cia.site_ref = cia.ship_site

	Update @RptSet	
			Set sch_subassy_ship_date = dbo._IEM_GetMCalDateFromDateByDays(start_date,sub_assy_transit,1)
				,calc_subassy_arr_date = start_date
			Where isnull(co_num,'') <> ''

		
	IF @PCallSite = @Site
	BEGIN
			DECLARE @QuickTable TABLE
				(co_num					CoNumType
				,co_line				CoLineType
				,co_release				CoReleaseType
				,last_group_seq			int
				,calc_subassy_arr_date	date
				,sch_final_ship_date	date)

			Insert into @QuickTable
			SELECT
				co_num,
				co_line,
				co_release,
				last_group_seq,
				calc_subassy_arr_date,
				sch_final_ship_date
			from @RptSet where isnull(co_num,'') <> ''
			union 
			SELECT
				co_num,
				co_line,
				co_release,
				last_group_seq,
				calc_subassy_arr_date,
				sch_final_ship_date
			from @CrossSiteTable where isnull(co_num,'') <> ''


			Update rs 
			SET rs.req_subassy_arr_date = (Select top 1 calc_subassy_arr_date from @QuickTable gt 
											where gt.co_num = rs.co_num and gt.co_line = rs.co_line and gt.co_release = rs.co_release 
											and rs.last_group_seq < gt.last_group_seq order by gt.last_group_seq ASC)
				,rs.sch_subassy_ship_date = (select top 1 sch_final_ship_date from @QuickTable gt
											 where gt.co_num = rs.co_num and gt.co_line = rs.co_line and gt.co_release = rs.co_release
											 and rs.last_group_seq > gt.last_group_seq order by gt.last_group_seq ASC)	
			from @RptSet rs 
			where isnull(rs.co_num,'') <> ''

			Update rs 
			SET rs.req_subassy_arr_date = (Select top 1 calc_subassy_arr_date from @QuickTable gt 
											where gt.co_num = rs.co_num and gt.co_line = rs.co_line and gt.co_release = rs.co_release 
											and rs.last_group_seq < gt.last_group_seq order by gt.last_group_seq ASC)
				,rs.sch_subassy_ship_date = (select top 1 sch_final_ship_date from @QuickTable gt
											 where gt.co_num = rs.co_num and gt.co_line = rs.co_line and gt.co_release = rs.co_release
											 and rs.last_group_seq > gt.last_group_seq order by gt.last_group_seq ASC)		
			from @CrossSiteTable rs 
			where isnull(rs.co_num,'') <> ''


	END --IF @PCallSite = @Site
	
	IF @PCallSite <> @Site
	BEGIN
		SELECT 
		sub_assy_site
		,site_assignment
		,last_group
		,last_group_seq
		,co_num
		,co_line
		,co_release
		,job_qty
		,job
		,suffix
		,job_type
		,material_cushion

		,groupexists1
		,group_hrs1
		,num_workers1
		,CASE WHEN isnull(groupexists1,0) = 1 THEN 
			CAST(CAST(group_hrs1 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers1 as nvarchar(3))
			ELSE ''
		END as groupcomb1

		,groupexists2
		,group_hrs2
		,num_workers2
		,CASE WHEN isnull(groupexists2,0) = 1 THEN 
			CAST(CAST(group_hrs2 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers2 as nvarchar(3))
			ELSE ''
		END as groupcomb2

		,groupexists3
		,group_hrs3
		,num_workers3
		,CASE WHEN isnull(groupexists3,0) = 1 THEN 
			CAST(CAST(group_hrs3 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers3 as nvarchar(3))
			ELSE ''
		END as groupcomb3

		,groupexists4
		,group_hrs4
		,num_workers4
		,CASE WHEN isnull(groupexists4,0) = 1 THEN 
			CAST(CAST(group_hrs4 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers4 as nvarchar(3))
			ELSE ''
		END as groupcomb4

		,groupexists5
		,group_hrs5
		,num_workers5
		,CASE WHEN isnull(groupexists5,0) = 1 THEN 
			CAST(CAST(group_hrs5 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers5 as nvarchar(3))
			ELSE ''
		END as groupcomb5

		,groupexists6
		,group_hrs6
		,num_workers6
		,CASE WHEN isnull(groupexists6,0) = 1 THEN 
			CAST(CAST(group_hrs6 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers6 as nvarchar(3))
			ELSE ''
		END as groupcomb6

		,groupexists7
		,group_hrs7
		,num_workers7
		,CASE WHEN isnull(groupexists7,0) = 1 THEN 
			CAST(CAST(group_hrs7 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers7 as nvarchar(3))
			ELSE ''
		END as groupcomb7

		,groupexists8
		,group_hrs8
		,num_workers8
		,CASE WHEN isnull(groupexists8,0) = 1 THEN 
			CAST(CAST(group_hrs8 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers8 as nvarchar(3))
			ELSE ''
		END as groupcomb8

		,groupexists9
		,group_hrs9
		,num_workers9
		,CASE WHEN isnull(groupexists9,0) = 1 THEN 
			CAST(CAST(group_hrs9 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers9 as nvarchar(3))
			ELSE ''
		END as groupcomb9

		,groupexists10
		,group_hrs10
		,num_workers10
		,CASE WHEN isnull(groupexists10,0) = 1 THEN 
			CAST(CAST(group_hrs10 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers10 as nvarchar(3))
			ELSE ''
		END as groupcomb10

		,groupexists11
		,group_hrs11
		,num_workers11
		,CASE WHEN isnull(groupexists11,0) = 1 THEN 
			CAST(CAST(group_hrs11 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers11 as nvarchar(3))
			ELSE ''
		END as groupcomb11

		,groupexists12
		,group_hrs12
		,num_workers12
		,CASE WHEN isnull(groupexists12,0) = 1 THEN 
			CAST(CAST(group_hrs12 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers12 as nvarchar(3))
			ELSE ''
		END as groupcomb12

		,groupexists13
		,group_hrs13
		,num_workers13
		,CASE WHEN isnull(groupexists13,0) = 1 THEN 
			CAST(CAST(group_hrs13 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers13 as nvarchar(3))
			ELSE ''
		END as groupcomb13

		,groupexists14
		,group_hrs14
		,num_workers14
		,CASE WHEN isnull(groupexists14,0) = 1 THEN 
			CAST(CAST(group_hrs14 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers14 as nvarchar(3))
			ELSE ''
		END as groupcomb14

		,groupexists15
		,group_hrs15
		,num_workers15
		,CASE WHEN isnull(groupexists15,0) = 1 THEN 
			CAST(CAST(group_hrs15 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers15 as nvarchar(3))
			ELSE ''
		END as groupcomb15


		,mech_hrs
		,mech_num_workers
		,CASE WHEN not mech_hrs is null THEN	
			CAST(CAST(mech_hrs as decimal(7,1)) as nvarchar(8)) + 
				CASE WHEN  @GroupMechanical = 1 THEN --grouping mech variable check
					'/' + CAST(mech_num_workers as nvarchar(3)) 
					ELSE ''
				END
			ELSE NULL
		 END as mech_comb
		,sub_assy_transit
		,prod_cycle_days
		,sch_subassy_ship_date
		,req_subassy_arr_date
		,sch_final_ship_date
		,cust_req_ship_date
		,prom_ship_date
		,start_date
		,assy_start_date
		,firstopseq
		,act_hrs1
		,act_hrs2
		,act_hrs3
		,act_hrs4
		,act_hrs5
		,act_hrs6
		,act_hrs7
		,act_hrs8
		,act_hrs9
		,act_hrs10
		,act_hrs11
		,act_hrs12
		,act_hrs13
		,act_hrs14
		,act_hrs15
		,act_mech_hrs
		,groupseq1  
		,groupseq2  
		,groupseq3 
		,groupseq4
		,groupseq5
		,groupseq6
		,groupseq7  
		,groupseq8  
		,groupseq9  
		,groupseq10  
		,groupseq11  
		,groupseq12  
		,groupseq13  
		,groupseq14
		,groupseq15
		,jobDesc
		,calc_subassy_arr_date
		,UbHot
		,tentative_date
		,sch_final_ship_date as orig_ship_date
		,NumSections -- Ref# 0000 OTD Added
		,EngLeadTime -- Ref# 0000 OTD Added
	FROM @RptSet r

	END

	ELSE BEGIN
		
		--The JobType of J will be used to identify jobs where the scheduled subasssy ship date is > 5 days of the requested value
		Update rs2
		set job_type = 'J'
		From @RptSet rs2 inner join 
		(select  
			max(ct.last_group_seq) as last_group_seq
			,ct.co_num as co_num
			,ct.co_line as co_line
			,DATEDIFF(DAY, max(ct.req_subassy_arr_date), max(ct.sch_final_ship_date) ) as date_diff
		from 
		@RptSet rs inner join @CrossSiteTable ct on rs.co_num = ct.co_num and rs.co_line = ct.co_line and rs.last_group_seq > ct.last_group_seq
		group by ct.co_num, ct.co_line) ct2 on rs2.co_num = ct2.co_num and rs2.co_line = ct2.co_line and date_diff > 5


		IF @PIncludeCrossSite = 0
		Delete from @CrossSiteTable

		SELECT 
			sub_assy_site
			,site_assignment
			,last_group
			,last_group_seq
			,co_num
			,co_line
			,co_release
			,job_qty
			,job
			,suffix
			,job_type
			,material_cushion

			,groupexists1
			,group_hrs1
			,num_workers1
			,CASE WHEN isnull(groupexists1,0) = 1 THEN 
				CAST(CAST(group_hrs1 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers1 as nvarchar(3))
				ELSE ''
			END as groupcomb1

			,groupexists2
			,group_hrs2
			,num_workers2
			,CASE WHEN isnull(groupexists2,0) = 1 THEN 
				CAST(CAST(group_hrs2 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers2 as nvarchar(3))
				ELSE ''
			END as groupcomb2

			,groupexists3
			,group_hrs3
			,num_workers3
			,CASE WHEN isnull(groupexists3,0) = 1 THEN 
				CAST(CAST(group_hrs3 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers3 as nvarchar(3))
				ELSE ''
			END as groupcomb3

			,groupexists4
			,group_hrs4
			,num_workers4
			,CASE WHEN isnull(groupexists4,0) = 1 THEN 
				CAST(CAST(group_hrs4 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers4 as nvarchar(3))
				ELSE ''
			END as groupcomb4

			,groupexists5
			,group_hrs5
			,num_workers5
			,CASE WHEN isnull(groupexists5,0) = 1 THEN 
				CAST(CAST(group_hrs5 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers5 as nvarchar(3))
				ELSE ''
			END as groupcomb5

			,groupexists6
			,group_hrs6
			,num_workers6
			,CASE WHEN isnull(groupexists6,0) = 1 THEN 
				CAST(CAST(group_hrs6 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers6 as nvarchar(3))
				ELSE ''
			END as groupcomb6

			,groupexists7
			,group_hrs7
			,num_workers7
			,CASE WHEN isnull(groupexists7,0) = 1 THEN 
				CAST(CAST(group_hrs7 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers7 as nvarchar(3))
				ELSE ''
			END as groupcomb7

			,groupexists8
			,group_hrs8
			,num_workers8
			,CASE WHEN isnull(groupexists8,0) = 1 THEN 
				CAST(CAST(group_hrs8 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers8 as nvarchar(3))
				ELSE ''
			END as groupcomb8

			,groupexists9
			,group_hrs9
			,num_workers9
			,CASE WHEN isnull(groupexists9,0) = 1 THEN 
				CAST(CAST(group_hrs9 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers9 as nvarchar(3))
				ELSE ''
			END as groupcomb9

			,groupexists10
			,group_hrs10
			,num_workers10
			,CASE WHEN isnull(groupexists10,0) = 1 THEN 
				CAST(CAST(group_hrs10 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers10 as nvarchar(3))
				ELSE ''
			END as groupcomb10

			,groupexists11
			,group_hrs11
			,num_workers11
			,CASE WHEN isnull(groupexists11,0) = 1 THEN 
				CAST(CAST(group_hrs11 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers11 as nvarchar(3))
				ELSE ''
			END as groupcomb11

			,groupexists12
			,group_hrs12
			,num_workers12
			,CASE WHEN isnull(groupexists12,0) = 1 THEN 
				CAST(CAST(group_hrs12 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers12 as nvarchar(3))
				ELSE ''
			END as groupcomb12

			,groupexists13
			,group_hrs13
			,num_workers13
			,CASE WHEN isnull(groupexists13,0) = 1 THEN 
				CAST(CAST(group_hrs13 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers13 as nvarchar(3))
				ELSE ''
			END as groupcomb13

			,groupexists14
			,group_hrs14
			,num_workers14
			,CASE WHEN isnull(groupexists14,0) = 1 THEN 
				CAST(CAST(group_hrs14 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers14 as nvarchar(3))
				ELSE ''
			END as groupcomb14

			,groupexists15
			,group_hrs15
			,num_workers15
			,CASE WHEN isnull(groupexists15,0) = 1 THEN 
				CAST(CAST(group_hrs15 as decimal(7,1)) as nvarchar(8)) + '/' + CAST(num_workers15 as nvarchar(3))
				ELSE ''
			END as groupcomb15


			,mech_hrs
			,mech_num_workers
			,CASE WHEN not mech_hrs is null THEN	
				CAST(CAST(mech_hrs as decimal(7,1)) as nvarchar(8)) + 
					CASE WHEN  @GroupMechanical = 1 THEN --grouping mech variable check
						'/' + CAST(mech_num_workers as nvarchar(3)) 
						ELSE ''
					END
				ELSE NULL
			 END as mech_comb
			,sub_assy_transit
			,prod_cycle_days
			,sch_subassy_ship_date
			,req_subassy_arr_date
			,sch_final_ship_date
			,cust_req_ship_date
			,prom_ship_date
			,start_date
			,assy_start_date
			,firstopseq
			,act_hrs1
			,act_hrs2
			,act_hrs3
			,act_hrs4
			,act_hrs5
			,act_hrs6
			,act_hrs7
			,act_hrs8
			,act_hrs9
			,act_hrs10
			,act_hrs11
			,act_hrs12
			,act_hrs13
			,act_hrs14
			,act_hrs15
			,act_mech_hrs
			,groupseq1  
			,groupseq2  
			,groupseq3 
			,groupseq4
			,groupseq5
			,groupseq6
			,groupseq7  
			,groupseq8  
			,groupseq9  
			,groupseq10  
			,groupseq11  
			,groupseq12  
			,groupseq13  
			,groupseq14
			,groupseq15
			,jobDesc
			,UbHot
			,tentative_date
			,sch_final_ship_date as orig_ship_date
			,NumSections -- Ref# 0000 OTD Added
			,EngLeadTime -- Ref# 0000 OTD Added

		FROM @RptSet
		UNION
		SELECT --*
			sub_assy_site
			,site_assignment
			,last_group
			,last_group_seq
			,co_num
			,co_line
			,co_release
			,job_qty
			,job
			,suffix
			,job_type
			,material_cushion
			,groupexists1
			,group_hrs1
			,num_workers1
			,group1comb
			,groupexists2
			,group_hrs2
			,num_workers2
			,group2comb
			,groupexists3
			,group_hrs3
			,num_workers3
			,group3comb
			,groupexists4
			,group_hrs4
			,num_workers4
			,group4comb
			,groupexists5
			,group_hrs5
			,num_workers5
			,group5comb
			,groupexists6
			,group_hrs6
			,num_workers6
			,group6comb
			,groupexists7
			,group_hrs7
			,num_workers7
			,group7comb
			,groupexists8
			,group_hrs8
			,num_workers8
			,group8comb
			,groupexists9
			,group_hrs9
			,num_workers9
			,group9comb
			,groupexists10
			,group_hrs10
			,num_workers10
			,group10comb
			,groupexists11
			,group_hrs11
			,num_workers11
			,group11comb
			,groupexists12
			,group_hrs12
			,num_workers12
			,group12comb
			,groupexists13
			,group_hrs13
			,num_workers13
			,group13comb
			,groupexists14
			,group_hrs14
			,num_workers14
			,group14comb
			,groupexists15
			,group_hrs15
			,num_workers15
			,group15comb
			,mech_hrs
			,mech_num_workers
			,mechanicalcomb
			,sub_assy_transit
			,prod_cycle_days
			,sch_subassy_ship_date
			,req_subassy_arr_date
			,sch_final_ship_date
			,cust_req_ship_date
			,prom_ship_date
			,start_date
			,assy_start_date
			,first_op_seq
			,act_hrs1
			,act_hrs2
			,act_hrs3
			,act_hrs4
			,act_hrs5
			,act_hrs6
			,act_hrs7
			,act_hrs8
			,act_hrs9
			,act_hrs10
			,act_hrs11
			,act_hrs12
			,act_hrs13
			,act_hrs14
			,act_hrs15
			,act_mech_hrs
			,groupseq1
			,groupseq2
			,groupseq3
			,groupseq4
			,groupseq5
			,groupseq6
			,groupseq7
			,groupseq8
			,groupseq9
			,groupseq10
			,groupseq11
			,groupseq12
			,groupseq13
			,groupseq14
			,groupseq15
			,jobDesc
			,UbHot
			,tentative_date
			,sch_final_ship_date as orig_ship_date
			,NumSections -- Ref# 0000 OTD Added
			,EngLeadTime -- Ref# 0000 OTD Added
		FROM @CrossSiteTable
		order by co_num, co_line, last_group_seq, job, suffix --Ref# 000 OTD Removed

	--where job = '100040JAX'
	END

	EXEC dbo.CloseSessionContextSp @SessionID = @RptSessionID

	RETURN @Severity
END

GO

