unit EditorEngine;
{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}
{$INTERFACES CORBA} //Needed for interfaces without guid
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}
interface

uses
  Messages, SysUtils, Forms, StrUtils, Dialogs, Variants, Classes, Controls,
  Graphics, Contnrs, Types, IniFiles, EditorOptions, EditorProfiles,
  SynEditMarks, SynCompletion, SynEditTypes, SynEditMiscClasses,
  SynEditHighlighter, SynEditKeyCmds, SynEditMarkupBracket, SynEditSearch,
  SynEdit, SynEditTextTrimmer, SynTextDrawer, EditorDebugger, SynGutterBase,
  dbgpServers, DebugClasses, Masks, mnXMLRttiProfile, mnXMLUtils, FileUtil,
  LazFileUtils, mnUtils, ConsoleProcess, LCLType, EditorClasses, EditorRun;

type
  TEditorChangeStates = set of (ecsChanged, ecsState, ecsRefresh, ecsOptions, ecsDebug, ecsShow, ecsEdit, ecsFolder, ecsProject, ecsProjectLoaded); //ecsShow bring to front
  TSynCompletionType = (ctCode, ctHint, ctParams);

  TEditorEngine = class;
  TFileCategory = class;
  TFileGroup = class;
  TFileGroups = class;
  TEditorFile = class;
  TEditorProject = class;
  TEditorProjectOptions = class;

  EEditorException = class(Exception)
  private
    FErrorLine: integer;
  public
    property ErrorLine: integer read FErrorLine write FErrorLine;
  end;

  IEditorOptions = interface
    ['{3D32B7C6-7D6A-4E95-B616-4374BCDAAD37}']
    procedure Apply;
    procedure Retrieve;
  end;

  IEditorControl = interface
    ['{8C2646A1-2738-4830-8107-CF8753D14EBD}']
    function GetMainControl: TWinControl; //Like datagrid in csv form
  end;

  TEditorDesktopFile = class(TCollectionItem)
  private
    FFileName: string;
    FCaretY: integer;
    FCaretX: integer;
    FTopLine: integer;
  public
  published
    property FileName: string read FFileName write FFileName;
    property CaretX: integer read FCaretX write FCaretX default 1;
    property CaretY: integer read FCaretY write FCaretY default 1;
    property TopLine: integer read FTopLine write FTopLine default 1;
  end;

  { TEditorDesktopFiles }

  TEditorDesktopFiles = class(TCollection)
  private
    FCurrentFile: string;
    FCurrentFolder: string;
    function GetItems(Index: integer): TEditorDesktopFile;
  protected
  public
    function Add(FileName: string): TEditorDesktopFile;
    function Find(vName: string): TEditorDesktopFile;
    function IsExist(vName: string): Boolean;
    property Items[Index: integer]: TEditorDesktopFile read GetItems; default;
  published
    property CurrentFile: string read FCurrentFile write FCurrentFile;
    property CurrentFolder: string read FCurrentFolder write FCurrentFolder;
  end;

  TEditorDesktop = class(TPersistent)
  private
    FFiles: TEditorDesktopFiles;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
  published
    property Files: TEditorDesktopFiles read FFiles;
  end;

  { TEditorElement }

  TEditorElement = class(TPersistent)
  private
  protected
    FName: string;
    FTitle: string;
    FDescription: string;
    FImageIndex: integer;
    function GetDescription: string; virtual;
  public
    constructor Create; virtual;

    property Name: string read FName write FName;
    property Title: string read FTitle write FTitle;
    property Description: string read GetDescription write FDescription;
    property ImageIndex: integer read FImageIndex write FImageIndex;
  end;

  { TEditorElements }

  TEditorElements = class(TObjectList)
  private
    function GetItem(Index: integer): TEditorElement;
  public
    function Find(vName: string): TEditorElement;
    function IndexOf(vName: string): Integer;
    property Items[Index: integer]: TEditorElement read GetItem; default;
  end;
  {
    Tendency
    Run, Compile, Collect file groups and have special properties
  }

  TEditorCapability = (capRun, capCompile, capLink, capLint, capDebug, capTrace, capDebugServer, capOSDepended, capBrowser, capOptions, capProjectOptions);

  TEditorCapabilities = set of TEditorCapability;

  { TEditorTendency }

  TEditorTendency = class(TEditorElement)
  private
    FGroups: TFileGroups;
    FDebug: TEditorDebugger;
    FCommand: string;
  protected
    FCapabilities: TEditorCapabilities;
    procedure AddGroup(vName, vCategory: string);
    function CreateDebugger: TEditorDebugger; virtual;
    function GetGroups: TFileGroups; virtual;
    procedure Init; virtual; abstract;
    procedure DoRun(Info: TmneRunInfo); virtual;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Run(RunActions: TmneRunActions);
    procedure Show; virtual;
    function FindExtension(vExtension: string): TFileGroup;
    function CreateEditorFile(vGroup: string): TEditorFile; virtual;
    function CreateEditorFile(vGroup: TFileGroup): TEditorFile; virtual;
    function CreateEditorProject: TEditorProject;
    function CreateOptions: TEditorProjectOptions; virtual;
    function GetDefaultGroup: TFileGroup; virtual;
    //OSDepended: When save to file, the filename changed depend on the os system name
    property Capabilities: TEditorCapabilities read FCapabilities;
    property Groups: TFileGroups read GetGroups;
    property Debug: TEditorDebugger read FDebug;//todo
  published
    property Command: string read FCommand write FCommand; //like php.exe or rdmd.exe
  end;

  TEditorTendencyClass = class of TEditorTendency;

  { TDefaultTendency }
  {
    used only if no Tendency defined
  }

  TDefaultTendency = class(TEditorTendency)
  protected
    procedure Init; override;
    function GetGroups: TFileGroups; override;
  public
    function GetDefaultGroup: TFileGroup; override;
  end;

  { TEditorSCM }

  TEditorSCM = class(TEditorElement)
  private
  protected
    procedure Execute(App, Cmd:string); virtual; abstract;
  public
    constructor Create; override;
    procedure CommitDirectory(Directory: string); virtual; abstract;
    procedure CommitFile(FileName: string); virtual; abstract;
    procedure UpdateDirectory(Directory: string); virtual; abstract;
    procedure UpdateFile(FileName: string); virtual; abstract;
    procedure RevertDirectory(Directory: string); virtual; abstract;
    procedure RevertFile(FileName: string); virtual; abstract;
    procedure DiffFile(FileName: string); virtual; abstract;
    procedure DiffToFile(FileName, ToFileName: string); virtual; abstract;
  end;

  TEditorSCMClass = class of TEditorSCM;

  TAddProjectCallBack = procedure(AFrame: TFrame) of object;

  { TEditorProjectOptions }

  TEditorProjectOptions = class(TPersistent)
  private
    FFRunParams: string;
    FMainFile: string;
    FPauseConsole: Boolean;
    FRootUrl: string;
    FRunMode: TmneRunMode;
    FRunParams: string;
    FOutputFile: string;
  public
    constructor Create; virtual;
    procedure CreateOptionsFrame(AOwner: TComponent; AProject: TEditorProject; AddFrame: TAddProjectCallBack); virtual;
  published
    property RunMode: TmneRunMode read FRunMode write FRunMode;
    property RootUrl: string read FRootUrl write FRootUrl;
    property MainFile: string read FMainFile write FMainFile;
    property OutputFile: string read FOutputFile write FOutputFile;
    property RunParams: string read FRunParams write FRunParams;
    //PauseConsole do not end until use press any key or enter
    property PauseConsole: Boolean read FPauseConsole write FPauseConsole;
  end;

  TCompilerProjectOptions = class(TEditorProjectOptions)
  private
    FConfigFile: string;
    FExpandPaths: Boolean;
    FPaths: TStrings;
    procedure SetPaths(AValue: TStrings);
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property Paths: TStrings read FPaths write SetPaths;
    property ExpandPaths: Boolean read FExpandPaths write FExpandPaths;
    property ConfigFile: string read FConfigFile write FConfigFile;
  end;

  { TEditorProject }

  TEditorProject = class sealed(TmnXMLProfile)
  private
    FOptions: TEditorProjectOptions;
    FTendencyName: string;
    FDescription: string;
    FRootUrl: string;
    FRootDir: string;
    FFileName: string;
    FName: string;
    FSaveDesktop: Boolean;
    FDesktop: TEditorDesktop;
    FTendency: TEditorTendency;
    FSCM: TEditorSCM;
    FTitle: string;
    procedure SetTendency(AValue: TEditorTendency);
    procedure SetTendencyName(AValue: string);
    procedure SetRootDir(AValue: string);
    procedure SetSCM(AValue: TEditorSCM);
  protected
    procedure RttiCreateObject(var vObject: TObject; vInstance: TObject; vObjectClass: TClass; const vClassName, vName: string); override;
    procedure Loaded(Failed: Boolean); override;
    procedure Saving; override;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure LoadFromFile(FileName: string); override;
    property FileName: string read FFileName write FFileName;
    procedure SetSCMClass(SCMClass: TEditorSCM);
    //Tendency here point to one of Engine.Tendencies so it is not owned by project
    property Tendency: TEditorTendency read FTendency write SetTendency;
  published
    property Name: string read FName write FName;
    property Title: string read FTitle write FTitle;
    property TendencyName: string read FTendencyName write SetTendencyName;
    //SCM now owned by project and saved or loaded with it, the SCM object so assigned to will be freed with the project
    property SCM: TEditorSCM read FSCM write SetSCM;

    property Description: string read FDescription write FDescription;
    property RootDir: string read FRootDir write SetRootDir;
    property SaveDesktop: Boolean read FSaveDesktop write FSaveDesktop default True;
    property Desktop: TEditorDesktop read FDesktop stored FSaveDesktop;
    property Options: TEditorProjectOptions read FOptions write FOptions default nil;
  end;

  { TDebugMarksPart }

  TSynDebugMarksPart = class(TSynGutterPartBase)
  protected
    FEditorFile: TEditorFile;
    procedure Init; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer); override;
  published
    property MarkupInfo;
  end;

  TEditorFileMode = (efmUnix, efmWindows, efmMac);
  TEditCapability = set of (ecpAllowCopy, ecpAllowPaste, ecpAllowCut);

  { TEditorFile }

  TEditorFile = class(TCollectionItem, IFileEditor)
  private
    FName: string;
    FIsNew: Boolean;
    FIsEdited: Boolean;
    FFileAge: Integer;
    FFileSize: int64;
    FGroup: TFileGroup;
    FRelated: string;
    FMode: TEditorFileMode;
    function GetCapability: TEditCapability;
    function GetIsText: Boolean;
    function GetNakeName: string;
    function GetPath: string;
    procedure SetGroup(const Value: TFileGroup);
    procedure SetIsEdited(const Value: Boolean);
    procedure SetIsNew(AValue: Boolean);
    function GetModeAsText: string;
    procedure SetMode(const Value: TEditorFileMode);
  protected
    procedure GroupChanged; virtual;
    function GetIsReadonly: Boolean; virtual;
    procedure SetIsReadonly(const Value: Boolean); virtual;
    function GetControl: TWinControl; virtual;
    procedure DoGetCapability(var vCapability: TEditCapability); virtual;
  protected
    procedure Edit;
    procedure DoEdit(Sender: TObject);
    procedure DoStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure UpdateAge; virtual;
    procedure NewContent; virtual;
    procedure DoLoad(FileName: string); virtual; abstract;
    procedure DoSave(FileName: string); virtual; abstract;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignTo(Dest: TPersistent); override;
    procedure Load(FileName: string);
    procedure Save(FileName: string);
    procedure Rename(ToNakeName: string); //only name not with the path
    procedure Delete; //only name not with the path

    procedure SaveFile(Extension: string = ''; AsNewFile: Boolean = False); virtual;
    procedure Show; virtual;
    procedure Close;
    procedure Reload;
    procedure OpenInclude; virtual;
    function CanOpenInclude: Boolean; virtual;
    function CheckChanged: Boolean;
    //
    procedure Activate; virtual;
    procedure GotoLine; virtual;
    procedure Find; virtual;
    procedure FindNext; virtual;
    procedure FindPrevious; virtual;
    procedure Replace; virtual;
    procedure Refresh; virtual;
    function GetHint(HintControl: TControl; CursorPos: TPoint; out vHint: string): Boolean; virtual;
    function GetGlance: string; virtual; //Simple string to show in the corner of mainform
    //
    function GetLanguageName: string; virtual; //TODO need to get more good name to this function
    procedure SetLine(Line: Integer); virtual;
    //Clipboard
    function CanCopy: Boolean;
    function CanPaste: Boolean;
    property Capability: TEditCapability read GetCapability;

    procedure Paste; virtual;
    procedure Copy; virtual;
    procedure Cut; virtual;
    procedure SelectAll; virtual;

    //run the file or run the project depend on the project type (Tendency)
    property Mode: TEditorFileMode read FMode write SetMode default efmUnix;
    property ModeAsText: string read GetModeAsText;
    property IsText: Boolean read GetIsText;
    property Name: string read FName write FName;
    property NakeName: string read GetNakeName;
    property Path: string read GetPath;
    property Related: string read FRelated write FRelated;
    property IsEdited: Boolean read FIsEdited write SetIsEdited; //TODO rename to IsChanged
    property IsNew: Boolean read FIsNew write SetIsNew default False;
    property IsReadOnly: Boolean read GetIsReadonly write SetIsReadonly;
    property Group: TFileGroup read FGroup write SetGroup;
    property Control: TWinControl read GetControl;
  published
  end;

  { TControlEditorFile }

  TControlEditorFile = class(TEditorFile, IControlEditor)
  private
    FControl: TWinControl;
    procedure SetControl(AValue: TWinControl);
  protected
    function GetControl: TWinControl; override;
    function GetIsReadonly: Boolean; override;
    procedure DoLoad(FileName: string); override;
    procedure DoSave(FileName: string); override;
  public
    destructor Destroy; override;
    property Control: TWinControl read GetControl write SetControl;
  end;

  { TTextEditorFile }

  TTextEditorFile = class(TEditorFile, ITextEditor)
  private
    FSynEdit: TSynEdit;
  protected
    LastGotoLine: Integer;
    function GetIsReadonly: Boolean; override;
    procedure SetIsReadonly(const Value: Boolean); override;
    function GetControl: TWinControl; override;
    procedure DoLoad(FileName: string); override;
    procedure DoSave(FileName: string); override;
    procedure GroupChanged; override;

    procedure DoGutterClickEvent(Sender: TObject; X, Y, Line: integer; Mark: TSynEditMark);
    procedure DoSpecialLineMarkup(Sender: TObject; Line: integer; var Special: Boolean; Markup: TSynSelectedColor);
    procedure DoGetCapability(var vCapability: TEditCapability); override;
    procedure SynEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignTo(Dest: TPersistent); override;
    procedure Find; override;
    procedure FindNext; override;
    procedure FindPrevious; override;
    procedure Replace; override;
    procedure Refresh; override;
    procedure Show; override;
    function GetHint(HintControl: TControl; CursorPos: TPoint; out vHint: string): Boolean; override;
    function GetGlance: string; override;
    function EvalByMouse(p: TPoint; out v, s, t: string): boolean;
    function EvalByCursor(out v, s, t: string): boolean;
    procedure UpdateAge; override;
    function GetLanguageName: string; override;

    procedure Copy; override;
    procedure Paste; override;
    procedure Cut; override;
    procedure SelectAll; override;

    procedure SetLine(Line: Integer); override;
    procedure GotoLine; override;
    property SynEdit: TSynEdit read FSynEdit;
  end;

  TSourceEditorFile = class(TTextEditorFile, IExecuteEditor, IWatchEditor)
  end;

  { TEditorFiles }

  TEditorFiles = class(TCollection)
  private
    FCheckChanged: Boolean;
    FCurrent: TEditorFile;
    function GetItems(Index: integer): TEditorFile;
    function GetCurrent: TEditorFile;
    procedure SetCurrent(const Value: TEditorFile);
    function InternalOpenFile(FileName: string; AppendToRecent: Boolean): TEditorFile;
  protected
    function SetActiveFile(FileName: string): TEditorFile;
  public
    destructor Destroy; override;
    function FindFile(const vFileName: string): TEditorFile;
    function IsExist(vName: string): Boolean;
    function LoadFile(vFileName: string; AppendToRecent: Boolean = True): TEditorFile;
    function ShowFile(vFileName: string): TEditorFile; overload; //open it without add to recent, for debuging
    function ShowFile(const FileName: string; Line: integer): TEditorFile; overload;
    function OpenFile(vFileName: string): TEditorFile;
    procedure SetCurrentIndex(Index: integer; vRefresh: Boolean);
    function New(vGroupName: string = ''): TEditorFile; overload;
    function New(Category, Name, Related: string; ReadOnly, Executable: Boolean): TEditorFile; overload;
    function New(Name: string; Control: TWinControl): TEditorFile; overload;
    procedure Open;
    procedure Save;
    procedure SaveAll;
    procedure SaveAs;
    procedure Revert;
    procedure Refresh;
    procedure Next;
    procedure Prior;
    procedure Edited;
    procedure Replace;
    procedure Find;
    procedure FindNext;
    procedure FindPrevious;
    procedure CheckChanged;
    procedure CloseAll;
    function GetEditedCount: integer;
    property Current: TEditorFile read GetCurrent write SetCurrent;
    property Items[Index: integer]: TEditorFile read GetItems; default;
  published
  end;

  TSynBreakPointItem = class(TSynObjectListItem)
  public
    IsBreakPoint: Boolean;
  end;

  TSortFolderFiles = (srtfByNames, srtfByExt);
  TShowFolderFiles = (sffRelated, sffKnown, sffAll);
  TEditorFileClass = class of TEditorFile;

  TOnEngineChanged = procedure of object;

  { TEditorOptions }

  TEditorOptions = class(TmnXMLProfile)
  private
    FAutoOpenProject: Boolean;
    FIgnoreNames: string;
    FShowFolder: Boolean;
    FShowFolderFiles: TShowFolderFiles;
    FSortFolderFiles: TSortFolderFiles;
    FWindowMaxmized: Boolean;
    FBoundRect: TRect;
    FCompilerFolder: string;
    FShowMessages: Boolean;
    FShowOutput: Boolean;
    FCollectAutoComplete: Boolean;
    FCollectTimeout: DWORD;
    FReplaceHistory: TStringList;
    FAutoStartDebugServer: Boolean;
    FOutputHeight: integer;
    FMessagesHeight: integer;
    FFoldersWidth: integer;

    FExtraExtensions: TStringList;
    FSearchFolderHistory: TStringList;
    FSearchHistory: TStringList;
    FProfile: TEditorProfile;

    FRecentFiles: TStringList;
    FRecentProjects: TStringList;
    FProjects: TStringList;
    procedure SetRecentFiles(const Value: TStringList);
    procedure SetRecentProjects(const Value: TStringList);
    procedure SetProjects(const Value: TStringList);
  protected
  public
    constructor Create;
    destructor Destroy; override;
    procedure Apply; virtual;
    procedure Load(vWorkspace: string);
    procedure Save(vWorkspace: string);
    procedure Show;

    property BoundRect: TRect read FBoundRect write FBoundRect; //not saved yet

    property RecentFiles: TStringList read FRecentFiles write SetRecentFiles;
    property RecentProjects: TStringList read FRecentProjects write SetRecentProjects;
    property Projects: TStringList read FProjects write SetProjects;

    property Profile: TEditorProfile read FProfile;
    property SearchHistory: TStringList read FSearchHistory;
    property ReplaceHistory: TStringList read FReplaceHistory;
    property SearchFolderHistory: TStringList read FSearchFolderHistory;
  published
    property AutoOpenProject: Boolean read FAutoOpenProject write FAutoOpenProject;
    property ExtraExtensions: TStringList read FExtraExtensions write FExtraExtensions;
    property IgnoreNames: string read FIgnoreNames write FIgnoreNames;
    property CollectAutoComplete: Boolean read FCollectAutoComplete write FCollectAutoComplete default False;
    property CollectTimeout: DWORD read FCollectTimeout write FCollectTimeout default 60;
    property ShowFolder: Boolean read FShowFolder write FShowFolder default True;
    property ShowFolderFiles: TShowFolderFiles read FShowFolderFiles write FShowFolderFiles default sffRelated;
    property SortFolderFiles: TSortFolderFiles read FSortFolderFiles write FSortFolderFiles default srtfByNames;
    property ShowMessages: Boolean read FShowMessages write FShowMessages default False;
    property ShowOutput: Boolean read FShowOutput write FShowOutput default False;
    property OutputHeight: integer read FOutputHeight write FOutputHeight default 100;
    property MessagesHeight: integer read FMessagesHeight write FMessagesHeight default 100;
    property FoldersWidth: integer read FFoldersWidth write FFoldersWidth default 180;
    property AutoStartDebugServer: Boolean read FAutoStartDebugServer write FAutoStartDebugServer default False;
    property WindowMaxmized: Boolean read FWindowMaxmized write FWindowMaxmized default False;
    property WindowTop: Integer read FBoundRect.Top write FBoundRect.Top;
    property WindowLeft: Integer read FBoundRect.Left write FBoundRect.Left;
    property WindowRight: Integer read FBoundRect.Right write FBoundRect.Right;
    property WindoBottom: Integer read FBoundRect.Bottom write FBoundRect.Bottom;
  end;

  TmneSynCompletion = class;

  TMap = class(TObject)
    Name: string;
    AttType: TAttributeType;
  end;

  { TMapper }

  TMapper = class(TObjectList)
  private
    function GetItem(Index: integer): TMap;
  public
    function Find(vName: string): TMap;
    function Add(Attribute: TSynHighlighterAttributes; AttType: TAttributeType): TMap;
    function IndexOf(vName: string): Integer;
    property Items[Index: integer]: TMap read GetItem; default;
  end;

  TFileCategoryKind = (fckPublish);
  TFileCategoryKinds = set of TFileCategoryKind;

  { TFileCategory }

  TFileCategory = class(TEditorElements)
  private
    FName: string;
    FHighlighter: TSynCustomHighlighter;
    FKind: TFileCategoryKinds;
    FMapper: TMapper;
    function GetHighlighter: TSynCustomHighlighter;
    function GetItem(Index: Integer): TFileGroup;
    function GetMapper: TMapper;
  protected
    FCompletion: TmneSynCompletion;
    function DoCreateHighlighter: TSynCustomHighlighter; virtual; abstract;
    procedure InitMappers; virtual; abstract;
    procedure DoExecuteCompletion(Sender: TObject); virtual;
    procedure InitCompletion(vSynEdit: TCustomSynEdit); virtual;
    procedure InitEdit(vSynEdit: TCustomSynEdit); virtual;
    function GetIsText: Boolean; virtual;
  public
    constructor Create(const vName: string; vKind: TFileCategoryKinds = []); virtual;
    destructor Destroy; override;
    function CreateHighlighter: TSynCustomHighlighter; //todo replace with doCreate....
    procedure InitHighlighter;
    property Mapper:TMapper read GetMapper write FMapper;
    procedure Apply(AHighlighter: TSynCustomHighlighter; Attributes: TGlobalAttributes);
    property Name: string read FName write FName;
    function Find(vName: string): TFileGroup;
    procedure EnumExtensions(vExtensions: TStringList);
    property IsText: Boolean read GetIsText;
    property Highlighter: TSynCustomHighlighter read GetHighlighter;
    property Completion: TmneSynCompletion read FCompletion;
    property Kind: TFileCategoryKinds read FKind;
    property Items[Index: Integer]: TFileGroup read GetItem; default;
  end;

  TFileCategoryClass = class of TFileCategory;

  { TTextFileCategory }

  TTextFileCategory = class(TFileCategory)
  protected
    function GetIsText: Boolean; override;
  public
  end;

  { TFileCategories }

  TFileCategories = class(TObjectList)
  private
    function GetItem(Index: integer): TFileCategory;
    procedure SetItem(Index: integer; AObject: TFileCategory);
  public
    function Find(vName: string): TFileCategory;
    function Add(vFileCategory: TFileCategory): Integer;
    property Items[Index: integer]: TFileCategory read GetItem write SetItem; default;
  end;

  TFileGroupKind = (
    fgkExecutable,//You can guess what is it :P
    fgkText, //Is it an Text Editor like SQL or PHP
    fgkEditor, // Can be editable
    fgkMain,//this can be the main file for project
    fgkMember,//a member of project, inc are member, c, h, cpp members, pas,pp, p , inc also members, ini,txt not member of any project
    fgkBrowsable,//When open file show it in the extension list
    fgkAssociated //Editor can be the editor of this files, like .php, .inc, but .txt is not
  );

  TFileGroupKinds = set of TFileGroupKind;

  TFileGroupStyle = (
    fgsFolding
  );

  TFileGroupStyles = set of TFileGroupStyle;

  { TFileGroup }

  TFileGroup = class(TEditorElement)
  private
    FFileClass: TEditorFileClass;
    FExtensions: TStringList;
    FKind: TFileGroupKinds;
    FCategory: TFileCategory;
    FStyle: TFileGroupStyles;
    procedure SetCategory(AValue: TFileCategory);
  protected
  public
    constructor Create; override;
    destructor Destroy; override;
    function CreateEditorFile(vFiles: TEditorFiles): TEditorFile; virtual;
    procedure EnumExtensions(vExtensions: TStringList; Kind: TFileGroupKinds = []);
    procedure EnumExtensions(vExtensions: TEditorElements);
    property Category: TFileCategory read FCategory write SetCategory;
    property Extensions: TStringList read FExtensions;
    property Kind: TFileGroupKinds read FKind write FKind;
    property Style: TFileGroupStyles read FStyle write FStyle;
    property FileClass: TEditorFileClass read FFileClass;
  end;

  TFileGroupClass = class of TFileGroup;

  { TFileGroups }

  TFileGroups = class(TEditorElements)
  private
    function GetItem(Index: integer): TFileGroup;
  public
    function Find(vName: string): TFileGroup;
    function Find(vName, vCategory: string): TFileGroup;
    procedure EnumExtensions(vExtensions: TStringList; Kind: TFileGroupKinds = []);
    procedure EnumExtensions(vExtensions: TEditorElements);
    function FindExtension(vExtension: string): TFileGroup;
    //FullFilter return title of that filter for open/save dialog boxes
    function CreateFilter(FullFilter:Boolean = True; FirstExtension: string = ''; vGroup: TFileGroup = nil; OnlyThisGroup: Boolean = true): string;
    procedure Add(vGroup: TFileGroup);
    procedure Add(GroupClass: TFileGroupClass; FileClass: TEditorFileClass; const Name, Title: string; Category: string; Extensions: array of string; Kind: TFileGroupKinds = []; Style: TFileGroupStyles = []);
    procedure Add(FileClass: TEditorFileClass; const Name, Title: string; Category: string; Extensions: array of string; Kind: TFileGroupKinds = []; Style: TFileGroupStyles = []);
    property Items[Index: integer]: TFileGroup read GetItem; default;
  end;

  { TTendencies }

  TTendencies = class(TEditorElements)
  private
    function GetItem(Index: integer): TEditorTendency;
  public
    function Find(vName: string): TEditorTendency;
    procedure Add(vEditorTendency: TEditorTendencyClass);
    procedure Add(vEditorTendency: TEditorTendency);
    property Items[Index: integer]: TEditorTendency read GetItem; default;
  end;

  { TSourceManagements }

  TSourceManagements = class(TEditorElements)
  private
    function GetItem(Index: integer): TEditorSCM;
  public
    function Find(vName: string): TEditorSCM;
    procedure Add(vEditorSCM: TEditorSCMClass);
    property Items[Index: Integer]: TEditorSCM read GetItem; default;
  end;

  { TEditorFormItem }

  TEditorFormItem = class(TObject)
  private
    FObjectClass: TClass;
    FItemClass: TCustomFormClass;
  protected
  public
    property ObjectClass: TClass read FObjectClass;
    property ItemClass: TCustomFormClass read FItemClass;
  end;

  { TEditorFormList }

  TEditorFormList = class(TObjectList)
  private
    function GetItem(Index: integer): TEditorFormItem;
  public
    function Find(ObjectClass: TClass): TEditorFormItem;
    procedure Add(vObjectClass: TClass; vFormClass: TCustomFormClass);
    property Items[Index: integer]: TEditorFormItem read GetItem; default;
  end;

  TEditorSessionOptions = class(TmnXMLProfile)
  private
    FDefaultTendency: string;
    FDefaultSCM: string;
  public
  published
    property DefaultTendency: string read FDefaultTendency write FDefaultTendency;
    property DefaultSCM: string read FDefaultSCM write FDefaultSCM;
  end;

  {
    Session object to manage the current opened project, only one project can open.
  }

  { TEditorSession }

  TEditorSession = class(TObject)
  private
    FIsChanged: Boolean;
    FOptions: TEditorSessionOptions;
    FProcess: TObject;
    FProject: TEditorProject;
    FRun: TmneRun;
    FCachedIdentifiers: THashedStringList;
    FCachedVariables: THashedStringList;
    FCachedAge: DWORD;
    procedure SetProcess(AValue: TObject);
    procedure SetProject(const Value: TEditorProject);
    function GetIsOpened: Boolean;
    procedure SetRun(AValue: TmneRun);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Changed;
    procedure Load(FileName: string);
    function New: TEditorProject;
    function New(Tendency: TEditorTendency): TEditorProject;
    procedure Close;
    procedure Open;
    function Save(AProject: TEditorProject): Boolean;
    function SaveAs(AProject: TEditorProject): Boolean;
    function Save: Boolean;
    function SaveAs: Boolean;
    function GetRoot: string;
    //Is project opened
    property IsOpened: Boolean read GetIsOpened;
    //Current is the opened project, if it is a nil that mean there is no opened project.
    property Project: TEditorProject read FProject write SetProject;
    //Session Options is depend on the system used not shared between OSs
    property Options: TEditorSessionOptions read FOptions;
    property IsChanged: Boolean read FIsChanged;
    //Process the project running if it is null, process should nil it after finish
    property Process: TObject read FProcess write SetProcess;
    property Run: TmneRun read FRun write SetRun;

    property CachedVariables: THashedStringList read FCachedVariables;
    property CachedIdentifiers: THashedStringList read FCachedIdentifiers;
    property CachedAge: Cardinal read FCachedAge write FCachedAge;
  end;

  TEditorMessagesList = class;

  TEditorMessage = class(TObject)
  private
    FText: string;
  public
    property Text: string read FText write FText;
  end;

  TEditorMessages = class(TObjectList)
  private
    FName: string;
    function GetItem(Index: integer): TEditorMessage;
    procedure SetItem(Index: integer; const Value: TEditorMessage);
  public
    function GetText(Index: integer): string;
    property Name: string read FName write FName;
    property Items[Index: integer]: TEditorMessage read GetItem write SetItem; default;
  end;

  TEditorMessagesList = class(TObjectList)
  private
    function GetItem(Index: integer): TEditorMessages;
    procedure SetItem(Index: integer; const Value: TEditorMessages);
  public
    function Find(Name: string): TEditorMessages;
    function GetMessages(Name: string): TEditorMessages;
    property Items[Index: integer]: TEditorMessages read GetItem write SetItem; default;
  end;

  TEditorAction = (eaClearOutput);

  TOnFoundEvent = procedure(FileName: string; const Line: string; LineNo, Column, FoundLength: integer) of object;
  TOnEditorChangeState = procedure(State: TEditorChangeStates) of object;

  INotifyEngine = interface(IInterface)
    procedure EditorChangeState(State: TEditorChangeStates);
    procedure EngineAction(EngineAction: TEditorAction);
    procedure EngineOutput(S: string);
    procedure EngineReplaceText(Sender: TObject; const ASearch, AReplace: string; Line, Column: integer; var ReplaceAction: TSynReplaceAction);
  end;

  { TEditorEngine }

  TEditorEngine = class(TObject)
  private
    //if the project not defined any Tendency this is the default one
    FDefaultTendency: TEditorTendency;
    FDefaultSCM: TEditorSCM;
    //FInternalTendency used only there is no any default Tendency defined, it is mean simple editor without any project type
    FInternalTendency: TDefaultTendency;
