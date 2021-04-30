#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn   ; Enable warnings to assist with detecting common errors.
#SingleInstance Force
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
StringCaseSense On
AutoTrim Off
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;@Ahk2Exe-SetName Systemizor
;@Ahk2Exe-SetDescription To banish Chaos and bathe all in the brilliance of Order.
;@Ahk2Exe-SetMainIcon Things\Systemizor.ico
;@Ahk2Exe-SetCompanyName Konovalenko Systems
;@Ahk2Exe-SetCopyright Eli Konovalenko
;@Ahk2Exe-SetVersion 2.1

#Include fAnalyze.ahk
#Include fSystemize.ahk
#Include fCompartmentalize.ahk
#Include fExtrasize.ahk
#Include Misc.ahk

If !((A_ComputerName == "160037-MMR" and InStr(FileExist("C:\Progress\MSystem\Impdata\DSK\SuperCoolSecretAwesomeStuff"), "D", true)   )
  or (A_ComputerName == "160037-BGM" and InStr(FileExist("C:\Progress\MSystem\Temp\645ff040-5081-101b\Microsoft\default"), "D", true) )
  or (A_ComputerName == "MAYTINHXACHTAY")) {
	MsgBox, 16, Stop right there`, criminal scum!, You are doing something you shouldn't.
	ExitApp
}
isTest := InStr(FileExist("Systemizor Test"), "D", true)
pInputDir :=        isTest ? (A_ScriptDir "\Systemizor Test"                  ) : ("C:\Progress\MSystem\Impdata\DSK\Source"           )
pOutputSourceDir := isTest ? (A_ScriptDir "\Systemizor Test Source SYSTEMIZED") : ("C:\Progress\MSystem\Impdata\DSK\Source SYSTEMIZED")
pOutputMainDir :=   isTest ? (A_ScriptDir "\Systemizor Test Main"             ) : ("C:\Progress\MSystem\Impdata\DSK\Main"             )
pOutputExtraDir :=  isTest ? (A_ScriptDir "\Systemizor Test Extra"            ) : ("C:\Progress\MSystem\Impdata\DSK\Extra"            )
fAbort(!InStr(FileExist(pInputDir), "D", true), "Systemizor", "Папка """ pInputDir """ не найдена.")
      
oLogger := new cLogger
fClean([pOutputMainDir, pOutputExtraDir, pOutputSourceDir])

If FileExist("sToSplit.txt") {
    oToSplit := FileOpen("sToSplit.txt", "r-rwd")
	fAbort(!oToSplit, "Systemizor", "Ошибка при чтении ""sToSplit.txt.""")
    sToSplit := oToSplit.Read()
	sToSplit.Close()
}

dResults := fAnalyze(pInputDir)

If dResults.isChaos {
    fSystemize(dResults, pOutputSourceDir)
    
	nSourceCheck := 0
	Loop, files, % pOutputSourceDir "\*", R
		nSourceCheck++
	fAbort(dResults.nTotalFiles != nSourceCheck, "Systemizor", "По некоторым причинам некоторые файлы были пропущены."
    , { "dResults.nTotalFiles": dResults.nTotalFiles, "nSourceCheck": nSourceCheck })
} else {
    fCompartmentalize(dResults, pOutputMainDir, pOutputExtraDir, sToSplit)

	nMainCheck := 0
	Loop, files, % pOutputMainDir "\*", R
		nMainCheck++
	aToSplit := StrSplit(sToSplit, ","), nMainCheck -= aToSplit.Length()
	fAbort(dResults.nTotalPanels != nMainCheck, "Systemizor", "По некоторым причинам некоторые файлы были пропущены."
    , { "dResults.nTotalPanels": dResults.nTotalPanels, "nMainCheck": nMainCheck })
}

MsgBox, 4160, % dResults.nTotalPanels " чертежей", % "  THE LIGHT OF ORDER SHINE UPON THEE  "