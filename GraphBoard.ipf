#pragma ModuleName = GraphBoard

static constant TRUE = 1
static constant FALSE = 0


Menu "Misc"
	"GraphBoard", /Q, NewGraphBoard()
End

//------------------------------------------------------------------------------
// Panel building
//------------------------------------------------------------------------------

Function NewGraphBoard()
	Variable monWidth  = MinimumMonitorSize("width")
	Variable monHeight = MinimumMonitorSize("height")

	// Make a GraphBoard window (singleton)
	if(strlen(WinList("GraphBoard", ";", "WIN:64")))
		KillWindow GraphBoard
	endif
	NewPanel/K=1/N=GraphBoard/W=(monWidth*0.7, monHeight*0, monWidth*1, monHeight*1) as "GraphBoard"
	String panelName = S_Name

	ModifyPanel/W=$panelName noEdit=1
	SetWindow $panelName, hook(base) = GraphBoard#WinProc
	
	SetVariable GB_Input, title = " "
	SetVariable GB_Input, value = $PackagePath() + "S_Input"
	SetVariable GB_Input, font = "Helvetica Neue", fSize = 15
	SetVariable GB_Input, proc=GraphBoard#InputAction
	
	ListBox GB_ListBox,listWave = GetTxtWave("GraphNames")	
	ListBox GB_ListBox, selWave = GetNumWave("SelectionOfGraphNames")
	ListBox GB_ListBox,mode = 10 // multiple select
	ListBox GB_ListBox,font = "Helvetica Neue", fsize = 13
	ListBox GB_ListBox,proc=GraphBoard#ListBoxAction

	UpdateGraphNameWave()
	UpdateControls(panelName)
EndMacro

static Function MinimumMonitorSize(type)
	String type // "width" or "height"
	String screens = GrepList(IgorInfo(0), "^SCREEN\\d+")
	
	Variable i, min_size = inf
	for(i = 0; i < ItemsInList(screens); i += 1)
		String screen = StringFromList(i, screens), left, top, right, bottom
		SplitString/E="RECT=(\\d+),(\\d+),(\\d+),(\\d+)" screen, left, top, right, bottom
		
		strSwitch(type)
			case "width":
				min_size = min(min_size, abs(Str2Num(left) - Str2Num(right)))
				break
			case "height":
				min_size = min(min_size, abs(Str2Num(top) - Str2Num(bottom)))
				break
		endSwitch
	endfor
	
	return min_size
End

#if Exists("PanelResolution") != 3
static Function PanelResolution(wName) // For compatibility between Igor 6 & 7
	String wName
	return 72 // that is, "pixels"
End
#endif

Function UpdateControls(win)
	String win
	
	if(GetVar("IsListView"))
		ListBox GB_ListBox,special= {0,0,1}
	else
		ListBox GB_ListBox,special= {1,0,1}
	endif
	
	//
	// Resize controls
	//
	if( PanelResolution(win) == 72 )
		GetWindow $win wsizeDC		// the new window size in pixels (the Igor 6 way)
	else
		GetWindow $win wsize		// the new window size in points (the Igor 7 way, sometimes)
	endif
	Variable panelWidth  = V_Right  - V_Left
	Variable panelHeight = V_Bottom - V_Top
	
	ControlInfo/W=$win GB_Input
	Variable inputHeight = V_height
	
	SetVariable GB_Input, win=$win, pos={0, 0}, size={panelWidth, inputHeight}
	ListBox GB_ListBox, win=$win, pos={0, inputHeight}, size={panelWidth, panelHeight - inputHeight}
End

//------------------------------------------------------------------------------
// Hook functions
//------------------------------------------------------------------------------

//
// Window hook
//
static Function WinProc(s)
	STRUCT WMWinHookStruct &s
	
	// GraphBoard window is a singleton:
	// Window-copying is disable 
	if(!StringMatch(s.winName,"GraphBoard"))
		KillWindow $s.winName
		return NaN
	endif
	
	if(s.eventCode == 0 || s.eventCode == 6) // activate or resize
		UpdateGraphNameWave()
		
		if(s.eventCode == 6)
			UpdateControls(s.winName)
		endif
	endif
