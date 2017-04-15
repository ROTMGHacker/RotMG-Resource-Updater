
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

	The GitHub repository can be found at: github.com/RotMGHacker/RotMG-Resource-Updater
#comments-end

#NoTrayIcon
#RequireAdmin

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
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

Global Const $VERSION = "1.0" ; Remember to increment!
Global Const $UseResExtractor = True ; Use ResExtractor instead of using RABCDAsm directly
Global Const $LogToFile = True

; These are IDs which dont work and shoud be ignored by the script
Global Const $aInvalid[] = []

If $LogToFile Then
	Global $fhLogFile = FileOpen("RotMG Resource Updater.log", $FO_OVERWRITE + $FO_CREATEPATH)
EndIf

Global $ErrorCount = 0

_Log("RotMG Resource Updater " & $VERSION & " by RotMGHacker (https://github.com/RotMGHacker)" & @CRLF)

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
	FileDelete($ResExtractorPath & "\client.swf")
	FileDelete($ResExtractorPath & "\abcdata.abc")
	DirRemove($ResExtractorPath & "\abcdata", $DIR_REMOVE)
Else
	FileDelete($RABCDAsmPath & "\client.swf")
	FileDelete($RABCDAsmPath & "\client-0.abc")
	DirRemove($RABCDAsmPath & "\client-0", $DIR_REMOVE)
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
EndIf

_WinHttpCloseHandle($hConnect)
$hConnect = _WinHttpConnect($hOpen, "static.drips.pw")

If Not $UseResExtractor Then
	_Log("Downloading GroundTypes.xml...")
	Local $hTiles = _WinHttpSimpleRequest($hConnect, "GET", "rotmg/production/" & $RotMGVersion & "/xmlc/GroundTypes.xml", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False, 0)
	If @error = 0 Then
		_Log("Successfully downloaded GroundTypes.xml")
	EndIf
EndIf

_Log("Downloading Objects.xml...")
Local $hObjects = _WinHttpSimpleRequest($hConnect, "GET", "rotmg/production/" & $RotMGVersion & "/xmlc/Objects.xml", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False, 0)
If @error = 0 Then
	_Log("Successfully downloaded Objects.xml")
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

	_Log("Creating packets.xml...")

	; Create packets.xml
	$fHandle = FileOpen($RABCDAsmPath & "\client-0\kabam\rotmg\messaging\impl\GameServerConnection.class.asasm", $FO_READ + $FO_UTF8)

	If Not FileExists($RABCDAsmPath & "\client-0\kabam\rotmg\messaging\impl\GameServerConnection.class.asasm") Then
		MsgBox(16, "", "GameServerConnection.class.asam wasnt found!")
		Exit
	Else
		_Log("Found GameServerConnection.class.asam")
	EndIf

	Global $aPacketFinal[0][2] ; 0 = Name, 1 = ID

	$fRead = FileReadToArray($fHandle)

	For $i = 0 To @extended - 1 Step 1
		Local $aPackets = StringRegExp($fRead[$i], '(?i) trait const QName\(PackageNamespace\(""\), "([^)]+)"\) slotid \d+ type QName\(PackageNamespace\(""\), "int"\) value Integer\(([^)]+)\) end', $STR_REGEXPARRAYGLOBALMATCH)

		If @error = 0 Then
			ReDim $aPacketFinal[UBound($aPacketFinal) + 1][2]
			$aPacketFinal[UBound($aPacketFinal) - 1][0] = StringReplace($aPackets[0], "_", "") ; Remove all underscores
			$aPacketFinal[UBound($aPacketFinal) - 1][1] = $aPackets[1]
		EndIf
	Next

	_Log("Found " & UBound($aPacketFinal) & " packets")

	$fHandle = FileOpen($KRelayLibPath & "\packets.xml", $FO_CREATEPATH + $FO_OVERWRITE)

	FileWrite($fHandle, "<Packets>" & @CRLF)

	For $i = 0 To UBound($aPacketFinal) - 1 Step 1
		FileWrite($fHandle, "  <Packet>" & @CRLF & "    <PacketName>" & $aPacketFinal[$i][0] & "</PacketName>" & @CRLF & "    <PacketID>" & $aPacketFinal[$i][1] & "</PacketID>" & @CRLF & "  </Packet>" & @CRLF)
	Next

	FileWrite($fHandle, "</Packets>")

	_Log("Successfully created packets.xml")

	_Log("Creating tiles.xml...")

	; Create Tiles.xml
	Local $fHandle = FileOpen($KRelayLibPath & "\tiles.xml", $FO_CREATEPATH + $FO_OVERWRITE)

	; Header
	FileWrite($fHandle, '<?xml version="1.0" encoding="ISO-8859-1"?>' & @CRLF & @CRLF & "<GroundTypes>" & @CRLF)

	$aTiles = StringSplit($hTiles, @CRLF)
	Local $startLogging = False

	For $i = 1 To $aTiles[0] - 1 Step 1
		If $startLogging And $aTiles[$i] <> "" Then
			FileWrite($fHandle, $aTiles[$i] & @CRLF)
		EndIf

		If StringInStr($aTiles[$i], "<!-- hanaminexusGround -->") Then
			$startLogging = True
		ElseIf StringInStr($aTiles[$i], "<!-- ") Then ; Any other category!
			If $startLogging Then ExitLoop
		EndIf
	Next

	; End of header
	FileWrite($fHandle, "</GroundTypes>")
	FileClose($fHandle)

	_Log("Successfully created tiles.xml")
