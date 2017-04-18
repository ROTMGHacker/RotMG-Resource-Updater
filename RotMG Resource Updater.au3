
#comments-start
	Copyright (c) 2017 RotMGHacker

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
	of the Software, and to permit persons to whom the Software is furnished to do so,
	subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies
	or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
	INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
	PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
	FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
	OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
	DEALINGS IN THE SOFTWARE.

	Copyright (c) 2017 RotMGHacker

	GitHub username: RotMGHacker
	GitHub repository name: RotMG-Resource-Updater

#comments-end

#NoTrayIcon
#RequireAdmin

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Fileversion=1.1.1.0
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /sf /sv /rm /rsln
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Array.au3>
#include <AutoItConstants.au3>
#include <File.au3>
#include <FileConstants.au3>
#include <GDIPlus.au3>
#include <WinHttp.au3>
#include <WinHttpConstants.au3>
#include <Crypt.au3>

Global Const $VERSION = "1.1.1" ; Remember to increment!
Global Const $UseResExtractor = False ; Use ResExtractor instead of using RABCDAsm directly
Global Const $LogToFile = True
Global Const $HashAlg = $CALG_MD5

; These are IDs which dont work and shoud be ignored by the script
Global Const $aInvalid[] = []

Global $ErrorCount = 0
Global $ErrorMissingFiles[0]
Global $ClientVersion = ""

If $LogToFile Then
	Global $fhLogFile = FileOpen("RotMG Resource Updater.log", $FO_OVERWRITE + $FO_CREATEPATH)
EndIf

_Log("RotMG Resource Updater " & $VERSION & " by RotMGHacker released for MPGH.net" & @CRLF)

; Get Paths
Global $KRelayLibPath = IniRead("Config.ini", "Paths", "KRelay", @ScriptDir & "\KRelay\Lib K Relay\Resources")
Global $MuleDumpPath = IniRead("Config.ini", "Paths", "muledump", @ScriptDir & "\muledump\lib")
If $UseResExtractor Then
	Global $ResExtractorPath = IniRead("Config.ini", "Paths", "ResExtractor", @ScriptDir & "\ResExtractor")
Else
	Global $RABCDAsmPath = IniRead("Config.ini", "Paths", "RABCDAsm", @ScriptDir & "\RABCDAsm")
EndIf

; First time launch
If Not FileExists("Config.ini") Then
	$KRelayLibPath = FileSelectFolder("Select your KRelay\Lib K Relay\Resource folder", $KRelayLibPath)
	$MuleDumpPath = FileSelectFolder("Select your Muledump\lib folder", $MuleDumpPath)
	If $UseResExtractor Then
		$ResExtractorPath = FileSelectFolder("Select your ResExtractor", $ResExtractorPath)
	Else
		$RABCDAsmPath = FileSelectFolder("Select your RABCDAsm folder", $RABCDAsmPath)
	EndIf
EndIf

; Make sure our paths are valid!
While True
	If _CheckForValidPaths() Then
		ExitLoop
	Else
		If $UseResExtractor Then
			$ResExtractorPath = FileSelectFolder("Select your ResExtractor folder", $ResExtractorPath)
		Else
			$RABCDAsmPath = FileSelectFolder("Select your RABCDAsm folder", $RABCDAsmPath)
		EndIf

		$ErrorCount = 0
	EndIf
WEnd

_SaveIni()

Local $WorkingDirectory
If $UseResExtractor Then
	$WorkingDirectory = $ResExtractorPath
Else
	$WorkingDirectory = $RABCDAsmPath
EndIf

; CleanUp
If $UseResExtractor Then
	FileDelete($WorkingDirectory & "\client.swf")
	FileDelete($WorkingDirectory & "\abcdata.abc")
	DirRemove($WorkingDirectory & "\abcdata", $DIR_REMOVE)
Else
	FileDelete($WorkingDirectory & "\client.swf")
	FileDelete($WorkingDirectory & "\client-0.abc")
	DirRemove($WorkingDirectory & "\client-0", $DIR_REMOVE)
EndIf

; Open needed handles
Local $hOpen = _WinHttpOpen()
Local $hConnect = _WinHttpConnect($hOpen, "realmofthemadgod.com")

; Grab version
Local $RotMGVersion = _WinHttpSimpleRequest($hConnect, "GET", "version.txt", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False)

_Log("RotMGVersion: " & $RotMGVersion)

_Log("Downloading Client.swf...")

_WinHttpCloseHandle($hConnect)
$hConnect = _WinHttpConnect($hOpen, "realmofthemadgodhrd.appspot.com")

Local $hClient = _WinHttpSimpleRequest($hConnect, "GET", "AssembleeGameClient" & $RotMGVersion & ".swf", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False, 2) ; <- Binary mode