//    FForms: TEditorFormList;
    FTendencies: TTendencies;
    FSourceManagements: TSourceManagements;
    FUpdateState: TEditorChangeStates;
    FUpdateCount: integer;
    FFiles: TEditorFiles;
    FContainer: TWinControl;
    FOptions: TEditorOptions;
    FSearchEngine: TSynEditSearch;
    FCategories: TFileCategories;
    FGroups: TFileGroups;
    FExtenstion: string;
    FSession: TEditorSession;
    FMessagesList: TEditorMessagesList;
    FBrowseFolder: string;
    //FMacroRecorder: TSynMacroRecorder;
    FWorkSpace: string;
    //Extenstion Cache
    //FExtenstionCache: TExtenstionCache; //TODO
    FEnvironment: TStringList;
    function GetTendency: TEditorTendency;
    function GetSCM: TEditorSCM;
    function GetUpdating: Boolean;
    procedure SetBrowseFolder(const Value: string);
    function GetWorkSpace: string;
    procedure SetDefaultTendency(AValue: TEditorTendency);
    procedure SetDefaultSCM(AValue: TEditorSCM);
  protected
    FInUpdateState: Integer;
    FNotifyObject: INotifyEngine; //TODO should be list
    property SearchEngine: TSynEditSearch read FSearchEngine;
    procedure InternalChangedState(State: TEditorChangeStates);
    procedure DoChangedState(State: TEditorChangeStates); virtual;
    procedure DoMacroStateChange(Sender: TObject);
    procedure DoReplaceText(Sender: TObject; const ASearch, AReplace: string; Line, Column: integer; var ReplaceAction: TSynReplaceAction);
    procedure UpdateExtensionsCache;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    //I used it for search in files
    function SearchReplace(const FileName: string; const ALines: TStringList; const ASearch, AReplace: string; OnFoundEvent: TOnFoundEvent; AOptions: TSynSearchOptions): integer;
    //Recent
    procedure ProcessRecentFile(const FileName: string);
    procedure RemoveRecentFile(const FileName: string);
    procedure ProcessRecentProject(const FileName: string);
    procedure RemoveRecentProject(const FileName: string);
    procedure ProcessProject(const FileName: string);
    procedure RemoveProject(const FileName: string);

    procedure Startup;
    procedure LoadOptions;
    procedure SaveOptions;
    procedure Shutdown;

    procedure BeginUpdate;
    procedure UpdateState(State: TEditorChangeStates);
    property Updating: Boolean read GetUpdating;
    procedure EndUpdate;

    function EnvReplace(S: string; ForVar: string = ''): string;
    function ExpandFile(FileName: string): string;
    function GetRoot: string;
    property Extenstion: string read FExtenstion write FExtenstion;

    property WorkSpace: string read GetWorkSpace write FWorkSpace;

    //AddInstant: Create category and file group for highlighter
    //procedure AddInstant(vName: string; vExtensions: array of string; vHighlighterClass: TSynCustomHighlighterClass; vKind: TFileCategoryKinds);

    property Categories: TFileCategories read FCategories;
    property Groups: TFileGroups read FGroups;
    property Tendencies: TTendencies read FTendencies;
    property SourceManagements: TSourceManagements read FSourceManagements;
    //property Forms: TEditorFormList read FForms;
    //
    property Files: TEditorFiles read FFiles;
    property Session: TEditorSession read FSession;
    property Options: TEditorOptions read FOptions;
    property MessagesList: TEditorMessagesList read FMessagesList;
    //Container is a panel or any wincontrol that the editor SynEdit put on it
    property Container: TWinControl read FContainer write FContainer;
    //BrowseFolder: Current folder
    property BrowseFolder: string read FBrowseFolder write SetBrowseFolder;
    procedure SetDefaultTendency(vName: string);
    procedure SetDefaultSCM(vName: string);
    property DefaultTendency: TEditorTendency read FDefaultTendency write SetDefaultTendency;
    property DefaultSCM: TEditorSCM read FDefaultSCM write SetDefaultSCM;
    property Tendency: TEditorTendency read GetTendency;
    property SCM: TEditorSCM read GetSCM;
    function GetIsChanged: Boolean;
    procedure SetNotifyEngine(ANotifyObject: INotifyEngine);
    procedure RemoveNotifyEngine(ANotifyObject: INotifyEngine);
    //property MacroRecorder: TSynMacroRecorder read FMacroRecorder;
    procedure SendOutout(S: string);
    procedure SendAction(EditorAction: TEditorAction);

    property Environment: TStringList read FEnvironment write FEnvironment;
  published
  end;

  { TmneSynCompletion }

  TmneSynCompletion = class(TSynCompletion)
  protected
    function OwnedByEditor: Boolean; override;
  public
  end;

  { TListFileSearcher }

  TListFileSearcher = class(TFileSearcher)
  protected
    procedure DoDirectoryFound; override;
    procedure DoFileFound; override;
  public
    List: TStringList;
  end;

