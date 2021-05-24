; Takes a path to a folder with panel files. Gathers data about them. Only one version per panel (tries to pick the newest).
; Returns = { dPanelList:                « See below. »
;               , aSkippedFiles:           « An array of data on files that didn't make it into dPanelList. »
;               , isAnyRenamed:         « If any file's name has applicable renamings. »
;               , nFilesTotal:              « Number of all files in pInputDir. »
;               , nPanelsTotalUnique:  « Number of unique panels\panelnames. »
;               , nFilesSkipped:          « Number of files that didn't make it into dPanelList. »
;               , nPanelsProgress:      « Number of panels in Progress format. »
;               , nPanelsUnitechnik:    « Number of panels in Unitechnik format. »
;              }
;
; dPanelList = {<panel's name>: { sName: <panel's name>
;                                           , sFileName:            « Full filename with extension. »
;                                           , sNewFileName:     « Full filename after renamings. »
;                                           , pFile:                    « C:\input_dir\dir\file »
;                                           , pDir:                     « C:\input_dir\dir »
;                                           , pRelFile:                « \dir\file »
;                                           , pRelDir:                « \dir\ »
;                                           , nInternalDate:        « The panel's internal date that was extracted from sFileContents, e.g.: 20190203 »
;                                           , nFileModifiedDate: « The last modified date of the panel's file, e.g.: 20211224 »
;                                           , nFileNameDate:     « If filename contains a date in <panelname>\sYY-MM-DD format. »
;                                           , sFormat:               « Unitechnik or Progress. »
;                                           , sFileContents:        « The file's contents as text. »},
;                  <panel's name>: {}, ...
;                 }
; aSkippedFiles = [ { sFileName, sNewFileName, pFile, pDir, pRelFile, pRelDir }, ..., { sFileName, ... } ]
fAnalyze(pInputDir, sOutputFormat, aRenamings) {
    Local
	Global oLogger
    dPanelList := {}, aSkippedFiles := [], isAnyRenamed := false
    nFilesTotal := 0, nPanelsTotalUnique := 0, nFilesSkipped := 0, nPanelsProgress := 0, nPanelsUnitechnik := 0

    Loop, files, % pInputDir "\*", R ; Iterating through the files in the input directory.
    {
        If ( InStr(A_LoopFileDir, (pInputDir "\Я"), true) or InStr(A_LoopFileDir, (".git"), true) )
            continue   ; Anything in the «Я» and «.git» folders is ignored.

        nFilesTotal++

        sFileName := A_LoopFileName
        pFile := A_LoopFileLongPath                                        ; "C:\input_dir\dir\file"
        pRelFile := StrReplace(A_LoopFileLongPath, pInputDir)  ; "\dir\file"
        pRelDir := StrReplace(pRelFile, A_LoopFileName)           ; "\dir\"
        pDir := RTrim(pInputDir . pRelDir, "\")                           ; "C:\input_dir\dir"

        ; #################################   vvv  RENAMING  vvv  ######################################## ;
        sNewFileName := A_LoopFileName
        For _, aPair in aRenamings {
            sRegex := aPair[1], sReplacement := aPair[2]
            sNewFileName := RegExReplace(sNewFileName, sRegex, sReplacement)
        }
        If (sNewFileName != A_LoopFileName) {
            isAnyRenamed := true
            oLogger.add("Переименовано", pRelDir, A_LoopFileName, sNewFileName)
        }
        ; #################################   ^^^  RENAMING  ^^^  ######################################## ;        

        If ( (A_LoopFileExt != "pxml") and (A_LoopFileExt != "PXML") and (A_LoopFileExt != "")
             and !RegExMatch(A_LoopFileExt, "S)\d\d?") ) {
            nFilesSkipped++
            aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
			oLogger.add("Пропущено", "BAD EXTENSION", pRelDir, A_LoopFileName)
			continue  ; SKIPPED if wrong extension.
		}

		aPNDFP := fGetPanelNameDateFilePath(A_LoopFileLongPath)
        sPanelNameFilePath := aPNDFP[1], nNameDate := aPNDFP[2]
        If !sPanelNameFilePath {
            nFilesSkipped++
            aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
			oLogger.add("Пропущено", "UNKNOWN PANEL", pRelDir, A_LoopFileName)
            continue  ; SKIPPED if couldn't get the panel's name from the file's name.
        }

        aPanelData := ""
        If (A_LoopFileExt == "") {
            aPanelData := fReadPanelU(A_LoopFileLongPath)
            If aPanelData {
                nPanelsUnitechnik++
                sPanelFormat := "Unitechnik"
            }
        } else {
            aPanelData := fReadPanelP(A_LoopFileLongPath)
             If aPanelData {
                nPanelsProgress++
                sPanelFormat := "Progress"
            }
        }

        If aPanelData {
            sPanel := RegExReplace(aPanelData[1], "^В\(к\)-", "ВК-")
            nInternalDate := aPanelData[2], sFileContents := aPanelData[3]
        } else {
            nFilesSkipped++
            aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
			oLogger.add("Пропущено", "COULDN'T READ", pRelDir, A_LoopFileName)
            continue ; SKIPPED if couldn't read the file.
        }    

        If (sPanel != sPanelNameFilePath) {
            nFilesSkipped++
            aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
			oLogger.add("Пропущено", "NAMES DIVERGE", pRelDir, A_LoopFileName, "   Internal name: «" sPanel "»")
            continue  ; SKIPPED if external and internal panel names don't match.
        }

        FileGetTime, nFileModifiedTime, A_LoopFileLongPath
        nFileModifiedDate := SubStr(nFileModifiedTime, 1, 8)

        If ( dPanelList.HasKey( sPanel ) ) { ; If this panel name is already in dPanelList.

            If (dPanelList[sPanel].nInternalDate > nInternalDate) { ; If list panel's inner date is NEWER than loop panel's.
                nFilesSkipped++
                aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
			    oLogger.add("Пропущено", "OLD INNR DATE", pRelDir, A_LoopFileName, "   Internal date: «" nInternalDate "»")
                continue ; SKIPPED because a newer version is already in dPanelList.

            ; ##################################### vvv INNER DATES EQUAL vvv ################################# ;

            } else if (dPanelList[sPanel].nInternalDate == nInternalDate) { ; If inner dates are EQUAL.

                 If (dPanelList[sPanel].sFormat != sPanelFormat) { ; If formats don't match.
                    nFilesSkipped++
                    sPreferredFormat := (sOutputFormat != "Progress" and sOutputFormat != "Unitechnik") ? "Progress" : sOutputFormat

                    If (sPanelFormat != sPreferredFormat) {
                        aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
                        oLogger.add("Пропущено", "DOUBLE FORMAT", pRelDir, A_LoopFileName)
                        continue ; SKIPPED because this panel has two versions in both formats and the loop panel is not sPreferredFormat.
                    } else {
                        aSkippedFiles.Push( { "sFileName": dPanelList[sPanel].sFileName, "sNewFileName": dPanelList[sPanel].sNewFileName, "pFile": dPanelList[sPanel].pFile, "pDir": dPanelList[sPanel].pDir, "pRelFile": dPanelList[sPanel].pRelFile, "pRelDir": dPanelList[sPanel].pRelDir } )
                        oLogger.add("Пропущено", "DOUBLE FORMAT", dPanelList[sPanel].pRelDir, dPanelList[sPanel].sFileName)
                        ; Proceed with adding loop panel's data to the panel list because it's in sPreferredFormat.
                    }

                } else if (dPanelList[sPanel].sFileContents == sFileContents) { ; If same format and both files have identical contents.
                    nFilesSkipped++
                    aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
                    oLogger.add("Пропущено", "SAME CONTENTS", pRelDir, A_LoopFileName)
                    continue ; SKIPPED because file contents are identical.

                } else if (dPanelList[sPanel].nFileModifiedDate > nFileModifiedDate) { ; If list panel's file is newer.
                    nFilesSkipped++
                    aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
                    oLogger.add("Пропущено", "OLD FILE DATE", pRelDir, A_LoopFileName, "   File Modified date: «" nFileModifiedDate "»")
                    continue ; SKIPPED because this file is older than the one that's already in dPanelList.

                } else if (dPanelList[sPanel].nFileModifiedDate < nFileModifiedDate) { ; If list panel's file is older.
                    nFilesSkipped++
                    aSkippedFiles.Push( { "sFileName": dPanelList[sPanel].sFileName, "sNewFileName": dPanelList[sPanel].sNewFileName, "pFile": dPanelList[sPanel].pFile, "pDir": dPanelList[sPanel].pDir, "pRelFile": dPanelList[sPanel].pRelFile, "pRelDir": dPanelList[sPanel].pRelDir } )
                    oLogger.add("Пропущено", "OLD FILE DATE", dPanelList[sPanel].pRelDir, dPanelList[sPanel].sFileName, "   File Modified date: «" dPanelList[sPanel].nFileModifiedDate "»")
                    ; Proceed with adding loop panel's data to the panel list. (Because same internal, but newer file date.)

                } else if ( dPanelList[sPanel].nNameDate > nNameDate ) {
                    nFilesSkipped++
                    aSkippedFiles.Push( { "sFileName": sFileName, "sNewFileName": sNewFileName, "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir } )
                    oLogger.add("Пропущено", "OLD NAME DATE", pRelDir, A_LoopFileName, "   Name date: «" nNameDate "»")
                    continue ; SKIPPED because the loop panel has an earlier filename date.

                } else if ( dPanelList[sPanel].nNameDate < nNameDate ) {
                    nFilesSkipped++
                    aSkippedFiles.Push( { "sFileName": dPanelList[sPanel].sFileName, "sNewFileName": dPanelList[sPanel].sNewFileName, "pFile": dPanelList[sPanel].pFile, "pDir": dPanelList[sPanel].pDir, "pRelFile": dPanelList[sPanel].pRelFile, "pRelDir": dPanelList[sPanel].pRelDir } )
                    oLogger.add("Пропущено", "OLD NAME DATE", dPanelList[sPanel].pRelDir, dPanelList[sPanel].sFileName, "   Name date: «" dPanelList[sPanel].nNameDate "»")
                    ; Proceed with adding loop panel's data to the panel list because it has a later filename date.

                } else fAbort( true, A_ThisFunc, "Все три даты одинаковые, но содержимое фаи̌лов разное."
                , {"dPanelList[""" sPanel """].pFile": dPanelList[sPanel].pFile, "pFile": pFile}) ; Don't know which to pick so throw an error.

            ; ####################################### ^^^ INNER DATES EQUAL ^^^ ################################# ;

            } else if (dPanelList[sPanel].nInternalDate < nInternalDate) { ; If list panel's date is OLDER than loop panel's.
                nFilesSkipped++
                aSkippedFiles.Push( { "sFileName": dPanelList[sPanel].sFileName, "sNewFileName": dPanelList[sPanel].sNewFileName, "pFile": dPanelList[sPanel].pFile, "pDir": dPanelList[sPanel].pDir, "pRelFile": dPanelList[sPanel].pRelFile, "pRelDir": dPanelList[sPanel].pRelDir } )
                oLogger.add("Пропущено", "OLD INNR DATE", dPanelList[sPanel].pRelDir, dPanelList[sPanel].sFileName, "   Internal date: «" dPanelList[sPanel].nInternalDate "»")
                ; Proceed with adding loop panel's data to the panel list. (Because newer internal date.)
            }
        
        } else ( nPanelsTotalUnique += 1 ) ; Proceed with adding loop panel's data to the list because it's a new panel. (dPanelList.HasKey == false)

        dPanelList[sPanel] := { "sName": sPanel, "sFileName": sFileName, "sNewFileName": sNewFileName
                                        , "pFile": pFile, "pDir": pDir, "pRelFile": pRelFile, "pRelDir": pRelDir
                                        , "nInternalDate": nInternalDate, "nFileModifiedDate": nFileModifiedDate, "nNameDate":  nNameDate
                                        , "sFormat": sPanelFormat, "sFileContents": sFileContents}
    }

    fAbort(nFilesTotal != (nPanelsTotalUnique + nFilesSkipped ), A_ThisFunc, "Какие-то фаи̌лы потерялись."
    , { "nFilesTotal": nFilesTotal, "nPanelsTotalUnique": nPanelsTotalUnique
    , "nPanelsProgress": nPanelsProgress, "nPanelsUnitechnik": nPanelsUnitechnik, "nFilesSkipped": nFilesSkipped })
     fAbort(nFilesTotal != ( dPanelList.Count() + aSkippedFiles.Count() ), A_ThisFunc, "Какие-то фаи̌лы потерялись."
	, { "nFilesTotal": nFilesTotal, "dPanelList.Count()": dPanelList.Count(), "aSkippedFiles.Count()": aSkippedFiles.Count() })

    return {"dPanelList": dPanelList, "aSkippedFiles": aSkippedFiles, "isAnyRenamed": isAnyRenamed
    , "nFilesTotal": nFilesTotal, "nPanelsTotalUnique": nPanelsTotalUnique, "nFilesSkipped": nFilesSkipped
    , "nPanelsProgress": nPanelsProgress, "nPanelsUnitechnik": nPanelsUnitechnik}    
}



; Reads Unitechnik panel. Returns [sInternalName, nInternalDate, sFileContents] or "".
fReadPanelU(pPanel) {
    Local

    oFile := FileOpen(pPanel, "r-rwd", "CP1251")
    sContents := oFile.Read()
    oFile.Close()
    fAbort(sContents == "", A_ThisFunc, "Неудалось прочитать фаи̌л.", { "pPanel": pPanel, "sContents": sContents })

    nPos := RegExMatch(sContents, "Sx)^"
    . "HEADER__\r?\n600\r?\n  (?: .++\r?\n){13}"
    . "(?<day>[0123]\d) \. (?<month>[01]\d) \. (?<year>20[012]\d) \r?\n"
    . "(?:.++\r?\n){2}  END\r?\n  SLABDATE\r?\n600\r?\n"
    . "\d? (?<type> [А-Я]{1,6} | В\(к\)) - (?<num> \d+)  \s", sMatch_)
    fAbort(ErrorLevel, A_ThisFunc, "Regex error.")
    If !nPos
        return ""
    fAbort(sMatch_year == "", A_ThisFunc, "Неудалось наи̌ти дату чертежа.", { "pPanel": pPanel, "sContents": sContents })

    nPanelDate := sMatch_year . sMatch_month . sMatch_day
    sPanelType := (sMatch_type == "В(к)") ? "ВК" : sMatch_type
    sPanelNum := LTrim(sMatch_num, "0")
    sPanelName := sPanelType "-" sPanelNum

    return [sPanelName, nPanelDate, sContents]
}

; Reads Progress panel. Returns [sInternalName, nInternalDate, sFileContents] or "".
fReadPanelP(pPanel) {
    Local

    oXML := ComObjCreate("MSXML2.DOMDocument.6.0")
	oXML.async := false, oXML.preserveWhiteSpace := true
    oXML.load(pPanel)
    fAbort(oXML.parseError.errorCode, A_ThisFunc, "Ошибка при чтении PXML-файла."
    , { "pPanel": pPanel, "oXML.parseError.errorCode": oXML.parseError.errorCode, "oXML.parseError.reason": oXML.parseError.reason })
    sContents := oXML.xml

    If !sContents
        return ""
    nPanelDate := oXML.selectSingleNode("/" ns("PXML_Document", "Order", "DrawingDate")).Text
    nPanelDate := SubStr(nPanelDate, 7, 4) . SubStr(nPanelDate, 4, 2) . SubStr(nPanelDate, 1, 2)
    sPanelName := oXML.selectSingleNode("/" ns("PXML_Document", "Order", "Product", "ElementNo")).Text
    sPanelName := RegExReplace(LTrim(sPanelName, "45"), "S)В\(к\)", "ВК")

    return [sPanelName, nPanelDate, sContents]
}

; Tries to get panel name from its file name, if fails returns empty string. Also if there is a date (YY-MM-DD) in the filename
; returns it as well; returns 0 if there isn't one.     Returns: [ panelname, date ]
fGetPanelNameDateFilePath(pFile) {
    Local

    SplitPath, pFile, sFileName, pDir, sExt, sFileNameBare

    ;!!!!!!!!!!!!!!!!!!!  vvv  LATIN => CYRILLIC   vvv  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!;
    aLatinToCyrillic := [ ["ixS) (?<!\.) [a-zа-я]++.", "$U0"] ; Capitalizes everything except file extensions
    , ["^V-", "В-"], ["^VK-", "ВК-"], ["^VC-", "ВЦ-"], ["^VT-", "ВТ-"], ["^NS-", "НС-"], ["^NT-", "НТ-"], ["^NC-", "НЦ-"]
    , ["^P-", "П-"], ["^PV-", "ПВ-"], ["^PG-", "ПГ-"], ["^PK-", "ПК-"], ["^PL-", "ПЛ-"], ["^PT-", "ПТ-"], ["^PC-", "ПЦ-"]
    , ["^SV-", "СВ-"], ["^SVSH-", "СВШ-"], ["^SSH-", "СШ-"], ["^PTKR-", "ПТКР-"], ["^KR-", "КР-"], ["^Z-", "Я-"] ]

    For _, aPair in aLatinToCyrillic
        sFileNameBare := RegExReplace( sFileNameBare, aPair[1], aPair[2] )
    ;!!!!!!!!!!!!!!!!!!!  ^^^  LATIN => CYRILLIC    ^^^  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!;
    
    nPos := RegExMatch(sFileNameBare , "isSx)^\d? (?<type> [а-яА-Я]{1,6} | В\(к\)) - (?<num1> \d+) (?<num2> -\d+)?"
                                                            . "(\s (?<year> [012]\d) - (?<month> [01]\d) - (?<day> [0123]\d) )?", sPanel_)
	fAbort(ErrorLevel, A_ThisFunc, "Regex error.")
    If !nPos
        return ""    
    If ( (sPanel_num2 != "") and (LTrim(sPanel_num1, "0") != LTrim(SubStr(sPanel_num2, 2), "0")) )
	    return ""
    sPanelType := (sPanel_type == "В(к)" or sPanel_type == "В(К)") ? "ВК" : sPanel_type
    StringUpper, sPanelType, sPanelType
    sPanelName := sPanelType "-" LTrim(sPanel_num1, "0") ; Removing leading zeroes.
    
    If ( sPanel_year )
        nPanelDate := "20" sPanel_year sPanel_month sPanel_day
    else nPanelDate := 0

    return [ sPanelName, nPanelDate ]
}