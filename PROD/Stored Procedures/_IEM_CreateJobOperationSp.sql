SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**************************************************************************
*                            Modification Log
*                                            
* Ref#  Init Date     Description           
* ----- ---- -------- ----------------------------------------------------- 
* MOD100 JWP   090115  eQuote to SyteLine interface
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_CreateJobOperationSp] (
	 @Job JobType
	,@Suffix SuffixType
	,@WorkCenter WCType
	,@LaborHours SchedHoursType
	,@OperNum OperNumType OUTPUT
	,@Infobar InfobarType OUTPUT
)
AS
BEGIN

	DECLARE 
		@Severity INT
		,@LaborTicks TicksType
		,@RGID ApsResgroupType
		,@JrgSequence INT
		,@PreferredOperNum OperNumType

	SET @Severity = 0

	set @PreferredOperNum = @OperNum
	SET @OperNum = NULL
	SET @workCenter = ISNULL(@WorkCenter,'ISUMAT')

	-- See if operation exists for specified work center
	DECLARE @varOvhd OverHeadRateType, @fixOvhd OverHeadRateType
	select @varOvhd=ISNULL(varovhd_rate,25.11), @fixOvhd=ISNULL(fixovhd_rate,35.11) from dept join wc on wc.dept=dept.dept where wc=@WorkCenter 

	
	SELECT @OperNum = oper_num
	FROM jobroute
	WHERE job = @Job
		AND suffix = @Suffix
		AND wc = @WorkCenter
			
	-- Add operation if it does not exist

	IF @OperNum IS NULL
	BEGIN

		if @PreferredOperNum is not null and not exists (select 1 from jobroute jr where job=@job and suffix=@Suffix and oper_num=@PreferredOperNum) begin
			set @OperNum=@PreferredOperNum
		end else begin
			SELECT TOP 1 @OperNum = oper_num
			FROM jobroute
			WHERE job = @Job
				AND suffix = @Suffix
			ORDER BY oper_num DESC

			SET @OperNum = ISNULL(@OperNum,0) + 1
		end

		BEGIN TRANSACTION

		insert into Jobroute (
			RowPointer, job, suffix, oper_num
			, wc, run_basis_lbr, run_basis_mch
			, bflush_type, cntrl_point, setup_rate, efficiency
			, fovhd_rate_mch, vovhd_rate_mch, run_rate_lbr
			, varovhd_rate, fixovhd_rate
			, effect_date, obs_date
			, NoteExistsFlag
			, Yield
			, MO_Shared
			)
			values (Newid(), @Job, @Suffix, @OperNum
			, @WorkCenter, 'H','H'
			, 'N', 1, 0, 100
			, 0, 0, 0
			, @varOvhd, @fixOvhd
			, NULL, NULL
			, 0
			, 100
			, 0
			)

		COMMIT TRANSACTION

		SET @LaborTicks = @LaborHours * 100

		IF NOT EXISTS(SELECT * FROM jrt_sch WHERE job = @Job AND suffix = @Suffix AND oper_num = @OperNum)
		BEGIN
					
			BEGIN TRANSACTION

			insert into jrt_sch(
				job, suffix, oper_num							-- 1
				, setup_ticks, setup_hrs, run_ticks_lbr			-- 2
				, run_lbr_hrs, run_ticks_mch, run_mch_hrs		-- 3
				, pcs_per_lbr_hr, pcs_per_mch_hr, sched_ticks	-- 4
				, sched_hrs, sched_off, offset_hrs				-- 5
				, move_ticks, move_hrs, queue_ticks				-- 6
				, queue_hrs, start_date, end_date				-- 7
				, start_tick, end_tick, finish_hrs				-- 8
				, matrixtype, tabid, whenrule					-- 9
				, sched_drv, plannerstep, setuprgid				-- 10
				, setuprule, schedsteprule, crsbrkrule			-- 11
				, allow_reallocation, splitsize, batch_definition_id	-- 12
				, splitrule, splitgroup, RowPointer				-- 13
				)
			values(
			  @Job, @Suffix, @OperNum						-- 1
			, 0, 0, @LaborTicks									-- 2
			, @LaborHours, 0, 0									-- 3
			, 0, 0, 0											-- 4
			, 0, NULL, 0										-- 5
			, 0, 0, 0											-- 6
			, 0, '2/2/2222', '2/2/2222'							-- 7
			, NULL, NULL, 0										-- 8
			, 'P', NULL, 0										-- 9
			, 'L', 0, NULL										-- 10
			, 5, 1, 0											-- 11
			, 0, 0, NULL										-- 12
			, 0, NULL, newid()
			)

			COMMIT TRANSACTION

		END
		ELSE
			BEGIN TRANSACTION

			UPDATE jrt_sch
			SET run_ticks_lbr = @LaborTicks, run_lbr_hrs = @LaborHours
			WHERE job = @Job AND suffix = @Suffix AND oper_num = @OperNum

			COMMIT TRANSACTION

		-- create JrtResourceGroup
		SET @RGID = NULL
				
		SELECT TOP 1 @RGID = rgid
		FROM wcresourcegroup_mst
		WHERE wc = @WorkCenter

		SET @JrgSequence = NULL

		SELECT TOP 1 @JrgSequence = sequence
		FROM jrtresourcegroup
		WHERE job = @Job
			AND suffix = @Suffix
		ORDER BY sequence DESC

		SET @JrgSequence = ISNULL(@JrgSequence,1) --+ 1

		IF NOT EXISTS(SELECT * FROM jrtresourcegroup WHERE job = @Job AND Suffix = @Suffix AND oper_num = @OperNum)
		BEGIN

			BEGIN TRANSACTION

			INSERT INTO jrtresourcegroup (
				RowPointer
				, job
				, suffix
				, oper_num
				, rgid
				, qty_resources
				, NoteExistsFlag
				, resactn
				, sequence
			)
			SELECT TOP 1
				NewID()
				, @Job
				, @Suffix
				, @OperNum
				, jrg.rgid
				, jrg.qty_resources
				, 0
				, 'S'
				, @JrgSequence
			from wcresourcegroup jrg
			WHERE wc = @WorkCenter

			COMMIT TRANSACTION
		END

	END
	ELSE
	BEGIN 

		BEGIN TRANSACTION
			UPDATE jobroute set varovhd_rate=@varOvhd, fixovhd_rate=@fixOvhd --djh 2016-4-18 update to latest labor rate if necessary
			WHERE job = @Job
			ANd suffix = @Suffix
			AND oper_num = @OperNum
		COMMIT TRANSACTION

		BEGIN TRANSACTION

		UPDATE jrt_sch
		SET run_lbr_hrs = run_lbr_hrs + @laborHours
		WHERE job = @Job
			ANd suffix = @Suffix
			AND oper_num = @OperNum

		COMMIT TRANSACTION

	END

	RETURN @Severity

END
GO