function SelectFolder(const Caption: string; const Root: WideString; var Directory: string): Boolean;
procedure SpliteStr(S, Separator: string; var Name, Value: string);
procedure SaveAsUnix(Strings: TStrings; Stream: TStream);
procedure SaveAsWindows(Strings: TStrings; Stream: TStream);
procedure SaveAsMAC(Strings: TStrings; Stream: TStream);
procedure SaveAsMode(const FileName: string; Mode: TEditorFileMode; Strings: Tstrings);
function DetectFileMode(const Contents: string): TEditorFileMode;
function ChangeTabsToSpace(const Contents: string; TabWidth: integer): string;

type
  //If set Resume to false it will stop loop
  TEnumFilesCallback = procedure(AObject: TObject; const FileName: string; Count, Level:Integer; var Resume: Boolean);

procedure EnumFiles(Folder, Filter: string; FileList: TStringList);
//EnumFileList return false if canceled by callback function
function EnumFileList(const Root, Masks, Ignore: string; Callback: TEnumFilesCallback; AObject: TObject; vMaxCount,vMaxLevel: Integer; ReturnFullPath, Recursive: Boolean): Boolean;
procedure EnumFileList(const Root, Masks, Ignore: string; Strings: TStringList; vMaxCount, vMaxLevel: Integer; ReturnFullPath, Recursive: Boolean);

function GetWordAtRowColEx(SynEdit: TCustomSynEdit; XY: TPoint; BreakChars: TSynIdentChars; Select: boolean): string;

function Engine: TEditorEngine;

const
{$ifdef WINDOWS}
  SysPlatform = 'WINDOWS';
{$else}
  SysPlatform = 'LINUX';
{$endif}

implementation

uses
  SynHighlighterApache, SynHighlighterXHTML, SynHighlighterHashEntries, SynGutterCodeFolding,
  Registry, SearchForms, SynEditTextBuffer, GotoForms,
  mneResources, MsgBox, GUIMsgBox;

var
  FIsEngineStart: Boolean = False;
  FIsEngineShutdown: Boolean  = False;
  FEngine: TEditorEngine = nil;

function Engine: TEditorEngine;
begin
  if FIsEngineShutdown then
    raise Exception.Create('Engine in shutdown?');
  if FEngine = nil then
    FEngine := TEditorEngine.Create;
  Result := FEngine;
end;

function SelectFolder(const Caption: string; const Root: WideString; var Directory: string): Boolean;
begin
  Result := SelectDirectory(Caption, Root, Directory);
end;

procedure SpliteStr(S, Separator: string; var Name, Value: string);
var
  p: integer;
begin
  p := AnsiPos(Separator, S);
  if P <> 0 then
  begin
    Name := Copy(s, 1, p - 1);
    Value := Copy(s, p + 1, MaxInt);
  end
  else
  begin
    Name := s;
    Value := '';
  end;
end;

procedure SaveAsUnix(Strings: TStrings; Stream: TStream);
var
  i, l: integer;
  S: string;
begin
  l := Strings.Count - 1;
  for i := 0 to l do
  begin
    S := Strings[i];
    if i <> l then
      S := S + #$A;
    Stream.WriteBuffer(Pointer(S)^, Length(S));
  end;
end;

procedure SaveAsWindows(Strings: TStrings; Stream: TStream);
var
  i, l: integer;
  S: string;
begin
  l := Strings.Count - 1;
  for i := 0 to l do
  begin
    S := Strings[i];
    if i <> l then
      S := S + #$D#$A;
    Stream.WriteBuffer(Pointer(S)^, Length(S));
  end;
end;

procedure SaveAsMAC(Strings: TStrings; Stream: TStream);
var
  i, l: integer;
  S: string;
begin
  l := Strings.Count - 1;
  for i := 0 to l do
  begin
    S := Strings[i];
    if i <> l then
      S := S + #$D;
    Stream.WriteBuffer(Pointer(S)^, Length(S));
  end;
end;

{ TControlEditorFile }

procedure TControlEditorFile.SetControl(AValue: TWinControl);
begin
  if FControl <> AValue then
  begin
    if FControl <> nil then
      FControl.Free;
    FControl := AValue;
    FControl.Align := alClient;
    FControl.Parent := Engine.Container;
    //FControl.Visible := True;
  end;
end;

function TControlEditorFile.GetControl: TWinControl;
begin
  Result := FControl;
end;

function TControlEditorFile.GetIsReadonly: Boolean;
begin
  Result := True;
end;

procedure TControlEditorFile.DoLoad(FileName: string);
begin
end;

procedure TControlEditorFile.DoSave(FileName: string);
begin
end;

destructor TControlEditorFile.Destroy;
begin
  FreeAndNil(FControl);
  inherited Destroy;
end;

{ TEditorProjectOptions }

constructor TEditorProjectOptions.Create;
begin
  inherited;
end;

procedure TEditorProjectOptions.CreateOptionsFrame(AOwner: TComponent; AProject: TEditorProject; AddFrame: TAddProjectCallBack);
begin
end;

procedure TCompilerProjectOptions.SetPaths(AValue: TStrings);
begin
  FPaths.Assign(AValue);
end;

constructor TCompilerProjectOptions.Create;
begin
  inherited;
  FPaths := TStringList.Create;
end;

destructor TCompilerProjectOptions.Destroy;
begin
  FreeAndNil(FPaths);
  inherited Destroy;
end;


{ TTextFileCategory }

function TTextFileCategory.GetIsText: Boolean;
begin
  Result := True;
end;

{ TMapper }

function TMapper.GetItem(Index: integer): TMap;
begin
  Result := inherited Items[Index] as TMap;
end;

function TMapper.Find(vName: string): TMap;
var
  i: integer;
begin
  Result := nil;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := Items[i];
        break;
      end;
    end;
end;

function TMapper.Add(Attribute: TSynHighlighterAttributes; AttType: TAttributeType): TMap;
begin
  Result := TMap.Create;
  Result.Name := Attribute.StoredName;
  Result.AttType := AttType;
  inherited Add(Result);
end;

function TMapper.IndexOf(vName: string): Integer;
var
  i: integer;
begin
  Result := -1;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := i;
        break;
      end;
    end;
end;

{ TTextEditorFile }

function TTextEditorFile.GetIsReadonly: Boolean;
begin
  Result := SynEdit.ReadOnly;
end;

procedure TTextEditorFile.SetIsReadonly(const Value: Boolean);
begin
  SynEdit.ReadOnly := Value;
end;

function TTextEditorFile.GetControl: TWinControl;
begin
  Result := SynEdit;
end;

procedure TTextEditorFile.DoLoad(FileName: string);
var
  Contents: string;
  Size: integer;
  Stream: TFileStream;
begin
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    SynEdit.BeginUpdate;
    try
      Size := Stream.Size - Stream.Position;
      SetString(Contents, nil, Size);
      Stream.Read(Pointer(Contents)^, Size);
      Mode := DetectFileMode(Contents);
      if eoTabsToSpaces in SynEdit.Options then
      begin
        Contents := ChangeTabsToSpace(Contents, SynEdit.TabWidth);
      end;
      SynEdit.Lines.Text := Contents;
    finally
      SynEdit.EndUpdate;
      Stream.Free;
    end;
  finally
  end;
end;

procedure TTextEditorFile.DoSave(FileName: string);
begin
  SaveAsMode(FileName, Mode, SynEdit.Lines);
end;

procedure TTextEditorFile.GroupChanged;
begin
  inherited;
  if Group <> nil then
  begin
    FSynEdit.Highlighter := FGroup.Category.Highlighter;
    FGroup.Category.InitCompletion(FSynEdit);

    if (fgkExecutable in FGroup.Kind) then
      with TSynDebugMarksPart.Create(FSynEdit.Gutter.Parts) do
      begin
        FEditorFile := Self;
        AutoSize := False;
        Width := EditorResource.DebugImages.Width + DEBUG_IMAGE_MARGINES;
      end;

    FSynEdit.Gutter.SeparatorPart(0).Index := FSynEdit.Gutter.Parts.Count - 1;

    FGroup.Category.InitEdit(FSynEdit);
    //Engine.MacroRecorder.AddEditor(FSynEdit);
  end;
end;

procedure TTextEditorFile.DoGutterClickEvent(Sender: TObject; X, Y, Line: integer; Mark: TSynEditMark);
var
  aLine: integer;
begin
  if (Engine.Tendency.Debug <> nil) and (fgkExecutable in Group.Kind) then
  begin
    aLine := SynEdit.PixelsToRowColumn(Point(X, Y)).y;
    Engine.Tendency.Debug.Lock;
    try
      Engine.Tendency.Debug.Breakpoints.Toggle(Name, aLine);
    finally
      Engine.Tendency.Debug.Unlock;
    end;
    SynEdit.InvalidateLine(aLine);
  end;
end;

procedure TTextEditorFile.DoSpecialLineMarkup(Sender: TObject; Line: integer; var Special: Boolean; Markup: TSynSelectedColor);
begin
  if (Engine.Tendency.Debug <> nil) and (Engine.Tendency.Debug.ExecutedControl = Sender) then
  begin
    if Engine.Tendency.Debug.ExecutedLine = Line then
    begin
      Special := True;
      Markup.Background := clNavy;
      Markup.Foreground := clWhite;
    end;
  end;
end;

procedure TTextEditorFile.DoGetCapability(var vCapability: TEditCapability);
begin
  inherited;

  if SynEdit.SelAvail then
    vCapability := vCapability + [ecpAllowCopy];

  if SynEdit.CanPaste then
    vCapability := vCapability + [ecpAllowPaste];
end;

procedure TTextEditorFile.SynEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Shift = [ssCtrl] then
  begin
    if (Key = VK_INSERT) then
    begin
      if not SynEdit.SelAvail then
      begin
        SynEdit.SelectWord;
        SynEdit.CopyToClipboard;
      end;
    end;
  end;
end;

constructor TTextEditorFile.Create(ACollection: TCollection);
var
  aKey: TSynEditKeyStroke;
begin
  inherited;
  { There is more assigns in TEditorFile.SetGroup and TEditorProfile.Assign}
  FSynEdit := TSynEdit.Create(Engine.Container);
  FSynEdit.OnChange := @DoEdit;
  FSynEdit.OnStatusChange := @DoStatusChange;
  FSynEdit.OnGutterClick := @DoGutterClickEvent;
  FSynEdit.OnSpecialLineMarkup := @DoSpecialLineMarkup;
  FSynEdit.BookMarkOptions.BookmarkImages := EditorResource.BookmarkImages;
  FSynEdit.OnReplaceText := @Engine.DoReplaceText;
  FSynEdit.OnKeyDown := @SynEditKeyDown;

  FSynEdit.TrimSpaceType := settLeaveLine;
  FSynEdit.BoundsRect := Engine.Container.ClientRect;
  FSynEdit.Font.Quality := fqDefault;
  FSynEdit.BorderStyle := bsNone;
  FSynEdit.ShowHint := True;
  FSynEdit.Visible := False;
  FSynEdit.WantTabs := True;
  FSynEdit.Parent := Engine.Container;
end;

destructor TTextEditorFile.Destroy;
begin
  FSynEdit.Free;
  inherited;
end;

procedure TTextEditorFile.Assign(Source: TPersistent);
var
  aProfile: TEditorProfile;
  cf: TSynGutterCodeFolding;
  OldCF: Boolean;
begin
  if Source is TEditorProfile then
  begin
    aProfile := Source as TEditorProfile;

    SynEdit.Font.Name := aProfile.FontName;
    SynEdit.Font.Size := aProfile.FontSize;
    if aProfile.FontNoAntialiasing then
      SynEdit.Font.Quality := fqNonAntialiased
    else
      SynEdit.Font.Quality := fqDefault;

    SynEdit.Font.Color := aProfile.Attributes.Whitespace.Foreground;
    SynEdit.Color := aProfile.Attributes.Whitespace.Background;
    SynEdit.SelectedColor.Foreground := aProfile.Attributes.Selected.Foreground;
    SynEdit.SelectedColor.Background := aProfile.Attributes.Selected.Background;
    SynEdit.BracketMatchColor.Foreground := aProfile.Attributes.Selected.Foreground;
    SynEdit.BracketMatchColor.Background := aProfile.Attributes.Selected.Background;

    SynEdit.Options := SynEdit.Options - [eoDropFiles]; //make main window accept the files
    SynEdit.Gutter.Assign(aProfile.Gutter);

    cf := SynEdit.Gutter.Parts.ByClass[TSynGutterCodeFolding, 0] as TSynGutterCodeFolding;
    if cf <> nil then
    begin
      OldCF := cf.Visible;
      cf.Visible := aProfile.CodeFolding and (SynEdit.Highlighter <> nil) and (hcCodeFolding in SynEdit.Highlighter.Capabilities);
      if (cf.Visible) and (cf.Visible <> OldCF) then
        SynEdit.UnfoldAll;
    end;

    SynEdit.Options := aProfile.Options;
    SynEdit.ExtraLineSpacing := aProfile.ExtraLineSpacing;
    SynEdit.InsertCaret := aProfile.InsertCaret;
    SynEdit.OverwriteCaret := aProfile.OverwriteCaret;
    SynEdit.MaxUndo := aProfile.MaxUndo;
    SynEdit.RightEdge := aProfile.RightEdge;
    SynEdit.RightEdgeColor := aProfile.RightEdgeColor;
    SynEdit.TabWidth := aProfile.TabWidth;

    if Group.Category.Highlighter <> nil then
      Group.Category.Apply(Group.Category.Highlighter, aProfile.Attributes);
  end
  else if (Source is TEditorDesktopFile) then
  begin
    with (Source as TEditorDesktopFile) do
    begin
