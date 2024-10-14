SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[_IEM_Rpt_BOMSyncSp] (
	  @Item						ItemType
	, @SLUserName				UsernameType
	, @Report					TINYINT = NULL
)
AS
BEGIN

DECLARE @Site siteType;
SELECT TOP 1 @Site = site FROM site WHERE app_db_name = DB_NAME()
EXEC dbo.SetSiteSp @Site, NULL;

DECLARE
	  @RC						INT
	, @Infobar					InfobarType = ''
	, @CallFromSite				SiteType = NULL
	, @UserName					UsernameType
	, @JJob						JobType
	, @JSuffix					SuffixType
	, @SJob						JobType

DECLARE @Update TABLE (
	  SubItem					ItemType
	, oper_num					OperNumType
	, sequence					SequenceType
	, OriginalQty				QtyUnitType
	, UpdatedQty				QtyUnitType
	)

SET @UserName = ISNULL(@SLUserName,REPLACE(SUSER_SNAME(),'IEM\',''))

SET @JJob = (SELECT TOP 1 job FROM job WHERE item = @item AND type = 'J')
SET @JSuffix = (SELECT TOP 1 suffix FROM job WHERE item = @item AND type = 'J')

IF @JJob IS NULL
	BEGIN
		SET @infobar = 'No J-Type Job found for Item ' + @item + '.'
		GOTO S_END
	END

INSERT INTO @Update
	SELECT	  item
			, oper_num
			, sequence
			, matl_qty
			, 0
		FROM jobmatl
			WHERE job = @JJob AND suffix = @JSuffix

INSERT INTO @Update
	SELECT	  'Labor Hours'
			, oper_num
			, NULL
			, run_lbr_hrs
			, 0
		FROM jrt_sch
			WHERE job = @JJob AND Suffix = @JSuffix

INSERT INTO @Update
	SELECT	  'Machine Hours'
			, oper_num
			, NULL
			, run_mch_hrs
			, 0
		FROM jrt_sch
			WHERE job = @JJob AND Suffix = @JSuffix

INSERT INTO @Update
	SELECT	  'Setup Hours'
			, oper_num
			, NULL
			, setup_hrs
			, 0
		FROM jrt_sch
			WHERE job = @JJob AND Suffix = @JSuffix

EXECUTE	@RC = _IEM_UpdateJobsSp
	  @Item
	, @Infobar OUTPUT
	, @CallFromSite
	, @UserName

UPDATE u
	SET UpdatedQty = matl_qty
		FROM @Update u
			JOIN jobmatl jm
				ON jm.job = @JJob AND jm.suffix = @JSuffix AND jm.item = u.SubItem AND jm.oper_num = u.oper_num AND jm.sequence = u.sequence

INSERT INTO @Update
	SELECT	  item
			, oper_num
			, sequence
			, 0
			, matl_qty
		FROM jobmatl jm
			WHERE job = @JJob AND suffix = @JSuffix
					AND NOT EXISTS (SELECT 1 FROM @Update u WHERE u.SubItem = jm.item AND u.oper_num = jm.oper_num AND u.sequence = jm.sequence)

INSERT INTO @Update
	SELECT	  'Labor Hours'
			, oper_num
			, NULL
			, 0
			, run_lbr_hrs
		FROM jrt_sch js
			WHERE NOT EXISTS (SELECT 1 FROM @Update u WHERE SubItem = 'Labor Hours' AND u.oper_num = js.oper_num)

INSERT INTO @Update
	SELECT	  'Machine Hours'
			, oper_num
			, NULL
			, 0
			, run_mch_hrs
		FROM jrt_sch js
			WHERE NOT EXISTS (SELECT 1 FROM @Update u WHERE SubItem = 'Machine Hours' AND u.oper_num = js.oper_num)

INSERT INTO @Update
	SELECT	  'Setup Hours'
			, oper_num
			, NULL
			, 0
			, setup_hrs
		FROM jrt_sch js
			WHERE NOT EXISTS (SELECT 1 FROM @Update u WHERE SubItem = 'Setup Hours' AND u.oper_num = js.oper_num)

UPDATE u
	SET UpdatedQty = run_lbr_hrs
		FROM @Update u
			JOIN jrt_sch js
				ON job = @JJob AND suffix = @JSuffix AND js.oper_num = u.oper_num AND u.SubItem = 'Labor Hours'

UPDATE u
	SET UpdatedQty = run_mch_hrs
		FROM @Update u
			JOIN jrt_sch js
				ON job = @JJob AND suffix = @JSuffix AND js.oper_num = u.oper_num AND u.SubItem = 'Machine Hours'

UPDATE u
	SET UpdatedQty = setup_hrs
		FROM @Update u
			JOIN jrt_sch js
				ON job = @JJob AND suffix = @JSuffix AND js.oper_num = u.oper_num AND u.SubItem = 'Setup Hours'

S_END:

IF (SELECT COUNT(*) FROM @Update WHERE OriginalQty <> UpdatedQty) = 0
	BEGIN
		INSERT INTO @Update (SubItem)
			SELECT '---'
	END

IF ISNULL(@Report,1) = 1
	BEGIN
		SELECT	  @JJob + '-' + RIGHT('0000' + CAST(@JSuffix AS NVARCHAR(4)),4)	AS JobSuffix
				, SubItem
				, ISNULL(@InfoBar,IIF(SubItem = '---','No updates necessary',
				'Operation ' + CONVERT(NVARCHAR(10),oper_num) +
					ISNULL(' / Sequence ' + CONVERT(NVARCHAR(5),sequence),'')
					+ ' updated from quantity '+ CONVERT(NVARCHAR(29), OriginalQty) +
					 '  to quantity ' + CONVERT(NVARCHAR(19),UpdatedQty) + '.')) AS InfoBar
			FROM @Update
				WHERE ISNULL(OriginalQty,0) <> ISNULL(UpdatedQty,1)
	END

END
GO

