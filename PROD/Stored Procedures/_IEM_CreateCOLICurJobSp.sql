SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* $Header: /ApplicationDB/Stored Procedures/_IEM_CreateCOLICurJobSp.sp 1     8/22/14 10:33a flagatta $ */
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

ALTER PROCEDURE [dbo].[_IEM_CreateCOLICurJobSp] (
   @Item			ItemType
  ,@ItemTemplate	ItemType
  ,@Job 			JobType			OUTPUT
  ,@Suffix 			SuffixType		OUTPUT
  ,@JobType 		JobTypeType		OUTPUT
  ,@Infobar    		InfobarType   	OUTPUT
) AS

DECLARE 
	  @Severity 		int
	, @RowPointer 		RowPointerType
	, @FromJob			JobType
	, @FromSuffix		SuffixType
	, @ToJob			JobType
	, @ToSuffix			SuffixType
	, @StartOper		OperNumType
	, @EndOper			OperNumType
	, @Debug			ListYesNoType
	, @OperNum			OperNumType
	, @Wc				WCType

SET @Severity = 0

SELECT @RowPointer = job.RowPointer
   FROM job
   WHERE job.item = @Item AND job.type = 'S'
   
IF @RowPointer IS NULL
BEGIN
	BEGIN TRY
		BEGIN TRAN

	   --Create the Current Route/BOM Header Job
		   EXEC @Severity = dbo.PreSaveCurrOperSp 
								 @Item    = @Item
							   , @OperNum = 10
							   , @Wc      = 'PM'
							   , @Job     = @Job	  OUTPUT
							   , @Suffix  = @Suffix	  OUTPUT
							   , @JobType = @JobType  OUTPUT
							   , @Infobar = @Infobar  OUTPUT

			SELECT @FromJob = job, @FromSuffix = suffix
			FROM item
			WHERE item = @ItemTemplate
			
			SELECT @ToJob = job, @ToSuffix = suffix
			FROM item 
			WHERE item = @Item

			SELECT TOP 1 @StartOper = oper_num
			FROM jobroute (NOLOCK)
			WHERE job = @FromJob AND suffix = @FromSuffix
			ORDER BY oper_num

			SELECT TOP 1 @EndOper = oper_num
			FROM jobroute (NOLOCK)
			WHERE job = @FromJob AND suffix = @FromSuffix
			ORDER BY oper_num DESC

			IF @Debug = 1 
			BEGIN
				PRINT 'Calling CopyBomDoProcessSp'
				PRINT '     From item ' + ISNULL(@ItemTemplate,'NULL')
				PRINT '     To job ' + ISNULL(@Job,'NULL')
			END

			EXEC @Severity = CopyBomDoProcessSp
				@FromJobCategory = 'C'
				,@FromJob = @FromJob
				,@FromSuffix = @FromSuffix
				,@FromItem = @ItemTemplate
				,@StartOper = @StartOper
				,@EndOper = @EndOper
				,@LMBVar = 'B'
				,@Revision = NULL
				,@ScrapFactor = 0
				,@CopyBom = 1
				,@ToJobCategory = 'C'
				,@ToItem = @Item
				,@ToJob = @ToJob
				,@ToSuffix = @ToSuffix
				,@EffectDate = NULL
				,@OptionType = 'D'
				,@AfterOper = NULL
				,@CopyToPSReleaseBom = NULL
				,@Infobar = @Infobar OUTPUT
				,@CopyUetValues = 1

		COMMIT TRAN
	   
		RETURN @Severity
    END TRY
	BEGIN CATCH
		DECLARE
		  @UDFErr InfobarType
		 ,@SQLBaseUDFErr InfobarType

		ROLLBACK TRAN
		SET @UDFErr = error_message()
		EXEC dbo.GetSQLBaseUDFErrSp @SQLBaseUDFErr OUTPUT
		SET @Infobar = dbo.UDFExceptionMsgApp(@Infobar,@UDFErr,@SQLBaseUDFErr)
		RETURN 16
	END CATCH
END
ELSE
BEGIN
	SET @Infobar =  'Current job for item ' + @Item + ' already exists.'
	RETURN 16
END
GO

