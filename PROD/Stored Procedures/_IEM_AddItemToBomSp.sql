SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**************************************************************************
DJH 2017-05-12 add KIT= to MSP BOM
***************************************************************************/
ALTER PROCEDURE [dbo].[_IEM_AddItemToBomSp] (
	 @Item ItemType,
	 @AddItem ItemType,
	 @Oper OperNumType,
	 @Qty QtyUnitType,
	 @Infobar InfobarType OUTPUT
) AS BEGIN
	DECLARE 
		 @JobmatlRowPointer RowPointerType
		,@JobmatlCost CostPrcType
		,@JobmatlSequence JobmatlSequenceType
		,@JobmatlBSequence JobmatlSequenceType
		,@TNextSequence JobmatlSequenceType
		,@TNextBSequence JobmatlSequenceType
		,@ToJob JobType
		,@ToSuffix SuffixType
		,@UM UmType = null
		,@ItemUnitCost CostPrcType = 0

	
	select @ToJob = job, @ToSuffix = suffix from job where job.item = @Item AND type = 'S'

	SELECT TOP 1 @JobmatlRowPointer = jobmatl.RowPointer , @JobmatlSequence   = jobmatl.sequence, @JobmatlBSequence   = jobmatl.bom_seq
	FROM jobmatl
	WHERE jobmatl.job = @ToJob AND jobmatl.suffix = @ToSuffix
	ORDER BY jobmatl.sequence DESC

	SELECT TOP 1 @JobmatlBSequence = jobmatl.bom_seq
	FROM jobmatl
	WHERE jobmatl.job = @ToJob AND jobmatl.suffix = @ToSuffix
	ORDER BY jobmatl.bom_seq DESC


	IF @JobmatlRowPointer IS NULL BEGIN
		SET @TNextSequence = 1
		SET @TNextBSequence = 1
	END ELSE BEGIN
		SET @TNextSequence = @JobmatlSequence + 1
		SET @TNextBSequence = @JobmatlBSequence + 1
	END

	select top 1 @um = u_m, @ItemUnitCost=cur_u_cost from item where item=@AddItem

	if @um is null begin
		set @Infobar = 'Item '+isnull(@AddItem,'[NULL]')+' could not be added to BOM'
		return -16
	end

	INSERT INTO jobmatl
	(
		job
		, suffix
		, oper_num
		, sequence
		, bom_seq
		, matl_type
		, item
		, u_m
		, matl_qty
		, matl_qty_conv
		, units
		, cost
		, matl_cost
		, lbr_cost
		, fovhd_cost
		, vovhd_cost
		, out_cost
		, cost_conv
		, ref_type
		, backflush
		, bflush_loc
		, alt_group
		, alt_group_rank
	)
	VALUES
	(
		@ToJob
		, @ToSuffix
		, @Oper
		, @TNextSequence
		, @TNextBSequence
		, 'M'
		, @AddItem
		, @UM
		, @Qty
		, @Qty
		, 'U'
		, @ItemUnitCost
		, @ItemUnitCost
		, 0
		, 0
		, 0
		, 0
		, @ItemUnitCost
		, 'I'
		, 0
		, NULL
		, @TNextSequence
		, 0
	)	

	Return 0
END
GO