End

//
// Control hook
//
static Function InputAction(s)
	STRUCT WMSetVariableAction &s
	
	if(s.eventCode == 2) // key input		
		switch(s.eventMod)
			case 0: // Enter
				SetStr("Input", s.sval)
				UpdateGraphNameWave()
				print s.sval
				break
			case 2: // Shift + Enter
				break
			case 4: // Alt + Enter
				break
		endswitch
	endif
	
	if(IgorVersion() < 7)
		SetVariable/Z $s.ctrlName, win=$s.win, activate
	endif
End

static Function ListBoxAction(s)
	STRUCT WMListboxAction &s

	switch(s.eventCode)
		case 1:
			if(s.eventMod > 15) // contextual menu click
				WAVE selection = GetNumWave("LastSelectionOfGraphNames")
				SetNumWave("SelectionOfGraphNames", selection)
				DoUpdate	

				WAVE/T selectedGraphs = SelectedGraphNames(GetTxtWave("GraphNames"), selection)								
								
				if(numpnts(selectedGraphs))
					PopupContextualMenu ListBoxContextMenuPopUp(numpnts(selectedGraphs) > 1)
					ListBoxContextMenuAction(S_Selection, selectedGraphs)
				else
					PopupContextualMenu ListBoxGeneralContextMenuPopUp()
					ListBoxGeneralContextMenuAction(S_Selection)
				endif
				
				UpdateGraphNameWave()
				UpdateControls(s.win)
			endif
			break		
		case 3: // double click
			WAVE/T graphNames = GetTxtWave("graphNames")
			DoWindow/F $graphNames[s.row][s.col]
			break
	endswitch

	SetNumWave("LastSelectionOfGraphNames", GetNumWave("SelectionOfGraphNames"))
End

//------------------------------------------------------------------------------
// Contextual menu
//------------------------------------------------------------------------------

//
// Countextual menu for graphs
//
static Function/S ListBoxGeneralContextMenuPopUp()
	String popup = ""
	popup += "sort by date;sort by name;"
	popup += "list view;"
	popup += "columns 1;columns 2;columns 3;columns 4;"
	return popup
End

static Function ListBoxGeneralContextMenuAction(action)
	String action
	strSwitch(action)
		case "sort by date":
			SetVar("SortedByName", FALSE)
			break
		case "sort by name":
			SetVar("SortedByName", TRUE)	
			break
		case "list view":
			SetVar("IsListView", TRUE); SetVar("NumberOfColumns", 1)
			break			
		case "columns 1":
			SetVar("IsListView", FALSE); SetVar("NumberOfColumns", 1)
			break
		case "columns 2":
			SetVar("IsListView", FALSE); SetVar("NumberOfColumns", 2)
			break
		case "columns 3":
			SetVar("IsListView", FALSE); SetVar("NumberOfColumns", 3)
			break
		case "columns 4":
			SetVar("IsListView", FALSE); SetVar("NumberOfColumns", 4)
			break
	endSwitch
End

//
// Contextual menu for GraphBoard panel
//
static Function/S ListBoxContextMenuPopUp(isMultipleSelection)
	Variable isMultipleSelection
	String popup = ""
	popup += "show window;hide window;kill window;"
	popup += "make style;apply style;"

	if(IsMultipleSelection)
		popup = RemoveFromList("make style", popup)
	endif
	return popup	
End

static Function ListBoxContextMenuAction(action, graphNames)
	String action; WAVE/T graphNames
	String styleName = ""
	
	// confirmation or parameter-setting
	strSwitch(action)
		case "kill window":
			DoAlert 1, "Do you sure you want to kill the graph windows?"
			if(V_Flag != 1)
				return NaN
			endif
			break
		case "apply style":
			Prompt styleName, "Select Graph Style:", popup, MacroList("*", ";", "SUBTYPE:GraphStyle")
			DoPrompt "Apply Style", styleName
			if(V_Flag)
				return NaN
			endif
			break
	endSwitch
	
	// do action
	Variable i
	for(i = DimSize(graphNames, 0) - 1; i >= 0; i -= 1)
		String graphName = graphNames[i]
		
		strSwitch(action)
			case "show window":
				print graphName

				DoWindow/F $graphName
				break
			case "hide window":
				DoWindow/HIDE=1 $graphName
				break	
			case "kill window":
				KillWindow $graphName
				break
			case "make style":
				styleName = graphName + "Style"
				Prompt styleName "Style Name:"
				DoPrompt "Make Style", styleName
				if(!V_Flag)
					Execute/P "DoWindow/R/S=" +styleName +" "+ graphName
				endif			
				break
			case "apply style":
				String cmd
				sprintf cmd, "DoWindow/F %s; %s()", graphName, styleName
				Execute cmd
				break
		endSwitch	
	endfor
