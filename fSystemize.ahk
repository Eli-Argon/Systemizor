fSystemize(dResults, pOutputDir) {
    Local
	Global oLogger

	If (dResults.nChaosLevel == 2) {
		Run, "C:\Progress\Avicad\bin\AviCAD.exe", , max, sAviPID
        WinWait, ahk_pid %sAviPID%, , 13
        fAbort(ErrorLevel, A_ThisFunc, "AviCAD не был запущен.")
		MsgBox, 64, , % "Если AviCAD готов к работе, нажмите ОК.`n"
					  . "sAviPID: """ sAviPID """"
		WinActivate, ahk_pid %sAviPID%
        WinWaitActive, ahk_pid %sAviPID%, , 2
        fAbort(ErrorLevel, A_ThisFunc, "AviCAD не активен.")
		BlockInput, MouseMove
		SetTimer, fBlockInputOff, -13000
	}

    nProcessedFiles := 0
    For sPanel, aVersions in dResults.dPanelList {
		For idx, dVersion in aVersions {
			FileCreateDir, % pOutputDir . dVersion.pRelDir
			pSauceFileDesto := pOutputDir . dVersion.pRelFile
			pSauceFileDesto := dVersion.isPXML ? pSauceFileDesto : pSauceFileDesto ".pxml"
			fAbort(FileExist(pSauceFileDesto), A_ThisFunc
			, "Ошибка при копировании. Фаи̌л уже существует: """ pSauceFileDesto """.")

			If (dVersion.isPXML) {
				FileCopy, % dVersion.pSauceLoco, % pSauceFileDesto, false
				fAbort(ErrorLevel, A_ThisFunc
				, "Ошибка при копировании """ dVersion.pSauceLoco """ в """ pSauceFileDesto """")
			} else {
				fUnitechnikPXML(dVersion.pSauceLoco, pSauceFileDesto, sAviPID)
				fAbort(!FileExist(pSauceFileDesto), A_ThisFunc
				, "Ошибка при конвертации """ dVersion.pSauceLoco """ в """ pSauceFileDesto """")
			}
			nProcessedFiles++
			SetTimer, fBlockInputOff, -13000
		}
    }
	BlockInput, MouseMoveOff

	oLogger.save([ "Пропущено", "Перенесено", "Переименовано", "Переделано" ])
    fAbort(nProcessedFiles != dResults.nTotalFiles, A_ThisFunc
	, "По некоторым причинам некоторые файлы были пропущены."
	, {"dResults.nTotalFiles": dResults.nTotalFiles, "dResults.nSystemized": dResults.nSystemized
	, "dResults.nChaoticPXML": dResults.nChaoticPXML, "dResults.nChaoticNoExt": dResults.nChaoticNoExt
	, "dResults.nSkipped": dResults.nSkipped, "nProcessedFiles": nProcessedFiles })
}

fUnitechnikPXML(pFile, pFileNew, sAviPID) {
    fAbort(!WinExist("ahk_pid" sAviPID), A_ThisFunc, "AviCAD не наи̌ден.", {"pFile": pFile})
    fAbort(!WinActive("ahk_pid" sAviPID), A_ThisFunc, "AviCAD не активен.", {"pFile": pFile})
    ControlSend, ahk_parent, {F10}fo, ahk_pid %sAviPID%
    WinWaitActive, Open ahk_exe AviCAD.exe, , 2
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не открылось.", {"pFile": pFile})
    Control, EditPaste, %pFile%, Edit1, Open ahk_exe AviCAD.exe
    ControlClick, Button1, Open ahk_exe AviCAD.exe
    WinWaitClose, Open ahk_exe AviCAD.exe, , 2
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не закрылось.", {"pFile": pFile})

    ControlSend, ahk_parent, {F10}fs, ahk_pid %sAviPID%
    WinWaitActive, Save ahk_exe AviCAD.exe, , 2
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Save» не открылось.", {"pFile": pFile})
    Control, EditPaste, %pFileNew%, Edit1, Save ahk_exe AviCAD.exe
    Control, Choose, 1, ComboBox2
    ControlClick, Button1, Save ahk_exe AviCAD.exe
    WinWaitClose, Save ahk_exe AviCAD.exe, , 2
    fAbort(ErrorLevel, A_ThisFunc, "Окно «Open» не закрылось.", {"pFile": pFile})
}

fBlockInputOff() {
	BlockInput, MouseMoveOff
}