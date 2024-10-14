SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* $Header: /ApplicationDB/Stored Procedures/CreateItemSp.sp 1     8/22/14 10:33a flagatta $ */
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
/* $Archive: /ApplicationDB/Stored Procedures/CreateItemSp.sp $
 *
 * SL9.00 1 184069 flagatta Fri Aug 22 10:33:36 2014
 * Manufacturing Window: Issue to get SP's checked in and also permissions
 * Added for Manufacturing Window. 184069
 *
 * $NoKeywords: $
 */

ALTER PROCEDURE [dbo].[_IEM_CreateItemSp] (
   @Item			ItemType
  ,@Description 	DescriptionType
  ,@Revision 		RevisionType
  ,@UM 				UMType
  ,@ProductCode 	ProductCodeType
  --,@Job 			JobType			OUTPUT
  --,@Suffix 			SuffixType		OUTPUT
  --,@JobType 		JobTypeType		OUTPUT
  ,@Infobar    		InfobarType   	OUTPUT
) AS

DECLARE 
	  @Severity 		int
	, @RowPointer 		RowPointerType
	, @LotPrefix 		LotPrefixType
	, @LotTracked 		ListYesNoType
	, @SerialTracked	ListYesNoType
	, @PreassignLots	ListYesNoType
	, @PreassignSerials	ListYesNoType

SET @Severity = 0

SELECT @RowPointer = item.RowPointer
   FROM item
   WHERE item.item = @Item
   
IF @RowPointer IS NULL
BEGIN
	BEGIN TRY
		SELECT
			  @LotPrefix 		= lot_prefix
			, @LotTracked 		= lot_tracking
			, @SerialTracked 	= serial_tracked
			, @PreassignLots 	= preassign_lots
			, @PreassignSerials = preassign_serials
		FROM invparms

		BEGIN TRAN
			INSERT INTO item (item, description, revision, u_m, product_code, lot_prefix, lot_tracked, serial_tracked, preassign_lots, preassign_serials)
			VALUES (@Item, @Description, @Revision, @UM, @ProductCode, @LotPrefix, @LotTracked, @SerialTracked, @PreassignLots, @PreassignSerials)

/*	   
	   --Create the Current Route/BOM Header Job
		   EXEC @Severity = dbo.PreSaveCurrOperSp 
								 @Item    = @Item
							   , @OperNum = NULL
							   , @Wc      = 'Dummy'
							   , @Job     = @Job	  OUTPUT
							   , @Suffix  = @Suffix	  OUTPUT
							   , @JobType = @JobType  OUTPUT
							   , @Infobar = @Infobar  OUTPUT
*/
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
	SET @Infobar =  @Item + ' already exists.'
	RETURN 16
END
GO