EndIf

_Log("Creating constants.js...")

; Create constants.js
Local $fHandle = FileOpen($MuleDumpPath & "\constants.js", $FO_CREATEPATH + $FO_OVERWRITE)

; File Header
FileWrite($fHandle, "// type: [id, slot, tier, x, y, famebonus, feedpower]" & @CRLF & "items = {" & @CRLF & "'-1'" & ': ["empty slot", 0, -1, 0, 0, 0, 0],' & @CRLF)

$aObjects = StringSplit($hObjects, "</Object>", $STR_ENTIRESPLIT)

$count = 1
Global $ListOfItems[0][3]

For $i = 1 To $aObjects[0] Step 1
	; Get Type, ID, Slot
	Local $aRegExpr = StringRegExp(StringReplace($aObjects[$i], @LF, ""), '(?i)<Object type="(.*?)" id="(.*?)"[ >].*?<Class>(?:Equipment|Dye)</Class>.*?<SlotType>(.*?)</SlotType>', $STR_REGEXPARRAYGLOBALMATCH)

	; Skipp all IDs which are marked as Invalid or not of type 'Dye' or 'Equipment'
	If @error = 0 And Not _MatchesAny($aRegExpr[1], $aInvalid) Then
		Local $sType = $aRegExpr[0]
		Local $sID = $aRegExpr[1]
		Local $sSlot = $aRegExpr[2]

		Local $sTier, $sFeedPower, $sFameBonus

		; Tier
		Local $aRegExpr = StringRegExp(StringReplace($aObjects[$i], @LF, ""), '(?i)<Tier>(.*?)</Tier>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid Tier value
			$sTier = $aRegExpr[0]
		Else
			$sTier = -1
		EndIf

		; FeedPower
		Local $aRegExpr = StringRegExp(StringReplace($aObjects[$i], @LF, ""), '(?i)<feedPower>(.*?)</feedPower>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid FeedPower value
			$sFeedPower = $aRegExpr[0]
		Else
			$sFeedPower = 0
		EndIf

		; FameBonus
		Local $aRegExpr = StringRegExp(StringReplace($aObjects[$i], @LF, ""), '(?i)<FameBonus>(.*?)</FameBonus>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error = 0 Then ; Valid FameBonus value
			$sFameBonus = $aRegExpr[0]
		Else
			$sFameBonus = 0
		EndIf

		; Needed for our Renders.png
		ReDim $ListOfItems[UBound($ListOfItems) + 1][3]
		$ListOfItems[UBound($ListOfItems) - 1][0] = $sID
		$ListOfItems[UBound($ListOfItems) - 1][1] = $sSlot
		$ListOfItems[UBound($ListOfItems) - 1][2] = $sTier

		; Calculate Renders.png position
		Local $x = Mod($count, 25) * 40
		Local $y = Floor($count / 25) * 40

		FileWrite($fHandle, $sType & ': ["' & $sID & '", ' & $sSlot & ", " & $sTier & ", " & $x & ", " & $y & ", " & $sFameBonus & ", " & $sFeedPower & "]," & @CRLF)

		$count += 1
	EndIf
Next

_Log("Found " & $count - 1 & " items")

FileWrite($fHandle, "}" & @CRLF & @CRLF & @CRLF & "// type: [id, starts, averages, maxes, slots]" & @CRLF & "classes = {" & @CRLF)

Const Enum $clType, $clID, $clSlot1, $clSlot2, $clSlot3, $clSlot4, $clHPMax, $clHP, $clMPMax, $clMP, $clAtkMax, $clAtk, $clDefMax, $clDef, $clSpdMax, $clSpd, $clDexMax, $clDex, $clVitMax, $clVit, $clWisMax, $clWis, $clLHPMin, $clLHPMax, $clLMPMin, $clLMPMax, $clLAtkMin, $clLAtkMax, $clLDefMin, $clLDefMax, $clLSpdMin, $clLSpdMax, $clLDexMin, $clLDexMax, $clLVitMin, $clLVitMax, $clLWisMin, $clLWisMax

; Classes
$startLogging = False
$count = 0
For $i = 1 To $aObjects[0] Step 1
	If StringInStr($aObjects[$i], "<!-- Players -->") Then
		$startLogging = True
	ElseIf StringInStr($aObjects[$i], "<!-- ") Then ; Any other category!
		If $startLogging Then ExitLoop
	EndIf

	If $startLogging Then
		; HpRegen = Vit
		; MpRegen = Wis
		Local $regex = StringRegExp(StringReplace($aObjects[$i], @LF, ""), '(?i)<Object type="(.*?)" id="(.*?)">.*?<SlotTypes>(\d+), (\d+), (\d+), (\d+), .*?</SlotTypes>.*?<MaxHitPoints max="(\d+)">(\d+)</MaxHitPoints>.*?<MaxMagicPoints max="(\d+)">(\d+)</MaxMagicPoints>.*?<Attack max="(\d+)">(\d+)</Attack>.*?<Defense max="(\d+)">(\d+)</Defense>.*?<Speed max="(\d+)">(\d+)</Speed>.*?<Dexterity max="(\d+)">(\d+)</Dexterity>.*?<HpRegen max="(\d+)">(\d+)</HpRegen>.*?<MpRegen max="(\d+)">(\d+)</MpRegen>.*?<LevelIncrease min="(\d+)" max="(\d+)">MaxHitPoints</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">MaxMagicPoints</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Attack</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Defense</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Speed</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">Dexterity</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">HpRegen</LevelIncrease>.*?<LevelIncrease min="(\d+)" max="(\d+)">MpRegen</LevelIncrease>', $STR_REGEXPARRAYGLOBALMATCH)

		FileWrite($fHandle, $regex[$clType] & ': ["' & $regex[$clID] & '", [' & $regex[$clHP] & ", " & $regex[$clMP] & ", " & $regex[$clAtk] & ", " & $regex[$clDef] & ", " & $regex[$clSpd] & ", " & $regex[$clDex] & ", " & $regex[$clVit] & ", " & $regex[$clWis] & "], [" & _CalcAverageAtLevel20($regex[$clLHPMin], $regex[$clLHPMax], $regex[$clHP]) & ", " & _CalcAverageAtLevel20($regex[$clLMPMin], $regex[$clLMPMax], $regex[$clMP]) & ", " & _CalcAverageAtLevel20($regex[$clLAtkMin], $regex[$clLAtkMax], $regex[$clAtk]) & ", " & _CalcAverageAtLevel20($regex[$clLDefMin], $regex[$clLDefMax], $regex[$clDef]) & ", " & _CalcAverageAtLevel20($regex[$clLSpdMin], $regex[$clLSpdMax], $regex[$clSpd]) & ", " & _CalcAverageAtLevel20($regex[$clLDexMin], $regex[$clLDexMax], $regex[$clDex]) & ", " & _CalcAverageAtLevel20($regex[$clLVitMin], $regex[$clLVitMax], $regex[$clVit]) & ", " & _CalcAverageAtLevel20($regex[$clLWisMin], $regex[$clLWisMax], $regex[$clWis]) & "], [" & $regex[$clHPMax] & ", " & $regex[$clMPMax] & ", " & $regex[$clAtkMax] & ", " & $regex[$clDefMax] & ", " & $regex[$clSpdMax] & ", " & $regex[$clDexMax] & ", " & $regex[$clVitMax] & ", " & $regex[$clWisMax] & "], [" & $regex[$clSlot1] & ", " & $regex[$clSlot2] & ", " & $regex[$clSlot3] & ", " & $regex[$clSlot4] & "]]," & @CRLF)

		$count = $count + 1
	EndIf
Next

_Log("Found " & $count & " classes")

FileWrite($fHandle, "}")
FileClose($fHandle)

_Log("Successfully created constants.js")

; Create Renders.png
_Log("Creating Renders.png")

_GDIPlus_Startup()
$hImage = _GDIPlus_BitmapCreateFromScan0(1000, Ceiling(UBound($ListOfItems) / 25) * 40)
$hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage)
_GDIPlus_GraphicsClear($hGraphic, "0x00000000") ; 0x00000000 = completly white and transparent

$hConnect = _WinHttpConnect($hOpen, "static.drips.pw")

Const Enum $SlSword = 1, $SlDagger, $SlBow, $SlTome, $SlShield, $SlLeatherArmor, $SlHeavyArmor, $SlWand, $SlRing, $SlConsumable, $SlSpellBomb, $SlSeal, $SlCloak, $SlRobe, $SlQuiver, $SlHelm, $SlStaff, $SlPoison, $SlSkull, $SlTrap, $SlOrb, $SlPrism, $SlScepter, $SlKatana, $SlNinjaStar, $SlPetEggs

Local Const $aMiscItems[] = ["Golden ", "Eye of Osiris", "Pharaoh's Mask", "Holy Cross", "Pearl Necklace", "Ruby Gemstone", "Soft Drink", "Fries", "Great Taco", "Power Pizza", "Chocolate Cream", "Grapes of Wrath", "burger", "Ambrosia", "Cranberries", "Ear of Corn", "Sliced Yam", "Pumpkin Pie", "Thanksgiving Turkey", "Tarot Card", "Pet Form Stone", "Pet Rock Item"]
Local Const $aWines[] = ["Cabernet", "Chardonnay", "Cream Spirit", "Fire Water", "Melon Liqueur", "Muscat", "Rice Wine", "Sauvignon Blanc", "Shiraz", "Vintage Port"]
Local Const $aRestoratives[] = ["Potion", "Elixir of ", "Ichor", "Snake Oil", "Coral Juice", "Pollen Powder", "Holy Water", "Bahama Sunrise", "Blue Paradise", "Pink Passion Breeze", "Pink Passion Breeze", "Lime Jungle Bay", "Mad God Ale", "Oryx Stout", "Realm-wheat Hefeweizen", " Gumball", "Saint Patty's Brew", "Candy Corn", "Apple"]
Local Const $aKeys[] = [" Key", " Incantation", "TH Honey Bottle"]
Local Const $aOther[] = ["Testing Mystery Dye", "Transformation Potion", "Loot"]

For $i = 0 To UBound($ListOfItems) - 1 Step 1
	Local $sBasePath = "rotmg/wiki/"

	If $ListOfItems[$i][2] = -1 And $ListOfItems[$i][1] <> $SlConsumable And $ListOfItems[$i][1] <> $SlPetEggs Then ; Untiered Equipment
		$sBasePath &= "Untiered/"
	Else
		Switch $ListOfItems[$i][1]
			Case $SlSword
				$sBasePath &= "Weapons/Swords/T" & $ListOfItems[$i][2] & " "
			Case $SlDagger
				$sBasePath &= "Weapons/Daggers/T" & $ListOfItems[$i][2] & " "
			Case $SlBow
				$sBasePath &= "Weapons/Bows/T" & $ListOfItems[$i][2] & " "
			Case $SlTome
				$sBasePath &= "Abilities/Tomes/T" & $ListOfItems[$i][2] & " "
			Case $SlShield
				$sBasePath &= "Abilities/Shields/T" & $ListOfItems[$i][2] & " "
			Case $SlLeatherArmor
				$sBasePath &= "Armor/Leather%20Armor/T" & $ListOfItems[$i][2] - 1 & " "
			Case $SlHeavyArmor
				$sBasePath &= "Armor/Heavy%20Armor/T" & $ListOfItems[$i][2] - 1 & " "
			Case $SlWand
				$sBasePath &= "Weapons/Wands/T" & $ListOfItems[$i][2] & " "
			Case $SlRing
				Switch $ListOfItems[$i][2] ; Tier
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
				If _MatchesAny($ListOfItems[$i][0], $aOther) Then
					$sBasePath &= "Consumable/Other/"
				ElseIf StringInStr($ListOfItems[$i][0], " Dye") Or StringInStr($ListOfItems[$i][0], " Cloth") Then ; Dyes / Clothes
					$sBasePath &= "Consumable/Dyes/"
				ElseIf StringInStr($ListOfItems[$i][0], "Potion of ") And Not StringInStr($ListOfItems[$i][0], "Health") And Not StringInStr($ListOfItems[$i][0], "Greater") Then ; Stat Potions
					$sBasePath &= "Consumable/Stat%20Potions/"
				ElseIf _MatchesAny($ListOfItems[$i][0], $aRestoratives) Then
					$sBasePath &= "Consumable/Restoratives/"
				ElseIf StringInStr($ListOfItems[$i][0], "Tincture of ") Or StringInStr($ListOfItems[$i][0], "Effusion of ") Then
					$sBasePath &= "Consumable/Tinctures and Effusions/"
				ElseIf StringInStr($ListOfItems[$i][0], " Drake Egg") Then
					$sBasePath &= "Consumable/Drakes/"
				ElseIf _MatchesAny($ListOfItems[$i][0], $aKeys) Then
					$sBasePath &= "Consumable/Keys/"
				ElseIf _MatchesAny($ListOfItems[$i][0], $aWines) Then
					$sBasePath &= "Consumable/Wines/"
				ElseIf _MatchesAny($ListOfItems[$i][0], $aMiscItems) Then
					$sBasePath &= "Misc items/"
				Else
					$sBasePath &= "Consumable/Other/"
				EndIf

				If StringInStr($ListOfItems[$i][0], " (SB)") Then
					$ListOfItems[$i][0] = StringReplace($ListOfItems[$i][0], " (SB)", "") ; Instead of using the SB version just use the normal one
				EndIf
			Case $SlSpellBomb
				$sBasePath &= "Abilities/Spells/T" & $ListOfItems[$i][2] & " "
			Case $SlSeal
				$sBasePath &= "Abilities/Seals/T" & $ListOfItems[$i][2] & " "
			Case $SlCloak
				$sBasePath &= "Abilities/Cloaks/T" & $ListOfItems[$i][2] & " "
			Case $SlRobe
				$sBasePath &= "Armor/Robes/T" & $ListOfItems[$i][2] - 1 & " "
			Case $SlQuiver
				$sBasePath &= "Abilities/Quivers/T" & $ListOfItems[$i][2] & " "
			Case $SlHelm
				$sBasePath &= "Abilities/Helms/T" & $ListOfItems[$i][2] & " "
			Case $SlStaff
				$sBasePath &= "Weapons/Staves/T" & $ListOfItems[$i][2] & " "
			Case $SlPoison
				$sBasePath &= "Abilities/Poisons/T" & $ListOfItems[$i][2] & " "
			Case $SlSkull
				$sBasePath &= "Abilities/Skulls/T" & $ListOfItems[$i][2] & " "
			Case $SlTrap
				$sBasePath &= "Abilities/Traps/T" & $ListOfItems[$i][2] & " "
			Case $SlOrb
				$sBasePath &= "Abilities/Orbs/T" & $ListOfItems[$i][2] & " "
			Case $SlPrism
				$sBasePath &= "Abilities/Prisms/T" & $ListOfItems[$i][2] & " "
			Case $SlScepter
				$sBasePath &= "Abilities/Scepters/T" & $ListOfItems[$i][2] & " "
			Case $SlKatana
				$sBasePath &= "Weapons/Katanas/T" & $ListOfItems[$i][2] & " "
			Case $SlNinjaStar
				$sBasePath &= "Abilities/Stars/T" & $ListOfItems[$i][2] & " "
			Case $SlPetEggs
				$sBasePath &= "Consumable/Pet%20Eggs/"
				$ListOfItems[$i][0] = StringReplace($ListOfItems[$i][0], "?", "_") ; For the '????' eggs which are named '____' instead
			Case Else
				MsgBox(0, "", $ListOfItems[$i][0] & " is of unknown type: " & $ListOfItems[$i][1])
		EndSwitch
	EndIf

	$hPic = _WinHttpSimpleRequest($hConnect, "GET", $sBasePath & $ListOfItems[$i][0] & ".png", $WINHTTP_NO_REFERER, $WINHTTP_NO_REQUEST_DATA, $WINHTTP_NO_ADDITIONAL_HEADERS, False, 2)
	If $hPic = "" Then
		_LogError("Coud'nt map: " & $ListOfItems[$i][0] & @CRLF & "Slot: " & $ListOfItems[$i][1] & @CRLF & "Tier: " & $ListOfItems[$i][2] & @CRLF & "URL: https://static.drips.pw/" & $sBasePath & $ListOfItems[$i][0] & ".png")
	Else
		Local $hBitMap = _GDIPlus_BitmapCreateFromMemory($hPic, False)

		; Calculate position to draw
		; We add 1 because $i starts at 0 and the first slot needs to be empty, see constants.js first entry
		$x = Mod($i + 1, 25) * 40
		$y = Floor(($i + 1) / 25) * 40

		_GDIPlus_GraphicsDrawImageRect($hGraphic, $hBitMap, $x, $y, 40, 40)

		_Log("[" & $i + 1 & "/" & UBound($ListOfItems) & "] Mapped '" & $ListOfItems[$i][0] & "' to " & $x & ", " & $y)
	EndIf
Next

_GDIPlus_ImageSaveToFile($hImage, $MuleDumpPath & "\Renders.png")

_Log("Successfully created Renders.png")

; Clean up WinHTTP
_WinHttpCloseHandle($hClient)
If Not $UseResExtractor Then
	_WinHttpCloseHandle($hTiles)
EndIf
_WinHttpCloseHandle($hObjects)
_WinHttpCloseHandle($hConnect)
_WinHttpCloseHandle($hOpen)

; Clean up GDIPlus
_GDIPlus_ImageDispose($hImage)
_GDIPlus_ImageDispose($hBitMap)
_GDIPlus_GraphicsDispose($hGraphic)
_GDIPlus_Shutdown()

If $ErrorCount <> 0 Then
	_Log("RotMG Resource Updater encountered " & $ErrorCount & " problems!" & @CRLF & "You can report the problem at GitHub.com/RotMGHacker or MPGH.net (megakillzor)" & @CRLF & "Please include your log file!")
EndIf

_Log(@CRLF & "Finished updating RotMG resources!" & @CRLF & "Automatically closing in 10 seconds...")

If $LogToFile Then
	FileClose($fhLogFile)
EndIf

Sleep(10 * 1000)

Exit 0

Func _CheckForValidPaths()
	If $UseResExtractor Then
		Local $aNeededFiles[] = [$ResExtractorPath & "\ResExtractor.exe", $ResExtractorPath & "\SwfDotNet.IO.dll", $ResExtractorPath & "\SharpZipLib.dll", $ResExtractorPath & "\log4net.dll"]
	Else
		Local $aNeededFiles[] = [$RABCDAsmPath & "\swfdecompress.exe", $RABCDAsmPath & "\abcexport.exe", $RABCDAsmPath & "\rabcdasm.exe"]
	EndIf

	For $i = 0 To UBound($aNeededFiles) - 1 Step 1
		If Not FileExists($aNeededFiles[$i]) Then
			_LogError('"' & $aNeededFiles[$i] & '" Doesnt exist!')

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
