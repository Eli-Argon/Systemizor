fSystemize(dResults, pOutputDir) {
    Local
	Global oLogger
    nCopied := 0
    For sPanel, aVersions in dResults.dPanelList
    {
		For idx, dVersion in aVersions {
			FileCreateDir, % pOutputDir . dVersion.pRelDir
			pSauceFileDesto := pOutputDir . dVersion.pRelFile
			If not FileExist(pSauceFileDesto) {
				FileCopy, % dVersion.pSauceLoco, % pSauceFileDesto, false
				fAbort(ErrorLevel, A_ThisFunc, "Ошибка при копировании """ dVersion.pSauceLoco """ в """ pSauceFileDesto """")
				If not ErrorLevel
					nCopied++
				
			}
		}
    }
	oLogger.save([ "Пропущено", "Переименовано", "Перенесено" ])
    fAbort(nCopied != dResults.nTotalFiles, A_ThisFunc, "По некоторым причинам некоторые файлы были пропущены."
	, {"dResults.nTotalFiles": dResults.nTotalFiles, "dResults.nSystemized": dResults.nSystemized
	, "dResults.nChaotic": dResults.nChaotic, "dResults.nSkipped": dResults.nSkipped, "nCopied": nCopied })
}