If @error = 0 Then
	Local $fHandle = FileOpen($WorkingDirectory & "\client.swf", $FO_CREATEPATH + $FO_OVERWRITE)
	FileWrite($fHandle, $hClient)
	FileClose($fHandle)

	_Log("Successfully downloaded Client.swf")
Else
	_LogError("Coudnt download Client.swf")
	_LogMissingFile("client.swf")
EndIf

_WinHttpCloseHandle($hConnect)

If $UseResExtractor Then
	_Log("Running ResExtractor...")

	Local $PID = Run($WorkingDirectory & "\ResExtractor.exe client.swf", $WorkingDirectory, @SW_SHOW, $STDIN_CHILD + $STDOUT_CHILD)

	While True
		Local $sOutput = StdoutRead($PID)
		If @error Or $sOutput <> "" Then ; Wait until ResExtractor askes for input
			ExitLoop
		EndIf
	WEnd

	StdinWrite($PID, "1" & @CRLF) ; Select Unpack all mode

	While True
		Local $sOutput = StdoutRead($PID)
		If @error Then ; StdoutRead will set @error once ResExtractor is finished
			ExitLoop
		EndIf
	WEnd

	FileMove($WorkingDirectory & "\tiles.xml", $KRelayLibPath & "\tiles.xml", $FC_OVERWRITE + $FC_CREATEPATH)
	FileMove($WorkingDirectory & "\packets.xml", $KRelayLibPath & "\packets.xml", $FC_OVERWRITE + $FC_CREATEPATH)
	FileMove($WorkingDirectory & "\objects.xml", $KRelayLibPath & "\objects.xml", $FC_OVERWRITE + $FC_CREATEPATH)

	_Log("Successfully extracted tiles.xml, packets.xml and objects.xml")
Else
	; Decompile our client
	_Log("Decompressing client...")
	RunWait($RABCDAsmPath & "\swfdecompress.exe client.swf", $RABCDAsmPath, @SW_SHOW)
	_Log("Exporting abc...")
	RunWait($RABCDAsmPath & "\abcexport.exe client.swf", $RABCDAsmPath, @SW_SHOW)
	_Log("Decompiling client...")
	RunWait($RABCDAsmPath & "\rabcdasm.exe client-0.abc", $RABCDAsmPath, @SW_SHOW)

	; Display client Version
	If FileExists($RABCDAsmPath & "\client-0\com\company\assembleegameclient\parameters\Parameters.class.asasm") Then
		Local $aRegExpr = StringRegExp(FileRead($RABCDAsmPath & "\client-0\com\company\assembleegameclient\parameters\Parameters.class.asasm"), '(?i)(?s)trait const QName\(PackageNamespace\(""\), "BUILD_VERSION"\) slotid \d+ type QName\(PackageNamespace\(""\), "String"\) value Utf8\("(.*?)"\) end.*?trait const QName\(PackageNamespace\(""\), "MINOR_VERSION"\) slotid \d+ type QName\(PackageNamespace\(""\), "String"\) value Utf8\("(.*?)"\) end', $STR_REGEXPARRAYGLOBALMATCH)

		$ClientVersion = $aRegExpr[0] & "." & $aRegExpr[1]
		_Log("Client version: " & $aRegExpr[0] & "." & $aRegExpr[1])
	EndIf

	; Create packets.xml
	_Log("Creating packets.xml...")
	Local $sGameSeverPath

	If Not FileExists($RABCDAsmPath & "\client-0\kabam\rotmg\messaging\impl\GameServerConnection.class.asasm") Then
		_Log("Looking for 'GameServerConnection.class.asasm'...")

		$aFileList = _FileListToArrayRec($RABCDAsmPath & "\client-0", "GameServerConnection.class.asasm", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)

		If Not @error Then
			$sGameSeverPath = $aFileList[1] ; we really shoud only get 1 entry

			_Log("Found 'GameServerConnection.class.asasm' at """ & $sGameSeverPath & '"')
		Else
			_LogError("Coudnt find 'GameServerConnection.class.asasm' at """ & $RABCDAsmPath & '\client-0"')
		EndIf
	Else
		$sGameSeverPath = $RABCDAsmPath & "\client-0\kabam\rotmg\messaging\impl\GameServerConnection.class.asasm"
		_Log("Found 'GameServerConnection.class.asasm' at """ & $sGameSeverPath & '"')
	EndIf

	If FileExists($sGameSeverPath) Then
		$fHandle = FileOpen($sGameSeverPath, $FO_READ + $FO_UTF8)
		$fRead = FileRead($fHandle)
		FileClose($fHandle)

		Local $aPackets = StringRegExp($fRead, '(?i)(?s)trait const QName\(PackageNamespace\(""\), "([^)]+)"\) slotid \d+ type QName\(PackageNamespace\(""\), "int"\) value Integer\(([^)]+)\) end', $STR_REGEXPARRAYGLOBALMATCH)

		If @error = 0 Then
			_Log("Found " & UBound($aPackets) / 2 & " packets")

			$fHandle = FileOpen($KRelayLibPath & "\packets.xml", $FO_CREATEPATH + $FO_OVERWRITE)
			FileWrite($fHandle, "<Packets>" & @CRLF)

			For $i = 0 To UBound($aPackets) - 1 Step 2
				FileWrite($fHandle, "  <Packet>" & @CRLF & "    <PacketName>" & $aPackets[$i] & "</PacketName>" & @CRLF & "    <PacketID>" & $aPackets[$i + 1] & "</PacketID>" & @CRLF & "  </Packet>" & @CRLF)
			Next

			FileWrite($fHandle, "</Packets>")

			_Log("Successfully created packets.xml")

		Else
			_LogError("Coudnt read packets.")
			_LogMissingFile("packets.xml")
		EndIf
	Else
		_LogMissingFile("packets.xml")
	EndIf

	; Create tiles.xml
	_Log("Creating tiles.xml...")

	$fHandle = FileOpen($RABCDAsmPath & "\client.swf", $FO_READ + $FO_ANSI)
	Local $fRead = FileRead($fHandle)
	FileClose($fHandle)

	$aRegExpr = StringRegExp($fRead, '(?i)(?s)<GroundTypes>(.*?)\R</GroundTypes>', $STR_REGEXPARRAYGLOBALMATCH)
	If Not @error Then

		$fHandle = FileOpen($KRelayLibPath & "\tiles.xml", $FO_OVERWRITE + $FO_CREATEPATH)
		FileWrite($fHandle, '<?xml version="1.0" encoding="ISO-8859-1"?>' & @CRLF & @CRLF & '<GroundTypes>' & $aRegExpr[UBound($aRegExpr) - 1] & @CRLF & '</GroundTypes>' & @CRLF)
		FileClose($fHandle)

		_Log("Successfully created tiles.xml...")
	Else
		_LogError("Coudnt get GroundTyües from client.swf")
		_LogMissingFile("tiles.xml")
	EndIf

	; Create objects.xml
	_Log("Creating objects.xml...")

	$aRegExpr = StringRegExp($fRead, '(?i)(?s)<Objects>(.*?)\R</Objects>', $STR_REGEXPARRAYGLOBALMATCH)
	If Not @error Then

		$fHandle = FileOpen($KRelayLibPath & "\objects.xml", $FO_OVERWRITE + $FO_CREATEPATH)
		FileWrite($fHandle, "<Objects>")

		For $i = 0 To UBound($aRegExpr) - 1 Step 1
			FileWrite($fHandle, $aRegExpr[$i])
		Next

		FileWrite($fHandle, @CRLF & "</Objects>" & @CRLF)
		FileClose($fHandle)

		_Log("Successfully created objects.xml")
	Else
		_LogError("Coudnt get Objects from client.swf")
		_LogMissingFile("objects.xml")
	EndIf
