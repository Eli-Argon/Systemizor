class cLogger {
	static sColEnd := "ø", sRowEnd := "ż"
	add(log, cols*) {
		For idx, col in cols
			this[log] .= col . (idx < cols.MaxIndex() ? this.sColEnd : this.sRowEnd)
	}
	save(aLogs) {                                             ; MsgBox % "cLogger.save()"		
		If !isObject(aLogs)
			return                                            ; MsgBox % "cLogger.save(): isObject = true"		
		For idx, log in aLogs {		
			If (this[log] == "") {
				this.del(log)
				continue
			}                                                  ; MsgBox % "sSortedLog: """ sSortedLog """"			
			sSortedLog := this[log], sRowEnd := this.sRowEnd
			Sort, sSortedLog, F fNaturalSort D%sRowEnd%
			
			sPaddedLog := "", pad := []		
			Loop, parse, sSortedLog, % this.sRowEnd
				Loop, parse, A_LoopField, % this.sColEnd
					If (pad[A_Index] < StrLen(A_LoopField))
						pad[A_Index] := StrLen(A_LoopField)
					
			Loop, parse, sSortedLog, % this.sRowEnd
			{
				Loop, parse, A_LoopField, % this.sColEnd
					sPaddedLog .= Format("{:-" pad[A_Index] + 3 "}", A_LoopField)
				sPaddedLog .= "`r`n"
			}

			oLogFile := FileOpen(log ".log", "w-rwd")
			fAbort(!oLogFile, A_ThisFunc, "Ошибка при открытии """ log ".log"".")
			oLogFile.Write(sPaddedLog)
			oLogFile.Close()
		}
	}
	del(aLogs) {
		If !isObject(aLogs)
			return
		For idx, log in aLogs {			
			If FileExist(log ".log") {
				this[log] := ""
				FileDelete, % log ".log"
				fAbort(ErrorLevel, A_ThisFunc, "Ошибка при удалении """ log ".log"".")
			}
		}
	}
}

fAbort(isCondition, sFuncName, sNote, dVars:="") {
	If isCondition {
		sAbortMessage := % sFuncName ": " sNote
		. "`n`nA_LineNumber: """ A_LineNumber """`nErrorLevel: """ ErrorLevel """`nA_LastError: """ A_LastError """`n"
		For sName, sValue in dVars
			sAbortMessage .= "`n" sName ": """ sValue """"
		MsgBox, 16,, % sAbortMessage
		ExitApp
	}
}

fClean(aToDelete) {
	If !isObject(aToDelete)
		return
	For idx, item in aToDelete {
		attrs := FileExist(item)
		If attrs {
			If InStr(attrs, "D", true)
				FileRemoveDir, % item, true				
			else
				FileDelete, % item
			fAbort((ErrorLevel or FileExist(item)), A_ThisFunc, "Ошибка при удалении """ item """.", { "sToDelete": fObjToStr(aToDelete) })
		}
	}	
}

fObjToStr(obj) {
	If !IsObject(obj)
		return obj
	str := "`n{"
	For key, value in obj
		str .= "`n    " key ": " fObjToStr(value) ","
	return str "`n}"
}

fNaturalSort(a, b) {
	return DllCall("shlwapi.dll\StrCmpLogicalW", "ptr", &a, "ptr", &b, "int")
}