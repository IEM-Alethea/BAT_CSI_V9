-------------------------------------------------------------------------------
-- SQL Script generated by FormSync 9.1.40.9 as of 10/11/2024 5:57 AM
-- Source Configuration: BAT_Forms
-- Objects scripted:
--   Form: ExtFRAInventoryVariations 
--      Components: BackgroundQueue, CurrentDate, CurrentDate1, DwRefreshBtn, EndingDateEdit,
--         EndingDateStatic, InvVariationsSuperGrid, MainGroupBox, StartingDateEdit,
--         StartingDateStatic
--      Event Handlers: DwRefresh(0), StdFormPredisplay(0)
--      Variables: cds_InvVariationsSuperGrid, cds_SummInvVariationsSuperGrid
--      ActiveXScripts: ExtFRAInventoryVariations
-------------------------------------------------------------------------------
DECLARE @FormID INT
SET @FormID = NULL
SELECT @FormID = Forms.ID FROM Forms WHERE [Name] = N'ExtFRAInventoryVariations' AND [ScopeType] = 1
IF @FormID IS NOT NULL
BEGIN
   DELETE FROM Forms WHERE ID = @FormID
   DELETE FROM FormEventHandlers WHERE FormID = @FormID
   DELETE FROM FormComponents WHERE FormID = @FormID
   DELETE FROM ActiveXComponentProperties WHERE FormID = @FormID
   DELETE FROM Variables WHERE FormID = @FormID
   DELETE FROM FormComponentDragDropEvents WHERE FormID = @FormID
   DELETE FROM DerivedFormOverrides WHERE FormID = @FormID
   DELETE FROM ActiveXScripts WHERE [Name] = N'ExtFRAInventoryVariations' AND [ScopeType] = 1
   DELETE FROM ActiveXScriptLines WHERE [ScriptName] = N'ExtFRAInventoryVariations' AND [ScopeType] = 1
END
INSERT INTO [Forms] (
  [ScopeType], [ScopeName], [Component], [Name], [SubComponent], [Type], [Caption], 
  [PrimaryDataSource], 
  [StandardOperations], [TopPos], [LeftPos], [Height], [Width], [IconFileName], [HelpFileName], [HelpContextID], [Flags], [LockedBy], 
  [FilterFormSpec], [PaneZeroSize], [Description], [MasterDeviceID], [BaseFormName] ) 
VALUES ( 
  1, N'[NULL]', NULL, N'ExtFRAInventoryVariations', NULL, 3, N'fExtFRAInventoryVariations', 
  NULL, 
  0, CAST('0' AS float), CAST('0' AS float), CAST('38.705883026123047' AS float), CAST('109' AS float), NULL, NULL, 0, 968, N'dave.hulme', 
  NULL, N'0', NULL, 0, NULL)