EndIf

$hObjects = FileRead($KRelayLibPath & "\objects.xml")

_Log("Creating constants.js...")

; Create constants.js
Local $fHandle = FileOpen($MuleDumpPath & "\constants.js", $FO_CREATEPATH + $FO_OVERWRITE)

; File Header
FileWrite($fHandle, "// type: [id, slot, tier, x, y, famebonus, feedpower]" & @CRLF & "items = {" & @CRLF & "'-1'" & ': ["empty slot", 0, -1, 0, 0, 0, 0],' & @CRLF)

; Get all Objects
;~ Local $aObjects = StringRegExp($hObjects, '(?i)(?s)(<Object*.?>.*?</Object>)', $STR_REGEXPARRAYGLOBALMATCH)
Local $aObjects = StringSplit($hObjects, "</Object>", $STR_ENTIRESPLIT)
_Log("Found " & $aObjects[0] & " objects")

Const Enum $itType, $itID, $itSlot, $itTier, $itFeedPower, $itFameBonus, $itMax
Global $aItems[0][$itMax]

Local $iItemsCount = 0

For $i = 1 To $aObjects[0] Step 1
	; Get Type, ID, Slot for Object of type Equipment or Dye
	Local $aRegExpr = StringRegExp($aObjects[$i], '(?i)(?s)<Object type="(.*?)" id="(.*?)".*?<Class>(?:Equipment|Dye)</Class>.*?<SlotType>(.*?)</SlotType>', $STR_REGEXPARRAYGLOBALMATCH)

	; Skip all IDs which are marked as Invalid and not of class Equipment or Dye
	If Not @error And Not _MatchesAny($aRegExpr[0], $aInvalid) Then
		ReDim $aItems[UBound($aItems) + 1][$itMax]

		$aItems[UBound($aItems) - 1][$itType] = $aRegExpr[0]
		$aItems[UBound($aItems) - 1][$itID] = $aRegExpr[1]
		$aItems[UBound($aItems) - 1][$itSlot] = $aRegExpr[2]

		; Tier
		Local $aRegExpr = StringRegExp($aObjects[$i], '(?i)(?s)<Tier>(.*?)</Tier>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid Tier value
			$aItems[UBound($aItems) - 1][$itTier] = $aRegExpr[0]
		Else
			$aItems[UBound($aItems) - 1][$itTier] = -1
		EndIf

		; FeedPower
		Local $aRegExpr = StringRegExp($aObjects[$i], '(?i)(?s)<feedPower>(.*?)</feedPower>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid FeedPower value
			$aItems[UBound($aItems) - 1][$itFeedPower] = $aRegExpr[0]
		Else
			$aItems[UBound($aItems) - 1][$itFeedPower] = 0
		EndIf

		; FameBonus
		Local $aRegExpr = StringRegExp($aObjects[$i], '(?i)(?s)<FameBonus>(.*?)</FameBonus>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid FameBonus value
			$aItems[UBound($aItems) - 1][$itFameBonus] = $aRegExpr[0]
		Else
			$aItems[UBound($aItems) - 1][$itFameBonus] = 0
		EndIf

		$iItemsCount += 1
	EndIf
Next

_Log("Found " & $iItemsCount & " items")

Const Enum $SlSword = 1, $SlDagger, $SlBow, $SlTome, $SlShield, $SlLeatherArmor, $SlHeavyArmor, $SlWand, $SlRing, $SlConsumable, $SlSpellBomb, $SlSeal, $SlCloak, $SlRobe, $SlQuiver, $SlHelm, $SlStaff, $SlPoison, $SlSkull, $SlTrap, $SlOrb, $SlPrism, $SlScepter, $SlKatana, $SlNinjaStar, $SlPetEggs

Local Const $aMiscItems[] = ["Golden ", "Eye of Osiris", "Pharaoh's Mask", "Holy Cross", "Pearl Necklace", "Ruby Gemstone", "Soft Drink", "Fries", "Great Taco", "Power Pizza", "Chocolate Cream", "Grapes of Wrath", "burger", "Ambrosia", "Cranberries", "Ear of Corn", "Sliced Yam", "Pumpkin Pie", "Thanksgiving Turkey", "Tarot Card", "Pet Form Stone", "Pet Rock Item"]
Local Const $aWines[] = ["Cabernet", "Chardonnay", "Cream Spirit", "Fire Water", "Melon Liqueur", "Muscat", "Rice Wine", "Sauvignon Blanc", "Shiraz", "Vintage Port"]
Local Const $aRestoratives[] = ["Potion", "Elixir of ", "Ichor", "Snake Oil", "Coral Juice", "Pollen Powder", "Holy Water", "Bahama Sunrise", "Blue Paradise", "Pink Passion Breeze", "Pink Passion Breeze", "Lime Jungle Bay", "Mad God Ale", "Oryx Stout", "Realm-wheat Hefeweizen", " Gumball", "Saint Patty's Brew", "Candy Corn", "Apple"]
Local Const $aKeys[] = [" Key", " Incantation", "TH Honey Bottle", "Test Enemy Item", "Prod Enemy Item"]
Local Const $aOther[] = ["Testing Mystery Dye", "Transformation Potion", "Loot", " Pet Stone"]
Local Const $aPets[] = ["Valentine Generator", "Beach Ball Generator", "Beer Slurp Generator", "Valentine Heart Generator"]

Const Enum $hmValue, $hmX, $hmY, $hmMAX
Local $HashMap[0][$hmMAX]
Local $aImages[0]
Local $iRendersIndex = 1

; GDIPlus
_GDIPlus_Startup()

; Crypt
_Crypt_Startup()

; WinHttp
$hConnect = _WinHttpConnect($hOpen, "static.drips.pw")

_HashMap_Add("0x3C68746D6C3E0D0A3C686561643E3C7469746C653E343034204E6F7420466F756E643C2F7469746C653E3C2F686561643E0D0A3C626F6479206267636F6C6F723D227768697465223E0D0A3C63656E7465723E3C68313E343034204E6F7420466F756E643C2F68313E3C2F63656E7465723E0D0A3C68723E3C63656E7465723E6E67696E782F312E31302E333C2F63656E7465723E0D0A3C2F626F64793E0D0A3C2F68746D6C3E0D0A", 0, 0) ; Empty tile

For $i = 0 To UBound($aItems) - 1 Step 1
	Local $sIDOrig = $aItems[$i][$itID]

	; Renders.png
	Local $sBasePath = "rotmg/wiki/"

	; Get our Path to static.drips.pw/rotmg/wiki/ to download our pictures
	If $aItems[$i][$itTier] = -1 And $aItems[$i][$itSlot] <> $SlConsumable And $aItems[$i][$itSlot] <> $SlPetEggs Then ; Untiered Equipment
		$sBasePath &= "Untiered/"
	Else
		Switch $aItems[$i][$itSlot]
			Case $SlSword
				$sBasePath &= "Weapons/Swords/T" & $aItems[$i][$itTier] & " "
			Case $SlDagger
				$sBasePath &= "Weapons/Daggers/T" & $aItems[$i][$itTier] & " "
			Case $SlBow
				$sBasePath &= "Weapons/Bows/T" & $aItems[$i][$itTier] & " "
			Case $SlTome
				$sBasePath &= "Abilities/Tomes/T" & $aItems[$i][$itTier] & " "
			Case $SlShield
				$sBasePath &= "Abilities/Shields/T" & $aItems[$i][$itTier] & " "
			Case $SlLeatherArmor
				$sBasePath &= "Armor/Leather%20Armor/T" & $aItems[$i][$itTier] - 1 & " "
			Case $SlHeavyArmor
				$sBasePath &= "Armor/Heavy%20Armor/T" & $aItems[$i][$itTier] - 1 & " "
			Case $SlWand
				$sBasePath &= "Weapons/Wands/T" & $aItems[$i][$itTier] & " "
			Case $SlRing
				Switch $aItems[$i][$itTier]
					Case 0
						$sBasePath &= "Rings/Minor/"
					Case 1
						$sBasePath &= "Rings/Standard/"
					Case 2
						$sBasePath &= "Rings/Greater/"
					Case 3
						$sBasePath &= "Rings/Superior/"
					Case 4
						$sBasePath &= "Rings/Paramount/"
					Case 5
						$sBasePath &= "Rings/Exalted/"
					Case 6
						$sBasePath &= "Rings/Unbound/"
				EndSwitch
			Case $SlConsumable
				If _MatchesAny($aItems[$i][$itID], $aOther) Then
					$sBasePath &= "Consumable/Other/"
				ElseIf StringInStr($aItems[$i][$itID], " Dye") Or StringInStr($aItems[$i][$itID], " Cloth") Then ; Dyes / Clothes
					$sBasePath &= "Consumable/Dyes/"
				ElseIf StringInStr($aItems[$i][$itID], "Potion of ") And Not StringInStr($aItems[$i][$itID], "Health") And Not StringInStr($aItems[$i][$itID], "Greater") Then ; Stat Potions
					$sBasePath &= "Consumable/Stat%20Potions/"
				ElseIf _MatchesAny($aItems[$i][$itID], $aRestoratives) Then
					$sBasePath &= "Consumable/Restoratives/"
				ElseIf StringInStr($aItems[$i][$itID], "Tincture of ") Or StringInStr($aItems[$i][$itID], "Effusion of ") Then
					$sBasePath &= "Consumable/Tinctures and Effusions/"
				ElseIf StringInStr($aItems[$i][$itID], " Drake Egg") Then
					$sBasePath &= "Consumable/Drakes/"
				ElseIf _MatchesAny($aItems[$i][$itID], $aKeys) Then
					$sBasePath &= "Consumable/Keys/"
				ElseIf _MatchesAny($aItems[$i][$itID], $aWines) Then
					$sBasePath &= "Consumable/Wines/"
				ElseIf _MatchesAny($aItems[$i][$itID], $aMiscItems) Then
					$sBasePath &= "Misc items/"
				ElseIf _MatchesAny($aItems[$i][$itID], $aPets) Then
					$sBasePath &= "Pets/"
				Else
					$sBasePath &= "Consumable/Other/"
				EndIf

				If StringInStr($aItems[$i][$itID], " (SB)") Then
					$aItems[$i][$itID] = StringReplace($aItems[$i][$itID], " (SB)", "") ; Instead of using the SB version just use the normal one
				EndIf
			Case $SlSpellBomb
				$sBasePath &= "Abilities/Spells/T" & $aItems[$i][$itTier] & " "
			Case $SlSeal
				$sBasePath &= "Abilities/Seals/T" & $aItems[$i][$itTier] & " "
			Case $SlCloak
				$sBasePath &= "Abilities/Cloaks/T" & $aItems[$i][$itTier] & " "
			Case $SlRobe
				$sBasePath &= "Armor/Robes/T" & $aItems[$i][$itTier] - 1 & " "
			Case $SlQuiver
				$sBasePath &= "Abilities/Quivers/T" & $aItems[$i][$itTier] & " "
			Case $SlHelm
				$sBasePath &= "Abilities/Helms/T" & $aItems[$i][$itTier] & " "
			Case $SlStaff
				$sBasePath &= "Weapons/Staves/T" & $aItems[$i][$itTier] & " "
			Case $SlPoison
				$sBasePath &= "Abilities/Poisons/T" & $aItems[$i][$itTier] & " "
			Case $SlSkull
				$sBasePath &= "Abilities/Skulls/T" & $aItems[$i][$itTier] & " "
			Case $SlTrap
				$sBasePath &= "Abilities/Traps/T" & $aItems[$i][$itTier] & " "
			Case $SlOrb
				$sBasePath &= "Abilities/Orbs/T" & $aItems[$i][$itTier] & " "
			Case $SlPrism
				$sBasePath &= "Abilities/Prisms/T" & $aItems[$i][$itTier] & " "
			Case $SlScepter
				$sBasePath &= "Abilities/Scepters/T" & $aItems[$i][$itTier] & " "
			Case $SlKatana
				$sBasePath &= "Weapons/Katanas/T" & $aItems[$i][$itTier] & " "
			Case $SlNinjaStar
				$sBasePath &= "Abilities/Stars/T" & $aItems[$i][$itTier] & " "
			Case $SlPetEggs
				$sBasePath &= "Consumable/Pet%20Eggs/"
				$aItems[$i][$itID] = StringReplace($aItems[$i][$itID], "?", "_") ; For the '????' eggs which are named '____' instead
			Case Else
				MsgBox(0, "", $sIDOrig & " is of unknown type: " & $aItems[$i][$itSlot])
		EndSwitch
	EndIf

	Local $hPic = _WinHttpSimpleRequest($hConnect, "GET", $sBasePath & $aItems[$i][$itID] & ".png", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False, 2)
	If @error Or $hPic = "" Then
		_LogError("Coud'nt map: " & $aItems[$i][$itID] & @CRLF & "Slot: " & $aItems[$i][$itSlot] & @CRLF & "Tier: " & $aItems[$i][$itTier] & @CRLF & "URL: https://static.drips.pw/" & $sBasePath & $aItems[$i][$itID] & ".png")
	Else

		$iIndex = _HashMap_LookUp($hPic)

		; Debug code
;~ 		If $iIndex = 0 Then
;~ 			_LogError("Coud'nt map: " & $aItems[$i][$itID] & @CRLF & "Slot: " & $aItems[$i][$itSlot] & @CRLF & "Tier: " & $aItems[$i][$itTier] & @CRLF & "URL: https://static.drips.pw/" & $sBasePath & $aItems[$i][$itID] & ".png")
;~ 		EndIf
		If $iIndex == -1 Then ; found new hash!
			ReDim $aImages[UBound($aImages) + 1]
			$aImages[UBound($aImages) - 1] = _GDIPlus_BitmapCreateFromMemory($hPic, False)

			; Calculate position to draw
			Local $X = Mod($iRendersIndex, 25) * 40
			Local $Y = Floor($iRendersIndex / 25) * 40

			_HashMap_Add($hPic, $X, $Y)

			$iRendersIndex += 1

		Else ; Hash found
			$X = $HashMap[$iIndex][$hmX]
			$Y = $HashMap[$iIndex][$hmY]
		EndIf
	EndIf

	_Log("[" & $i + 1 & "/" & $iItemsCount & "] Mapped '" & $sIDOrig & "' to " & $X & ", " & $Y)

	FileWrite($fHandle, $aItems[$i][$itType] & ': ["' & $sIDOrig & '", ' & $aItems[$i][$itSlot] & ", " & $aItems[$i][$itTier] & ", " & $X & ", " & $Y & ", " & $aItems[$i][$itFameBonus] & ", " & $aItems[$i][$itFeedPower] & "]," & @CRLF)
Next

_Log("Found " & $iItemsCount - $iRendersIndex & " identical looking items")

$hImage = _GDIPlus_BitmapCreateFromScan0(1000, Ceiling(($iRendersIndex) / 25) * 40)
$hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage)
_GDIPlus_GraphicsClear($hGraphic, "0x00000000") ; 0x00000000 = completly white and transparent

; Draw our Image
For $i = 1 To UBound($aImages) Step 1
	Local $X = Mod($i, 25) * 40
	Local $Y = Floor($i / 25) * 40

	_GDIPlus_GraphicsDrawImageRect($hGraphic, $aImages[$i - 1], $X, $Y, 40, 40)
Next

_GDIPlus_ImageSaveToFile($hImage, $MuleDumpPath & "\Renders.png")
If Not @error Then
	_Log("Successfully created Renders.png")
Else
	_LogError("Coudnt create Renders.png")
	_LogMissingFile("renders.png")
EndIf

FileWrite($fHandle, "}" & @CRLF & @CRLF & @CRLF & "// type: [id, starts, averages, maxes, slots]" & @CRLF & "classes = {" & @CRLF)

Const Enum $clType, $clID, $clSlot1, $clSlot2, $clSlot3, $clSlot4, $clHPMax, $clHP, $clMPMax, $clMP, $clAtkMax, $clAtk, $clDefMax, $clDef, $clSpdMax, $clSpd, $clDexMax, $clDex, $clVitMax, $clVit, $clWisMax, $clWis, $clLHPMin, $clLHPMax, $clLMPMin, $clLMPMax, $clLAtkMin, $clLAtkMax, $clLDefMin, $clLDefMax, $clLSpdMin, $clLSpdMax, $clLDexMin, $clLDexMax, $clLVitMin, $clLVitMax, $clLWisMin, $clLWisMax

; Classes
Local $iClassCount = 0
For $i = 1 To $aObjects[0] Step 1
	; HpRegen = Vit
	; MpRegen = Wis
	Local $regex = StringRegExp($aObjects[$i], '(?i)(?s)<Object type="(.*?)" id="(.*?)">.*?<Class>Player</Class>.*?<SlotTypes>(\d+), (\d+), (\d+), (\d+), .*?</SlotTypes>.*?<MaxHitPoints max="(\d+)">(\d+)</MaxHitPoints>.*?<MaxMagicPoints max="(\d+)">(\d+)</MaxMagicPoints>.*?<Attack max="(\d+)">(\d+)</Attack>.*?<Defense max="(\d+)">(\d+)</Defense>.*?<Speed max="(\d+)">(\d+)</Speed>.*?<Dexterity max="(\d+)">(\d+)</Dexterity>.*?<HpRegen max="(\d+)">(\d+)</HpRegen>.*?<MpRegen max="(\d+)">(\d+)</MpRegen>.*?<LevelIncrease min="(\d+)" max="(\d+)">MaxHitPoints</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">MaxMagicPoints</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Attack</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Defense</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Speed</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Dexterity</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">HpRegen</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">MpRegen</LevelIncrease>', $STR_REGEXPARRAYGLOBALMATCH)
	If Not @error Then
		FileWrite($fHandle, $regex[$clType] & ': ["' & $regex[$clID] & '", [' & $regex[$clHP] & ", " & $regex[$clMP] & ", " & $regex[$clAtk] & ", " & $regex[$clDef] & ", " & $regex[$clSpd] & ", " & $regex[$clDex] & ", " & $regex[$clVit] & ", " & $regex[$clWis] & "], [" & _CalcAverageAtLevel20($regex[$clLHPMin], $regex[$clLHPMax], $regex[$clHP]) & ", " & _CalcAverageAtLevel20($regex[$clLMPMin], $regex[$clLMPMax], $regex[$clMP]) & ", " & _CalcAverageAtLevel20($regex[$clLAtkMin], $regex[$clLAtkMax], $regex[$clAtk]) & ", " & _CalcAverageAtLevel20($regex[$clLDefMin], $regex[$clLDefMax], $regex[$clDef]) & ", " & _CalcAverageAtLevel20($regex[$clLSpdMin], $regex[$clLSpdMax], $regex[$clSpd]) & ", " & _CalcAverageAtLevel20($regex[$clLDexMin], $regex[$clLDexMax], $regex[$clDex]) & ", " & _CalcAverageAtLevel20($regex[$clLVitMin], $regex[$clLVitMax], $regex[$clVit]) & ", " & _CalcAverageAtLevel20($regex[$clLWisMin], $regex[$clLWisMax], $regex[$clWis]) & "], [" & $regex[$clHPMax] & ", " & $regex[$clMPMax] & ", " & $regex[$clAtkMax] & ", " & $regex[$clDefMax] & ", " & $regex[$clSpdMax] & ", " & $regex[$clDexMax] & ", " & $regex[$clVitMax] & ", " & $regex[$clWisMax] & "], [" & $regex[$clSlot1] & ", " & $regex[$clSlot2] & ", " & $regex[$clSlot3] & ", " & $regex[$clSlot4] & "]]," & @CRLF)

		$iClassCount += 1
	EndIf
Next

_Log("Found " & $iClassCount & " classes")

FileWrite($fHandle, "}")
FileClose($fHandle)

_Log("Successfully created constants.js")

; Clean up WinHTTP
_WinHttpCloseHandle($hClient)
_WinHttpCloseHandle($hConnect)
_WinHttpCloseHandle($hOpen)

; Clean up GDIPlus
_GDIPlus_ImageDispose($hImage)
_GDIPlus_GraphicsDispose($hGraphic)
_GDIPlus_Shutdown()

; Clean up Crypt
_Crypt_Shutdown()

; Error handling
If $ErrorCount <> 0 Then
	_Log(@CRLF & "[WARNING] RotMG Resource Updater encountered " & $ErrorCount & " problems!" & @CRLF & "You can report the problem at GitHub (RotMGHacker) or MPGH.net (megakillzor)" & @CRLF & "Please remember to include your log file!")
EndIf

If UBound($ErrorMissingFiles) <> 0 Then
	Local $sList
	For $i = 0 To UBound($ErrorMissingFiles) - 1 Step 1
		$sList &= '"' & $ErrorMissingFiles[$i] & '", '
	Next

	$sList = StringMid($sList, 0, StringLen($sList) - 2) ; remove the last ", "

	_Log(@CRLF & "[WARNING] RotMG Resource Updater wasn't able to create the following files: " & @CRLF & $sList)
EndIf

; Display client version if we have, other wise display version from the server
Local $sVrs
If $ClientVersion <> "" Then
	$sVrs = $ClientVersion
Else
	$sVrs = $RotMGVersion
EndIf

_Log(@CRLF & "Finished updating RotMG resources to version: " & $sVrs & "!" & @CRLF & "Automatically closing in 10 seconds...")

If $LogToFile Then
	FileClose($fhLogFile)
EndIf

Sleep(10 * 1000)

Exit 0

Func _HashMap_Add(Const $sData, Const $iX, Const $iY)
	ReDim $HashMap[UBound($HashMap) + 1][$hmMAX]

	$HashMap[UBound($HashMap) - 1][0] = _Crypt_HashData($sData, $HashAlg)
	$HashMap[UBound($HashMap) - 1][1] = $iX
	$HashMap[UBound($HashMap) - 1][2] = $iY
EndFunc   ;==>_HashMap_Add

Func _HashMap_LookUp(Const $sData)
	Local $sHash = _Crypt_HashData($sData, $HashAlg)

	For $i = 0 To UBound($HashMap) - 1 Step 1
		If $sHash == $HashMap[$i][$hmValue] Then
			Return $i
		EndIf
	Next

	Return -1
EndFunc   ;==>_HashMap_LookUp

Func _CheckForValidPaths()
	If $UseResExtractor Then
		Local $aNeededFiles[] = [$ResExtractorPath & "\ResExtractor.exe", $ResExtractorPath & "\SwfDotNet.IO.dll", $ResExtractorPath & "\SharpZipLib.dll", $ResExtractorPath & "\log4net.dll"]
	Else
		Local $aNeededFiles[] = [$RABCDAsmPath & "\swfdecompress.exe", $RABCDAsmPath & "\abcexport.exe", $RABCDAsmPath & "\rabcdasm.exe"]
	EndIf

	For $i = 0 To UBound($aNeededFiles) - 1 Step 1
		If Not FileExists($aNeededFiles[$i]) Then
			_LogError('Unable to locate "' & $aNeededFiles[$i] & '"')

			Return False
		EndIf
	Next

	Return True
EndFunc   ;==>_CheckForValidPaths

Func _SaveIni()
	If $UseResExtractor Then
		IniWrite("Config.ini", "Paths", "ResExtractor", $ResExtractorPath)
	Else
		IniWrite("Config.ini", "Paths", "RABCDAsm", $RABCDAsmPath)
	EndIf
	IniWrite("Config.ini", "Paths", "KRelay", $KRelayLibPath)
	IniWrite("Config.ini", "Paths", "Muledump", $MuleDumpPath)
EndFunc   ;==>_SaveIni

Func _CalcAverageAtLevel20(Const $Min, Const $Max, Const $start)
	Return Floor(((($Min + $Max) / 2) * 19) + $start) ; The average you get per level (Min + Max) / 2, multiplied with 19 (you start at Level 1 so 19 Levelups later your at level 20), and add the amount you start with to calculate the average at level 20
EndFunc   ;==>_CalcAverageAtLevel20

Func _MatchesAny(Const $sTest, Const $aArray)
	If Not IsArray($aArray) Then Return False ; No array: no matches

	For $i = 0 To UBound($aArray) - 1 Step 1
		If StringInStr($sTest, $aArray[$i]) Then
			Return True
		EndIf
	Next

	Return False
EndFunc   ;==>_MatchesAny

Func _Log(Const $sText)
	ConsoleWrite($sText & @CRLF)

	If $LogToFile Then
		FileWrite($fhLogFile, $sText & @CRLF)
	EndIf
EndFunc   ;==>_Log

Func _LogError(Const $sText)
	ConsoleWrite("[ERROR] " & $sText & @CRLF)

	If $LogToFile Then
		FileWrite($fhLogFile, "[ERROR] " & $sText & @CRLF)
	EndIf

	$ErrorCount += 1
EndFunc   ;==>_LogError

Func _LogMissingFile(Const $sFile)
	ReDim $ErrorMissingFiles[UBound($ErrorMissingFiles) + 1]

	$ErrorMissingFiles[UBound($ErrorMissingFiles) - 1] = $sFile

	_LogError("Missing file: '" & $sFile & "'")
EndFunc   ;==>_LogMissingFile
