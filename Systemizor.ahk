#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn   ; Enable warnings to assist with detecting common errors.
#SingleInstance Force
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
StringCaseSense On
AutoTrim Off
SetControlDelay -1           ; To increase reliability of ControlClick
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;@Ahk2Exe-SetName Systemizor
;@Ahk2Exe-SetDescription To banish Chaos and bathe all in the brilliance of Order.
;@Ahk2Exe-SetMainIcon Things\Systemizor.ico
;@Ahk2Exe-SetCompanyName Konovalenko Systems
;@Ahk2Exe-SetCopyright Eli Konovalenko
;@Ahk2Exe-SetVersion 4.0.3

#Include fAnalyze.ahk
#Include fSystemize.ahk
#Include fCompartmentalizeP.ahk
#Include fCompartmentalizeU.ahk
#Include MiscFuncs.ahk

OnExit("fBlockInputOff")

If !((A_ComputerName == "160037-MMR" and InStr(FileExist("C:\Progress\MSystem\Impdata\DSK\SuperCoolSecretAwesomeStuff"), "D", true)   )
    or (A_ComputerName == "160037-BGM" and InStr(FileExist("C:\Progress\MSystem\Temp\645ff040-5081-101b\Microsoft\default"), "D", true) )
    or (A_ComputerName == "MAYTINHXACHTAY")) {
	MsgBox, 16, Stop right there`, criminal scum!, You are doing something you shouldn't.
	ExitApp
}

fAbort(!FileExist("Systemizor.ini"), "Systemizor", """Systemizor.ini"" не наи̌ден.")
IniRead, pInputDir,         Systemizor.ini,  IO,        Input
IniRead, pOutputSourceDir,  Systemizor.ini,  IO,        OutputSource
IniRead, pOutputMainDir,    Systemizor.ini,  IO,        OutputMain
IniRead, pOutputExtraDir,   Systemizor.ini,  IO,        OutputExtra
IniRead, sOutputFormat,     Systemizor.ini,  Options,   OutputFormat
IniRead, sMode,             Systemizor.ini,  Options,   Mode
IniRead, sPanelsToSplit,    Systemizor.ini,  Options,   Split
IniRead, isRenaming,        Systemizor.ini,  Options,   Renaming
IniRead, sRenamings,        Systemizor.ini,  Renamings

aPanelsToSplit := ( sPanelsToSplit != "ERROR" ) ? StrSplit( sPanelsToSplit, ",", " `r`n" ) : ""
If (sRenamings != "ERROR") {
    aRenamings := []
    Loop, parse, sRenamings, `n, `r
    {
        aPair := StrSplit(A_LoopField, "×", " `r`n")
        aRenamings.Push([ aPair[1], aPair[2] ])
    }
} else aRenamings := ""

isTest := InStr(FileExist("Test"), "D", true)
pInputDir :=         isTest ? (A_ScriptDir "\Test"           ) : pInputDir
pOutputSourceDir :=  isTest ? (A_ScriptDir "\Test SYSTEMIZED") : pOutputSourceDir
pOutputMainDir :=    isTest ? (A_ScriptDir "\Test Main"      ) : pOutputMainDir
pOutputExtraDir :=   isTest ? (A_ScriptDir "\Test Extra"     ) : pOutputExtraDir
pOutputRenamedDir := pInputDir " RENAMED"
pOutputSortedDir :=  pInputDir " SORTED"
pOutputSkippedDir := pInputDir " SKIPPED"
fAbort(!InStr(FileExist(pInputDir), "D", true), "Systemizor", "Папка """ pInputDir """ не найдена.")
      
oLogger := new cLogger
oLogger.del([ "Принято", "Пропущено", "Переименовано", "Переделано" ])
fClean([ pOutputMainDir, pOutputExtraDir, pOutputSourceDir, pOutputRenamedDir, pOutputSortedDir, pOutputSkippedDir ])



dResults := fAnalyze( pInputDir, sOutputFormat, aRenamings )

If ( sMode == "Rename" ) {

    fSystemize(dResults.dPanelList, pOutputRenamedDir, true, false, "")
    fSystemize(dResults.aSkippedFiles, pOutputRenamedDir, true, false, "")
    oLogger.save([ "Переименовано" ])

    If InStr(FileExist(pInputDir "\.git"), "D", true) {
        FileCopyDir, % pInputDir "\.git", % pOutputRenamedDir "\.git", false
        fAbort(ErrorLevel, A_ThisFunc, "Ошибка копирования папки "".git""")
    }
} else if ( sMode == "Sort" ) {

    fSystemize(dResults.dPanelList, pOutputSortedDir, isRenaming, false, "")
    fSystemize(dResults.aSkippedFiles, pOutputSkippedDir, false, false, "")

    If InStr(FileExist(pInputDir "\.git"), "D", true) {
        FileCopyDir, % pInputDir "\.git", % pOutputSortedDir "\.git", false
        fAbort(ErrorLevel, A_ThisFunc, "Ошибка копирования папки "".git""")
    }
} else {

    If ( ( sOutputFormat == "Progress" and dResults.nPanelsUnitechnik > 0 )
         or ( sOutputFormat == "Unitechnik" and dResults.nPanelsProgress > 0 ) )
        isConversionNeeded := true
    else isConversionNeeded := false

    If ( isConversionNeeded or ( dResults.isAnyRenamed and isRenaming ) ) {
        fSystemize(dResults.dPanelList, pOutputSourceDir, isRenaming, isConversionNeeded, sOutputFormat)
        fSystemize(dResults.aSkippedFiles, pOutputSkippedDir, false, false, "")

        If InStr(FileExist(pInputDir "\Я"), "D", true) {
            FileCopyDir, % pInputDir "\Я", % pOutputSourceDir "\Я", false
            fAbort(ErrorLevel, A_ThisFunc, "Ошибка копирования папки ""Я""")
        }
        ; ###  Copying «.git» folder to output. ### ;
        If InStr(FileExist(pInputDir "\.git"), "D", true) {
            FileCopyDir, % pInputDir "\.git", % pOutputSourceDir "\.git", false
            fAbort(ErrorLevel, A_ThisFunc, "Ошибка копирования папки "".git""")
        }
    } else {
        nPanelsSplit := 0
        For _, dPanel in dResults.dPanelList {
            If ( dPanel.sFormat == "Progress" )
                isPanelSplit := fCompartmentalizeP(dPanel, pOutputMainDir, pOutputExtraDir, aPanelsToSplit)
            else if ( dPanel.sFormat == "Unitechnik" )
                isPanelSplit := fCompartmentalizeU(dPanel, pOutputMainDir, pOutputExtraDir, aPanelsToSplit)
            nPanelsSplit := isPanelSplit ? ( nPanelsSplit + 1) : nPanelsSplit
        }

        nMainCheck := 0
        Loop, files, % pOutputMainDir "\*", R
            nMainCheck++
        fAbort(dResults.nPanelsTotalUnique != (nMainCheck - nPanelsSplit), "Systemizor", "Какие-то файлы потерялись."
        , { "dResults.nPanelsTotalUnique": dResults.nPanelsTotalUnique, "nMainCheck": nMainCheck })
        If InStr(FileExist(pInputDir "\Я"), "D", true) {
            FileCopyDir, % pInputDir "\Я", % pOutputMainDir "\Я", false
            fAbort(ErrorLevel, A_ThisFunc, "Ошибка копирования папки ""Я""")
        }
    }
}

If ( isRenaming )
    oLogger.save([ "Переименовано" ])
For _, dPanel in dResults.dPanelList
    oLogger.add("Принято", dPanel.pRelDir, dPanel.sFileName)
oLogger.save([ "Принято", "Пропущено", "Переделано" ])


MsgBox, 4160, % dResults.nPanelsTotalUnique " чертежей", % "  THE LIGHT OF ORDER SHINE UPON THEE  "
ExitApp