//      SynEdit.CaretX := CaretX;
      SynEdit.CaretY := CaretY;
      SynEdit.TopLine := TopLine;
    end;
  end
  else
    inherited Assign(Source);
end;

procedure TTextEditorFile.AssignTo(Dest: TPersistent);
begin
  if (Dest is TEditorDesktopFile) then
  begin
    with (Dest as TEditorDesktopFile) do
    begin
      CaretX := SynEdit.CaretX;
      CaretY := SynEdit.CaretY;
      TopLine := SynEdit.TopLine;
    end;
  end
  else
    inherited AssignTo(Dest);
end;

procedure TTextEditorFile.Find;
begin
  inherited;
  ShowSearchForm(SynEdit, Engine.Options.SearchHistory, Engine.Options.ReplaceHistory, False);
end;

procedure TTextEditorFile.FindNext;
begin
  inherited;
  SearchTextNext(SynEdit);
end;

procedure TTextEditorFile.FindPrevious;
begin
  inherited;
  SearchTextPrevious(SynEdit);
end;

procedure TTextEditorFile.Replace;
begin
  inherited;
  ShowSearchForm(SynEdit, Engine.Options.SearchHistory, Engine.Options.ReplaceHistory, True);
end;

procedure TTextEditorFile.Refresh;
begin
  inherited;
  SynEdit.Refresh;
end;

procedure TTextEditorFile.Show;
begin
  inherited;
end;

function TTextEditorFile.GetHint(HintControl: TControl; CursorPos: TPoint; out vHint: string): Boolean;
var
  v, s, t: string;
begin
  Result := EvalByMouse(CursorPos, v, s, t);
  if Result then
    vHint := v + ':' + t + '=' + #13#10 + s;
end;

function TTextEditorFile.GetGlance: string;
var
  r: Integer;
begin
  Result := IntToStr(SynEdit.CaretY) + ':' + IntToStr(SynEdit.CaretX);
  if SynEdit.SelAvail then
  begin
    r := SynEdit.BlockEnd.y - SynEdit.BlockBegin.y + 1;
    Result := Result + ' [' + IntToStr(r) + ']';
  end;
end;

function TTextEditorFile.EvalByMouse(p: TPoint; out v, s, t: string): boolean;
var
  l: variant;