SELECT @FormID = Forms.ID FROM Forms WHERE [Name] = N'ExtFRAInventoryVariations' AND [ScopeType] = 1
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'BackgroundQueue', -1, 
  19, 10, CAST('0' AS float), CAST('0' AS float), CAST('0' AS float), CAST('0' AS float), CAST('0' AS float), N'sBackground', 
  NULL, 
  NULL, 0, NULL, 
  0, N'RunBackgroundQueue', NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl)', 
  NULL, N'sBackground' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'CurrentDate', -1, 
  6, 1, CAST('1.2352941176470589' AS float), CAST('85.5' AS float), CAST('1.2999999523162842' AS float), CAST('0' AS float), CAST('10.142856597900391' AS float), NULL, 
  NULL, 
  NULL, 0, N'variables.CurrentDate(INITIALVALUE(CURDATE()))', 
  6, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 1, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  N'DATATYPE(DATE)', N'AUTOIME(NoControl) JUSTIFY(C)', 
  NULL, NULL )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'CurrentDate1', -1, 
  21, 1, CAST('1.2352941176470589' AS float), CAST('96.375' AS float), CAST('1.2999999523162842' AS float), CAST('0' AS float), CAST('10.142856597900391' AS float), NULL, 
  NULL, 
  NULL, 0, N'variables.CurrentDate1', 
  6, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 1, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl) JUSTIFY(C)', 
  NULL, NULL )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'DwRefreshBtn', -1, 
  20, 8, CAST('1.1764705882352942' AS float), CAST('61.875' AS float), CAST('1.3529411764705883' AS float), CAST('0' AS float), CAST('11.625' AS float), N's&Refresh', 
  NULL, 
  NULL, 0, NULL, 
  0, N'DwRefresh', NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl)', 
  NULL, N's&Refresh' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'EndingDateEdit', -1, 
  4, 1, CAST('1.2352941176470589' AS float), CAST('41.875' AS float), CAST('1.2999999523162842' AS float), CAST('0' AS float), CAST('10.142856597900391' AS float), N'C(EndingDateStatic)', 
  NULL, 
  NULL, 0, N'variables.EndingDate', 
  6, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  N'DATATYPE(DATE)', N'AUTOIME(NoControl) JUSTIFY(C)', 
  NULL, N'C(EndingDateStatic)' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'EndingDateStatic', -1, 
  3, 0, CAST('1.3529411764705883' AS float), CAST('28.375' AS float), CAST('1' AS float), CAST('0' AS float), CAST('12.571429252624512' AS float), N'sEndingDate', 
  NULL, 
  NULL, 0, NULL, 
  0, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl) JUSTIFY(R)', 
  NULL, N'sEndingDate' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'InvVariationsSuperGrid', -1, 
  5, 47, CAST('3.4117647058823528' AS float), CAST('1.125' AS float), CAST('34.999999326818127' AS float), CAST('0' AS float), CAST('107.5' AS float), N'sExtFRAInventoryVariations', 
  NULL, 
  NULL, 0, N'V(cds_InvVariationsSuperGrid)', 
  21, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  384, NULL, 0, 0, NULL, NULL, NULL, 0, N'StdDataView', 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl)', 
  NULL, N'sExtFRAInventoryVariations' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'MainGroupBox', -1, 
  0, 6, CAST('0.25' AS float), CAST('1.1249999998730238' AS float), CAST('2.7647058823529411' AS float), CAST('0' AS float), CAST('107.5' AS float), NULL, 
  NULL, 
  NULL, 0, NULL, 
  0, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl)', 
  NULL, NULL )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'StartingDateEdit', -1, 
  2, 1, CAST('1.2352941176470589' AS float), CAST('16.125' AS float), CAST('1.2999999523162842' AS float), CAST('0' AS float), CAST('10.142856597900391' AS float), N'C(StartingDateStatic)', 
  NULL, 
  NULL, 0, N'variables.StartingDate', 
  6, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  N'DATATYPE(DATE)', N'AUTOIME(NoControl) JUSTIFY(C)', 
  NULL, N'C(StartingDateStatic)' )
INSERT INTO FormComponents (
  [FormID], [Name], [DeviceID], 
  [TabOrder], [Type], [TopPos], [LeftPos],[Height], [ListHeight], [Width], [Caption], 
  [Validators], 
  [ContainerName], [ContainerSequence], [DataSource], 
  [Binding], [EventToGenerate], [SelectionEventToGenerate], [LoseFocusEventToGenerate], [GainFocusEventToGenerate], [RadioButtonSelectedValue], 
  [ComboListSource], 
  [Flags], [DefaultData], [ReadOnly], [Hidden], [BitmapFileName], [HelpString], [HelpFileName], [HelpContextID], [MenuName], 
  [Format], [FindFromSpec], [MaintainFromSpec], 
  [MaxCharacters], [DefaultFrom], [DataType], [ActiveXControlName], [PropertyClassName], 
  [Post301DataType], [Post301Format], 
  [Description], [EffectiveCaption] )
VALUES (
  @FormID, N'StartingDateStatic', -1, 
  1, 0, CAST('1.3529411764705883' AS float), CAST('2.375' AS float), CAST('1' AS float), CAST('0' AS float), CAST('12.571429252624512' AS float), N'sStartingDate', 
  NULL, 
  NULL, 0, NULL, 
  0, NULL, NULL, NULL, NULL, NULL, 
  NULL, 
  0, NULL, 0, 0, NULL, NULL, NULL, 0, NULL, 
  NULL, NULL, NULL, 
  N'0', NULL, NULL, NULL, NULL, 
  NULL, N'AUTOIME(NoControl) JUSTIFY(R)', 
  NULL, N'sStartingDate' )
