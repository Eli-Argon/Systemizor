; Removes RODSTOCK and BRGIRDER blocks above REFORCEM, the RODSTOCK block with extra reinforcement data
; is converted to XML by fExtrasyzeU, BRGIRDER is discarded. XML files are saved to %pOutputExtraDir%,
; the main part of the file to %pOutputMainDir%. Panels in %aPanelsToSplit% save their meshes in separately.
fCompartmentalizeU(dPanel, pOutputMainDir, pOutputExtraDir, aPanelsToSplit) { ; Takes the newest version of each panel,
	Local                                                               
	Global oLogger

    ; Pattern 1 (VC-17, 23000 steps): sSx)
    ; ^(?<top>    HEADER__\r?\n600\r?\n     .+?\r?\nEND\r?\n(?=(?: RODSTOCK | BRGIRDER | REFORCEM )))
    ;  (?<extra>  RODSTOCK\r?\n               .+?\r?\nEND\r?\n(?=(?: BRGIRDER | REFORCEM)))?
    ;  (?:            BRGIRDER\r?\n                 .+?\r?\nEND\r?\n(?=    REFORCEM))?
    ;  (?<mid>    REFORCEM\r?\n600\r?\n    .+?\r?\nEND\r?\n(?=   STEELMAT))
    ;  (?<mat1>  STEELMAT\r?\n                 .+?\r?\nEND\sSTEELMAT\r?\n)
    ;  (?<mat2>  (?&mat1))?
    ;  (?<mat3>  (?&mat1))?
    ;  (?<bot>    END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$
            
    ; Pattern 2 (VC-17, 433 steps): sSx)
    ; ^(?<top>     HEADER__\r?\n600\r?\n   (?: [^E]++ | E (?!ND\r?\n  (RODSTOCK | BRGIRDER | REFORCEM) ) )++ END\r?\n)
    ;  (?<extra>   RODSTOCK\r?\n             (?: [^E]++ | E (?!ND\r?\n  (                     BRGIRDER | REFORCEM) ) )++ END\r?\n)?+
    ;  (?:             BRGIRDER\r?\n              (?: [^E]++ | E (?!ND\r?\n                                             REFORCEM  ) )++ END\r?\n)?+
    ;  (?<mid>     REFORCEM\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n   STEELMAT                                             ) )++ END\r?\n)
    ;  (?<mat1>  STEELMAT\r?\n               (?: [^E]++ | E (?!ND\sSTEELMAT                          ) )++  END\sSTEELMAT\r?\n)
    ;  (?<mat2>  (?&mat1))?+
    ;  (?<mat3>  (?&mat1))?+
    ;  (?<bot>     END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$
    
    nPos := RegExMatch(dPanel.sFileContents, "sSx)^"
    . "(?<top>     HEADER__\r?\n600\r?\n   (?: [^E]++ | E (?!ND\r?\n  (RODSTOCK | BRGIRDER | REFORCEM) ) )++ END\r?\n)"
    . "(?<extra>   RODSTOCK\r?\n             (?: [^E]++ | E (?!ND\r?\n  (                     BRGIRDER | REFORCEM) ) )++ END\r?\n)?+"
    . "(?:             BRGIRDER\r?\n              (?: [^E]++ | E (?!ND\r?\n                                             REFORCEM  ) )++ END\r?\n)?+"
    . "(?<mid>     REFORCEM\r?\n600\r?\n (?: [^E]++ | E (?!ND\r?\n   STEELMAT                                             ) )++ END\r?\n)"
    . "(?<mat1>  STEELMAT\r?\n               (?: [^E]++ | E (?!ND\sSTEELMAT                          ) )++  END\sSTEELMAT\r?\n)"
    . "(?<mat2>  (?&mat1))?+"
    . "(?<mat3>  (?&mat1))?+"
    . "(?<bot>     END\sREFORCEM\r?\nEND\sSLABDATE\r?\nEND\sHEADER__)$", sSauce_)

    fAbort(ErrorLevel, A_ThisFunc, "Regex error.")
    fAbort(!nPos, A_ThisFunc, "Содержимое «" dPanel.sName "» не опознано.", { "dPanel.pFile": dPanel.pFile })			
    fAbort(sSauce_mat1 == "", A_ThisFunc, "Не были найдены сетки в «" dPanel.sName "».", { "dPanel.pFile": dPanel.pFile }) 
    fAbort(sSauce_mat3 != "", A_ThisFunc, "Три сетки в «" dPanel.sName "»?", { "dPanel.pFile": dPanel.pFile }) 

    pMainFile := pOutputMainDir . dPanel.pRelDir . dPanel.sName
    FileCreateDir, % pOutputMainDir . dPanel.pRelDir

    shouldSplit := false
    For _, sPanelName in aPanelsToSplit {
        If dPanel.sName == sPanelName
            shouldSplit := true
    }
    
    If shouldSplit { ; ################## If the main file needs to be split in two ##################################### ;
        fAbort(sSauce_mat2 == "", A_ThisFunc, "«" dPanel.sName "» в списке «Split», но найдена только одна сетка."
        , { "dPanel.pFile": dPanel.pFile }) 
        sBendingRegex := "xS)\s00[12]\r?\n"
                        . "  \d{3}  (?:\s\d{5}){4}  \s([01][0-8]\d)  \s\d{3}  (?:\s\d{5}){4}  \s(?1)      \s[+-](?1)"
        isBentMat1 := RegExMatch(sSauce_mat1, sBendingRegex), isBentMat2 := RegExMatch(sSauce_mat2, sBendingRegex)
        
        fAbort( ( isBentMat1 and isBentMat2), A_ThisFunc, "Обе сетки с загибами?", { "dPanel.pFile": dPanel.pFile } ) 
        fAbort( ( !isBentMat1 and !isBentMat2), A_ThisFunc, "Обе сетки плоские?", { "dPanel.pFile": dPanel.pFile } ) 

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
    } else { ; ************************ If the main file is saved in one piece ************************************** ;
        sMainContents := sSauce_top . sSauce_mid . sSauce_mat1 . sSauce_mat2 . sSauce_bot
        oMainFile := FileOpen(pMainFile, "w-rwd", "CP1251")
        fAbort(!oMainFile, A_ThisFunc, "Ошибка при открытии """ pMainFile """.")
        oMainFile.Write(sMainContents)
        oMainFile.Close()
    }
    ; =================================== Extra file ========================================== ;
    sExtraContents := fExtrasyzeU(sSauce_extra, dPanel.pFile)
    If (sExtraContents != "") {
        pExtraFile := pOutputExtraDir . dPanel.pRelDir . dPanel.sName ".xml"
        FileCreateDir, % pOutputExtraDir . dPanel.pRelDir
        oExtraFile := FileOpen(pExtraFile, "w-rwd")
        fAbort(!oExtraFile, A_ThisFunc, "Ошибка при открытии """ pExtraFile """.")
        oExtraFile.Write(sExtraContents)
        oExtraFile.Close()
    }
	
    return ( shouldSplit ? 1 : 0 )
}

 ; Converts a RODSTOCK block with extra reinforcement data from UNITECHNIK to XML. Sorts bars first by length,
 ; then by diameter. Returns XML string.
fExtrasyzeU(sExtra, pFile) {
	Local
	sTemplateTop =
(
<xml xmlns:s='uuid:BDC6E3F0-6DA3-11d1-A2A3-00AA00C14882'
	xmlns:dt='uuid:C2F41010-65B3-11d1-A29F-00AA00C14882'
	xmlns:rs='urn:schemas-microsoft-com:rowset'
	xmlns:z='#RowsetSchema'>
<s:Schema id='RowsetSchema'>
	<s:ElementType name='row' content='eltOnly' rs:updatable='true'>
		<s:AttributeType name='AH_Typ' rs:number='18' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='AH_Typ'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='AuftragID' rs:number='30' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='AuftragID'>
			<s:datatype dt:type='string' dt:maxLength='255'/>
		</s:AttributeType>
		<s:AttributeType name='AZ_ID' rs:number='32' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='AZ_ID'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='B_Win' rs:number='23' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='B_Win'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Bewehrung' rs:number='24' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Bewehrung'>
			<s:datatype dt:type='string' dt:maxLength='5'/>
		</s:AttributeType>
		<s:AttributeType name='BGForm' rs:number='25' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='BGForm'>
			<s:datatype dt:type='bin.hex' dt:maxLength='1073741823' rs:long='true'/>
		</s:AttributeType>
		<s:AttributeType name='BGSammler' rs:number='17' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='BGSammler'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Biegetyp' rs:number='12' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Biegetyp'>
			<s:datatype dt:type='string' dt:maxLength='255'/>
		</s:AttributeType>
		<s:AttributeType name='Changed' rs:number='27' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Changed'>
			<s:datatype dt:type='dateTime' rs:dbtype='variantdate' dt:maxLength='16' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Dateiname' rs:number='1' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='Matten'
			 rs:basecolumn='Dateiname'>
			<s:datatype dt:type='string' dt:maxLength='250'/>
		</s:AttributeType>
		<s:AttributeType name='Draht' rs:number='8' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Draht'>
			<s:datatype dt:type='string' dt:maxLength='15'/>
		</s:AttributeType>
		<s:AttributeType name='Error' rs:number='19' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Error'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Exectime' rs:number='39' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Exectime'>
			<s:datatype dt:type='float' dt:maxLength='8' rs:precision='15' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Fach' rs:number='14' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Fach'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Flags' rs:number='6' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Flags'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='GlobalID' rs:number='16' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='GlobalID'>
			<s:datatype dt:type='string' dt:maxLength='15'/>
		</s:AttributeType>
		<s:AttributeType name='ID' rs:number='3' rs:maydefer='true' rs:writeunknown='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ID' rs:autoincrement='true'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='ImportID' rs:number='15' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ImportID'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Istmenge' rs:number='11' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Istmenge'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='KundeID' rs:number='29' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='KundeID'>
			<s:datatype dt:type='string' dt:maxLength='255'/>
		</s:AttributeType>
		<s:AttributeType name='LenData' rs:number='40' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='LenData'>
			<s:datatype dt:type='string' dt:maxLength='20'/>
		</s:AttributeType>
		<s:AttributeType name='ListenNr' rs:number='26' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ListenNr'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Matrize' rs:number='9' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Matrize'>
			<s:datatype dt:type='string' dt:maxLength='2'/>
		</s:AttributeType>
		<s:AttributeType name='Matte' rs:number='36' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Matte'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='MatteID' rs:number='33' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='MatteID'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Palette' rs:number='34' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Palette'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='PaletteID' rs:number='31' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='PaletteID'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Platte' rs:number='35' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Platte'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='PlatteName' rs:number='42' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='PlatteName'>
			<s:datatype dt:type='string' dt:maxLength='20'/>
		</s:AttributeType>
		<s:AttributeType name='Pos' rs:number='7' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Pos'>
			<s:datatype dt:type='string' dt:maxLength='255'/>
		</s:AttributeType>
		<s:AttributeType name='ProdDraht' rs:number='13' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ProdDraht'>
			<s:datatype dt:type='string' dt:maxLength='15'/>
		</s:AttributeType>
		<s:AttributeType name='ProdRotor' rs:number='43' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ProdRotor'>
			<s:datatype dt:type='string' dt:maxLength='15'/>
		</s:AttributeType>
		<s:AttributeType name='ProductSize' rs:number='38' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ProductSize'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Reihe' rs:number='28' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Reihe'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Sollmenge' rs:number='10' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Sollmenge'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Status' rs:number='4' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Status'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='TischNr' rs:number='41' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='TischNr'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='TLen' rs:number='37' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='TLen'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Typ' rs:number='5' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='Typ'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='Typ_' rs:number='2' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='Matten'
			 rs:basecolumn='Typ_'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='XPos' rs:number='20' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='XPos'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='YPos' rs:number='21' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='YPos'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:AttributeType name='ZPos' rs:number='22' rs:nullable='true' rs:maydefer='true' rs:write='true' rs:basetable='ProdZeilen'
			 rs:basecolumn='ZPos'>
			<s:datatype dt:type='int' dt:maxLength='4' rs:precision='10' rs:fixedlength='true'/>
		</s:AttributeType>
		<s:extends type='rs:rowbase'/>
	</s:ElementType>
</s:Schema>
<rs:data>

)
	sTemplateBot =
(
</rs:data>
</xml>
)
	If (sExtra == "")
		return ""
    pos := RegExMatch(sExtra, "sSxD)"
				. "^RODSTOCK\r?\n600\r?\n\d{3}\r?\n"
				. "(?<data> \d{3}\s  \d{3}\s  \d\s  [A-Za-z0-9\s]{10}\s (?:\d{5})\s  (?:\d{3})\s  (?:\d{5})\s" ; quantity, diameter, length
				. "[+-]\d{5}\s  [+-]\d{5}\s  [+-]\d{5}\s  [+-]\d{3}\s  [A-Za-z0-9\s]{10}\s  [012]\r?\n"
				. "\d{3}\s  \d{3}\s  \d{3}\s  \d{5}\s  \d{5}\s  \d{5}\s  00[012]\r?\n)*"
				. "END\r?\n$", sExtra_)            
	fAbort(!pos, A_ThisFunc, "Блок с усилениями не опознан.", { "pFile": pFile, "sExtra": sExtra })
	If (sExtra_data == "")
		return ""          ; If no bars, reture empty string.

    ; #########################  vvv  Making a list of extra reinforcement  vvv  ####################################### ;
    dList := {}
    Loop, parse, sExtra, `n, `r
	{
		If ( StrLen( A_LoopField ) < 75 ) 
			continue
		nBarLength := 0 + SubStr( A_LoopField, 32, 5 ), nBarDiameter := 0 + SubStr( A_LoopField, 28, 3 )
		bar := nBarLength "-" nBarDiameter
		
		If ( dList[bar] != "" )
			dList[bar]["quantity"] += SubStr( A_LoopField, 22, 5 ) 
		else
			dList[bar] := { "length": nBarLength, "diameter": nBarDiameter, "quantity": ( 0 + SubStr(A_LoopField, 22, 5) ) }
	}

    ; +++++++++++++++++++  vvv  Sorting the list of extra reinforcement  vvv  +++++++++++++++++++++++++++++++++++ ;
    aSortedList := []
    For _, value in dList
        aSortedList.Push(value)
    stop := 1
    Loop {
        stop := 1
        Loop % aSortedList.Length() - 1
        {            
            If (aSortedList[A_Index]["length"] < aSortedList[A_Index+1]["length"])                       ; If the next bar is longer,
            or ((aSortedList[A_Index]["length"] = aSortedList[A_Index+1]["length"])                     ; Or same length
            			and (aSortedList[A_Index]["diameter"] < aSortedList[A_Index+1]["diameter"])) ; but wider diameter.
            {
                rv := aSortedList.RemoveAt( A_Index + 1 ), aSortedList.InsertAt( A_Index, rv ), stop := 0
                break
            }
        }
    } until stop

	; ///////////////////////////////  vvv  Now we create the XML file's contents vvv  ////////////////////////////////////////////////////////// ;
    sExtraXml := sTemplateTop
	
    For i, dRowData in aSortedList {
		; 13 - 0d00, 14 - 0e00, 15 - 0f00, 16 - 1000, 17 - 1100, 18 - 1200, 19 - 1300
		; 254 - fe00, 255 - ff00, 256 - 0001, 257 - 0101, 258 - 0201
		; 4093 - fd0f, 4094 - fe0f, 4095 - ff0f, 4096 - 0010, 4097 - 0110, 4098 - 0210, 4099 - 0310
		; 8998 - 2623, 8999 - 2723, 9000 - 2823, 9001 - 2923, 9002 - 2a23, 65535 - , 65536 - 000001, 65537 - 010001
	
        biegetyp := dRowData["length"], draht := dRowData["diameter"], sollmenge := dRowData["quantity"]
		hexa := Format("{:06x}", biegetyp) ; Length is formatted as a hexadecimal fixed length (6) number, padded with zeroes
		hexa1 := SubStr(hexa, 5, 2), hexa2 := SubStr(hexa, 3, 2), hexa3 := SubStr(hexa, 1, 2)
        row =
(
%A_Tab%<z:row AH_Typ='0' AuftragID='' BGForm='1e00000001000000000100000000000000000000000000000000000000001c000000
%A_Tab%%A_Tab%024c310100000000%hexa1%%hexa2%%hexa3%00000000000000000001000000' Biegetyp='%biegetyp%' Changed='%A_Year%-%A_Mon%-%A_MDay%T%A_Hour%:%A_Min%:%A_Sec%' Draht='%draht%' Exectime='0'
%A_Tab%%A_Tab%%A_Space%Flags='0' ID='%i%' Istmenge='0' KundeID='' LenData='0' ListenNr='2' Matrize='' Matte='0' MatteID='0' Palette='0'
%A_Tab%%A_Tab%%A_Space%PaletteID='0' Platte='0' ProdDraht='' ProductSize='%biegetyp%' Reihe='%i%' Sollmenge='%sollmenge%' Status='1' TLen='%biegetyp%' Typ='5'/>

)
        sExtraXml .= row
    }
	
    sExtraXml .= sTemplateBot

    return sExtraXml
}