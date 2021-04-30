fAnalyze(pInputDir) {
    Local
	Global oLogger
    dResults := {isChaos: false, dPanelList: {}, nTotalFiles: 0, nTotalPanels: 0, nSkipped: 0, nChaotic: 0, nSystemized: 0}

    Loop, files, % pInputDir "\*", R
    {
        dResults.nTotalFiles++
        If (A_LoopFileExt != "") {
            dResults.nSkipped++
			oLogger.add("Пропущено", "EXTENSION", A_LoopFileDir "\", A_LoopFileName)
            continue
        }

        dVersion := { pSauceLoco: A_LoopFileLongPath }
        If (RegExMatch(A_LoopFileName, "sSx)^(?<name>[A-Zauoech]{1,6}-\d+)  \s  (?<date>[0123]\d-[01]\d-[0123]\d)", sPanel_)) {
            dResults.nSystemized++
			oLogger.add("Перенесено", A_LoopFileDir "\", A_LoopFileName)
			sPanel := sPanel_name, 
			dVersion.sFullName := A_LoopFileName
			dVersion.pRelFile := StrReplace(A_LoopFileLongPath, pInputDir)
       	    dVersion.pRelDir := StrReplace(dVersion.pRelFile, A_LoopFileName)
			dVersion.nDate := "20" StrReplace(sPanel_date, "-")
        } else { ; + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +  Systemizing + + + + + + + + + + + + + + + + + + +#
			; MsgBox % "Not systemized: """ dVersion.pSauceLoco """"
			If not RegExMatch(A_LoopFileName, "isSx)^\d?   (?<type> [A-ZА-Я]{1,6}) - (?<num1> \d+)   (?<num2> -\d+)?   (?<rest> .*)", sPanel_) {
				fAbort(ErrorLevel, A_ThisFunc, "RegExMatch error.")				
				dResults.nSkipped++
				oLogger.add("Пропущено", "NOT MATCHED", A_LoopFileDir "\", A_LoopFileName)
				continue
			}       
			If (sPanel_num2 != "") and (sPanel_num1 != SubStr(sPanel_num2, 2)) {
				dResults.nSkipped++
				oLogger.add("Пропущено", "NUMS DIFFER", A_LoopFileDir "\", A_LoopFileName)
				continue
			}
			dResults.nChaotic++, dResults.isChaos := true

			StringUpper, sPanelType, sPanel_type
			sPanelType := fTransliterate(sPanelType)
			RegExMatch(sPanel_rest, "sSx)"
								  . "^(?<mod>  [-_\s]?(new|opt|modern|mod|зм\d?|v2)){0,3}"
								  . " (?<cor>  \s\( (OPT|COR) .*\) )?"
								  . " (?<rest> .*)", sCleaned_)
			sPanel := sPanelType "-" LTrim(sPanel_num1, "0")
			dVersion.sFullName := sPanel " "
				. SubStr(A_LoopFileTimeModified, 3, 2) "-" SubStr(A_LoopFileTimeModified, 5, 2) "-" SubStr(A_LoopFileTimeModified, 7, 2)
				. sCleaned_rest            

			dVersion.pRelDir := StrReplace(StrReplace(A_LoopFileLongPath, pInputDir), A_LoopFileName)
			dVersion.pRelFile := dVersion.pRelDir . dVersion.sFullName
			dVersion.nDate := SubStr(A_LoopFileTimeModified, 1, 8)
			oLogger.add("Переименовано", A_LoopFileDir "\", A_LoopFileName, dVersion.sFullName)
        } ; + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + Systemizing + + + + + + + + + + + + + + + +#
	    If (dResults.dPanelList.HasKey(sPanel)) {
	        For idx, dListedVer in dResults.dPanelList[(sPanel)]
		    fAbort(dVersion.nDate == dListedVer.nDate, A_ThisFunc, "У двух версий """ sPanel """ та же дата."
									, { "dVersion.pSauceLoco": dVersion.pSauceLoco, "dVersion.nDate": dVersion.nDate })
			dResults.dPanelList[(sPanel)].Push(dVersion)
	    } else {
	        dResults.nTotalPanels++
			dResults.dPanelList[(sPanel)] := [ dVersion ]
	    }
    }

    fAbort(dResults.nTotalFiles != dResults.nSystemized + dResults.nChaotic + dResults.nSkipped, A_ThisFunc
	, "По некоторым причинам некоторые файлы были пропущены."
	, {"dResults.nTotalFiles": dResults.nTotalFiles
	, "dResults.nSystemized": dResults.nSystemized, "dResults.nChaotic": dResults.nChaotic, "dResults.nSkipped": dResults.nSkipped })
    return dResults    
}

fTransliterate(str) {
    Local
    dRusToEng := {"А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Е": "Je", "Ё": "Jo", "Ж": "Zh", "З": "Z", "И": "I"
				 ,"Й": "J", "К": "K", "Л": "L", "М": "M", "Н": "N", "О": "O", "П": "P", "Р": "R", "С": "S", "Т": "T"
				 ,"У": "U", "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Ch", "Ш": "Sh", "Щ": "Shch", "Ъ": "bitch you crazy"
				 ,"Ы": "Y", "Ь": "waat", "Э": "E", "Ю": "Ju", "Я": "Ja"}
    newStr := ""
    Loop, parse, str
        If RegExMatch(A_LoopField, "S)[А-Я]")
            newStr .= dRusToEng[A_LoopField]
        else
            newStr .= A_LoopField
    return newStr
}