End

//------------------------------------------------------------------------------
// Manage the text wave containing graph names
//------------------------------------------------------------------------------

static Function/WAVE SelectedGraphNames(graphNames, selection)
	WAVE/T graphNames; WAVE selection
	Extract/FREE graphNames, selected, selection && strlen(graphNames)
	return selected
End

static Function UpdateGraphNameWave()
	Variable numCol = GetVar("NumberOfColumns")
	String regExps = GetStr("Input")
	
	if(numType(numCol) || numCol < 1)
		numCol = 3
	endif
	
	String graphList = WinList("*", ";", "WIN:1") 
	
	if(GetVar("SortedByName"))
		graphList = SortList(graphList, ";", 16)
	endif
	
	Variable i
	for(i = 0; i < ItemsInList(regExps, " "); i += 1)
		String regExp = StringFromList(i, "(?i)" + regExps, " ")
		graphList = GrepList(graphList, regExp)
	endfor
	
	Make/FREE/T/N=(ItemsInList(graphlist)) graphNames = StringFromList(p, graphList)
	Redimension/N=(ceil(numpnts(graphNames)/numCol), numCol) graphNames
	
	Make/FREE/N=(DimSize(graphNames, 0), DimSize(graphNames, 1)) selection = 0

	SetTxtWave("GraphNames", graphNames)
	SetNumWave("SelectionOfGraphNames", selection)
End

//------------------------------------------------------------------------------
// Getter & Setter of package parameters
//------------------------------------------------------------------------------

static Function/S PackagePath()
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:GraphBoard
	return "root:Packages:GraphBoard:"
End

static Function/WAVE GetNumWave(name)
	String name
	String path = PackagePath() + "W_" + name
	WAVE/Z w = $path
	if( !WaveExists(w) )
		Make/O/N=0 $path/WAVE=w
	endif
	return w
End

static Function SetNumWave(name,w)
	String name; WAVE w
	String path = PackagePath() + "W_" + name	
	if( !WaveRefsEqual(w, $path) )
		Duplicate/O w $path
	endif
End

static Function SetTxtWave(name,w)
	String name; WAVE/T w
	String path = PackagePath() + "W_" + name	
	if( !WaveRefsEqual(w, $path) )
		Duplicate/T/O w $path
	endif
End

static Function/WAVE GetTxtWave(name)
	String name
	String path = PackagePath() + "W_" + name
	WAVE/T/Z w = $path
	if( !WaveExists(w) )
		Make/O/T/N=0 $path/WAVE=w
	endif
	return w
End

static Function GetVar(name)
	String name
	String path = PackagePath() + "V_" + name
	NVAR/Z v = $path
	if( !NVAR_Exists(v) )
		Variable/G $path
		NVAR v = $path
	endif
	return v
End

static Function SetVar(name, v)
	String name; Variable v
	String path = PackagePath() + "V_" + name
	NVAR/Z target = $path
	if( !NVAR_Exists(target) )
		Variable/G $path
		NVAR target = $path
	endif
	target = v
End

static Function/S GetStr(name)
	String name
	String path = PackagePath() + "S_" + name
	SVAR/Z s = $path
	if( !SVAR_Exists(s) )
		String/G $path
		SVAR s = $path
	endif
	return s
End

static Function SetStr(name, s)
	String name, s
	String path = PackagePath() + "S_" + name
	SVAR/Z target = $path
	if( !SVAR_Exists(target) )
		String/G $path
		SVAR target = $path
	endif
	target = s
End