INSERT INTO FormEventHandlers ( [FormID], [EventName], [Sequence], [ResponseType], [Response], [Response2], [Response3], [Description] ) 
VALUES ( @FormID, N'DwRefresh', 0, 35, N'DwRefresh()', NULL, NULL, NULL )
INSERT INTO FormEventHandlers ( [FormID], [EventName], [Sequence], [ResponseType], [Response], [Response2], [Response3], [Description] ) 
VALUES ( @FormID, N'StdFormPredisplay', 0, 35, N'PredisplayDefaults()', NULL, NULL, NULL )
INSERT INTO Variables ( [FormID], [Name], [ScopeType], [ScopeName], [Value], [Value2], [Value3], [LockedBy], [Description] ) 
VALUES (@FormID, N'cds_InvVariationsSuperGrid', 1, N'[NULL]', N'dataview( DATAVIEWMODE(PREDEFINED) DATAVIEWNAME(_IEM_ExtFRAInventoryVariations) DATAVIEWFILTER(V(DataviewFilter)) DATAVIEWLAYOUT(ExtFRAInventoryVariations) )', NULL, NULL, NULL, NULL)
INSERT INTO Variables ( [FormID], [Name], [ScopeType], [ScopeName], [Value], [Value2], [Value3], [LockedBy], [Description] ) 
VALUES (@FormID, N'cds_SummInvVariationsSuperGrid', 1, N'[NULL]', N'dataview( DATAVIEWMODE(PREDEFINED) DATAVIEWNAME(ExtFRAInventoryVariations) )', NULL, NULL, NULL, NULL)
INSERT INTO ActiveXScripts ([Name], [ScopeType], [ScopeName], [LockedBy], [Language]) VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', NULL, N'Visual Basic')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 0, N'Option Explicit On')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 1, N'Option Strict On')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 2, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 3, N'Imports System')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 4, N'Imports Microsoft.VisualBasic')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 5, N'Imports Mongoose.IDO.Protocol')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 6, N'Imports Mongoose.Scripting')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 7, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 8, N'Namespace SyteLine.FormScripts')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 9, N' Public Class ExtFRAInventoryVariations')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 10, N'  Inherits FormScript')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 11, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 12, N'  Sub PredisplayDefaults()')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 13, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 14, N'   '' DataView Filter init')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 15, N'   ThisForm.Variables("CurrentDate1").Value = CStr(DateAdd("m", 1, ThisForm.Variables("CurrentDate").Value))')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 16, N'   ThisForm.Variables("DwStartingDate").Value = ThisForm.Variables("CurrentDate1").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 17, N'   ThisForm.Variables("DwEndingDate").Value = ThisForm.Variables("CurDate").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 18, N'   ThisForm.Variables("DataviewFilter").Value = "JrnlTransDate BETWEEN FV(DwStartingDate) AND FV(DwEndingDate)"')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 19, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 20, N'   '' Form components init')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 21, N'   If CStr(ThisForm.Variables("StartingDate").Value) = "" Then')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 22, N'    ThisForm.Variables("StartingDate").Value = ThisForm.Variables("CurrentDate").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 23, N'   End If')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 24, N'   If CStr(ThisForm.Variables("EndingDate").Value) = "" Then')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 25, N'    ThisForm.Variables("EndingDate").Value = ThisForm.Variables("CurrentDate").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 26, N'   End If')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 27, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 28, N'  End Sub')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 29, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 30, N'  Sub DwRefresh()')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 31, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 32, N'   '' Set Dataview filter')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 33, N'   ThisForm.Variables("DwStartingDate").Value = ThisForm.Variables("StartingDate").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 34, N'   ThisForm.Variables("DwEndingDate").Value = ThisForm.Variables("EndingDate").Value')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 35, N'   ThisForm.Variables("DataviewFilter").Value = "JrnlTransDate BETWEEN FV(DwStartingDate) AND FV(DwEndingDate)"')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 36, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 37, N'   '' Refresh Dataview')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 38, N'   ThisForm.Components("InvVariationsSuperGrid").DataViewRefresh()')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 39, NULL)
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 40, N'  End Sub')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 41, N' End Class')
INSERT INTO ActiveXScriptLines ([ScriptName], [ScopeType], [ScopeName], [Sequence], [CodeLine])
VALUES (N'ExtFRAInventoryVariations', 1, N'[NULL]', 42, N'End Namespace')
