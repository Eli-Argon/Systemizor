fAnalyze(pInputDir) {
    Local
	Global oLogger
    dResults := {nChaosLevel: 0, dPanelList: {}, nTotalFiles: 0, nTotalPanels: 0
				, nSkipped: 0, nChaoticPXML: 0, nChaoticNoExt: 0, nSystemized: 0}

    Loop, files, % pInputDir "\*", R ; Iterating through the files in the input directory.
    {
        If InStr(A_LoopFileDir, (pInputDir "\Z"), true) ; Anything in the Z folder is ignored.
            continue
        dResults.nTotalFiles++

        If ((A_LoopFileExt != "pxml") and (A_LoopFileExt != "")) { ; Skip if wrong extension.
            dResults.nSkipped++
			oLogger.add("Пропущено", "EXTENSION", A_LoopFileDir "\", A_LoopFileName)
			continue
		}

        dVersion := { pSauceLoco: A_LoopFileLongPath }
		isNameSystemized := (RegExMatch(A_LoopFileName, "sSx)^"
						. "(?<name>[A-Zauoech]{1,6}-\d+)\s"
						. "(?<date>[012][890123]-[01]\d-[0123]\d)", sPanel_))
        If isNameSystemized {
			sPanel := sPanel_name
			dVersion.sFullName := A_LoopFileName
			dVersion.pRelFile := StrReplace(A_LoopFileLongPath, pInputDir)
       	    dVersion.pRelDir := StrReplace(dVersion.pRelFile, A_LoopFileName)
			dVersion.nDate := "20" StrReplace(sPanel_date, "-")
        } else { ; + + + + + + + + + + + +  Systemizing + + + + + + + + + + + + + + + + + + + +#
			If not RegExMatch(A_LoopFileName
			, "isSx)^\d? (?<type> [A-ZА-Я]{1,6}) - (?<num1> \d+) (?<num2> -\d+)? (?<rest> .*)"
			, sPanel_) {
				fAbort(ErrorLevel, A_ThisFunc, "RegExMatch error.")				
				dResults.nSkipped++
				oLogger.add("Пропущено", "NOT MATCHED", A_LoopFileDir "\", A_LoopFileName)
				continue
			}       
			If (sPanel_num2 != "")
			and (LTrim(sPanel_num1, "0") != LTrim(SubStr(sPanel_num2, 2), "0")) {
				dResults.nSkipped++
				oLogger.add("Пропущено", "NUMS DIFFER", A_LoopFileDir "\", A_LoopFileName)
				continue
			}
			
			StringUpper, sPanelType, sPanel_type
			sPanelType := fTransliterate(sPanelType)
			sPanel := sPanelType "-" LTrim(sPanel_num1, "0") ; Removing leading zeroes.
			sDate := SubStr(A_LoopFileTimeModified, 3, 2) "-" ; Year (last two digits)
				   . SubStr(A_LoopFileTimeModified, 5, 2) "-" ; Month
				   . SubStr(A_LoopFileTimeModified, 7, 2)     ; Day
			
			RegExMatch(sPanel_rest, "sSx)"      ; Removing trash from file name.
					. "^(?<mod>  [-_\s]?(new|opt|modern|mod|зм\d?|v2)){0,3}"
					. " (?<cor>  \s\( (OPT|COR) .*\) )?"
					. " (?<date> \s" sDate ")?" ; If the name already has a date.
					. " (?<rest> .*)", sCleaned_)
			dVersion.sFullName := sPanel " " sDate sCleaned_rest

			dVersion.pRelDir := StrReplace(StrReplace(A_LoopFileLongPath, pInputDir), A_LoopFileName)
			dVersion.pRelFile := dVersion.pRelDir . dVersion.sFullName
			dVersion.nDate := SubStr(A_LoopFileTimeModified, 1, 8)

        } ; + + + + + + + + + + + + + + + + + + + + + + + + + Systemizing + + + + + + + + + + +#
		If ((A_LoopFileExt == "pxml") and isNameSystemized) {
            dResults.nSystemized++
			dVersion.isPXML := true
			oLogger.add("Перенесено", A_LoopFileDir "\", A_LoopFileName)
		} else if ((A_LoopFileExt == "pxml") and !isNameSystemized) {
			dResults.nChaosLevel := 1
			dResults.nChaoticPXML++
			dVersion.isPXML := true
			oLogger.add("Переименовано", A_LoopFileDir "\", A_LoopFileName, dVersion.sFullName)
		} else {
			dResults.nChaosLevel := 2
			dResults.nChaoticNoExt++
			dVersion.isPXML := false
			oLogger.add("Переделано", A_LoopFileDir "\", A_LoopFileName, dVersion.sFullName . ".pxml")
		}

	    If (dResults.dPanelList.HasKey(sPanel)) {
	        For idx, dListedVer in dResults.dPanelList[(sPanel)]
		    	fAbort(dVersion.nDate == dListedVer.nDate, A_ThisFunc
				, "У двух версий """ sPanel """ та же дата."
				, { "dVersion.pSauceLoco": dVersion.pSauceLoco, "dVersion.nDate": dVersion.nDate })
			dResults.dPanelList[(sPanel)].Push(dVersion) ; Add a new version to panel %sPanel%.
	    } else {
	        dResults.nTotalPanels++
			dResults.dPanelList[(sPanel)] := [ dVersion ] ; Or if this is the first version
	    }                                                 ; of the panel %sPanel%.
    }

    fAbort(dResults.nTotalFiles != ( dResults.nSystemized
	+ dResults.nChaoticPXML + dResults.nChaoticNoExt + dResults.nSkipped ), A_ThisFunc
	, "По некоторым причинам некоторые файлы были пропущены."
	, { "dResults.nTotalFiles": dResults.nTotalFiles
	  , "dResults.nSystemized": dResults.nSystemized
	  , "dResults.nChaoticPXML": dResults.nChaoticPXML
	  , "dResults.nChaoticNoExt": dResults.nChaoticNoExt
	  , "dResults.nSkipped": dResults.nSkipped })

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