begin
  if Engine.Tendency.Debug <> nil then
  begin
    if not SynEdit.SelAvail then
      v := Trim(GetWordAtRowColEx(SynEdit, SynEdit.PixelsToRowColumn(p), TSynWordBreakChars + [' ', #13, #10, #9] - ['.', '"', '''', '-', '>', '[', ']'], False))//todo get it from the synedit
    else
      v := SynEdit.SelText;
    Result := (v <> '') and Engine.Tendency.Debug.Watches.GetValue(v, l, t, False);
    s := l;
  end
  else
    Result := False;
end;

function TTextEditorFile.EvalByCursor(out v, s, t: string): boolean;
var
  l: variant;
begin
  if Engine.Tendency.Debug <> nil then
  begin
    if not SynEdit.SelAvail then
      v := Trim(SynEdit.GetWordAtRowCol(SynEdit.CaretXY))
    else
      v := SynEdit.SelText;
    Result := (v <> '') and Engine.Tendency.Debug.Watches.GetValue(v, l, t, False);
    s := l;
  end
  else
    Result := False;
end;

procedure TTextEditorFile.UpdateAge;
begin
  inherited;
  if SynEdit <> nil then
  begin
    SynEdit.Modified := False;
    SynEdit.MarkTextAsSaved;
  end;
end;

function TTextEditorFile.GetLanguageName: string;
begin
  if (SynEdit <> nil) and (SynEdit.Highlighter <> nil) then
    Result := SynEdit.Highlighter.GetLanguageName
  else
    Result := inherited;
end;

procedure TTextEditorFile.Copy;
begin
  SynEdit.CopyToClipboard
end;

procedure TTextEditorFile.Paste;
begin
  SynEdit.PasteFromClipboard;
end;

procedure TTextEditorFile.Cut;
begin
  SynEdit.CutToClipboard;
end;

procedure TTextEditorFile.SelectAll;
begin
  SynEdit.SelectAll;
end;

procedure TTextEditorFile.SetLine(Line: Integer);
begin
  SynEdit.CaretY := Line;
  SynEdit.CaretX := 1;
end;

procedure TTextEditorFile.GotoLine;
begin
  with TGotoLineForm.Create(Application) do
  begin
    NumberEdit.Text := IntToStr(LastGotoLine);
    if ShowModal = mrOk then
    begin
      if NumberEdit.Text <> '' then
      begin
        LastGotoLine := StrToIntDef(NumberEdit.Text, 0);
        SynEdit.CaretXY := Point(0, LastGotoLine);
      end;
    end;
    Free;
  end;
end;

{ TmneSynCompletion }

function TmneSynCompletion.OwnedByEditor: Boolean;
begin
  Result := False;
end;

{ TEditorSCM }

constructor TEditorSCM.Create;
begin
  inherited Create;
end;

{ TEditorElements }

function TEditorElements.GetItem(Index: integer): TEditorElement;
begin
  Result := inherited Items[Index] as TEditorElement;
end;

function TEditorElements.Find(vName: string): TEditorElement;
var
  i: integer;
begin
  Result := nil;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := Items[i];
        break;
      end;
    end;
end;

function TEditorElements.IndexOf(vName: string): Integer;
var
  i: integer;
begin
  Result := -1;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := i;
        break;
      end;
    end;
end;

{ TSourceManagements }

function TSourceManagements.GetItem(Index: integer): TEditorSCM;
begin
  Result := inherited Items[Index] as TEditorSCM;
end;

function TSourceManagements.Find(vName: string): TEditorSCM;
begin
  Result := inherited Find(vName) as TEditorSCM;
end;

procedure TSourceManagements.Add(vEditorSCM: TEditorSCMClass);
var
  aItem: TEditorSCM;
begin
  RegisterClass(vEditorSCM);
  aItem := vEditorSCM.Create;
  inherited Add(aItem);
end;

{ TEditorElement }

function TEditorElement.GetDescription: string;
begin
  Result := FDescription;
end;

constructor TEditorElement.Create;
begin
  inherited Create;
  FImageIndex := -1;
end;

{ TDefaultTendency }

procedure TDefaultTendency.Init;
begin
  FTitle := 'Default';
  FName := 'Default';
  FDescription := 'Default project type';
end;

function TDefaultTendency.GetGroups: TFileGroups;
begin
  Result := Engine.Groups;
end;

function TDefaultTendency.GetDefaultGroup: TFileGroup;
begin
  Result := Groups.Find('txt');
end;

{ TEditorFormList }

function TEditorFormList.GetItem(Index: integer): TEditorFormItem;
begin
  Result := inherited Items[Index] as TEditorFormItem;
end;

function TEditorFormList.Find(ObjectClass: TClass): TEditorFormItem;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    if ObjectClass.InheritsFrom(Items[i].ObjectClass) then
    begin
      Result := Items[i] as TEditorFormItem;
      break;
    end;
  end;
end;

procedure TEditorFormList.Add(vObjectClass: TClass; vFormClass: TCustomFormClass);
var
  aItem: TEditorFormItem;
begin
  aItem := TEditorFormItem.Create;
  aItem.FObjectClass := vObjectClass;
  aItem.FItemClass := vFormClass;
  inherited Add(aItem);
end;

{ TEditorTendency }

function TEditorTendency.GetGroups: TFileGroups;
begin
  Result := FGroups;
end;

procedure TEditorTendency.DoRun(Info: TmneRunInfo);
begin
end;

procedure TEditorTendency.AddGroup(vName, vCategory: string);
var
  G: TFileGroup;
  C: TFileCategory;
begin
  if vCategory = '' then
    C := nil
  else
    C := Engine.Categories.Find(vName);
  if C = nil then
    G := Engine.Groups.Find(vName)
  else
    G := C.Find(vName);

  if G = nil then
    raise Exception.Create(vName + ' file group not found');
  Groups.Add(G);
end;

function TEditorTendency.CreateDebugger: TEditorDebugger;
begin
  Result := nil;
end;

constructor TEditorTendency.Create;
begin
  inherited;
  FGroups := TFileGroups.Create(False);//it already owned by Engine.Groups
  FDebug := CreateDebugger;
  Init;
{  if Groups.Count = 0 then
    raise Exception.Create('You must add groups in Init method');}//removed DefaultTendency has no groups
end;

destructor TEditorTendency.Destroy;
begin
  FreeAndNil(FDebug);
  FreeAndNil(FGroups);
  inherited;
end;

procedure TEditorTendency.Run(RunActions: TmneRunActions);
var
  p: TmneRunInfo;
  s: string;
begin
  s := Name;
  p.Actions := RunActions;
  if (Engine.Tendency.Debug <> nil) and (Engine.Tendency.Debug.Running) then
  begin
    if rnaDebug in RunActions then
      Engine.Tendency.Debug.Action(dbaRun)
    else
      Engine.Tendency.Debug.Action(dbaResume);
  end
  else
  begin
    if rnaCompile in RunActions then
      Engine.SendAction(eaClearOutput);
    p.Root := Engine.Session.GetRoot;
    if (Engine.Session.IsOpened) then
    begin
      p.Mode := Engine.Session.Project.Options.RunMode;
      p.MainFile := Engine.Session.Project.Options.MainFile;//ExpandToPath(Engine.Session.Project.Options.MainFile, p.Root);
      p.Pause := Engine.Session.Project.Options.PauseConsole;
    end
    else
    begin
      p.Mode := runConsole;
      p.Pause := True;
    end;
    if (p.MainFile = '') and (Engine.Files.Current <> nil) and (fgkExecutable in Engine.Files.Current.Group.Kind) then
      p.MainFile := Engine.Files.Current.Name;

    if (p.MainFile <> '') then
    begin
      if (p.Root = '') then
        p.Root := ExtractFileDir(p.MainFile);
      DoRun(p);
    end;
  end;
end;

procedure TEditorTendency.Show;
begin
  MsgBox.Msg.Show('No Options');
end;

function TEditorTendency.FindExtension(vExtension: string): TFileGroup;
begin
  if LeftStr(vExtension, 1) = '.' then
    vExtension := Copy(vExtension, 2, MaxInt);
  Result := Groups.FindExtension(vExtension);
  if Result = nil then
    Result := Engine.Groups.FindExtension(vExtension)
end;

function TEditorTendency.CreateEditorFile(vGroup: string): TEditorFile;
var
  G: TFileGroup;
begin
  G := Groups.Find(vGroup);
  if G = nil then
    G := Engine.Groups.Find(vGroup);
  Result := CreateEditorFile(G);
end;

function TEditorTendency.CreateEditorFile(vGroup: TFileGroup): TEditorFile;
begin
  if vGroup <> nil then
    Result := vGroup.CreateEditorFile(Engine.Files)
  else
    Result := TTextEditorFile.Create(Engine.Files);
  Result.Group := vGroup;
  Result.Assign(Engine.Options.Profile);
end;

function TEditorTendency.CreateEditorProject: TEditorProject;
begin
  Result := TEditorProject.Create;
  Result.TendencyName := Name;
end;

function TEditorTendency.CreateOptions: TEditorProjectOptions;
begin
  Result := TEditorProjectOptions.Create;
end;

function TEditorTendency.GetDefaultGroup: TFileGroup;
begin
  if Groups.Count > 0 then
    Result := Groups[0]
  else
    Result := Engine.Groups[0];//first group in all groups, naah //TODO wrong wrong
end;

{ TTendencies }

function TTendencies.GetItem(Index: integer): TEditorTendency;
begin
  Result := inherited Items[Index] as TEditorTendency;
end;

function TTendencies.Find(vName: string): TEditorTendency;
begin
  Result := inherited Find(vName) as TEditorTendency;
end;

procedure TTendencies.Add(vEditorTendency: TEditorTendencyClass);
var
  aItem: TEditorTendency;
begin
  RegisterClass(vEditorTendency);
  aItem := vEditorTendency.Create;
  Add(aItem);
end;

procedure TTendencies.Add(vEditorTendency: TEditorTendency);
begin
  inherited Add(vEditorTendency);
end;

{ TSynDebugMarksPart }

procedure TSynDebugMarksPart.Init;
begin
  inherited;
end;

constructor TSynDebugMarksPart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  //  FMouseActions := TSynEditMouseActionsLineNum.Create(self);
  //  FMouseActions.ResetDefaults;
end;

destructor TSynDebugMarksPart.Destroy;
begin
//  FreeAndNil(FMouseActions);
  inherited;
end;

function TEditorEngine.SearchReplace(const FileName: string; const ALines: TStringList; const ASearch, AReplace: string; OnFoundEvent: TOnFoundEvent; AOptions: TSynSearchOptions): integer;
var
  i: integer;
  nSearchLen, nReplaceLen, n, nChar: integer;
  nInLine: integer;
  iResultOffset: integer;
  aLine, aReplaceText: string;
  Replaced: Boolean;
begin
  if not Assigned(SearchEngine) then
  begin
    raise ESynEditError.Create('No search engine has been assigned');
  end;

  Result := 0;
  // can't search for or replace an empty string
  if Length(ASearch) = 0 then
    exit;

  i := 0;
  // initialize the search engine
  //SearchEngine.Options := AOptions;
  SearchEngine.Pattern := ASearch;
  // search while the current search position is inside of the search range
  try
    while i < ALines.Count do
    begin
      aLine := ALines[i];
      nInLine := SearchEngine.FindAll(aLine);
      iResultOffset := 0;
      n := 0;
      // Operate on all results in this line.
      Replaced := False;
      while nInLine > 0 do
      begin
        // An occurrence may have been replaced with a text of different length
        nChar := SearchEngine.Results[n] + iResultOffset;
        nSearchLen := SearchEngine.ResultLengths[n];
        Inc(n);
        Dec(nInLine);

        Inc(Result);
        OnFoundEvent(FileName, aLine, i + 1, nChar, nSearchLen);

        if (ssoReplace in AOptions) then
        begin
          //aReplaceText := SearchEngine.Replace(ASearch, AReplace);//need to review
          nReplaceLen := Length(aReplaceText);
          aLine := Copy(aLine, 1, nChar - 1) + aReplaceText + Copy(aLine, nChar + nSearchLen, MaxInt);
          if (nSearchLen <> nReplaceLen) then
          begin
            Inc(iResultOffset, nReplaceLen - nSearchLen);
          end;
          Replaced := True;
        end;
      end;
      if Replaced then
        ALines[i] := aLine;
      // search next / previous line
      Inc(i);
    end;
  finally
  end;
end;

{ TEditorEngine }

procedure TEditorOptions.Apply;
var
  i: integer;
  List: TFileCategories;
begin
  List := TFileCategories.create(False);
  try
    for i := 0 to Engine.Files.Count - 1 do
    begin
      Engine.Files[i].Assign(Profile);
      if List.IndexOf(Engine.Files[i].Group.Category) < 0 then
        List.Add(Engine.Files[i].Group.Category);
    end;

    for i := 0 to List.Count - 1 do
    begin
      //check if List[i].Completion = nil
      //List[i].Completion.Font := Profile.Font;
      //List[i].Completion.Options := List[i].Completion.Options + [scoTitleIsCentered];

{      if List[i].Highlighter <> nil then
        List[i].Apply(List[i].Highlighter, Profile.Attributes);}
    end;

    List.Free;
  finally
  end;
end;

procedure TEditorEngine.BeginUpdate;
begin
  if FUpdateCount = 0 then
  begin
    FUpdateState := [];
  end;
  Inc(FUpdateCount);
end;

procedure TEditorFiles.CheckChanged;
var
  i: integer;
  b: Boolean;
  aList: TObjectList;
begin
  if not FCheckChanged then
  begin
    Engine.BeginUpdate;
    FCheckChanged := True;
    aList := TObjectList.Create(False);
    try
      for i := 0 to Count - 1 do
        aList.Add(Items[i]);

      b := True;
      try
        for i := 0 to aList.Count - 1 do
        begin
          if not b then
            (aList.Items[i] as TEditorFile).UpdateAge
          else
            b := (aList.Items[i] as TEditorFile).CheckChanged;
        end;
      finally
        aList.Free;
      end;
    finally
      FCheckChanged := False;
      Engine.EndUpdate;
    end;
  end;
end;

procedure TEditorFiles.CloseAll;
begin
  Engine.BeginUpdate;
  try
    while Engine.Files.Count > 0 do
      Engine.Files[0].Close;
  finally
    Engine.EndUpdate;
  end;
end;

procedure TEditorSession.Close;
begin
  Engine.Files.CloseAll;
  FreeAndNil(FProject);
  FCachedIdentifiers.Clear;
  FCachedVariables.Clear;
  FCachedAge := 0;
  Engine.UpdateState([ecsChanged, ecsState, ecsRefresh, ecsProject]);
end;

constructor TEditorEngine.Create;
begin
  inherited;
  FEnvironment := TStringList.Create;
  FMessagesList := TEditorMessagesList.Create;
  //FMacroRecorder := TSynMacroRecorder.Create(nil);
  //FMacroRecorder.OnStateChange := DoMacroStateChange;
  FEnvironment.Add('HOME=' + SysUtils.GetEnvironmentVariable('HOME'));
  FEnvironment.Add('EXE=' + Application.ExeName);
  FEnvironment.Add('MINIEDIT=' + Application.Location);

  FInternalTendency := TDefaultTendency.Create;
  //FForms := TEditorFormList.Create(True);
  FOptions := TEditorOptions.Create;
  FCategories := TFileCategories.Create(True);
  FGroups := TFileGroups.Create(True);
  FTendencies := TTendencies.Create(True);
  FSourceManagements := TSourceManagements.Create(True);
  FSearchEngine := TSynEditSearch.Create;
  FFiles := TEditorFiles.Create(TEditorFile);
  FSession := TEditorSession.Create;
  Extenstion := 'mne-project';
  Tendencies.Add(FInternalTendency);
end;

destructor TEditorEngine.Destroy;
begin
  SetNotifyEngine(nil);
  if not FIsEngineShutdown then
    Shutdown;
  FreeAndNil(FFiles);
  FreeAndNil(FSession);
  FreeAndNil(FCategories);
  FreeAndNil(FGroups);
  FreeAndNil(FTendencies);
  FreeAndNil(FSearchEngine);
  FreeAndNil(FOptions);
  FreeAndNil(FSourceManagements);
  //FreeAndNil(FMacroRecorder);
  FreeAndNil(FMessagesList);
  FInternalTendency := nil;
  //FreeAndNil(FForms);
  FreeAndNil(FEnvironment);
  inherited;
end;

procedure EnumFiles(Folder, Filter: string; FileList: TStringList);
var
  R: integer;
  SearchRec: TSearchRec;
begin
  Folder := IncludeTrailingPathDelimiter(Folder);
  R := FindFirst(Folder + Filter, faAnyFile, SearchRec);
  while R = 0 do
  begin
    if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
    begin
      FileList.Add(SearchRec.Name);
    end;
    R := FindNext(SearchRec);
  end;
  FindClose(SearchRec);
end;

function EnumFileList(const Root, Masks, Ignore: string; Callback: TEnumFilesCallback; AObject: TObject; vMaxCount,vMaxLevel: Integer; ReturnFullPath, Recursive: Boolean): Boolean;
var
  Resume: Boolean;
  IgnoreList: TStringList;
  MaskList: TMaskList;
  aCount: Integer;

  procedure DoFind(const Root, Path: string; vLevel: Integer);
  var
    sr: TSearchRec;
    f: string;
  begin
    vLevel := vLevel + 1;
    if FindFirst(Root + Path + '*'{Files}, faAnyFile, sr) = 0 then
    begin
      repeat
        if (sr.Name = '') or
          ((IgnoreList <> nil) and (IgnoreList.IndexOf(sr.Name) >= 0)) or
          not ((MaskList = nil) or (MaskList.Matches(sr.Name))) then
            continue;
        if ReturnFullPath then
          f := Root + IncludePathSeparator(Path) + sr.Name
        else
          f := IncludePathSeparator(Path) + sr.Name;
        Callback(AObject, f, aCount, vLevel, Resume);
        if (vMaxCount > 0) and (aCount > vMaxCount) then
          Resume := False;
          //raise Exception.Create('Too many files');
        if not Resume then
          break;
        aCount := aCount + 1;
      until (FindNext(sr) <> 0);
    end;

    if (vMaxLevel = 0) or (vLevel < vMaxLevel) then
      if Resume and Recursive then
        if FindFirst(Root + Path + '*', faDirectory, sr) = 0 then
        begin
          repeat
            if (sr.Name = '') or (sr.Name[1] = '.') or (sr.Name = '..') or
              ((IgnoreList <> nil) and (IgnoreList.IndexOf(sr.Name) >= 0)) then
                continue;
            if (sr.Attr and faDirectory) <> 0 then
            begin
              DoFind(Root, IncludePathSeparator(Path + sr.Name), vLevel);
            end;
          until (FindNext(sr) <> 0);
        end;
  end;
begin
  if Ignore <> '' then
  begin
    IgnoreList := TStringList.Create;
    StrToStrings(Ignore, IgnoreList, [';'], [' ']);
    IgnoreList.Sort;
    IgnoreList.Sorted := true;
  end
  else
    IgnoreList := nil;

  if Masks <> '' then
    MaskList := TMaskList.Create(Masks)
  else
    MaskList := nil;
  aCount := 0;
  Resume := true;
  try
    DoFind(IncludeTrailingPathDelimiter(Root), '', 0);
  finally
    FreeAndNil(IgnoreList);
    FreeAndNil(MaskList);
  end;
  Result := Resume;
end;

procedure EnumFileListStringsCallback(AObject: TObject; const FileName: string; Count, Level:Integer; var Resume: Boolean);
begin
  TStringList(AObject).Add(FileName);
end;

procedure EnumFileList(const Root, Masks, Ignore: string; Strings: TStringList; vMaxCount, vMaxLevel: integer; ReturnFullPath, Recursive: Boolean);
begin
  EnumFileList(Root, Masks, Ignore, @EnumFileListStringsCallback, Strings, vMaxCount, vMaxLevel, ReturnFullPath, Recursive);
end;

function GetWordAtRowColEx(SynEdit: TCustomSynEdit; XY: TPoint; BreakChars: TSynIdentChars; Select: boolean): string;
var
  Line: string;
  Len, Stop: integer;
begin
  Result := '';
  if (XY.Y >= 1) and (XY.Y <= SynEdit.Lines.Count) then
  begin
    Line := SynEdit.Lines[XY.Y - 1];
    Len := Length(Line);
    if Len <> 0 then
    begin
      if (XY.X > 1) and (XY.X <= Len + 1) and (Line[XY.X] in BreakChars) then
        XY.X := XY.X - 1;
      if (XY.X >= 1) and (XY.X <= Len + 1) and not (Line[XY.X] in BreakChars) then
      begin
        Stop := XY.X;
        while (Stop <= Len) and not (Line[Stop] in BreakChars) do
          Inc(Stop);
        while (XY.X > 1) and not (Line[XY.X - 1] in BreakChars) do
          Dec(XY.X);
        if Stop > XY.X then
        begin
          Result := Copy(Line, XY.X, Stop - XY.X);
          if Select then
          begin
            SynEdit.CaretXY := XY;
            SynEdit.BlockBegin := XY;
            SynEdit.BlockEnd := Point(XY.x + Length(Result), XY.y);
          end;
        end;
      end;
    end;
  end;
end;


{ TListFileSearcher }

procedure TListFileSearcher.DoDirectoryFound;
begin
  inherited;

end;

procedure TListFileSearcher.DoFileFound;
begin
  inherited;
end;

procedure TEditorFiles.Edited;
begin
  Engine.UpdateState([ecsEdit]);
end;

procedure TEditorEngine.EndUpdate;
begin
  if (FUpdateCount = 1) and (Files.Current <> nil) then
    Files.Current.Show;
  Dec(FUpdateCount);
  if FUpdateCount = 0 then
  begin
    if FUpdateState <> [] then
      InternalChangedState(FUpdateState);
    FUpdateState := [];
  end;
end;

procedure TEditorFiles.Find;
begin
  if Current <> nil then
    Current.Find;
end;

procedure TEditorEngine.DoReplaceText(Sender: TObject; const ASearch, AReplace: string; Line, Column: integer; var ReplaceAction: TSynReplaceAction);
begin
  if FNotifyObject <> nil then
    FNotifyObject.EngineReplaceText(Sender, ASearch, AReplace, Line, Column, ReplaceAction);
end;

procedure TEditorEngine.UpdateExtensionsCache;
begin

end;

function TEditorFiles.FindFile(const vFileName: string): TEditorFile;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    if SameText(vFileName, Items[i].Name) then
    begin
      Result := Items[i];
      break;
    end;
  end;
end;

procedure TEditorFiles.FindNext;
begin
  if Current <> nil then
    Current.FindNext;
end;

procedure TEditorFiles.FindPrevious;
begin
  if Current <> nil then
    Current.FindPrevious;
end;

function TEditorFiles.GetCurrent: TEditorFile;
begin
  Result := FCurrent;
end;

function TEditorFiles.GetEditedCount: integer;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Count - 1 do
  begin
    if Items[i].IsEdited then
      Result := Result + 1;
  end;
end;

function TEditorEngine.GetRoot: string;
begin
  if Session.IsOpened then
  begin
    if (Session.Project.RootDir <> '') then
      Result := EnvReplace(Session.Project.RootDir, 'root')
    else
      Result := ExtractFilePath(Session.Project.FileName);
  end
  else
    Result := Application.Location;
  Result := ExpandFileName(IncludePathSeparator(Result));
end;

function TEditorEngine.GetSCM: TEditorSCM;
begin
  if (Session <> nil) and (Session.Project <> nil) and (Session.Project.SCM <> nil) then
    Result := Session.Project.SCM
  else if DefaultSCM <> nil then
    Result := DefaultSCM
  else
    Result := nil;
end;

function TEditorEngine.GetTendency: TEditorTendency;
begin
  if (Session <> nil) and (Session.Project <> nil) and (Session.Project.Tendency <> nil) then
    Result := Session.Project.Tendency
  else if DefaultTendency <> nil then
    Result := FDefaultTendency
  else
    Result := FInternalTendency;
end;

function TEditorFiles.InternalOpenFile(FileName: string; AppendToRecent: Boolean): TEditorFile;
var
  lFileName: string;
begin
  {$ifdef windows}
  lFileName := ExpandFileName(FileName);
  {$else}
  if ExtractFilePath(FileName) = '' then
    lFileName := IncludeTrailingPathDelimiter(SysUtils.GetCurrentDir()) + FileName
  else lFileName := FileName;
  {$endif}
  Result := FindFile(lFileName);
  if Result = nil then
  begin
    Result := Engine.Tendency.CreateEditorFile(Engine.Tendency.FindExtension(ExtractFileExt(lFileName)));
    Result.Load(lFileName);
  end;
  if AppendToRecent then
    Engine.ProcessRecentFile(lFileName);
end;

procedure TEditorOptions.Load(vWorkspace: string);
  procedure SafeLoad(s: TStringList; vName:string);
  begin
    if FileExistsUTF8(vName) then
      s.LoadFromFile(vName);
  end;
begin
  SafeLoadFromFile(vWorkspace + 'mne-options.xml');
  Profile.SafeLoadFromFile(vWorkspace + 'mne-editor.xml');

  SafeLoad(RecentFiles, vWorkspace + 'mne-recent-files.ini');
  SafeLoad(RecentProjects, vWorkspace + 'mne-recent-projects.ini');
  SafeLoad(Projects, vWorkspace + 'mne-projects.ini');

  SafeLoad(SearchHistory, vWorkspace + 'mne-search-history.ini');
  SafeLoad(ReplaceHistory, vWorkspace + 'mne-replace-history.ini');
  SafeLoad(SearchFolderHistory, vWorkspace + 'mne-folder-history.ini');

  Apply;
end;

procedure TEditorSession.Load(FileName: string);
var
  aProject: TEditorProject;
begin
  Close; //must free before load project for save the desktop and sure to save its files
  Engine.BeginUpdate;
  try
    aProject := New;
    try
      aProject.LoadFromFile(FileName);
    except
      aProject.Free;
      raise;
    end;
    Project := aProject;
    FIsChanged := False;
    Engine.ProcessRecentProject(FileName);
    Engine.UpdateState([ecsChanged, ecsState, ecsRefresh, ecsProject, ecsProjectLoaded]);
  finally
    Engine.EndUpdate;
  end;
end;

function TEditorFiles.New(vGroupName: string): TEditorFile;
var
  aGroup: TFileGroup;
begin
  Engine.BeginUpdate;
  try
    if vGroupName = '' then
      aGroup := Engine.Tendency.GetDefaultGroup
    else
      aGroup := Engine.Groups.Find(vGroupName);
    Result := Engine.Tendency.CreateEditorFile(aGroup);
    Result.NewContent;
    Result.Edit;
    Current := Result;
    Engine.UpdateState([ecsChanged, ecsState, ecsRefresh]);
  finally
    Engine.EndUpdate;
  end;
end;

function TEditorFiles.New(Category, Name, Related: string; ReadOnly, Executable: Boolean): TEditorFile;
begin
  Result := Engine.Tendency.CreateEditorFile(Category);
  Result.IsReadOnly := ReadOnly;
  Result.Name := Name;
  Result.Related := Related;
  Current := Result;
  Engine.UpdateState([ecsChanged, ecsState, ecsRefresh]);
end;

function TEditorFiles.New(Name: string; Control: TWinControl): TEditorFile;
begin
  BeginUpdate;
  try
    Result := TControlEditorFile.Create(Engine.Files);
    (Result as TControlEditorFile).Control := Control;
    Result.Name := Name;
    Engine.UpdateState([ecsChanged, ecsState, ecsRefresh]);
    Current := Result;
  finally
    EndUpdate;
  end;
end;

function TEditorSession.New: TEditorProject;
begin
  Result := New(Engine.Tendency);
end;

function TEditorSession.New(Tendency: TEditorTendency): TEditorProject;
begin
  Result := Tendency.CreateEditorProject;
end;

procedure TEditorFiles.Next;
var
  i: integer;
begin
  if Current <> nil then
  begin
    i := Current.Index + 1;
    if i >= Count then
      i := 0;
    SetCurrentIndex(i, True);
  end;
end;

procedure TEditorFiles.Open;
var
  i: integer;
  aFile: TEditorFile;
  aDialog: TOpenDialog;
begin
  aDialog := TOpenDialog.Create(nil);
  try
    aDialog.Title := 'Open file';
    aDialog.Options := aDialog.Options + [ofHideReadOnly, ofFileMustExist, ofAllowMultiSelect];
    aDialog.Filter := Engine.Groups.CreateFilter;
    aDialog.FilterIndex := 0;
    aDialog.InitialDir := Engine.BrowseFolder;
    aDialog.DefaultExt := Engine.Tendency.GetDefaultGroup.Extensions[0];
    //aDialog.FileName := '*' + aDialog.DefaultExt;
    if aDialog.Execute then
    begin
      Engine.BeginUpdate;
      try
        aFile := nil;
        for i := 0 to aDialog.Files.Count - 1 do
        begin
          aFile := InternalOpenFile(aDialog.Files[i], True);
          //aFile.IsReadOnly := aDialog. TODO
        end;
        if aFile <> nil then
          Current := aFile;
        Engine.UpdateState([ecsChanged, ecsState, ecsRefresh]);
      finally
        Engine.EndUpdate;
      end;
    end;
  finally
    aDialog.Free;
  end;
end;

function TEditorFiles.OpenFile(vFileName: string): TEditorFile;
begin
  if SameText(ExtractFileExt(vFileName), '.' + Engine.Extenstion) then
  begin
    Engine.Session.Load(vFileName);
    Result := nil; //it is a project not a file.
  end
  else
  begin
    Result := LoadFile(vFileName);
  end;
end;

procedure TEditorSession.Open;
var
  aDialog: TOpenDialog;
begin
  aDialog := TOpenDialog.Create(nil);
  try
    aDialog.Title := 'Open project';
    aDialog.DefaultExt := Engine.Extenstion;
    aDialog.Filter := 'Project files (*.' + Engine.Extenstion + ')|*.' + Engine.Extenstion + '|All files|*.*';
    aDialog.InitialDir := Engine.BrowseFolder;
    aDialog.FileName := '*' + aDialog.DefaultExt;
    if aDialog.Execute then
      Load(aDialog.FileName);
  finally
    aDialog.Free;
  end;
end;

function TEditorSession.Save(AProject: TEditorProject): Boolean;
begin
  if AProject.FileName = '' then
    Result := SaveAs(AProject)
  else
  begin
    AProject.SaveToFile(AProject.FileName);
    Engine.ProcessRecentProject(AProject.FileName);
    Engine.UpdateState([ecsFolder, ecsChanged, ecsState, ecsRefresh]);
    Result := True;
    FIsChanged := False;
  end;
end;

function TEditorSession.Save: Boolean;
begin
  if Project <> nil then
    Result := Save(Project)
  else
    Result := False;
end;

function TEditorSession.SaveAs(AProject: TEditorProject): Boolean;
var
  aDialog: TSaveDialog;
begin
  aDialog := TSaveDialog.Create(nil);
  try
    aDialog.Title := 'Save project';
    aDialog.DefaultExt := Engine.Extenstion;
    aDialog.Filter := 'Project files (*.' + Engine.Extenstion + ')|*.' + Engine.Extenstion + '|All files|*.*';
    aDialog.InitialDir := Engine.BrowseFolder;
    aDialog.FileName := AProject.Name + aDialog.DefaultExt;
    Result := aDialog.Execute;
    if Result then
    begin
      AProject.FileName := aDialog.FileName;
      Save(AProject);
    end;
  finally
    aDialog.Free;
  end;
end;

function TEditorSession.SaveAs: Boolean;
begin
  if Project <> nil then
    Result := SaveAs(Project)
  else
    Result := False;
end;

function TEditorSession.GetRoot: string;
begin
  if IsOpened then
  begin
    if (Project.RootDir <> '') then
      Result := Engine.EnvReplace(Project.RootDir, 'root')
    else
      Result := ExtractFilePath(Project.FileName);
  end
  else if Engine.Files.Current <> nil then
    Result := ExtractFilePath(Engine.Files.Current.Name)
  else if Engine.BrowseFolder <> '' then
    Result := Engine.BrowseFolder
  else
    Result := Application.Location;
  Result := ExpandFileName(IncludePathSeparator(Result));
end;

procedure TEditorFiles.Prior;
var
  i: integer;
begin
  if Current <> nil then
  begin
    i := Current.Index - 1;
    if i < 0 then
      i := Count - 1;
    SetCurrentIndex(i, True);
  end;
end;

procedure TEditorEngine.ProcessRecentFile(const FileName: string);
var
  i: integer;
begin
  i := Options.RecentFiles.IndexOf(FileName);
  if i >= 0 then
    Options.RecentFiles.Move(i, 0)
  else
    Options.RecentFiles.Insert(0, FileName);
  while Options.RecentFiles.Count > 50 do
    Options.RecentFiles.Delete(50);
end;

procedure TEditorEngine.ProcessRecentProject(const FileName: string);
var
  i: integer;
begin
  i := Options.RecentProjects.IndexOf(FileName);
  if i >= 0 then
    Options.RecentProjects.Move(i, 0)
  else
    Options.RecentProjects.Insert(0, FileName);
  while Options.RecentProjects.Count > 50 do
    Options.RecentProjects.Delete(50);
end;

procedure TEditorEngine.ProcessProject(const FileName: string);
var
  i: integer;
begin
  i := Options.Projects.IndexOf(FileName);
  if i >= 0 then
    Options.Projects.Move(i, 0)
  else
    Options.Projects.Insert(0, FileName);
end;

procedure TEditorFiles.Save;
begin
  if Current <> nil then
    Current.SaveFile;
end;

procedure TEditorFiles.SaveAll;
var
  i: integer;
begin
  for i := 0 to Count - 1 do
  begin
    Items[i].SaveFile;
  end;
end;

procedure TEditorFiles.SaveAs;
begin
  if Current <> nil then
    Current.SaveFile(ExtractFileExt(Current.Name), True);
end;

procedure TEditorOptions.Save(vWorkspace: string);
begin
  if DirectoryExistsUTF8(vWorkspace) then
  begin
    Profile.SaveToFile(vWorkspace + 'mne-editor.xml');
    SaveToFile(vWorkspace + 'mne-options.xml');
    RecentFiles.SaveToFile(vWorkspace + 'mne-recent-files.ini');
    RecentProjects.SaveToFile(vWorkspace + 'mne-recent-projects.ini');
    Projects.SaveToFile(vWorkspace + 'mne-projects.ini');

    SearchHistory.SaveToFile(vWorkspace + 'mne-search-history.ini');
    ReplaceHistory.SaveToFile(vWorkspace + 'mne-replace-history.ini');
    SearchFolderHistory.SaveToFile(vWorkspace + 'mne-folder-history.ini');

    Engine.UpdateState([ecsFolder]);
  end;
end;

procedure TEditorFiles.SetCurrent(const Value: TEditorFile);
begin
  if FCurrent <> Value then
  begin
    FCurrent := Value;
    if not Engine.Updating then
      FCurrent.Show;
  end;
end;

procedure TEditorFiles.SetCurrentIndex(Index: integer; vRefresh: Boolean);
var
  aCurrent: TEditorFile;
begin
  if Count <> 0 then
  begin
    if Index >= Count then
      Index := Count - 1;
    aCurrent := Items[Index];
    if aCurrent <> nil then
    begin
      Current := aCurrent;
    end;
  end;
  if vRefresh then
    Engine.UpdateState([ecsState, ecsRefresh]);
end;

procedure TEditorSession.SetProject(const Value: TEditorProject);
begin
  if FProject <> Value then
  begin
    Engine.BeginUpdate;
    try
      if IsOpened then
        Close;
      FProject := Value;
      Changed;
      Engine.UpdateState([ecsChanged, ecsState, ecsRefresh, ecsProject, ecsProjectLoaded]);
    finally
      Engine.EndUpdate;
    end;
  end;
end;

procedure TEditorSession.SetProcess(AValue: TObject);
begin
  if FProcess =AValue then Exit;
  FProcess :=AValue;
end;

procedure TEditorOptions.Show;
var
  i: integer;
  aList: TList;
  aSelect: string;
begin
  with TEditorOptionsForm.Create(Application) do
  begin
    try
      if (Engine.Files.Current <> nil) then
        aSelect := Engine.Files.Current.GetLanguageName //just to select a language in the combobox
      else
        aSelect := '';
      if Execute(Profile, aSelect) then
        Apply;
      Engine.UpdateState([ecsOptions]);
    finally
      Free;
    end;
  end;
end;

procedure TEditorEngine.RemoveProject(const FileName: string);
var
  i: integer;
begin
  i := Options.Projects.IndexOf(FileName);
  if i >= 0 then
    Options.Projects.Delete(i);
end;

function SortGroupsByTitle(Item1, Item2: Pointer): Integer;
begin
  Result := CompareText(TFileGroup(Item1).Title, TFileGroup(Item2).Title);
end;

procedure TEditorEngine.Startup;
begin
  FIsEngineStart := True;
  LoadOptions;
  Groups.Sort(@SortGroupsByTitle);
  UpdateExtensionsCache;
end;

procedure TEditorEngine.LoadOptions;
var
  aFile: string;
  i: Integer;
begin
  Engine.BeginUpdate;
  try
    Options.Load(Workspace);
    Session.Options.SafeLoadFromFile(LowerCase(Workspace + 'mne-options-' + SysPlatform + '.xml'));
    for i := 0 to Tendencies.Count - 1 do
    begin
      if capOptions in Tendencies[i].Capabilities then
      begin
        if capOSDepended in Tendencies[i].Capabilities then
          aFile := LowerCase(Workspace + 'mne-tendency-' + SysPlatform + '-' + Tendencies[i].Name + '.xml')
        else
          aFile := LowerCase(Workspace + 'mne-tendency-' + Tendencies[i].Name + '.xml');
        if FileExists(aFile) then
          XMLReadObjectFile(Tendencies[i], aFile);
      end;
    end;
    SetDefaultTendency(Session.Options.DefaultTendency);
    SetDefaultSCM(Session.Options.DefaultSCM);
    Engine.UpdateState([ecsOptions]);
  finally
    Engine.EndUpdate;
  end;
end;

procedure TEditorEngine.SaveOptions;
var
  aFile: string;
  i: integer;
begin
  Options.Save(WorkSpace);
  Session.Options.SaveToFile(LowerCase(Workspace + 'mne-options-' + SysPlatform + '.xml'));

  for i := 0 to Tendencies.Count - 1 do
  begin
    if capOptions in Tendencies[i].Capabilities then
    begin
      if capOSDepended in Tendencies[i].Capabilities then
        aFile := LowerCase(Workspace + 'mne-tendency-' + SysPlatform + '-' + Tendencies[i].Name + '.xml')
      else
        aFile := LowerCase(Workspace + 'mne-tendency-' + Tendencies[i].Name + '.xml');
      XMLWriteObjectFile(Tendencies[i], aFile);
    end;
  end;
end;

procedure TEditorEngine.Shutdown;
begin
  if FIsEngineStart then
  begin
    SaveOptions;
  end;
  if Tendency.Debug <> nil then
    Tendency.Debug.Action(dbaStop);
  Files.Clear;
  FIsEngineShutdown := True;
end;

procedure TEditorEngine.RemoveRecentProject(const FileName: string);
var
  i: integer;
begin
  i := Options.RecentProjects.IndexOf(FileName);
  if i >= 0 then
    Options.RecentProjects.Delete(i);
end;

procedure TEditorEngine.RemoveRecentFile(const FileName: string);
var
  i: integer;
begin
  i := Options.RecentFiles.IndexOf(FileName);
  Options.RecentFiles.Delete(i);
end;

function TEditorEngine.GetUpdating: Boolean;
begin
  Result := FUpdateCount > 0;
end;

function TEditorEngine.EnvReplace(S: string; ForVar: string): string;
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Assign(Environment);
    if not SameText(ForVar, 'ROOT') then
      List.Add('ROOT=' + GetRoot)
    else
    begin
      if Session.IsOpened then
        List.Add('ROOT=' + ExtractFilePath(Session.Project.FileName))
      else
        List.Add('ROOT=' + Application.Location)
    end;

    if Session.IsOpened then
    begin
      List.Add('MAIN=' + Session.Project.Options.MainFile);
    end;

    if Files.Current <> nil then
      List.Add('FileDir=' + Files.Current.Path);
    Result := VarReplace(S, List, '?');
  finally
    List.Free;
  end;
end;

function TEditorEngine.ExpandFile(FileName: string): string;
begin
  Result := ExpandFileName(ExpandToPath(FileName, Session.GetRoot));
end;
{
procedure TEditorEngine.AddInstant(vName:string; vExtensions: array of string; vHighlighterClass: TSynCustomHighlighterClass; vKind: TFileCategoryKinds);
var
  aFC: TCustomFileCategory;
begin
  aFC := TCustomFileCategory.Create(vName);
  aFC.FHighlighterClass := vHighlighterClass;
  aFC.FKind := vKind;
  Categories.Add(aFC);
  Groups.Add(TFileGroup, TEditorFile, vExtensions[0], vName + ' files', vName, vExtensions, []);
end;
}
procedure TEditorEngine.SetDefaultTendency(vName: string);
var
  P: TEditorTendency;
begin
  P := Tendencies.Find(vName);
  if P = nil then
    P := FInternalTendency;
  DefaultTendency := P;
end;

procedure TEditorEngine.SetDefaultSCM(vName: string);
begin
  DefaultSCM := SourceManagements.Find(vName);
end;

function TEditorEngine.GetIsChanged: Boolean;
begin
  Result := (Files.GetEditedCount > 0) or Session.IsChanged;
end;

procedure TEditorEngine.SetNotifyEngine(ANotifyObject: INotifyEngine);
begin
  if (FNotifyObject <> nil) and (ANotifyObject <> nil) then
    raise Exception.Create('There is already NotifyObject');
  FNotifyObject := ANotifyObject;
end;

procedure TEditorEngine.RemoveNotifyEngine(ANotifyObject: INotifyEngine);
begin
  if FNotifyObject <> ANotifyObject then
    raise Exception.Create('NotifyObject not exists');
  FNotifyObject := nil; //TODO if list we should remove it
end;

procedure TEditorEngine.SendOutout(S: string);
begin
  if FNotifyObject <> nil then
    FNotifyObject.EngineOutput(S);
end;

procedure TEditorEngine.SendAction(EditorAction: TEditorAction);
begin
  if FNotifyObject <> nil then
    FNotifyObject.EngineAction(EditorAction);
end;

procedure TEditorEngine.DoChangedState(State: TEditorChangeStates);
begin
  if FNotifyObject <> nil then
    FNotifyObject.EditorChangeState(State);
end;

procedure TEditorEngine.UpdateState(State: TEditorChangeStates);
begin
  if Updating then
    FUpdateState := FUpdateState + State
  else //if (FInUpdateState = 0) or not (State in FUpdateState) then
    InternalChangedState(State);
end;

function TEditorFiles.LoadFile(vFileName: string; AppendToRecent: Boolean): TEditorFile;
begin
  Result := InternalOpenFile(vFileName, AppendToRecent);
  Engine.UpdateState([ecsChanged]);
  if Result <> nil then
    Current := Result;
  Engine.UpdateState([ecsState, ecsRefresh]);
end;

procedure TEditorFiles.Replace;
begin
  if Current <> nil then
    Current.Replace;
end;

procedure TEditorFiles.Revert;
begin
  if Current <> nil then
  begin
    if MsgBox.Msg.Yes('Revert file ' + Current.Name) then
      Current.Load(Current.Name);
  end;
end;

procedure TEditorEngine.SetBrowseFolder(const Value: string);
begin
  FBrowseFolder := Value;
  if FBrowseFolder <> '' then
    FBrowseFolder := IncludeTrailingPathDelimiter(FBrowseFolder);
  UpdateState([ecsFolder]);
end;

procedure TEditorEngine.DoMacroStateChange(Sender: TObject);
begin
  UpdateState([ecsState]);
end;

function TEditorEngine.GetWorkSpace: string;
begin
  Result := IncludeTrailingPathDelimiter(FWorkSpace);
end;

procedure TEditorEngine.SetDefaultTendency(AValue: TEditorTendency);
begin
  if FDefaultTendency = AValue then
    exit;
  FDefaultTendency := AValue;
  if FDefaultTendency <> nil then
    Session.Options.DefaultTendency := FDefaultTendency.Name;
  Engine.UpdateState([ecsChanged, ecsProject]);
end;

procedure TEditorEngine.SetDefaultSCM(AValue: TEditorSCM);
begin
  if FDefaultSCM =AValue then
    exit;
  FDefaultSCM :=AValue;
  if FDefaultSCM <> nil then
    Session.Options.DefaultSCM := FDefaultSCM.Name;
  Engine.UpdateState([ecsChanged, ecsProject]);
end;

procedure TEditorEngine.InternalChangedState(State: TEditorChangeStates);
begin
  Inc(FInUpdateState);
  try
    DoChangedState(State);
  finally
    Dec(FInUpdateState);
  end;
end;

{ TEditorFiles }

function TEditorFiles.GetItems(Index: integer): TEditorFile;
begin
  Result := inherited Items[Index] as TEditorFile;
end;

function TEditorFiles.IsExist(vName: string): Boolean;
begin
  Result := FindFile(vName) <> nil;
end;

function TEditorFiles.SetActiveFile(FileName: string): TEditorFile;
begin
  Result := FindFile(FileName);
  if Result <> nil then
    Current := Result;
end;

destructor TEditorFiles.Destroy;
begin
  inherited;
end;

function TEditorFiles.ShowFile(vFileName: string): TEditorFile;
begin
  Result := InternalOpenFile(vFileName, False);
  Engine.UpdateState([ecsChanged]);
  if Result <> nil then
    Current := Result;
  Engine.UpdateState([ecsState, ecsRefresh]);
end;

procedure TEditorFiles.Refresh;
begin
  if Current <> nil then
    Current.Refresh;
end;

function TEditorFiles.ShowFile(const FileName: string; Line: integer): TEditorFile;
begin
  Result := InternalOpenFile(FileName, False);
  Result.SetLine(Line);
  Engine.UpdateState([ecsChanged]);
  if Result <> nil then
    Current := Result;
  Engine.UpdateState([ecsState, ecsRefresh]);
end;

{ TEditorFile }

procedure TEditorFile.Edit;
begin
  if not IsReadOnly then
    IsEdited := True;
end;

procedure TEditorFile.Close;
var
  aParent: TEditorEngine;
  i: integer;
  mr: TmsgChoice;
begin
  if IsEdited then
  begin
    mr := MsgBox.Msg.YesNoCancel('Save file ' + Name + ' before close?');
    if mr = msgcCancel then
      Abort
    else if mr = msgcYes then
      SaveFile;
  end;

  i := Index;
  aParent := Engine;
  if aParent.Files.FCurrent = self then
    aParent.Files.FCurrent := nil;
  Free;
  aParent.Files.SetCurrentIndex(i, False);
  aParent.UpdateState([ecsChanged, ecsState, ecsRefresh]);
end;

procedure TEditorFile.OpenInclude;
begin
end;

function TEditorFile.CanOpenInclude: Boolean;
begin
  Result := False;
end;

constructor TEditorFile.Create(ACollection: TCollection);
begin
  inherited;
  FIsNew := True;
  FIsEdited := False;
end;

destructor TEditorFile.Destroy;
begin
  inherited;
end;

procedure TEditorFile.Assign(Source: TPersistent);
begin
end;

procedure TEditorFile.AssignTo(Dest: TPersistent);
begin
end;

procedure TEditorFile.DoEdit(Sender: TObject);
begin
  Edit;
  Engine.Files.Edited;
end;

procedure TEditorFile.Load(FileName: string);
begin
  FileName := ExpandFileName(FileName);
  DoLoad(FileName);
  Name := FileName;
  IsEdited := False;
  IsNew := False;
  UpdateAge;
end;

procedure SaveAsMode(const FileName: string; Mode: TEditorFileMode; Strings: TStrings);
var
  aStream: TFileStream;
begin
  aStream := TFileStream.Create(FileName, fmCreate);
  try
    case Mode of
      efmWindows: SaveAsWindows(Strings, aStream);
      efmMac: SaveAsMac(Strings, aStream);
      else
        SaveAsUnix(Strings, aStream);
    end;
  finally
    aStream.Free;
  end;
end;

procedure TEditorFile.Save(FileName: string);
begin
  DoSave(FileName);
  Name := FileName;
  IsEdited := False;
  IsNew := False;
  Engine.UpdateState([ecsFolder]);
  UpdateAge;
end;

procedure TEditorFile.Rename(ToNakeName: string);
var
  p: string;
begin
  Engine.BeginUpdate;
  try
    if Name <> '' then
    begin
      p := ExtractFilePath(Name);
      if RenameFileUTF8(Name, p + ToNakeName) then
      begin
        Engine.RemoveRecentFile(Name);
        Name := p + ToNakeName;
        Engine.ProcessRecentFile(Name);
      end;
    end
    else
      Name := ToNakeName;
    Engine.UpdateState([ecsRefresh, ecsFolder, ecsState, ecsChanged]);
  finally
    Engine.EndUpdate;
  end;
end;

procedure TEditorFile.Delete;
var
  p: string;
begin
  Engine.BeginUpdate;
  try
    if Name <> '' then
    begin
      if DeleteFileUTF8(Name) then
      begin
        Engine.RemoveRecentFile(Name);
        Name := ExtractFileName(Name);
        IsNew := True;
        IsEdited := True;
      end;
    end;
    Engine.UpdateState([ecsRefresh, ecsFolder, ecsState, ecsChanged]);
  finally
    Engine.EndUpdate;
  end;
end;

procedure TEditorFile.SetIsEdited(const Value: Boolean);
begin
  FIsEdited := Value;
end;

procedure TEditorFile.Show;
begin
  if Control <> nil then
  begin
    Control.Align := alClient;
    Control.Realign;
    Control.Visible := True;
    Control.Show;
    Control.BringToFront;
    Activate;
  end;
end;

procedure TEditorFile.SaveFile(Extension:string; AsNewFile: Boolean);
var
  aDialog: TSaveDialog;
  aSave, DoRecent: Boolean;
  aName: string;
begin
  DoRecent := False;
  aName := '';
  if IsNew or (FName = '') or AsNewFile then
  begin
    aDialog := TSaveDialog.Create(nil);
    aDialog.Title := 'Save file';
    aDialog.Filter := Engine.Groups.CreateFilter(True, Extension, Group, False);//put the group of file as the first one
    aDialog.InitialDir := Engine.BrowseFolder;
    if Extension <> '' then
      aDialog.DefaultExt := Extension
    else
    begin
      if Group <> nil then
        aDialog.DefaultExt := Group.Extensions[0]
      else
        aDialog.DefaultExt := Engine.Tendency.GetDefaultGroup.Extensions[0];
    end;
    aDialog.FileName := '*' + aDialog.DefaultExt;

    aSave := aDialog.Execute;
    if aSave then
    begin
      aName := aDialog.FileName;
      DoRecent := True;
    end;
    aDialog.Free;
  end
  else
  begin
    aName := FName;
    aSave := True;
  end;

  if aSave then
  begin
    Save(aName);
    FName := aName;
    if DoRecent then
    begin
      Engine.ProcessRecentFile(aName);
      Engine.UpdateState([ecsRefresh, ecsState, ecsChanged]);
    end
    else
      Engine.UpdateState([ecsState, ecsRefresh]);
  end;
end;

function TEditorFile.CheckChanged: Boolean;
var
  mr: TmsgChoice;
  n: Integer;
begin
  Result := True;
  if not IsNew then
  begin
    if (FileExists(Name)) then
    begin
      if ((FFileAge <> FileAge(Name)) or (FFileSize <> FileSize(Name)))  then
      begin
        mr := MsgBox.Msg.YesNoCancel(Name + #13' was changed, update it?');
        if mr = msgcYes then
          Reload;
        if mr = msgcCancel then
          Result := False
        else
          UpdateAge;
      end;
    end
    else
    begin
      n := MsgBox.Msg.Ask(Name + #13' was not found, what do want?', [Choice('&Keep It', msgcYes), Choice('&Close', msgcCancel), Choice('Read only', msgcNo)], 0, 2);
      if n = 0 then //Keep It
        IsNew := True
      else if n = 2 then //Keep It
      begin
        IsEdited := False;
        IsReadOnly := True
      end
      else
        Close;
    end;
  end;
end;

procedure TEditorFile.Activate;
var
  aControl: TWinControl;
begin
  if Control.CanFocus then
  begin
    if Supports(Control, IEditorControl) then
      aControl := (Control as IEditorControl).GetMainControl
    else
      aControl := nil;

    if aControl = nil then
      aControl := Control as TWinControl;

    (Engine.Container.Owner as TCustomForm).ActiveControl := aControl;
  end;
end;

procedure TEditorFile.GotoLine;
begin
end;

procedure TEditorFile.Find;
begin
end;

procedure TEditorFile.FindNext;
begin
end;

procedure TEditorFile.FindPrevious;
begin
end;

procedure TEditorFile.Replace;
begin
end;

procedure TEditorFile.Refresh;
begin
end;

function TEditorFile.GetHint(HintControl: TControl; CursorPos: TPoint; out vHint: string): Boolean;
begin
  Result := False;
end;

function TEditorFile.GetGlance: string;
begin
  Result := '';
end;

function TEditorFile.GetLanguageName: string;
begin
  Result := '';
end;

procedure TEditorFile.SetLine(Line: Integer);
begin

end;

function TEditorFile.CanCopy: Boolean;
begin
  Result := ecpAllowCopy in Capability;
end;

function TEditorFile.CanPaste: Boolean;
begin
  Result := ecpAllowPaste in Capability
end;

procedure TEditorFile.Paste;
begin
end;

procedure TEditorFile.Copy;
begin
end;

procedure TEditorFile.Cut;
begin
end;

procedure TEditorFile.SelectAll;
begin
end;

procedure TEditorFile.UpdateAge;
begin
  FFileAge := FileAge(Name);
  FFileSize := FileSize(Name);
end;

procedure TEditorFile.Reload;
begin
  Load(Name);
end;

procedure TEditorFile.SetGroup(const Value: TFileGroup);
begin
  if FGroup <> Value then
  begin
    FGroup := Value;
    GroupChanged;
  end;
end;

function TEditorFile.GetCapability: TEditCapability;
begin
  Result := [];
end;

function TEditorFile.GetIsText: Boolean;
begin
  Result := (Group <> nil) and Group.Category.IsText;
end;

function TEditorFile.GetNakeName: string;
begin
  Result := ExtractFileName(Name);
end;

function TEditorFile.GetPath: string;
begin
  Result := ExtractFilePath(Name);
end;

function TEditorFile.GetControl: TWinControl;
begin
  Result := nil;
end;

procedure TEditorFile.DoGetCapability(var vCapability: TEditCapability);
begin
  vCapability := [];
end;

function TEditorFile.GetIsReadonly: Boolean;
begin
  Result := False;//TODO true
end;

procedure TEditorFile.SetIsNew(AValue: Boolean);
begin
  if FIsNew =AValue then
    Exit;
  FIsNew :=AValue;
end;

procedure TEditorFile.SetIsReadonly(const Value: Boolean);
begin
end;

procedure TEditorFile.NewContent;
begin
end;

function DetectFileMode(const Contents: string): TEditorFileMode;
var
  i: integer;
begin
  Result := efmUnix;
  for i := 1 to Length(Contents) do
  begin
    if Contents[i] = #$D then
    begin
      if (i < Length(Contents) - 1) and (Contents[i + 1] = #$A) then
        Result := efmWindows
      else
        Result := efmMac;
      break;
    end
    else if Contents[i] = #$A then
    begin
      Result := efmUnix;
      break;
    end;
  end;
end;

function ChangeTabsToSpace(const Contents: string; TabWidth: integer): string;
var
  p, l: integer;

  procedure ScanToEOL;
  var
    i: integer;
  begin
    i := p;
    while i <= l do
    begin
      if Contents[i] in [#13, #10] then
        break;
      Inc(i);
    end;
    if ((i + 1) <= l) and (Contents[i + 1] in [#13, #10]) then
      Inc(i);
    Result := Result + Copy(Contents, p, i - p + 1);
    p := i + 1;
  end;

  procedure ScanSpaces;
  var
    i, c: integer;
  begin
    i := p;
    c := 0;
    while i <= l do
    begin
      if Contents[i] = ' ' then
        c := c + 1
      else if Contents[i] = #9 then
        c := c + TabWidth
      else
        break;
      Inc(i);
    end;
    Result := Result + RepeatString(' ', c);
    p := i;
  end;

begin
  p := 1;
  l := Length(Contents);
  while p <= l do
  begin
    ScanSpaces;
    ScanToEOL;
  end;
end;

function TEditorFile.GetModeAsText: string;
begin
  case Mode of
    efmUnix: Result := 'Unix';
    efmWindows: Result := 'Windows';
    efmMac: Result := 'Mac';
  end;
end;

procedure TEditorFile.SetMode(const Value: TEditorFileMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    Edit;
    Engine.UpdateState([ecsState, ecsRefresh]);
  end;
end;

procedure TEditorFile.GroupChanged;
begin
end;

procedure TEditorFile.DoStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  if ([scReadOnly, scCaretX, scCaretY, scLeftChar, scTopLine, scSelection] * Changes) <> [] then
    Engine.UpdateState([ecsState]);
end;

{ TEditorOptions }

constructor TEditorOptions.Create;
begin
  inherited Create;
  FSearchHistory := TStringList.Create;
  FReplaceHistory := TStringList.Create;
  FSearchFolderHistory := TStringList.Create;
  FProfile := TEditorProfile.Create;
  FExtraExtensions := TStringList.Create;
  FRecentFiles := TStringList.Create;
  FRecentProjects := TStringList.Create;
  FProjects := TStringList.Create;
  FShowFolder := True;
  FSortFolderFiles := srtfByNames;
  FShowMessages := False;
  FCollectTimeout := 60;
  FOutputHeight := 100;
  FMessagesHeight := 100;
  FFoldersWidth := 180;
end;

destructor TEditorOptions.Destroy;
begin
  FSearchHistory.Free;
  FReplaceHistory.Free;
  FSearchFolderHistory.Free;
  FExtraExtensions.Free;
  FProfile.Free;
  FRecentFiles.Free;
  FRecentProjects.Free;
  FProjects.Free;
  inherited;
end;

procedure TEditorOptions.SetProjects(const Value: TStringList);
begin
  if FProjects <> Value then
    FProjects.Assign(Value);
end;

procedure TEditorOptions.SetRecentFiles(const Value: TStringList);
begin
  if FRecentFiles <> Value then
    FRecentFiles.Assign(Value);
end;

procedure TEditorOptions.SetRecentProjects(const Value: TStringList);
begin
  if FRecentProjects <> Value then
    FRecentProjects.Assign(Value);
end;

{ TFileCategories }

function TFileGroups.CreateFilter(FullFilter:Boolean; FirstExtension: string; vGroup: TFileGroup; OnlyThisGroup: Boolean): string;
var
  aSupported: string;
  procedure AddIt(AGroup: TFileGroup);
  var
    i, n: integer;
    s: string;
    AExtensions: TStringList;
  begin
    if fgkBrowsable in AGroup.Kind then
    begin
      if FullFilter then
        if Result <> '' then
          Result := Result + '|';
      s := '';
      AExtensions := TStringList.Create;
      try
        AGroup.EnumExtensions(AExtensions);
        if (AGroup = vGroup) and (FirstExtension <> '') then
        begin
          if AExtensions.Find(FirstExtension, n) then
            AExtensions.Move(n, 0);
        end;

        for i := 0 to AExtensions.Count - 1 do
        begin
          if s <> '' then
            s := s + ';';
          s := s + '*.' + AExtensions[i];
          if aSupported <> '' then
            aSupported := aSupported + ';';
          aSupported := aSupported + '*.' + AExtensions[i];
        end;
        if FullFilter then
          Result := Result + AGroup.Title + ' (' + s + ')|' + s;
      finally
        AExtensions.Free;
      end;
    end;
  end;
var
  i: integer;
  s: string;
  aDefaultGroup: TFileGroup;
begin
  aSupported := '';
  if LeftStr(FirstExtension, 1) = '.' then
    FirstExtension := MidStr(FirstExtension, 2, MaxInt);
  if (vGroup <> nil) and OnlyThisGroup then
    AddIt(vGroup)
  else
  begin
    if vGroup <> nil then
      aDefaultGroup := vGroup
    else
      aDefaultGroup := Engine.Tendency.GetDefaultGroup;
    AddIt(aDefaultGroup);
    for i := 0 to Count - 1 do
    begin
      if (Items[i] <> aDefaultGroup) then
        AddIt(Items[i]);
    end;
  end;

  if FullFilter then
  begin
    if Result <> '' then
      Result := 'All files (' + aSupported + ')|' + aSupported + '|' + Result;

    if Result <> '' then
      Result := Result + '|';
    Result := Result + 'Any file (*.*)|*.*';
  end
  else
    Result := aSupported;
end;

procedure TFileGroups.Add(vGroup: TFileGroup);
begin
  inherited Add(vGroup);
end;

function TFileCategories.Find(vName: string): TFileCategory;
var
  i: integer;
begin
  Result := nil;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := Items[i];
        break;
      end;
    end;
end;

function TFileCategories.Add(vFileCategory: TFileCategory): Integer;
begin
  Result := inherited Add(vFileCategory);
end;

function TFileGroups.FindExtension(vExtension: string): TFileGroup;
var
  i, j: integer;
  AExtensions: TStringList;
begin
  Result := nil;
  if LeftStr(vExtension, 1) = '.' then
    vExtension := Copy(vExtension, 2, MaxInt);
  if vExtension <> '' then
  begin
    AExtensions := TStringList.Create;
    try
      for i := 0 to Count - 1 do
      begin
        AExtensions.Clear;
        Items[i].EnumExtensions(AExtensions);
        for j := 0 to AExtensions.Count - 1 do
        begin
          if SameText(AExtensions[j], vExtension) then
          begin
            Result := Items[i];
            break;
          end;
        end;
      end;
    finally
      AExtensions.Free;
    end;
  end;
end;

function TFileCategories.GetItem(Index: integer): TFileCategory;
begin
  Result := inherited Items[Index] as TFileCategory;
end;

procedure TFileCategories.SetItem(Index: integer; AObject: TFileCategory);
begin
  inherited Items[Index] := AObject;
end;

{ TFileCategory }

constructor TFileCategory.Create(const vName: string; vKind: TFileCategoryKinds);
begin
  inherited Create(False);//childs is groups and already added to Groups and freed by it
  FName := vName;
  FKind := vKind;
end;

procedure TFileCategory.EnumExtensions(vExtensions: TStringList);
var
  i: Integer;
begin
  for i  := 0 to Count - 1 do
  begin
    Items[i].EnumExtensions(vExtensions);
  end;
end;

procedure TFileCategory.Apply(AHighlighter: TSynCustomHighlighter; Attributes: TGlobalAttributes);
var
  i, a: Integer;
  M: TMap;
  G: TGlobalAttribute;
  Att: TSynHighlighterAttributes;
begin
  for i := 0 to AHighlighter.AttrCount -1 do
  begin
    Att := AHighlighter.Attribute[i];
    G := nil;

    M := Mapper.Find(Att.Name);
    if M <> nil then
      G := Attributes.Find(M.AttType);

    if M <> nil then
      G := Attributes.Find(M.AttType);

    if G = nil then
      G := Attributes.Whitespace;

    Att.Background := G.Background;
    Att.Foreground := G.Foreground;
    Att.Style := G.Style;
  end;
end;

procedure TFileCategory.InitCompletion(vSynEdit: TCustomSynEdit);
begin
end;

procedure TFileCategory.InitEdit(vSynEdit: TCustomSynEdit);
begin
end;

destructor TFileCategory.Destroy;
begin
  FreeAndNil(FMapper);
  FreeAndNil(FCompletion);
  FreeAndNil(FHighlighter);
  inherited;
end;

function TFileCategory.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := DoCreateHighlighter;
end;

procedure TFileCategory.InitHighlighter;
var
  i: integer;
begin
  if FHighlighter = nil then
  begin
    FHighlighter := CreateHighlighter; //CreateHighlighter maybe return nil so check it again
    if FHighlighter <> nil then
    begin
      for i := 0 to FHighlighter.DividerDrawConfigCount - 1 do
        FHighlighter.DividerDrawConfig[i].MaxDrawDepth := 0;

      if FMapper = nil then
      begin
        FMapper := TMapper.Create;
        InitMappers;
        if FHighlighter.AttrCount <> Mapper.Count then
          raise Exception.Create('Mapper count not equal to AttrCount for: ' + FHighlighter.ClassName);
      end;
      Apply(FHighlighter, Engine.Options.Profile.Attributes);
    end;
  end;
end;

function TFileCategory.Find(vName: string): TFileGroup;
begin
  Result := inherited Find(vName) as TFileGroup;
end;

function TFileCategory.GetItem(Index: Integer): TFileGroup;
begin
  Result := inherited Items[Index] as TFileGroup;
end;

function TFileCategory.GetMapper: TMapper;
begin
  Result := FMapper;
  if FMapper = nil then
    raise Exception.Create('Mapper is null');
end;

function TFileCategory.GetHighlighter: TSynCustomHighlighter;
begin
  InitHighlighter;
  Result := FHighlighter;
end;

function TFileCategory.GetIsText: Boolean;
begin
  Result := True;
end;

procedure TFileCategory.DoExecuteCompletion(Sender: TObject);
begin
end;

{ TEditorProject }

constructor TEditorProject.Create;
begin
  inherited Create;
  FDesktop := TEditorDesktop.Create;
  FSaveDesktop := True;
end;

destructor TEditorProject.Destroy;
begin
  FDesktop.Free;
  FreeAndNil(FOptions);
  inherited;
end;

procedure TEditorProject.LoadFromFile(FileName: string);
begin
  FFileName := FileName;
  inherited LoadFromFile(FileName);
end;

procedure TEditorProject.SetTendencyName(AValue: string);
var
  aTendency: TEditorTendency;
begin
  FTendencyName := AValue;

  aTendency := Engine.Tendencies.Find(TendencyName);
  if aTendency = nil then
    aTendency := Engine.DefaultTendency;

  Tendency := aTendency;

  Engine.UpdateState([ecsChanged, ecsProject]); //TODO move to caller
end;

procedure TEditorProject.SetTendency(AValue: TEditorTendency);
begin
  if FTendency <> AValue then
  begin
    FTendency := AValue;
    FOptions.Free;
    FOptions := FTendency.CreateOptions;
  end;
end;

procedure TEditorProject.SetRootDir(AValue: string);
begin
  if FRootDir <> AValue then
    FRootDir := AValue;
end;

procedure TEditorProject.SetSCM(AValue: TEditorSCM);
begin
  if FSCM =AValue then exit;
  FreeAndNil(FSCM);
  FSCM :=AValue;
  Engine.UpdateState([ecsChanged, ecsProject]);
end;

procedure TEditorProject.RttiCreateObject(var vObject: TObject; vInstance: TObject; vObjectClass:TClass; const vClassName, vName: string);
begin
  inherited;
  if vObjectClass.InheritsFrom(vObjectClass) then
    vObject := TEditorSCMClass(vObjectClass).Create;
end;

procedure TEditorProject.Loaded(Failed: Boolean);
begin
  inherited;
  if not Failed and FSaveDesktop then
    Desktop.Load;
end;

procedure TEditorProject.SetSCMClass(SCMClass: TEditorSCM);
begin
  if (SCMClass = nil) or not((SCM <> nil) and (SCM.ClassType = SCMClass.ClassType)) then
    SCM := nil;
  if (SCMClass <> nil) then
    SCM := TEditorSCMClass(SCMClass.ClassType).Create;
end;

procedure TEditorProject.Saving;
begin
  inherited;
  if FSaveDesktop then
    Desktop.Save;
end;

{ TFileGroup }

procedure TFileGroup.SetCategory(AValue: TFileCategory);
begin
  if FCategory <> AValue then
  begin
    if FCategory <> nil then
      FCategory.Extract(Self);
    FCategory :=AValue;
    if FCategory <> nil then
      FCategory.Add(Self);
  end;
end;

constructor TFileGroup.Create;
begin
  inherited;
  FExtensions := TStringList.Create;
  FKind := [fgkBrowsable];
end;

procedure TFileGroup.EnumExtensions(vExtensions: TStringList; Kind: TFileGroupKinds);
  procedure AddIt(E: string);
  begin
    if vExtensions.IndexOf(E) < 0 then
      vExtensions.Add(E);
  end;

  procedure AddStrings(E: TStringList);
  var
    i: Integer;
  begin
    for i := 0 to E.Count -1 do
      AddIt(E[i]);
  end;
var
  s: string;
  lStrings:TStringList;
begin
  vExtensions.BeginUpdate;
  try
    AddStrings(Extensions);
    s := Engine.Options.ExtraExtensions.Values[Name];
    if s <> '' then
    begin
      lStrings := TStringList.Create;
      try
        StrToStrings(s, lStrings, [';'], [' ']);
        AddStrings(lStrings);
      finally
        lStrings.Free;
      end;
    end;
  finally
    vExtensions.EndUpdate;
  end;
end;

procedure TFileGroup.EnumExtensions(vExtensions: TEditorElements);
var
  lList:TStringList;
  i: Integer;
  lItem: TEditorElement;
begin
  lList := TStringList.Create;
  try
    EnumExtensions(lList);
    for i := 0 to lList.Count -1 do
    begin
      lItem := TEditorElement.Create;
      lItem.Name := lList[i];
      lItem.Title := lList[i];
      lItem.Description := Title;
      vExtensions.Add(lItem);
    end;
  finally
    lList.Free;
  end;
end;

destructor TFileGroup.Destroy;
begin
  FExtensions.Free;
  inherited;
end;

function TFileGroup.CreateEditorFile(vFiles: TEditorFiles): TEditorFile;
begin
  Result := FFileClass.Create(vFiles);
end;

{ TFileGroups }

procedure TFileGroups.Add(GroupClass: TFileGroupClass; FileClass: TEditorFileClass; const Name, Title:string; Category: string; Extensions: array of string; Kind: TFileGroupKinds; Style: TFileGroupStyles);
var
  aCategory: TFileCategory;
  aGroup: TFileGroup;
  i: integer;
begin
  aCategory := Engine.Categories.Find(Category);
  if aCategory = nil then
    raise Exception.Create('Can not find category ' + Category);
  aGroup:= Find(Name);
  if aGroup <> nil then
    raise Exception.Create(Name + ' already exists');
  aGroup := GroupClass.Create;
  aGroup.FFileClass := FileClass;
  aGroup.FTitle := Title;
  aGroup.FName := Name;
  aGroup.FKind := Kind;
  aGroup.FStyle := Style;
  for i := 0 to Length(Extensions) - 1 do
    aGroup.Extensions.Add(Extensions[i]);
  aGroup.Category := aCategory;
  inherited Add(aGroup);
end;

procedure TFileGroups.Add(FileClass: TEditorFileClass; const Name, Title: string; Category: string; Extensions: array of string; Kind: TFileGroupKinds; Style: TFileGroupStyles);
begin
  Add(TFileGroup, FileClass, Name, Title, Category, Extensions, Kind, Style);
end;

function TFileGroups.Find(vName: string): TFileGroup;
begin
  Result := inherited Find(vName) as TFileGroup;
end;

function TFileGroups.Find(vName, vCategory: string): TFileGroup;
var
  i: integer;
begin
  Result := nil;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) and (Items[i].Category.Name = vCategory) then
      begin
        Result := Items[i];
        break;
      end;
    end;
end;

function TFileGroups.GetItem(Index: integer): TFileGroup;
begin
  Result := inherited Items[Index] as TFileGroup;
end;

destructor TEditorSession.Destroy;
begin
  Run.Stop;
  FreeAndNil(FRun);
  if (FProject <> nil) and (FProject.FileName <> '') then
    Save;
  FProject := nil;
  FreeAndNil(FOptions);
  FCachedVariables.Free;
  FCachedIdentifiers.Free;
  inherited;
end;

procedure TEditorSession.Changed;
begin
  FIsChanged := True;
  Engine.UpdateState([ecsChanged, ecsState, ecsRefresh, ecsProject]);
end;

function TEditorSession.GetIsOpened: Boolean;
begin
  Result := FProject <> nil;
end;

procedure TEditorSession.SetRun(AValue: TmneRun);
begin
  if FRun =AValue then Exit;
  FRun :=AValue;
end;

constructor TEditorSession.Create;
begin
  inherited;
  FOptions := TEditorSessionOptions.Create;
  FRun := TmneRun.Create;
  FCachedVariables := THashedStringList.Create;
  FCachedIdentifiers := THashedStringList.Create;
end;

procedure TFileGroups.EnumExtensions(vExtensions: TStringList; Kind: TFileGroupKinds);
var
  i: integer;
begin
  for i := 0 to Count - 1 do
  begin
    if (Kind = []) or (Items[i].Kind = Kind) then
      Items[i].EnumExtensions(vExtensions);
  end;
end;

procedure TFileGroups.EnumExtensions(vExtensions: TEditorElements);
var
  i: integer;
begin
  for i := 0 to Count - 1 do
  begin
    Items[i].EnumExtensions(vExtensions);
  end;
end;

{ TEditorDesktopFiles }

function TEditorDesktopFiles.Add(FileName: string): TEditorDesktopFile;
begin
  Result := inherited Add as TEditorDesktopFile;
  Result.FileName := FileName;
end;

function TEditorDesktopFiles.Find(vName: string): TEditorDesktopFile;
var
  i: integer;
begin
  Result := nil;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].FileName, vName) then
      begin
        Result := Items[i] as TEditorDesktopFile;
        break;
      end;
    end;
end;

function TEditorDesktopFiles.GetItems(Index: integer): TEditorDesktopFile;
begin
  Result := inherited Items[Index] as TEditorDesktopFile;
end;

function TEditorDesktopFiles.IsExist(vName: string): Boolean;
begin
  Result := Find(vName) <> nil;
end;

{ TDebugSupportPlugin }

type
  THackSynEdit = class(TCustomSynEdit);

procedure CenterRect(var R1: TRect; R2: TRect);//from posDraws
begin
  OffsetRect(R1, ((R2.Right - R2.Left) div 2) - ((R1.Right - R1.Left) div 2) + (R2.Left - R1.Left), ((R2.Bottom - R2.Top) div 2) - ((R1.Bottom - R1.Top) div 2) + (R2.Top - R1.Top));
end;

procedure TSynDebugMarksPart.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
var
  i, x, y, lh, iw, el: integer;
  aLine: integer;
  aRect: TRect;

  procedure DrawIndicator(Line: integer; ImageIndex: integer);
  var
    r: TRect;
  begin
    Line := TSynEdit(SynEdit).RowToScreenRow(Line);
    if (Line >= FirstLine) and (Line <= LastLine) then
    begin
      aRect := AClip;
      aRect.Top := Line * lh;
      aRect.Bottom := aRect.Top + lh;
      r := aRect;
      r.Right := r.Left + iw;
      CenterRect(r, aRect);
      //todo center the rect by image size
      EditorResource.DebugImages.Draw(Canvas, r.Left, r.Top, ImageIndex);
    end;
  end;

begin
  //inherited;
  if Engine.Tendency.Debug <> nil then
  begin
    lh := TSynEdit(SynEdit).LineHeight;
    iw := EditorResource.DebugImages.Width;

    Engine.Tendency.Debug.Lock;
    try
      for i := 0 to Engine.Tendency.Debug.Breakpoints.Count - 1 do
      begin
        if SameText(Engine.Tendency.Debug.Breakpoints[i].FileName, FEditorFile.Name) then//need improve
          DrawIndicator(Engine.Tendency.Debug.Breakpoints[i].Line, DEBUG_IMAGE_BREAKPOINT);
      end;
    finally
      Engine.Tendency.Debug.Unlock;
    end;

    if (Engine.Tendency.Debug.ExecutedControl = SynEdit) and (Engine.Tendency.Debug.ExecutedLine >= 0) then
      DrawIndicator(Engine.Tendency.Debug.ExecutedLine, DEBUG_IMAGE_EXECUTE);
  end;
end;

{ TEditorDesktop }

constructor TEditorDesktop.Create;
begin
  FFiles := TEditorDesktopFiles.Create(TEditorDesktopFile);
  inherited;
end;

destructor TEditorDesktop.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TEditorDesktop.Load;
var
  i: integer;
  aItem: TEditorDesktopFile;
  aFile: TEditorFile;
begin
  Engine.BeginUpdate;
  try
    if Engine.Tendency.Debug <> nil then
    begin
      Engine.Tendency.Debug.Lock;
      try
  {      Engine.Tendency.Debug.BreakpointsClear;
        for i := 0 to Breakpoints.Count - 1 do
        begin
          Engine.Tendency.Debug.Breakpoints.Add(Breakpoints[i].FileName, Breakpoints[i].Line);
        end;

        Engine.Tendency.Debug.Watches.Clear;
        for i := 0 to Watches.Count - 1 do
        begin
          Engine.Tendency.Debug.Watches.Add(Watches[i].VariableName, Watches[i].Value);
        end;}
      finally
        Engine.Tendency.Debug.Unlock;
      end;
      Engine.UpdateState([ecsDebug]);
    end;

    Engine.Files.CloseAll;
    for i := 0 to Files.Count - 1 do
    begin
      aItem := Files[i];
      if FileExists(aItem.FileName) then
      begin
        aFile := Engine.Files.LoadFile(aItem.FileName, False);
        if aFile <> nil then
        begin
          aFile.Assign(aItem);
        end;
      end;
    end;
    Engine.Files.SetActiveFile(Files.CurrentFile);
    Engine.BrowseFolder := Files.CurrentFolder;
  finally
    Engine.EndUpdate;
    Files.Clear;
  end;
end;

procedure TEditorDesktop.Save;
var
  i: integer;
  aItem: TEditorDesktopFile;
  aFile: TEditorFile;
begin
{  Breakpoints.Clear;
  Watches.Clear;
  Engine.Tendency.Debug.Lock;
  try
    for i := 0 to Engine.Tendency.Debug.Breakpoints.Count - 1 do
    begin
      Breakpoints.Add(Engine.Tendency.Debug.Breakpoints[i].FileName, Engine.Tendency.Debug.Breakpoints[i].Line);
    end;

    for i := 0 to Engine.Tendency.Debug.Watches.Count - 1 do
    begin
      Watches.Add(Engine.Tendency.Debug.Watches[i].VariableName, Engine.Tendency.Debug.Watches[i].Value);
    end;
  finally
    Engine.Tendency.Debug.Unlock;
  end;}

  Files.CurrentFolder := Engine.BrowseFolder;
  Files.Clear;

  if Engine.Files.Current <> nil then
    Files.CurrentFile := Engine.Files.Current.Name
  else
    Files.CurrentFile := '';

  for i := 0 to Engine.Files.Count - 1 do
  begin
    aFile := Engine.Files[i];
    aItem := Files.Add(aFile.Name);
    aFile.AssignTo(aItem);
  end;
end;

{ TEditorMessages }

function TEditorMessages.GetItem(Index: integer): TEditorMessage;
begin
  Result := inherited Items[Index] as TEditorMessage;
end;

function TEditorMessages.GetText(Index: integer): string;
begin
  if Index < Count then
    Result := Items[Index].Text
  else
    Result := '';
end;

procedure TEditorMessages.SetItem(Index: integer; const Value: TEditorMessage);
begin
  inherited Items[Index] := Value;
end;

{ TEditorMessagesList }

function TEditorMessagesList.GetItem(Index: integer): TEditorMessages;
begin
  Result := inherited Items[Index] as TEditorMessages;
end;

function TEditorMessagesList.GetMessages(Name: string): TEditorMessages;
begin
  Result := Find(Name);
  if Result = nil then
  begin
    Result := TEditorMessages.Create;
    Result.Name := Name;
  end;
  Add(Result);
end;

procedure TEditorMessagesList.SetItem(Index: integer; const Value: TEditorMessages);
begin
  inherited Items[Index] := Value;
end;

function TEditorMessagesList.Find(Name: string): TEditorMessages;
var
  i: integer;
begin
  Result := nil;
  if Name <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, Name) then
      begin
        Result := Items[i];
        break;
      end;
    end;
end;

finalization
  FreeAndNil(FEngine);
end.
