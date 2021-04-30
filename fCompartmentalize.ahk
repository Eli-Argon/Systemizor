fCompartmentalize(dResults, pOutputMainDir, pOutputExtraDir, sToSplit) { ; Takes the newest version of each panel,
	Local                                                               ; Removes RODSTOCK and BRGIRDER blocks above REFORCEM,
	Global oLogger                                                     ; The RODSTOCK block with extra reinforcement data is converted
	oLogger.del([ "Пропущено", "Переименовано"                        ; to XML by fExtrasyze, BRGIRDER is discarded,
				, "Перенесено", "Переделано" ])			             ; XML files are saved to %pOutputExtraDir%,  
	oXml := ComObjCreate("MSXML2.DOMDocument.6.0")                  ; The main part of the file to %pOutputMainDir%,
	oXml.async := false                                            ; Panels in %A_ScriptDir%\sToSplit.txt save their meshes separately. 
	oXml.preserveWhiteSpace := true
    nPanelsSplit := 0
																    
	For sPanel, aVers in dResults.dPanelList {
		nNewestVerIdx := 1, nDatePrev := 0, nDateComparer := 0
		For idx, dVer in aVers {  ; +++++++++++ Looking for the newest panel version +++++++++++
			If (idx == 1) {
				nDatePrev := dVer.nDate
			} else {
				nDateComparer := dVer.nDate
				EnvSub, nDateComparer, %nDatePrev%, seconds			
				If (nDateComparer > 0)
					nNewestVerIdx := idx, nDatePrev := dVer.nDate			
			}
		} ; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		
		;;;;;; Now we are working with the panel version file that has the latest date ;;;;;;;;;
		dNewest := aVers[nNewestVerIdx] ; { pSauceLoco: a, isPXML: b, pRelDir: c, pRelFile: d, nDate: e, sFullName: f }		
		oXml.load(dNewest.pSauceLoco)
		fAbort(oXml.parseError.errorCode, A_ThisFunc
		, "Ошибка при чтении source-файла """ dNewest.sFullName """."
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco
		, "oXml.parseError.errorCode": oXml.parseError.errorCode
		, "oXml.parseError.reason": oXml.parseError.reason })
		
		nSteelNodes := 0, hasFlat := false, hasBent := false, hasExtra := false
		oSteelExtra := "", oSteelBent := "", oSteelFlat := ""
		For oSteel in oXml.selectNodes("/" ns("PXML_Document","Order","Product","Slab","Steel")) {
			nSteelNodes++

			If (oSteel.getAttribute("Type") == "none") { ;===== An extra reinforcement node ====
				fAbort(hasExtra, A_ThisFunc, "Два комплекта усилении̌ в """ dNewest.sFullName """?", { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 
				hasExtra := true, oSteelExtra := oSteel.parentNode.removeChild(oSteel)
				sExtraContents := fExtrasyze(oSteelExtra, dNewest.pSauceLoco)
                If (sExtraContents != "") {
                    pExtraFile := pOutputExtraDir . dNewest.pRelDir . sPanel ".xml"
                    FileCreateDir, % pOutputExtraDir . dNewest.pRelDir
                    oExtraFile := FileOpen(pExtraFile, "w-rwd")
                    fAbort(!oExtraFile, A_ThisFunc, "Ошибка при открытии """ pExtraFile """.")
                    oExtraFile.Write(sExtraContents)
                    oExtraFile.Close()
                }
			}
			
			If (oSteel.getAttribute("Type") == "mesh") { ;========= A mesh node ================
				isBent := false ; True if this particular mesh has bent bars
				For oBar in oSteel.selectNodes(ns("Bar")) { ; Checking if mesh is bent.
					If (oBar.selectNodes(ns("Segment")).length > 1) {
						fAbort(hasBent, A_ThisFunc, "Две гнутых сетки в """ dNewest.sFullName """?", { "dNewest.pSauceLoco": dNewest.pSauceLoco })
						isBent := true, hasBent := true, oSteelBent := oSteel
						break
					}
				}
				If (!isBent) { ; If bent bars have not been found in this mesh.
					fAbort(hasFlat, A_ThisFunc, "Две плоских сетки в """ dNewest.sFullName """?", { "dNewest.pSauceLoco": dNewest.pSauceLoco })
					hasFlat := true, oSteelFlat := oSteel
				}
			} ;==================================== A mesh node ================================
		} ; For loop: looking for Steel nodes in the PXML document
	
		fAbort(nSteelNodes == 0, A_ThisFunc, "Нет сеток в source-файле """ dNewest.sFullName """?"
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 
		fAbort(nSteelNodes > 3, A_ThisFunc, "Три сетки в source-файле """ dNewest.sFullName """?"
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 

		pMainFile := pOutputMainDir . dNewest.pRelDir . sPanel
		FileCreateDir, % pOutputMainDir . dNewest.pRelDir
		
		If sPanel in %sToSplit%
		{ ; ############### If the main file needs to be split in two ##########################
			fAbort(nSteelNodes == 1, A_ThisFunc, """" sPanel """ в sToSplit.txt, но найдена только одна сетка."
			, { "dNewest.pSauceLoco": dNewest.pSauceLoco })
            nPanelsSplit++

			oSteelFlat := oSteelFlat.parentNode.removeChild(oSteelFlat)
			oXml.save(pMainFile . "-BENT.pxml")
			; fAbort(!FileExist(pMainFile . "-BENT.pxml"), A_ThisFunc
            ; , "Ошибка при создании """ pMainFile "-BENT"".")

			oSteelBent.parentNode.appendChild(oSteelFlat)
			oSteelBent.parentNode.removeChild(oSteelBent)
			oXml.save(pMainFile . "-FLAT.pxml")		
			; fAbort(!FileExist(pMainFile . "-FLAT.pxml"), A_ThisFunc
            ; , "Ошибка при создании """ pMainFile "-FLAT"".")
			
		} else { ; ************** If the main file is saved in one piece ***********************
			oXml.save(pMainFile ".pxml")
			; fAbort(!FileExist(pMainFile), A_ThisFunc, "Ошибка при создании """ pMainFile """.")
		}		
	}

    return nPanelsSplit ; Returns the number of panels whose meshes were saved separately.
}

ns(aNodeNames*) { ; Some XML namespace bullshit
    Local
    sSelector := ""
    For idx, sNodeName in aNodeNames {
        If (A_Index > 1)
            sSelector .= "/"
        sSelector .= "*[namespace-uri()=""http://progress-m.com/ProgressXML/Version1"" and local-name()=""" sNodeName """]"
    }
    return sSelector
}