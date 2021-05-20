fSystemize(aFileList, pOutputDir, isRenaming, isConversionNeeded, sOutputFormat) {
    Local
	Global oLogger

	If ( isConversionNeeded ) {
		Run, "C:\Progress\Avicad\bin\AviCAD.exe", , max, sAviPID
        WinWait, ahk_pid %sAviPID%, , 13
        fAbort(ErrorLevel, A_ThisFunc, "AviCAD не был запущен.")
		MsgBox, 64, , % "Если AviCAD готов к работе, нажмите ОК.`n sAviPID: """ sAviPID """"
		WinActivate, ahk_pid %sAviPID%
        WinWaitActive, ahk_pid %sAviPID%, , 2
        fAbort(ErrorLevel, A_ThisFunc, "AviCAD не в фокусе.")
		BlockInput, MouseMove
		SetTimer, fBlockInputOff, -13000
	}

    nFilesProcessed := 0
    For _, dFile in aFileList {
        FileCreateDir, % pOutputDir . dFile.pRelDir
        pDest := pOutputDir . dFile.pRelDir
        pDest := isRenaming ? ( pDest . dFile.sNewFileName ) : ( pDest . dFile.sFileName)

        If ( !isConversionNeeded or ( dFile.sFormat == sOutputFormat ) ) {
            fAbort(FileExist(pDest), A_ThisFunc, "Ошибка при копировании. Фаи̌л уже существует: """ pDest """.")
            FileCopy, % dFile.pFile, % pDest, false
            fAbort(ErrorLevel, A_ThisFunc, "Ошибка при копировании """ dFile.pFile """ в """ pDest """")
        } else {
            pDest := ( sOutputFormat == "Progress" ) ? ( pDest ".pxml" ) : ( RegExReplace(pDest, "iS)\.pxml$", ""))
            fAbort(FileExist(pDest), A_ThisFunc, "Ошибка при копировании. Фаи̌л уже существует: """ pDest """.")
            fConvert(dFile.pFile, pDest, sOutputFormat, sAviPID)
            fAbort(!FileExist(pDest), A_ThisFunc, "Ошибка при конвертации """ dFile.pFile """ в """ pDest """")

            SplitPath, pDest, sDestFileName
            oLogger.add( "Переделано", dFile.pRelDir, dFile.sFileName, sDestFileName)
            SetTimer, fBlockInputOff, -13000
        }        
        nFilesProcessed++
    }
	BlockInput, MouseMoveOff

    fAbort( nFilesProcessed != aFileList.Count(), A_ThisFunc, "Какие-то фаи̌лы потерялись."
	, { "aFileList.Count()": aFileList.Count(), "nFilesProcessed": nFilesProcessed } )
}

fConvert( pFile, pFileNew, sOutputFormat, sAviPID ) {
    fAbort(!WinExist("ahk_pid" sAviPID), A_ThisFunc, "AviCAD не наи̌ден.", {"pFile": pFile})
    fAbort(!WinActive("ahk_pid" sAviPID), A_ThisFunc, "AviCAD не активен.", {"pFile": pFile})
    ControlSend, ahk_parent, {F10}fo, ahk_pid %sAviPID%
    WinWaitActive, Open ahk_exe AviCAD.exe, , 5
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не открылось.", {"pFile": pFile})
    Control, EditPaste, %pFile%, Edit1, Open ahk_exe AviCAD.exe
    ControlClick, Button1, Open ahk_exe AviCAD.exe
    WinWaitClose, Open ahk_exe AviCAD.exe, , 5
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не закрылось.", {"pFile": pFile})

    ControlSend, ahk_parent, {F10}fs, ahk_pid %sAviPID%
    WinWaitActive, Save ahk_exe AviCAD.exe, , 5
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Save» не открылось.", {"pFile": pFile})
    Control, EditPaste, %pFileNew%, Edit1, Save ahk_exe AviCAD.exe

    If ( sOutputFormat == "Progress" )
        Control, Choose, 1, ComboBox2
    else if ( sOutputFormat == "Unitechnik" )
        Control, Choose, 9, ComboBox2

    ControlClick, Button1, Save ahk_exe AviCAD.exe
    WinWaitClose, Save ahk_exe AviCAD.exe, , 5
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не закрылось.", {"pFile": pFile})
}

fBlockInputOff() {
	BlockInput, MouseMoveOff
}