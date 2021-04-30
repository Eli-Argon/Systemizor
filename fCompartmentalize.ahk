fCompartmentalize(dResults, pOutputMainDir, pOutputExtraDir, sToSplit) { ; Takes the newest version of each panel,
	Local                                                               ; Removes RODSTOCK and BRGIRDER blocks above REFORCEM,
	Global oLogger                                                     ; The RODSTOCK block with extra reinforcement data is converted
	oLogger.del([ "Пропущено", "Переименовано", "Перенесено" ])       ; to XML by fExtrasize, BRGIRDER is discarded,
																     ; XML files are saved to %pOutputExtraDir%,  
																    ; The main part of the file to %pOutputMainDir%,
	For sPanel, aVers in dResults.dPanelList                       ; Panels in %A_ScriptDir%\sToSplit.txt save their meshes in separately. 
        { ; +++++++++++ Looking for the newest panel version +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		nNewestVerIdx := 1, nDatePrev := 0, nDateComparer := 0
		For idx, dVer in aVers {
			If (idx == 1) {
				nDatePrev := dVer.nDate
			} else {
				nDateComparer := dVer.nDate
				EnvSub, nDateComparer, %nDatePrev%, seconds			
				If (nDateComparer > 0)
					nNewestVerIdx := idx, nDatePrev := dVer.nDate			
			}
		} ; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		
		;;;;;;;;;;;;;;;;;;;;;;;;;; Now we are working with the panel version file that has the latest date ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		dNewest := aVers[nNewestVerIdx] ; { pSauceLoco: a, pRelDir: b, pRelFile: c, nDate: d, sFullName: e }		
		oNewestFile := FileOpen(dNewest.pSauceLoco, "r-rwd", "CP1251"), sSauceContents := oNewestFile.Read()
		oNewestFile.Close()
		fAbort(sSauceContents == "", A_ThisFunc, "Ошибка при чтении source-файла """ dNewest.sFullName """."
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco, "sSauceContents": sSauceContents })
		/* Pattern 1 (VC-17, 23000 steps): sSx)
		^(?<top>   HEADER__\r?\n600\r?\n.+?\r?\nEND\r?\n(?=(?:RODSTOCK|BRGIRDER|REFORCEM)))
		 (?<extra> RODSTOCK\r?\n        .+?\r?\nEND\r?\n(?=(?:BRGIRDER|REFORCEM)))?
		 (?:       BRGIRDER\r?\n        .+?\r?\nEND\r?\n(?=REFORCEM))?
		 (?<mid>   REFORCEM\r?\n600\r?\n.+?\r?\nEND\r?\n(?=STEELMAT))
		 (?<mat1>  STEELMAT\r?\n        .+?\r?\nEND\sSTEELMAT\r?\n)
		 (?<mat2>  (?&mat1))?
		 (?<mat3>  (?&mat1))?
		 (?<bot>   END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$
		*/		
		/* Pattern 2 (VC-17, 433 steps): sSx)
		^(?<top>   HEADER__\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n  (RODSTOCK|BRGIRDER|REFORCEM) ) )++ END\r?\n)
		 (?<extra> RODSTOCK\r?\n         (?: [^E]++ | E (?!ND\r?\n  (         BRGIRDER|REFORCEM) ) )++ END\r?\n)?+
		 (?:       BRGIRDER\r?\n         (?: [^E]++ | E (?!ND\r?\n                     REFORCEM  ) )++ END\r?\n)?+
		 (?<mid>   REFORCEM\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n   STEELMAT                    ) )++ END\r?\n)
		 (?<mat1>  STEELMAT\r?\n         (?: [^E]++ | E (?!ND\sSTEELMAT                          ) )++ END\sSTEELMAT\r?\n)
		 (?<mat2>  (?&mat1))?+
		 (?<mat3>  (?&mat1))?+
		 (?<bot>   END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$
		*/
		pos := RegExMatch(sSauceContents, "sSx)^"
		. "(?<top>   HEADER__\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n  (RODSTOCK|BRGIRDER|REFORCEM) ) )++ END\r?\n)"
		. "(?<extra> RODSTOCK\r?\n         (?: [^E]++ | E (?!ND\r?\n  (         BRGIRDER|REFORCEM) ) )++ END\r?\n)?+"
		. "(?:       BRGIRDER\r?\n         (?: [^E]++ | E (?!ND\r?\n                     REFORCEM  ) )++ END\r?\n)?+"
		. "(?<mid>   REFORCEM\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n   STEELMAT                    ) )++ END\r?\n)"
		. "(?<mat1>  STEELMAT\r?\n         (?: [^E]++ | E (?!ND\sSTEELMAT                          ) )++ END\sSTEELMAT\r?\n)"
		. "(?<mat2>  (?&mat1))?+"
		. "(?<mat3>  (?&mat1))?+"
		. "(?<bot>   END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$", sSauce_)
		fAbort(!pos, A_ThisFunc, "Содержимое source-файла """ dNewest.sFullName """ не опознано."
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco })			
		fAbort(sSauce_mat1 == "", A_ThisFunc, "Не были найдены сетки в source-файле """ dNewest.sFullName """."
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 
		fAbort(sSauce_mat3 != "", A_ThisFunc, "Три сетки в source-файле """ dNewest.sFullName """?"
		, { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 

		pMainFile := pOutputMainDir . dNewest.pRelDir . sPanel
		FileCreateDir, % pOutputMainDir . dNewest.pRelDir
		
		If sPanel in %sToSplit%
		{ ; ############################# If the main file needs to be split in two ########################################################
			fAbort(sSauce_mat2 == "", A_ThisFunc, """" sPanel """ в sToSplit.txt, но найдена только одна сетка."
			, { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 
			sBendingRegex := "xS)\s00[12]\r?\n"
						   . "  \d{3}  (?:\s\d{5}){4}  \s([01][0-8]\d)  \s\d{3}  (?:\s\d{5}){4}  \s(?1)      \s[+-](?1)"
			isBentMat1 := RegExMatch(sSauce_mat1, sBendingRegex), isBentMat2 := RegExMatch(sSauce_mat2, sBendingRegex)
			
			fAbort((isBentMat1 and isBentMat2), A_ThisFunc, "Обе сетки с загибами?", { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 
			fAbort((!isBentMat1 and !isBentMat2), A_ThisFunc, "Обе сетки плоские?", { "dNewest.pSauceLoco": dNewest.pSauceLoco }) 

			sBentContents := sSauce_top . sSauce_mid . (isBentMat1 ? sSauce_mat1 : sSauce_mat2) . sSauce_bot
			sFlatContents := sSauce_top . sSauce_mid . (isBentMat2 ? sSauce_mat1 : sSauce_mat2) . sSauce_bot
			
			oBentFile := FileOpen((pMainFile . "-BENT"), "w-rwd", "CP1251")
			fAbort(!oBentFile, A_ThisFunc, "Ошибка при открытии """ pMainFile "-BENT"".")
			oBentFile.Write(sBentContents)
			oBentFile.Close()
			
			oFlatFile := FileOpen((pMainFile . "-FLAT"), "w-rwd", "CP1251")
			fAbort(!oFlatFile, A_ThisFunc, "Ошибка при открытии """ pMainFile "-FLAT"".")
			oFlatFile.Write(sFlatContents)
			oFlatFile.Close()			
		} else { ; ******************************** If the main file is saved in one piece *************************************************
			sMainContents := sSauce_top . sSauce_mid . sSauce_mat1 . sSauce_mat2 . sSauce_bot
			oMainFile := FileOpen(pMainFile, "w-rwd", "CP1251")
			fAbort(!oMainFile, A_ThisFunc, "Ошибка при открытии """ pMainFile """.")
			oMainFile.Write(sMainContents)
			oMainFile.Close()
		}
		; ========================================= Extra file =============================================================================
		sExtraContents := fExtrasize(sSauce_extra, dNewest.pSauceLoco)
		If (sExtraContents != "") {
			pExtraFile := pOutputExtraDir . dNewest.pRelDir . sPanel ".xml"
			FileCreateDir, % pOutputExtraDir . dNewest.pRelDir
			oExtraFile := FileOpen(pExtraFile, "w-rwd")
			fAbort(!oExtraFile, A_ThisFunc, "Ошибка при открытии """ pExtraFile """.")
			oExtraFile.Write(sExtraContents)
			oExtraFile.Close()
		}
	}
}