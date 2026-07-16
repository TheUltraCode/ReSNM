@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM Refined Silent .NET Maker (ReSNM) - refinement of Silent .NET Maker Synthesized (aka SNMsynth) by strel
REM Current maintainer - ultra_code (or just ultra :) )
REM Original SNMsynth forum thread: https://msfn.org/board/topic/127790-silent-net-maker-synthesized-20100118-w2kxp2k3-x86/

REM This script can be ran on Windows NT OSes from 2000 onwards, although I'd recommend just running this under XP.
REM NOTE: If you plan on creating a .NET 1.1 SP1 installer, you ironically need .NET 1.1 SP1 and the latest security updates (just KB2833941 for XP) installed.

REM NOTE: .NET 3.0 SP2 updates KB982168 & KB2756918 both contain two .msp updates targeted at .NET 2.0 SP2: 976765.msp and 980773.msp.
REM       980773.msp gets installed by .NET 2.0 SP2 updates KB2604092, KB2836941, and KB2901111, thus we can ignore the .msp
REM       provided by either KB982168 or KB2756918.
REM       976765.msp is a required update for the .NET 2.0 SP2 version included in the .NET 3.5 SP1 redist, and should be installed by
REM       itself from KB976765. However, KB2656352 (with its 2656352.msp) builds-upon 976765.msp, and KB2901111 (with its 2901111.msp)
REM       succeeds that. Thus, we can skip KB2656352 and instead install KB2901111 after KB976765.
REM       Therefore, the .NET 2.0 SP2 .msp's included by .NET 3.0 SP2 updates KB982168 & KB2756918 are worthless, as there are
REM       .NET 2.0 SP2 updates that include the same or better .msp's.
REM       So when you decide to make a .NET 3.0 SP2 installer and include KB982168 & KB2756918 as updates, you are okay
REM       hitting "okay" on the pop-up error windows that appear when ReSNM tries to apply their provided .msp's and fails.

REM A couple of formatting standards I've used:
REM   * All white-space code indentation is done with TABs, not 4 SPACEs, because it is more compatbile with CMD.
REM   * All SETs are surrounded by appropriate double-quotation marks when possible.
REM   * All variables meant to be integer-only use the /A switch prior to the setting of the variable, excpet "external" integers read from ReSNM.ini.
REM   * All variables are ideally "deleted" when done with.
REM   * All file extensions are in lower case.
REM   * All commands with switches after them have their switches separated from them by a space (e.g. DIR /B vs DIR/B). Switches themselves can be joined together however (e.g. DIR /B/A-D).
REM   * CMD commands, variables, etc., are capitalized.
REM   * Parentheses are used when possible with all code blocks; *nothing* is to be left to the programmer to interpret.
REM   * Escapes like "&&" that allow for multiple commands on one line are avoided.
REM   * Newlines created by ECHOs are done by "ECHO/" (supposedly this causes the least amount of potential issues).
REM   * Comments are ideally supposed to follow normal English grammatical structure.
REM   * Functions are roughly ordered in the order they are called from in "main", grouped by category.

REM NOTE: When you try ECHO'ing text containing parentheses *inside* of a codeblock without escapes, the parser will interpret the parentheses as code.
REM NOTE: All ERRORLEVEL checks happening inside of code blocks need to be done with DelayedExpansion.
REM NOTE: Make sure if you are doing a compare operation between a variable and an integer in an IF statement (e.g. IF %X% EQU 1) that said variable is defined, or else the script will crash.
REM       You can avoid this by either doing checks before-hand to check if it exists first and if not set the variable to a default value, or use DelayedExpansion with the variable in the comparition.

REM Please look for TODO's (in caps) throughout this script for things I have questions on, worry about, etc.



REM ++++++++++++++++++++++++++++++ Main ++++++++++++++++++++++++++++++



REM ******************** Setup ********************


REM ---------- Initial Setup ----------

TITLE Refined Silent .NET Maker
ECHO/

SET "RSNMVER=v1.00"
ECHO Refined Silent .NET Maker %RSNMVER%
ECHO/
ECHO ^<Initial checks^>

REM While on Windows 10 not passing a parameter to this script and then setting a variable to resulting NUL value does not change ERRORLEVEL.
REM However, under XP this seems to be not acceptable, resulting in the ERRORLEVEL being set to 1. Therefore, we check to see if a parameter was passed.
IF NOT "%1"=="" (
	SET "SWITCH=%1"
)
IF DEFINED SWITCH (
	IF /I "%SWITCH%"=="echo" (
		@ECHO ON
		SET "SWITCH="
	) ELSE (
		ECHO ERROR: %1 is not a supported switch.
		SET "SWITCH="
		GOTO :TERMINATE
	)
)

REM Dependency checks.
IF NOT EXIST 7za.exe (
	ECHO ERROR: 7za.exe is missing.
	ECHO Please download the latest "Extra" package from 7-zip.org to pull 7za.exe from
	ECHO and place it alongside ReSNM.cmd.
	GOTO :TERMINATE
)
IF NOT EXIST 7zSD.sfx (
	ECHO ERROR: 7zSD.sfx is missing.
	ECHO Please download the latest "LZMA SDK" package from 7-zip.org,
	ECHO pull 7zSD.sfx from the "bin" directory of said package,
	ECHO and place it alongside ReSNM.cmd.
	GOTO :TERMINATE
)
IF NOT EXIST FILEVER.vbs (
	ECHO ERROR: FILEVER.vbs is missing.
	ECHO Please download all required .vbs files and  place them alongside ReSNM.cmd.
	GOTO :TERMINATE
)
IF NOT EXIST TRANSFORMDB.vbs (
	ECHO ERROR: TRANSFORMDB.vbs is missing.
	ECHO Please download all required .vbs files and place them alongside ReSNM.cmd.
	GOTO :TERMINATE
)
IF NOT EXIST HFXS (
	MD HFXS
	ECHO ERROR: There was not a "HFXS" directory to place the redistributables
	ECHO and updates in.
	ECHO Please place said files into the newly-created "HFXS" directory.
	GOTO :TERMINATE
)
IF NOT EXIST MSTS (
	ECHO ERROR: The required "MSTS" directory with its required .mst files is missing.
	ECHO Please place the directory alongside ReSNM.cmd.
	GOTO :TERMINATE
) ELSE IF NOT EXIST MSTS\*.mst (
	ECHO ERROR: There does not appear to be any .mst files inside the "MSTS" directory.
	ECHO Please download required .mst files, place them inside the direcoty.
	GOTO :TERMINATE
)

REM Preparing the work environment.
ECHO/
ECHO Cleaning work folder...
IF EXIST OUT* (
	FOR /F %%I IN ('DIR /B/A:D OUT*') DO (
		IF NOT EXIST %%I\*.exe IF NOT EXIST %%I\*.7z IF NOT EXIST %%I\*.cmd (
			RD /Q/S %%I 1>NUL 2>&1
			IF !ERRORLEVEL! NEQ 0 (
				ECHO/
				ECHO ERROR: Close any process using .\%%I to allow its deletion.
			)
		)
	)
)
IF EXIST TMP (
	RD /Q/S TMP 1>NUL 2>&1
	IF !ERRORLEVEL! NEQ 0 (
		ECHO/
		ECHO ERROR: Close any process using .\TMP to allow its deletion.
		GOTO :TERMINATE
	)
)
MD TMP 1>NUL 2>&1
SET /A "OUTCNT=0"
CALL :OUTCOUNT

ECHO>>OUT%OUTCNT%\PROCESSDATA.txt --- HFXS FOLDER CONTENT:
DIR /B/O:G HFXS>>OUT%OUTCNT%\PROCESSDATA.txt
ECHO/>>OUT%OUTCNT%\PROCESSDATA.txt
ECHO>>OUT%OUTCNT%\PROCESSDATA.txt --- ReSNM.ini SETTINGS USED:

REM ReSNM.ini checks.
IF EXIST ReSNM.ini (
	FOR /F "tokens=1,2 delims==" %%I IN ('FINDSTR "=" ReSNM.ini') DO (
		SET "%%I=%%J"
		IF DEFINED %%I (
			ECHO>>OUT%OUTCNT%\PROCESSDATA.txt %%I=%%J
		)
	)
) ELSE (
	ECHO/
	ECHO WARNING: ReSNM.ini not present - using default settings to build installers.
	SET "PROCESSDNF11=1"
	SET "PROCESSDNF20=1"
	SET "PROCESSDNF3520=1"
	SET "PROCESSDNF3530=1"
	SET "PROCESSDNF3535=1"
	SET "PROCESSLNGDNF11=1"
	SET "PROCESSLNGDNF20=1"
	SET "PROCESSLNGDNF3520=1"
	SET "PROCESSLNGDNF3530=1"
	SET "PROCESSLNGDNF3535=1"
)

REM Making sure TARGETOS value is uppercase.
IF DEFINED TARGETOS (
	IF /I "%TARGETOS%"=="2K" (
		SET "TARGETOS=2K"
	) ELSE IF /I "%TARGETOS%"=="XP" (
		SET "TARGETOS=XP"
	) ELSE IF /I "%TARGETOS%"=="2K3" (
		SET "TARGETOS=2K3"
	)
)
IF NOT "%TARGETOS%"=="2K" IF NOT "%TARGETOS%"=="XP" IF NOT "%TARGETOS%"=="2K3" (
	ECHO/
	ECHO ERROR: You have to define an appropriate target OS version in ReSNM.ini.
	GOTO :TERMINATE
)

REM The special parameter-syntax that is responsible for providing the full directory path is required for extraction commands to work properly.
IF "%MERGEFXS%"=="1" (
	SET "DNF11DIR=%~dp0TMP\DNF"
	SET "DNF20DIR=%~dp0TMP\DNF"
	SET "DNF30DIR=%~dp0TMP\DNF"
	SET "DNF35DIR=%~dp0TMP\DNF"
) ELSE (
	SET "DNF11DIR=%~dp0TMP\DNF11"
	SET "DNF20DIR=%~dp0TMP\DNF20"
	SET "DNF30DIR=%~dp0TMP\DNF30"
	SET "DNF35DIR=%~dp0TMP\DNF35"
)

IF "%SILENT%"=="1" (
	SET "VERBOSITY=quiet"
) ELSE (
	SET "VERBOSITY=passive"
)

CALL :SETMEMPARAM

REM See if we can even do anything.
ECHO/
ECHO Checking .NET stuff to build installers/addons for %TARGETOS%...
IF NOT EXIST HFXS\dotnetfx.exe IF NOT EXIST HFXS\NetFx20SP2_x86.exe IF NOT EXIST HFXS\dotnetfx35.exe (
	ECHO ERROR: There is no valid .NET framework package present in the work folder.
	GOTO :TERMINATE
)
IF NOT "%PROCESSDNF11%"=="1" IF NOT "%PROCESSDNF20%"=="1" (
	IF "%TARGETOS%"=="2K" (
		ECHO ERROR: ReSNM.ini is not set to process any valid 1.1 SP1/2.0 SP2 package for Win2K.
		GOTO :TERMINATE
	) ELSE IF NOT "%PROCESSDNF3520%"=="1" IF NOT "%PROCESSDNF3530%"=="1" IF NOT "%PROCESSDNF3535%"=="1" (
		ECHO ERROR: ReSNM.ini is not set to process any package.
		GOTO :TERMINATE
	)
)

REM ---------- .NET 1.1 Staging ----------

IF EXIST HFXS\dotnetfx.exe IF "%PROCESSDNF11%"=="1" (
	ECHO/
	ECHO ^<.NET 1.1 Staging^>
	
	SET "DNF11VER=1.1.4322.573"
	FOR /F %%I IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\dotnetfx.exe') DO (
		IF NOT "%%I"=="!DNF11VER!" (
			ECHO ERROR: The provided .NET 1.1 installer is not the latest.
			ECHO/
			ECHO Queried version: %%I
			ECHO Required version: !DNF11VER!
			GOTO :TERMINATE
		)
	)
	
	REM .NET 1.1 is already included with Win2K3, hence this check.
	IF "%TARGETOS%"=="2K3" (
		ECHO NOTE: .NET 1.1 is not going to be processed to build installers for Win2K3.
		ECHO/
	) ELSE (
		IF NOT EXIST HFXS\NDP1.1sp1-KB867460-X86.exe (
			ECHO ERROR: Service Pack 1 for .NET 1.1 ^(NDP1.1sp1-KB867460-X86.exe^) is missing.
			GOTO :TERMINATE
		)
		
		SET /A "DNF11INPROCESS=1"
		
		IF "%TARGETOS%"=="2K" (
			REM Update checks will be listed in order of release date, then ascending numeric order.
			IF NOT EXIST HFXS\NDP1.1sp1-KB971108-X86.exe (
				ECHO WARNING: NDP1.1sp1-KB971108-X86.exe ^(Win2K^) is absent.
				ECHO/
				SET /A "ABSENCEMSG=1"
			)
			IF NOT EXIST HFXS\NDP1.1sp1-KB979906-x86.exe (
				ECHO WARNING: NDP1.1sp1-KB979906-X86.exe ^(Win2K^) is absent.
				ECHO/
				SET /A "ABSENCEMSG=1"
			)
		) ELSE (
			IF NOT EXIST HFXS\NDP1.1sp1-KB2833941-X86.exe (
				ECHO WARNING: NDP1.1sp1-KB2833941-X86.exe ^(WinXP/2K3^) is absent.
				ECHO/
				SET /A "ABSENCEMSG=1"
			)
		)
		
		IF EXIST HFXS\langpack*.exe IF "%PROCESSLNGDNF11%"=="1" (
			SET /A "LNGDNF11INPROCESS=1"
			FOR /F %%I IN ('DIR /B HFXS\langpack*.exe') DO (
				FOR /F %%J IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\%%I') DO (
					IF NOT "%%J"=="!DNF11VER!" (
						ECHO ERROR: %%I's version does not match that of .NET 1.1.
						ECHO Queried version: %%J
						ECHO Required version: !DNF11VER!
						ECHO/
						ECHO Please provide newer version of the language pack meant for .NET 1.1.
						GOTO :TERMINATE
					)
					SET /A "DNF11LNGCNT+=1"
				)
			)
		)
	)
)
SET "DNF11VER="

REM ---------- .NET 2.0/3.0/3.5 Prep ----------

REM Feels kinda silly, but oh well.
IF "%PROCESSDNF20%"=="1" (
	SET /A "P20=1"
) ELSE (
	SET /A "P20=0"
)
IF "%PROCESSDNF3520%"=="1" (
	SET /A "P3520=1"
) ELSE (
	SET /A "P3520=0"
)
IF "%PROCESSDNF3530%"=="1" (
	SET /A "P3530=1"
) ELSE (
	SET /A "P3530=0"
)
IF "%PROCESSDNF3535%"=="1" (
	SET /A "P3535=1"
) ELSE (
	SET /A "P3535=0"
)
SET /A "PROCESSANY20PLUS=%P20% | %P3520% | %P3530% | %P3535%"
IF %PROCESSANY20PLUS% EQU 1 (
	SET "PROCESSANY20PLUS="
	ECHO/
	ECHO ^<.NET 2.0/3.0/3.5 Prep^>
)

IF EXIST HFXS\NetFx20SP2_x86.exe IF %P20% EQU 1 (
	IF %P3520% EQU 1 IF EXIST HFXS\dotnetfx35.exe (
		ECHO ERROR: Choose which package to process .NET 2.0 SP2 framework
		ECHO from via ReSNM.ini.
		ECHO Either define "PROCESSDNF20" to pull from NetFx20SP2_x86.exe, or
		ECHO define "PROCESSDNF3520" to pull from dotnetfx35.exe, not both.
		GOTO :TERMINATE
	)
	IF %P3520% EQU 1 (
		ECHO ERROR: You cannot have both "PROCESSDNF20" and "PROCESSDNF3520" defined
		ECHO in ReSNM.ini.
		ECHO Choose the appropriate one given the provided .NET 2.0 SP2 source.
		GOTO :TERMINATE
	)
	
	SET "P20="
	SET /A "DNF20INPROCESS=1"
)

SET /A "PROCESSANY35=%P3520% | %P3530% | %P3535%"

IF EXIST HFXS\dotnetfx35.exe IF %PROCESSANY35% EQU 1 (
	SET "PROCESSANY35="
	
	IF NOT "%TARGETOS%"=="2K" (
		IF %P3520% EQU 1 (
			SET /A "DNF35INPROCESS=1"
			SET /A "DNF3520INPROCESS=1"
		)
		IF %P3530% EQU 1 (
			SET /A "DNF35INPROCESS=1"
			SET /A "DNF3530INPROCESS=1"
		)
		IF %P3535% EQU 1 (
			SET /A "DNF35INPROCESS=1"
			SET /A "DNF3535INPROCESS=1"
		)
	) ELSE (
		IF %P3520% EQU 1 (
			ECHO ERROR: The provided .NET 3.5 SP1 installer will not be used to create
			ECHO a Win2K .NET 2.0 SP2 installer.
			ECHO Please provide a standalone .NET 2.0 SP2 installer ^(NetFx20SP2_x86.exe^)
			ECHO and make the appropriate changes in ReSNM.ini.
			GOTO :TERMINATE
		) ELSE (
			ECHO NOTE: .NET 3.0 SP2/3.5 SP1 cannot be installed under Win2K, and thus
			ECHO the provided .NET 3.5 SP1 installer will not be processed.
		)
	)
	SET "P3520="
	SET "P3530="
	SET "P3535="
)

IF NOT DEFINED DNF11INPROCESS IF NOT DEFINED DNF20INPROCESS IF NOT DEFINED DNF35INPROCESS (
	ECHO/
	ECHO ERROR: No ReSNM.ini settings trigger the processing
	ECHO of any .NET framework packages present in the work folder.
	GOTO :TERMINATE
)

IF "%MERGEFXS%"=="1" (
	IF DEFINED DNF20INPROCESS (
		IF DEFINED DNF3530INPROCESS (
			SET /A "WRONG=1"
		)
		IF DEFINED DNF3535INPROCESS (
			SET /A "WRONG=1"
		)
		IF DEFINED WRONG (
			SET "WRONG="
			ECHO ERROR: You can only create a merged installer/add-on that
			ECHO includes .NET 2.0 SP2 and 3.0 SP2/3.5 SP1 for WinXP/Win2K3
			ECHO from a .NET 3.5 SP1 installer.
			ECHO Please leave "PROCESSDNF20" undefined and define "PROCESSDNF3520" in ReSNM.ini.
			GOTO :TERMINATE
		)
	)
	
	IF NOT DEFINED DNF3520INPROCESS IF DEFINED DNF3530INPROCESS IF DEFINED DNF3535INPROCESS (
		ECHO ERROR: .NET 2.0 SP2 framework must be included in a merged
		ECHO installer/add-on containing .NET 3.0 SP2 and 3.5 SP1 frameworks.
		GOTO :TERMINATE
	)
	
	IF NOT DEFINED DNF3530INPROCESS IF DEFINED DNF3535INPROCESS IF DEFINED DNF3520INPROCESS (
		ECHO ERROR: .NET 3.0 SP2 framework must be included in a merged
		ECHO installer/add-on containing .NET 2.0 SP2 and 3.5 SP1 frameworks.
		GOTO :TERMINATE
	)
	
	IF NOT DEFINED DNF3535INPROCESS IF DEFINED DNF3520INPROCESS IF DEFINED DNF3530INPROCESS (
		ECHO ERROR: .NET 3.5 SP1 framework must be included in a merged
		ECHO installer/add-on containing .NET 2.0 SP2 and 3.0 SP2 frameworks.
		GOTO :TERMINATE
	)
)

REM ---------- .NET 2.0 Staging ----------

IF DEFINED DNF20INPROCESS (
	ECHO/
	ECHO ^<.NET 2.0 Staging^>
	
	SET "DNF20VER=2.2.30729.1"
	FOR /F %%I IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\NetFx20SP2_x86.exe') DO (
		IF NOT "%%I"=="!DNF20VER!" (
			ECHO ERROR: The provided .NET 2.0 standalone installer is not the latest.
			ECHO/
			ECHO Queried version: %%I
			ECHO Required version: !DNF20VER!
			GOTO :TERMINATE
		)
	)
	
	CALL :DNF20MSTCHECK
	
	IF "%TARGETOS%"=="2K" (
		IF NOT EXIST HFXS\NDP20SP2-KB971111-x86.exe (
			ECHO WARNING: NDP20SP2-KB971111-x86.exe ^(Win2K^) is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP20SP2-KB974417-x86.exe (
			ECHO WARNING: NDP20SP2-KB974417-x86.exe ^(Win2K^) is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP20SP2-KB979909-x86.exe (
			ECHO WARNING: NDP20SP2-KB979909-x86.exe ^(Win2K^) is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		REM TODO: What value do you gain from installing KB958481 under Win2000?
		REM Also, wouldn't the "KB951847 FIX" need to be applied for this as well?
		REM IF NOT EXIST HFXS\NDP20SP2-KB958481-x86.exe (
		REM	ECHO NOTE: NDP20SP2-KB958481-x86.exe ^(WinXP/2K3^) can be installed for 2000, although its purpose it meant to fix an issue with .NET 3.5.
		REM 	ECHO/
		REM )
	) ELSE (
		CALL :DNF20XP2K3CHECK
	)
	REM For subroutines that throw "ERROR"'s that I intend to halt the script for, I cannot simply "GOTO :TERMINATE" because we are inside of a subroutine.
	REM Trying to :TERMINATE inside a subroutine simply EXITs out of that particular subroutine, not the entire script itself.
	REM And I don't want a "hard" EXIT - I prefer using a "soft" EXIT /B, thus this particular workaround:
	REM  * If an error occurs inside a subroutine, define a variable to denote that an ERROR has transpired, jump to the end of the subroutine,
	REM    verify that the variable was defined, and then finally GOTO :TERMINATE within the main script.
	CALL :UPDT23VGEQ3REQCHECK
	IF DEFINED MISSING (
		GOTO :TERMINATE
	)
	
	IF EXIST HFXS\NetFx20SP2_x86*.exe IF "%PROCESSLNGDNF20%"=="1" (
		SET /A "LNGDNF20INPROCESS=1"
		FOR /F %%I IN ('DIR /B HFXS\NetFx20SP2_x86*.exe') DO (
			FOR /F %%J IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\%%I') DO (
				IF NOT "%%J"=="!DNF20VER!" (
					ECHO ERROR: %%I's version does not match that of .NET 2.0 SP2.
					ECHO Queried version: %%J
					ECHO Required version: !DNF20VER!
					ECHO/
					ECHO Please provide newer version of the language pack meant for .NET 2.0 SP2.
					GOTO :TERMINATE
				)
			)
		)
		
		FOR /F %%I IN ('DIR /B HFXS\NetFx20SP2_x86*.exe') DO (
			IF /I NOT "%%I"=="NetFx20SP2_x86.exe" (
				SET /A "DNF20LNGCNT+=1"
				IF /I "%%I"=="NetFx20SP2_x86zh-CHS.exe" (
					SET "DNF20LNGSTR=cn"
				) ELSE IF /I "%%I"=="NetFx20SP2_x86zh-CHT.exe" (
					SET "DNF20LNGSTR=tw"
				) ELSE IF /I "%%I"=="NetFx20SP2_x86pt-BR.exe" (
					SET "DNF20LNGSTR=br"
				) ELSE IF /I "%%I"=="NetFx20SP2_x86pt-PT.exe" (
					SET "DNF20LNGSTR=pt"
				) ELSE (
					SET "DNF20LNGNAME=%%~nI"
					IF /I "!DNF20LNGNAME:~0,-2!.exe"=="NetFx20SP2_x86.exe" (
						FOR %%J IN (ar,cs,da,de,el,es,fr,he,hu,it,ja,ko,nl,no,pl,ru,sv,tr) DO (
							IF /I "%%J"=="!DNF20LNGNAME:~-2!" (
								SET "DNF20LNGSTR=!DNF20LNGNAME:~-2!"
							)
						)
					)
					SET "DNF20LNGNAME="
				)
				
				IF DEFINED DNF20LNGSTR (
					IF DEFINED DNF20LNGSTRSET (
						SET "DNF20LNGSTRSET=!DNF20LNGSTRSET!,!DNF20LNGSTR!"
					) ELSE (
						SET "DNF20LNGSTRSET=!DNF20LNGSTR!"
					)
					REM All of these .mst files seem to remove a specific row from three tables inside of the langpack installers - `CA BlockDirectInstall Cartman MSI x86`
					REM This allows for our custom installer to proceed with the installation.
					REM Otherwise we'd get an error like: "To install this product please run Setup.exe" (from .NET 2.0 SP2 installer).
					IF NOT EXIST TMP\20SP#LNG!DNF20LNGSTR!_REM_MSI_BLOCKING.mst (
						COPY /Y MSTS\20SP#LNG!DNF20LNGSTR!_REM_MSI_BLOCKING.mst TMP >NUL
					)
					REM KB829019 *seems* to be a language pack update for base .NET 2.0, not SP2 (despite the naming of the .mst file indicating it would still apply to SP2).
					REM Looking at the .mst file's two binary payloads, they are just two different VB scripts that make changes to the registry.
					REM I would want to wager that the issue would have been resolved by SP2, but am unsure.
					REM TODO: see if this .mst is required anymore.
					IF "!DNF20LNGSTR!"=="br" IF NOT EXIST TMP\20SP#LNGbr_KB829019FIX.mst (
						COPY /Y MSTS\20SP#LNGbr_KB829019FIX.mst TMP >NUL
					)
					SET "DNF20LNGSTR="
				) ELSE (
					ECHO WARNING: %%I is not a supported langpack and will not be used.
					ECHO/
				)
			)
		)
		IF NOT EXIST TMP\20SP2LNG_KB951847FIX.mst (
			COPY /Y MSTS\20SP2LNG_KB951847FIX.mst TMP >NUL
		)
	)
)
SET "DNF20VER="

REM ---------- .NET 2.0/3.0/3.5 Staging ----------

IF DEFINED DNF35INPROCESS (
	ECHO/
	ECHO ^<.NET 2.0/3.0/3.5 Staging^>
	
	SET "DNF35VER=3.5.30729.1"
	FOR /F %%I IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\dotnetfx35.exe') DO (
		IF NOT "%%I"=="!DNF35VER!" (
			ECHO ERROR: The provided .NET 3.5 installer is presumably missing the necessary service packs for each respective .NET version
			ECHO and is not the latest version.
			ECHO/
			ECHO Queried version: %%I
			ECHO Required version: !DNF35VER!
			GOTO :TERMINATE
		)
	)
	
	IF DEFINED DNF3520INPROCESS (
		CALL :DNF20MSTCHECK
		CALL :DNF20XP2K3CHECK
		CALL :UPDT23VGEQ3REQCHECK
		IF DEFINED MISSING (
			GOTO :TERMINATE
		)
		
		IF EXIST HFXS\dotnetfx35langpack_x86*.exe IF "%PROCESSLNGDNF3520%"=="1" (
			SET /A "LNGDNF35INPROCESS=1"
			SET /A "LNGDNF3520INPROCESS=1"
		)
	)
	
	IF DEFINED DNF3530INPROCESS (
		IF NOT EXIST TMP\30SP2_REM_MSI_BLOCKING.mst (
			COPY /Y MSTS\30SP2_REM_MSI_BLOCKING.mst TMP >NUL
		)
		IF "%RMDNF30RGBRASTERIZER%"=="1" (
			ECHO NOTE: DirectX9 RGB Rasterizer will be removed from 3.0 SP2 framework.
			ECHO/
		)
		IF "%RMDNF30WIC%"=="1" (
			ECHO NOTE: WIC will be removed from 3.0 SP2 framework.
			ECHO Use another source to install it before 3.0 SP2 framework.
			ECHO/
		)
		IF "%RMDNF30MSXML6%"=="1" (
			ECHO NOTE: MSXML6 will be removed from 3.0 SP2 framework.
			ECHO Use another source to install it before 3.0 SP2 framework.
			ECHO/
		) ELSE (
			REM First msxml6-KB*x86.exe file will be used.
			REM First msxml6*.msi file will be only be used if there are no msxml6-KB*x86.exe files.
			REM This should only be considered if you are on XP SP2, otherwise stock SP3's msxml6.dll is more than new enough.
			REM KB2757638 for SP3 provides the latest version of msxml6.dll AFAIK.
			REM 
			REM Stock XP SP2 msxml6.dll version - [does not exist]
			REM Stock XP SP3 msxml6.dll version - 6.20.1076.0 (SP2)
			REM Version from dotnetfx35.exe     - 6.10.1200.0 (SP1) (the most out-of-date version out of the bunch)
			REM Version from msxml6-KB973686    - 6.20.2003.0 (SP2)
			REM Version from KB2757638          - 6.20.2502.0 (SP2)
			IF EXIST HFXS\msxml6-KB*-x86.exe (
				SET /A "XMLFILETYPE=1"
				FOR /F %%I IN ('DIR /B HFXS\msxml6-KB*-x86.exe') DO (
					SET /A "LOOPCNT+=1"
					IF !LOOPCNT! EQU 1 (SET "XMLFILE=%%I")
				)
				IF !LOOPCNT! GTR 1 (
					ECHO WARNING: Only !XMLFILE! will be used.
					ECHO/
				)
				SET "LOOPCNT="
			) ELSE IF EXIST HFXS\msxml6*.msi (
				SET /A "XMLFILETYPE=0"
				FOR /F %%I IN ('DIR /B HFXS\msxml6*.exe') DO (
					SET /A "LOOPCNT+=1"
					IF !LOOPCNT! EQU 1 (SET "XMLFILE=%%I")
				)
				IF !LOOPCNT! GTR 1 (
					ECHO WARNING: Only !XMLFILE! will be used.
					ECHO/
				)
				SET "LOOPCNT="
			)
		)
		IF "%RMDNF30XPS%"=="1" (
			ECHO NOTE: XPS print driver will be removed from 3.0 SP2 framework.
			ECHO Use another source to install it.
			ECHO/
		) ELSE (
			IF "%TARGETOS%"=="XP" (
				IF EXIST HFXS\WindowsXP-KB971276-v3-x86-ENU.exe (
					IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
						ECHO NOTE: WindowsXP-KB971276-v3-x86-ENU.exe will update 3.0 SP2 XPS driver,
						ECHO patched with the latest files from WindowsServer2003-KB971276-v2-x86-ENU.exe.
						ECHO/
					) ELSE (
						ECHO WARNING: WindowsXP-KB971276-v3-x86-ENU.exe will update 3.0 SP2 XPS driver,
						ECHO but lacking the latest files from WindowsServer2003-KB971276-v2-x86-ENU.exe.
						ECHO/
					)
				) ELSE (
					IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
						ECHO WARNING: WindowsXP-KB971276-v3-x86-ENU.exe is required to update 3.0 SP2 XPS
						ECHO driver with the latest files from WindowsServer2003-KB971276-v2-x86-ENU.exe.
					) ELSE (
						ECHO WARNING: WindowsXP-KB971276-v3-x86-ENU.exe and WindowsServer2003-KB971276-v2-
						ECHO x86-ENU.exe are required to update 3.0 SP2 XPS driver with the latest files.
					)
					ECHO/
					SET /A "ORIGINALXPS=1"
				)
			) ELSE (
				IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
					ECHO NOTE: WindowsServer2003-KB971276-v2-x86-ENU.exe will update 3.0 SP2 XPS driver.
					ECHO/
				) ELSE (
					ECHO WARNING: WindowsServer2003-KB971276-v2-x86-ENU.exe is required to update
					ECHO 3.0 SP2 XPS driver.
					ECHO/
					SET /A "ORIGINALXPS=1"
				)
			)
		)
		
		IF NOT EXIST HFXS\NDP30SP2-KB958483-x86.exe (
			ECHO WARNING: NDP30SP2-KB958483-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB976570-x86.exe (
			ECHO WARNING: NDP30SP2-KB976570-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB982168-x86.exe (
			ECHO WARNING: NDP30SP2-KB982168-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB977354-x86.exe (
			ECHO WARNING: NDP30SP2-KB977354-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB2832411-x86.exe (
			ECHO WARNING: NDP30SP2-KB2832411-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB2861189-x86.exe (
			ECHO WARNING: NDP30SP2-KB2861189-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP30SP2-KB2756918-x86.exe (
			ECHO WARNING: NDP30SP2-KB2756918-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		
		IF EXIST HFXS\NDP30SP2-KB958483-x86.exe (
			IF NOT EXIST TMP\30SP2_KB951847FIX.mst (
					COPY /Y MSTS\30SP2_KB951847FIX.mst TMP >NUL
			)
		)
		IF NOT EXIST TMP\30SP2_REMFONTCACHEFIX.mst (
			COPY /Y MSTS\30SP2_REMFONTCACHEFIX.mst TMP >NUL
		)
		
		IF EXIST HFXS\dotnetfx35langpack_x86*.exe IF "%PROCESSLNGDNF3530%"=="1" (
			SET /A "LNGDNF35INPROCESS=1"
			SET /A "LNGDNF3530INPROCESS=1"
		)
	)
	
	IF DEFINED DNF3535INPROCESS (
		IF NOT EXIST TMP\35SP1_REM_MSI_BLOCKING.mst (
			COPY /Y MSTS\35SP1_REM_MSI_BLOCKING.mst TMP >NUL
		)
		IF NOT EXIST TMP\35SP1_REM_CAB.mst (
			COPY /Y MSTS\35SP1_REM_CAB.mst TMP >NUL
		)
		IF "%RMDNF35VC9RUNTIME%"=="1" (
			IF NOT EXIST TMP\35SP1_REM_VC9.mst (
				COPY /Y MSTS\35SP1_REM_VC9.mst TMP >NUL
			)
			ECHO NOTE: Visual C++ 9 runtime libraries will be removed from 3.5 SP1 framework.
			ECHO Use another source to install them.
			ECHO/
		)
		IF NOT "%RMDNF35FFXBAPPLUGIN%"=="1" (
			SET /A "FFXBAPINPROCESS=1"
			IF NOT EXIST TMP\35SP1_FFXBAPSWITCH.mst (
				COPY /Y MSTS\35SP1_FFXBAPSWITCH.mst TMP >NUL
			) ELSE IF NOT EXIST TMP\35SP1_REM_FFXBAPPLUGIN.mst (
				COPY /Y MSTS\35SP1_REM_FFXBAPPLUGIN.mst TMP >NUL
			)
		)
		
		IF NOT EXIST HFXS\NDP35SP1-KB958484-x86.exe (
			ECHO WARNING: NDP35SP1-KB958484-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF "%RMDNF35FFCLICKONCEEXT%"=="1" (
			IF NOT EXIST TMP\35SP1_REM_FFCLICKONCEEXT.mst (
				COPY /Y MSTS\35SP1_REM_FFCLICKONCEEXT.mst TMP >NUL
			)
			IF EXIST HFXS\NDP35SP1-KB963707-x86.exe (
				ECHO NOTE: NDP35SP1-KB963707-x86.exe won't be used as ClickOnce is being removed.
				ECHO/
			)
		) ELSE (
			IF NOT EXIST HFXS\NDP35SP1-KB963707-x86.exe (
				ECHO ERROR: NDP35SP1-KB963707-x86.exe is needed with valid ReSNM.ini settings to fix
				ECHO .NET Framework Assistant 1.0 Firefox add-on from 3.5 SP1 framework.
				GOTO :TERMINATE
			)
			IF NOT EXIST TMP\35SP1_KB963707FIX_FFCLICKONCESWITCH.mst (
				COPY /Y MSTS\35SP1_KB963707FIX_FFCLICKONCESWITCH.mst TMP >NUL
			)
			SET /A "FFCLICKONCEINPROCESS=1"
		)
		IF NOT EXIST HFXS\NDP35SP1-KB2604111-x86.exe (
			ECHO WARNING: NDP35SP1-KB2604111-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP35SP1-KB2840629-x86.exe (
			ECHO WARNING: NDP35SP1-KB2840629-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP35SP1-KB2861697-x86.exe (
			ECHO WARNING: NDP35SP1-KB2861697-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP35SP1-KB2836940-x86.exe (
			ECHO WARNING: NDP35SP1-KB2836940-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		IF NOT EXIST HFXS\NDP35SP1-KB2736416-x86.exe (
			ECHO WARNING: NDP35SP1-KB2736416-x86.exe is absent.
			ECHO/
			SET /A "ABSENCEMSG=1"
		)
		
		IF EXIST HFXS\NDP35SP1-KB958484-x86.exe (
			IF NOT EXIST TMP\35SP1_KB951847FIX.mst (
				COPY /Y MSTS\35SP1_KB951847FIX.mst TMP >NUL
			)
		)
		
		IF EXIST HFXS\dotnetfx35langpack_x86*.exe IF "%PROCESSLNGDNF3535%"=="1" (
			SET /A "LNGDNF35INPROCESS=1"
			SET /A "LNGDNF3535INPROCESS=1"
		)
	)
	
	IF DEFINED LNGDNF35INPROCESS (
		FOR /F %%I IN ('DIR /B HFXS\dotnetfx35langpack_x86*.exe') DO (
			FOR /F %%J IN ('CSCRIPT //NOLOGO FILEVER.vbs HFXS\%%I') DO (
				IF NOT "%%J"=="!DNF35VER!" (
					ECHO ERROR: %%I's version does not match that of .NET 3.5 SP1.
					ECHO Queried version: %%J
					ECHO Required version: !DNF35VER!
					ECHO/
					ECHO Please provide newer version of the language pack meant for .NET 3.5 SP1.
					GOTO :TERMINATE
				)
			)
		)
		
		FOR /F %%I IN ('DIR /B HFXS\dotnetfx35langpack_x86*.exe') DO (
			IF DEFINED LNGDNF3520INPROCESS (SET /A "DNF20LNGCNT+=1")
			IF DEFINED LNGDNF3530INPROCESS (SET /A "DNF30LNGCNT+=1")
			IF DEFINED LNGDNF3535INPROCESS (SET /A "DNF35LNGCNT+=1")
			IF /I "%%I"=="dotnetfx35langpack_x86zh-CHS.exe" (
				SET "DNF35LNGSTR=cn"
			) ELSE IF /I "%%I"=="dotnetfx35langpack_x86zh-CHT.exe" (
				SET "DNF35LNGSTR=tw"
			) ELSE IF /I "%%I"=="dotnetfx35langpack_x86pt-BR.exe" (
				SET "DNF35LNGSTR=br"
			) ELSE IF /I "%%I"=="dotnetfx35langpack_x86pt-PT.exe" (
				SET "DNF35LNGSTR=pt"
			) ELSE (
				SET "DNF35LNGNAME=%%~nI"
				IF /I "!DNF35LNGNAME:~0,-2!"=="dotnetfx35langpack_x86" (
					FOR %%J IN (ar,cs,da,de,el,es,fi,fr,he,hu,it,ja,ko,nl,no,pl,ru,sv,tr) DO (
						IF /I "%%J"=="!DNF35LNGNAME:~-2!" (
							SET "DNF35LNGSTR=!DNF35LNGNAME:~-2!"
						)
					)
				)
				SET "DNF35LNGNAME="
			)
			
			IF DEFINED DNF35LNGSTR (
				IF DEFINED DNF35LNGSTRSET (
					SET "DNF35LNGSTRSET=!DNF35LNGSTRSET!,!DNF35LNGSTR!"
				) ELSE (
					SET "DNF35LNGSTRSET=!DNF35LNGSTR!"
				)
				
				IF DEFINED LNGDNF3520INPROCESS (
					IF NOT EXIST TMP\20SP#LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst (
						COPY /Y MSTS\20SP#LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst TMP >NUL
					)
					IF "!DNF35LNGSTR!"=="br" IF NOT EXIST TMP\20SP#LNGbr_KB829019FIX.mst (
						COPY /Y MSTS\20SP#LNGbr_KB829019FIX.mst TMP >NUL
					)
				)
				IF DEFINED LNGDNF3530INPROCESS (
					REM Just like with .NET 2.0, all of these .mst files remove a specific row from three tables inside of the langpack installers - `CA BlockDirectInstall Cartman MSI x86`
					IF NOT EXIST TMP\30SP#LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst (
						COPY /Y MSTS\30SP#LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst TMP >NUL
					)
				)
				IF DEFINED LNGDNF3535INPROCESS (
					REM These *REM_CAB.mst files actually delete a lot of rows in a lot of different tables in the installer. Not sure if they are not necessary, would cause conflicts with what
					REM ReSNM is trying to do, or both?
					IF NOT EXIST TMP\35SP1LNG!DNF35LNGSTR!_REM_CAB.mst (
						COPY /Y MSTS\35SP1LNG!DNF35LNGSTR!_REM_CAB.mst TMP >NUL
					)
					REM Just like with .NET 2.0 & 3.0, all of these .mst files remove a specific row from three tables inside of the langpack installers - `CA BlockDirectInstall Cartman MSI x86`
					IF NOT EXIST TMP\35SP1LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst (
						COPY /Y MSTS\35SP1LNG!DNF35LNGSTR!_REM_MSI_BLOCKING.mst TMP >NUL
					)
				)
				SET "DNF35LNGSTR="
			) ELSE  (
				ECHO WARNING: %%I is not a supported langpack and will not be used.
				ECHO/
			)
		)
		
		IF DEFINED LNGDNF3520INPROCESS (
			IF NOT EXIST TMP\20SP2LNG_KB951847FIX.mst (
				COPY /Y MSTS\20SP2LNG_KB951847FIX.mst TMP >NUL
			)
		)
		IF DEFINED LNGDNF3530INPROCESS (
			REM KB928416 *seems* to have been replaced for the most part by KB951847.
			REM There is specifically a "language pack" KB928416 update that is only replaced by the "language pack" KB929300 update, which is then replaced by nothing new.
			REM However, the other KB929300 updates *are* also replaced by KB951847.
			REM For now I am going to treat this as unnecessary and replace the .mst extension with .old.
			REM TODO: see if this .mst is required anymore.
			REM IF NOT EXIST TMP\30SP#LNG_KB928416FIX.mst (
			REM 	COPY /Y MSTS\30SP#LNG_KB928416FIX.mst TMP >NUL
			REM )
			IF NOT EXIST TMP\30SP2LNG_KB951847FIX.mst (
				COPY /Y MSTS\30SP2LNG_KB951847FIX.mst TMP >NUL
			)
		)
		IF DEFINED LNGDNF3535INPROCESS (
			IF NOT EXIST TMP\35SP1LNG_KB951847FIX.mst (
				COPY /Y MSTS\35SP1LNG_KB951847FIX.mst TMP >NUL
			)
		)
	)
)
SET "DNF35VER="

REM ---------- Missing Files Last-Check ----------

IF DEFINED ABSENCEMSG (
	SET "ABSENCEMSG="
	ECHO/
	ECHO *** It would appear there are updates missing.
	ECHO *** They are required for a fully-updated installation.
	ECHO *** ReSNM will not continue without them.
	ECHO/
	GOTO :TERMINATE
)


REM ******************** Processing ********************


REM ---------- .NET Package Processing ----------

ECHO/
ECHO ^<.NET Package Processing^>

IF DEFINED DNF11INPROCESS (
	ECHO/
	ECHO ^> Processing .NET 1.1 package
	CALL :TMPCOUNT
	START /WAIT HFXS\dotnetfx.exe /C /T:"!TMPDIR!"
	CALL :DNF11
	IF DEFINED MISSING (
		GOTO :TERMINATE
	)
	SET /A "LNGPROCESSCNT=0"
	IF DEFINED LNGDNF11INPROCESS (
		ECHO/
		ECHO ^> Processing .NET 1.1 Language Packs
		FOR /F %%J IN ('DIR /B HFXS\langpack*.exe') DO (
			SET /A "LNGPROCESSCNT+=1"
			ECHO Processing %%J...
			START /WAIT HFXS\%%J /C /T:"!TMPDIR!\LANGPACK!LNGPROCESSCNT!"
			CALL :DNF11LNG
			START /WAIT HFXS\%%J /C /T:"%DNF11DIR%\DNF11\!DNF11LNGSTR!LNG"
			IF !LNGPROCESSCNT! EQU !DNF11LNGCNT! (
				ECHO/>>TMP\INSTALL1.cmd
				ECHO>>TMP\INSTALL1.cmd FOR %%%%I IN ^(!DNF11LNGSTRSET!^) DO ^(START /WAIT DNF11\%%%%ILNG\langpack.msi /l*v "%%TMP%%\DNF11%%%%ILNGinstall.log" REBOOT=ReallySuppress /%%VERBOSITY%%^)
			)
		)
		ECHO/>>TMP\INSTALL1.cmd
		ECHO>>TMP\INSTALL1.cmd DIR /B/A:-D/S "%%ALLUSERSPROFILE%%"^>AUP.txt
		ECHO>>TMP\INSTALL1.cmd FOR /F "delims=" %%%%I IN ^('FINDSTR /IC:"Microsoft .NET Framework 1.1 Configuration.lnk" AUP.txt'^) DO ^(SET "DNFC=%%%%I"^)
		ECHO>>TMP\INSTALL1.cmd FOR /F "delims=" %%%%I IN ^('FINDSTR /IC:"Microsoft .NET Framework 1.1 Wizards.lnk" AUP.txt'^) DO ^(SET "DNFW=%%%%I"^)
		ECHO>>TMP\INSTALL1.cmd DEL /F/Q AUP.txt
		ECHO>>TMP\INSTALL1.cmd IF DEFINED DNFC ^(
		ECHO>>TMP\INSTALL1.cmd 	DEL /F/Q "%%DNFC%%"
		ECHO>>TMP\INSTALL1.cmd 	SET "DNFC="
		ECHO>>TMP\INSTALL1.cmd ^)
		ECHO>>TMP\INSTALL1.cmd IF DEFINED DNFW ^(
		ECHO>>TMP\INSTALL1.cmd 	DEL /F/Q "%%DNFW%%"
		ECHO>>TMP\INSTALL1.cmd 	SET "DNFW="
		ECHO>>TMP\INSTALL1.cmd ^)
	)
	SET "DNF11DIR="
	ECHO/
)

IF DEFINED DNF20INPROCESS (
	ECHO/
	ECHO ^> Processing .NET 2.0 SP2 package
	CALL :TMPCOUNT
	START /WAIT HFXS\NetFx20SP2_x86.exe /Q /X:"!TMPDIR!"
	CALL :DNF20
	IF DEFINED MISSING (
		GOTO :TERMINATE
	)
	SET /A "LNGPROCESSCNT=0"
	IF DEFINED LNGDNF20INPROCESS (
		ECHO/
		ECHO ^> Processing .NET 2.0 SP2 Language Packs
		FOR %%I IN (!DNF20LNGSTRSET!) DO (
			SET /A "LNGPROCESSCNT+=1"
			ECHO Processing NetFx20SP2_x86%%I.exe...
			SET "DNF20LNGSTR=%%I"
			START /WAIT HFXS\NetFx20SP2_x86%%I.exe /Q /X:"!TMPDIR!\LANGPACK!DNF20LNGSTR!"
			CALL :DNF20LNG
		)
	)
	ECHO/
)

IF DEFINED DNF35INPROCESS (
	ECHO/
	ECHO ^> Processing .NET 3.5 SP1 package
	CALL :TMPCOUNT
	START /WAIT HFXS\dotnetfx35.exe /Q /X:"!TMPDIR!"
	IF DEFINED DNF3520INPROCESS (
		ECHO/
		ECHO ^>^> Processing .NET 2.0 SP2 portion
		CALL :DNF20
		IF DEFINED MISSING (
			GOTO :TERMINATE
		)
	)
	IF DEFINED DNF3530INPROCESS (
		ECHO/
		ECHO ^>^> Processing .NET 3.0 SP2 portion
		CALL :DNF30
		IF DEFINED MISSING (
			GOTO :TERMINATE
		)
	)
	IF DEFINED DNF3535INPROCESS (
		ECHO/
		ECHO ^>^> Processing .NET 3.5 SP1 portion
		CALL :DNF35
		IF DEFINED MISSING (
			GOTO :TERMINATE
		)
	)
	SET /A "LNGPROCESSCNT=0"
	IF DEFINED LNGDNF35INPROCESS (
		ECHO/
		ECHO ^> Processing .NET 3.5 SP1 Language Packs
		FOR %%I IN (!DNF35LNGSTRSET!) DO (
			SET /A "LNGPROCESSCNT+=1"
			ECHO Processing dotnetfx35langpack_x86%%I.exe...
			ECHO {
			SET "DNF35LNGSTR=%%I"
			START /WAIT HFXS\dotnetfx35langpack_x86%%I.exe /Q /X:"!TMPDIR!\LANGPACK!DNF35LNGSTR!"
			IF DEFINED LNGDNF3520INPROCESS (
				ECHO ^* Processing .NET 2.0 SP2 !DNF35LNGSTR! language portion...
				SET "DNF20LNGSTR=!DNF35LNGSTR!"
				CALL :DNF20LNG
			)
			IF DEFINED LNGDNF3530INPROCESS (
				ECHO ^* Processing .NET 3.0 SP2 !DNF35LNGSTR! language portion...
				SET "DNF30LNGSTR=!DNF35LNGSTR!"
				CALL :DNF30LNG
			)
			IF DEFINED LNGDNF3535INPROCESS (
				ECHO ^* Processing .NET 3.5 SP1 !DNF35LNGSTR! language portion...
				CALL :DNF35LNG
			)
			ECHO }
		)
	)
	ECHO/
)
SET "DNF20DIR="
SET "DNF30DIR="
SET "DNF35DIR="

SET "LNGDNF20INPROCESS="
SET "DNF20LNGSTRSET="
SET "LNGDNF35INPROCESS="
SET "LNGDNF3520INPROCESS="
SET "LNGDNF3535INPROCESS="
SET "DNF35LNGSTRSET="
SET "LNGPROCESSCNT="

REM ---------- Installation Script Preparation ----------

ECHO/
ECHO ^<Installation Script Preparation^>

IF !DNF11LNGCNT! GTR 1 (SET "DNF11LNGSTR=multi")
IF !DNF20LNGCNT! GTR 1 (SET "DNF20LNGSTR=multi")
IF !DNF30LNGCNT! GTR 1 (SET "DNF30LNGSTR=multi")
IF !DNF35LNGCNT! GTR 1 (SET "DNF35LNGSTR=multi")

SET "DNF11LNGCNT="
SET "DNF20LNGCNT="
SET "DNF30LNGCNT="
SET "DNF35LNGCNT="

IF "%MERGEFXS%"=="1" (
	SET "NAME=DNF"
	IF DEFINED DNF11INPROCESS (
		SET "MSG=1.1 SP1"
		IF DEFINED DNF11LNGSTR (SET "MSG=!MSG! %DNF11LNGSTR%")
		SET "NAME=!NAME!11SP1%DNF11LNGSTR%"
	)
	REM This will only execute under 2K, as XP+ will require merged-installers to use .NET 3.5 SP1 installer as the source for .NET 2.0 SP2.
	IF DEFINED DNF20INPROCESS (
		SET /A "SAFETY=1"
		IF DEFINED MSG (SET "MSG=!MSG!/")
		SET "MSG=!MSG!2.0 SP2"
		IF DEFINED DNF20LNGSTR (SET "MSG=!MSG! %DNF20LNGSTR%")
		SET "NAME=!NAME!20SP2%DNF20LNGSTR%"
	)
	IF DEFINED DNF3520INPROCESS (
		SET /A "SAFETY=1"
		IF DEFINED MSG (SET "MSG=!MSG!/")
		SET "MSG=!MSG!2.0 SP2"
		IF DEFINED DNF20LNGSTR (SET "MSG=!MSG! %DNF20LNGSTR%")
		SET "NAME=!NAME!20SP2%DNF20LNGSTR%"
	)
	IF DEFINED DNF3530INPROCESS (
		SET /A "SAFETY=1"
		IF DEFINED MSG (SET "MSG=!MSG!/")
		SET "MSG=!MSG!3.0 SP2"
		IF DEFINED DNF30LNGSTR (SET "MSG=!MSG! %DNF30LNGSTR%")
		SET "NAME=!NAME!30SP2%DNF30LNGSTR%"
	)
	IF DEFINED DNF3535INPROCESS (
		SET /A "SAFETY=1"
		IF DEFINED MSG (SET "MSG=!MSG!/")
		SET "MSG=!MSG!3.5 SP1"
		IF DEFINED DNF35LNGSTR (SET "MSG=!MSG! %DNF35LNGSTR%")
		SET "NAME=!NAME!35SP1%DNF35LNGSTR%"
	)
	REM If you only create a .NET 1.1 installer with MERGEFXS defined, even though you'll get an error at the end of installation,
	REM .NET 1.1 will have been successfully installed.
	REM This will just make sure that error does not happen. :P
	IF DEFINED SAFETY (
		SET "SAFETY="
		CALL :INSTBASE 1
	) ELSE (
		CALL :INSTBASE 0
	)
	COPY /Y TMP\INSTALL.cmd TMP\DNF >NUL
	IF EXIST TMP\INSTALL1.cmd (
		TYPE TMP\INSTALL1.cmd>>TMP\DNF\INSTALL.cmd
		IF EXIST TMP\DNF11.reg (
			MOVE /Y TMP\DNF11.reg TMP\DNF >NUL
			ECHO/>>TMP\DNF\INSTALL.cmd
			ECHO>>TMP\DNF\INSTALL.cmd %%SYSTEMROOT%%\REGEDIT /S DNF11.reg
		)
	)
	IF EXIST TMP\INSTALL2.cmd (
		TYPE TMP\INSTALL2.cmd>>TMP\DNF\INSTALL.cmd
		IF EXIST TMP\INSTREGDOWN2.cmd (
			TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF\INSTALL.cmd
			TYPE TMP\INSTREGDOWN2.cmd>>TMP\DNF\INSTALL.cmd
		)
	)
	IF EXIST TMP\INSTALL3.cmd (
		TYPE TMP\INSTALL3.cmd>>TMP\DNF\INSTALL.cmd
		IF EXIST TMP\INSTREGDOWN3.cmd (
			TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF\INSTALL.cmd
			TYPE TMP\INSTREGDOWN3.cmd>>TMP\DNF\INSTALL.cmd
		)
	)
	IF EXIST TMP\INSTALL35.cmd (
		TYPE TMP\INSTALL35.cmd>>TMP\DNF\INSTALL.cmd
		IF EXIST TMP\INSTREGDOWN35.cmd (
			TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF\INSTALL.cmd
			TYPE TMP\INSTREGDOWN35.cmd>>TMP\DNF\INSTALL.cmd
		)
	)
	
	IF EXIST TMP\INSTEND.cmd (TYPE TMP\INSTEND.cmd>>TMP\DNF\INSTALL.cmd)
	DEL /F/Q TMP\INSTEND.cmd
	REN TMP\DNF\INSTALL.cmd %TARGETOS%!NAME!.cmd
	SET "FLD=TMP\DNF"
	ECHO Creating merged .NET !MSG! %TARGETOS% %VERBOSITY% installer...
	CALL :EXEMAKER
	IF "%T13ADDONS%"=="1" (
		ECHO Creating merged .NET !MSG! %VERBOSITY% T-13 add-on...
		CALL :T13ADDONMAKER
	)
	IF "%ROEADDONS%"=="1" (
		ECHO Creating merged .NET !MSG! %VERBOSITY% RunOnceEx add-on...
		CALL :ROEADDONMAKER
	)
) ELSE (
	IF EXIST TMP\DNF11 (
		SET "MSG=.NET 1.1 SP1"
		IF DEFINED DNF11LNGSTR (SET "MSG=!MSG! %DNF11LNGSTR%")
		SET "NAME=DNF11SP1%DNF11LNGSTR%"
		SET "FLD=TMP\DNF11"
		CALL :INSTBASE 0
		COPY /Y TMP\INSTALL.cmd TMP\DNF11 >NUL
		IF EXIST TMP\INSTALL1.cmd (
			TYPE TMP\INSTALL1.cmd>>TMP\DNF11\INSTALL.cmd
			IF EXIST TMP\DNF11.reg (
				MOVE /Y TMP\DNF11.reg TMP\DNF11 >NUL
				ECHO/>>TMP\DNF11\INSTALL.cmd
				ECHO>>TMP\DNF11\INSTALL.cmd %%SYSTEMROOT%%\REGEDIT /S DNF11.reg
			)
			TYPE TMP\INSTEND.cmd>>TMP\DNF11\INSTALL.cmd
			REN TMP\DNF11\INSTALL.cmd %TARGETOS%!NAME!.cmd
			DEL /F/Q TMP\INSTEND.cmd
		)
		CALL :INSTALLERMAKER
	)
	IF EXIST TMP\DNF20 (
		SET "MSG=.NET 2.0 SP2"
		IF DEFINED DNF20LNGSTR (SET "MSG=!MSG! %DNF20LNGSTR%")
		SET "NAME=DNF20SP2%DNF20LNGSTR%"
		SET "FLD=TMP\DNF20"
		CALL :INSTBASE 1
		COPY /Y TMP\INSTALL.cmd TMP\DNF20 >NUL
		IF EXIST TMP\INSTALL2.cmd (
			TYPE TMP\INSTALL2.cmd>>TMP\DNF20\INSTALL.cmd
			IF EXIST TMP\INSTREGDOWN2.cmd (
				TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF20\INSTALL.cmd
				TYPE TMP\INSTREGDOWN2.cmd>>TMP\DNF20\INSTALL.cmd
			)
			TYPE TMP\INSTEND.cmd>>TMP\DNF20\INSTALL.cmd
			REN TMP\DNF20\INSTALL.cmd %TARGETOS%!NAME!.cmd
			DEL /F/Q TMP\INSTEND.cmd
		)
		CALL :INSTALLERMAKER
	)
	IF EXIST TMP\DNF30 (
		SET "MSG=.NET 3.0 SP2"
		IF DEFINED DNF30LNGSTR (SET "MSG=!MSG! %DNF30LNGSTR%")
		SET "NAME=DNF30SP2%DNF30LNGSTR%"
		SET "FLD=TMP\DNF30"
		CALL :INSTBASE 1
		COPY /Y TMP\INSTALL.cmd TMP\DNF30 >NUL
		IF EXIST TMP\INSTALL3.cmd (
			TYPE TMP\INSTALL3.cmd>>TMP\DNF30\INSTALL.cmd
			IF EXIST TMP\INSTREGDOWN3.cmd (
				TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF30\INSTALL.cmd
				TYPE TMP\INSTREGDOWN3.cmd>>TMP\DNF30\INSTALL.cmd
			)
			TYPE TMP\INSTEND.cmd>>TMP\DNF30\INSTALL.cmd
			REN TMP\DNF30\INSTALL.cmd %TARGETOS%!NAME!.cmd
			DEL /F/Q TMP\INSTEND.cmd
		)
		CALL :INSTALLERMAKER
	)
	IF EXIST TMP\DNF35 (
		SET "MSG=.NET 3.5 SP1"
		IF DEFINED DNF35LNGSTR (SET "MSG=!MSG! %DNF35LNGSTR%")
		SET "NAME=DNF35SP1%DNF35LNGSTR%"
		SET "FLD=TMP\DNF35"
		CALL :INSTBASE 1
		COPY /Y TMP\INSTALL.cmd TMP\DNF35 >NUL
		IF EXIST TMP\INSTALL35.cmd (
			TYPE TMP\INSTALL35.cmd>>TMP\DNF35\INSTALL.cmd
			IF EXIST TMP\INSTREGDOWN35.cmd (
				TYPE TMP\INSTREGDOWN.cmd>>TMP\DNF35\INSTALL.cmd
				TYPE TMP\INSTREGDOWN35.cmd>>TMP\DNF35\INSTALL.cmd
			)
			TYPE TMP\INSTEND.cmd>>TMP\DNF35\INSTALL.cmd
			REN TMP\DNF35\INSTALL.cmd %TARGETOS%!NAME!.cmd
			DEL /F/Q TMP\INSTEND.cmd
		)
		CALL :INSTALLERMAKER
	)
)
SET "DNF11INPROCESS="
SET "LNGDNF11INPROCESS="
SET "DNF20INPROCESS="
SET "DNF20LNGSTR="
SET "DNF35INPROCESS="
SET "DNF3520INPROCESS="
SET "DNF3530INPROCESS="
SET "DNF3535INPROCESS="
SET "LNGDNF3530INPROCESS="
SET "DNF30LNGSTR="
SET "DNF35LNGSTR="
SET "NAME="
SET "MSG="
SET "FLD="

ECHO/
ECHO/>>OUT%OUTCNT%\PROCESSDATA.txt
ECHO>>OUT%OUTCNT%\PROCESSDATA.txt --- .\TMP FOLDER CONTENT:
DIR /B/O:GN TMP>>OUT%OUTCNT%\PROCESSDATA.txt
ECHO/
ECHO ^<Finished^>
ECHO/
EXIT /B
REM ---------- .NET Installers Made, Work Complete ----------



REM ++++++++++++++++++++++++++++++ Subroutines ++++++++++++++++++++++++++++++



REM ******************** Core .NET Subroutines ********************


REM ---------- .NET 2.0 MST Checks ----------
:DNF20MSTCHECK
IF NOT EXIST TMP\20SP2_REM_MSI_BLOCKING.mst (
	COPY /Y MSTS\20SP2_REM_MSI_BLOCKING.mst TMP >NUL
)
IF "%RMDNF20VC8RUNTIME%"=="1" (
	IF NOT EXIST TMP\20SP2_REM_VC8.mst (
		COPY /Y MSTS\20SP2_REM_VC8.mst TMP >NUL
	)
	ECHO NOTE: Visual C++ 8 runtime libraries from 2.0 SP2 framework will be removed.
	ECHO Use another source to install them.
	ECHO/
)
IF "%RMDNF20OFFICE2K3DEBUGGER%"=="1" (
	IF NOT EXIST TMP\20SP2_REM_OFFICE2K3DEBUGGER.mst (
		COPY /Y MSTS\20SP2_REM_OFFICE2K3DEBUGGER.mst TMP >NUL
	)
	ECHO NOTE: Office 2K3 debugger from 2.0 SP2 framework will be removed.
	ECHO/
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 2.0 XP/2K3 Checks ----------
:DNF20XP2K3CHECK
REM You can find KB958481 via searching for hotfix families KB959209 or KB951847, with the only difference being the
REM latter offering a "dotnetfx35" hotfix installer and language packs from the Microsoft Update Catalog.
REM All individual hotfixes for .NET 2.0, 3.0, and 3.5 in each family are the same.
REM Article: https://web.archive.org/web/20081231180151/http://support.microsoft.com/kb/958481/
IF NOT EXIST HFXS\NDP20SP2-KB958481-x86.exe (
	ECHO WARNING: NDP20SP2-KB958481-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB976569-x86.exe (
	ECHO WARNING: NDP20SP2-KB976569-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB974417-x86.exe (
	ECHO WARNING: NDP20SP2-KB974417-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB976576-x86.exe (
	ECHO WARNING: NDP20SP2-KB976576-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2604092-x86.exe (
	ECHO WARNING: NDP20SP2-KB2604092-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2729450-x86.exe (
	ECHO WARNING: NDP20SP2-KB2729450-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2844285-x86.exe (
	ECHO WARNING: NDP20SP2-KB2844285-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2863239-x86.exe (
	ECHO WARNING: NDP20SP2-KB2863239-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2836941-x86.exe (
	ECHO WARNING: NDP20SP2-KB2836941-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2898856-x86.exe (
	ECHO WARNING: NDP20SP2-KB2898856-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2901111-x86.exe (
	ECHO WARNING: NDP20SP2-KB2901111-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2742596-x86.exe (
	ECHO WARNING: NDP20SP2-KB2742596-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)
IF NOT EXIST HFXS\NDP20SP2-KB2789643-x86.exe (
	ECHO WARNING: NDP20SP2-KB2789643-x86.exe ^(WinXP/2K3^) is absent.
	ECHO/
	SET /A "ABSENCEMSG=1"
)

REM While it might make more sense to place the following two checks after the initial checks above, I want to keep these "FIXes" checks separate.
IF EXIST HFXS\NDP20SP2-KB958481-x86.exe (
	IF NOT EXIST TMP\20SP2_KB951847FIX.mst (
		COPY /Y MSTS\20SP2_KB951847FIX.mst TMP >NUL
	)
)
IF EXIST HFXS\NDP20SP2-KB974417-x86.exe (
	IF NOT EXIST TMP\20SP2_KB974417FIX.mst (
		COPY /Y MSTS\20SP2_KB974417FIX.mst TMP >NUL
	)
)
IF NOT EXIST TMP\20SP2_REM_W2K_COMPONENTS.mst (
	COPY /Y MSTS\20SP2_REM_W2K_COMPONENTS.mst TMP >NUL
)
GOTO :EOF
REM ---------- ----------

REM If only I could know whether or not these hotfixes were included in newer updates, then this wouldn't be necessary...
REM TODO: Determine if this subroutine is necessary.
REM ---------- UPDT23VGEQ3REQ Check ----------
:UPDT23VGEQ3REQCHECK
IF EXIST HFXS\NDP20SP2-KB970924-x86.exe (SET /A "UPDT23VGEQ3REQ=0")
IF EXIST HFXS\NDP20SP2-KB971169-x86.exe (SET /A "UPDT23VGEQ3REQ=0")
IF EXIST HFXS\NDP20SP2-KB971993-x86.exe (SET /A "UPDT23VGEQ3REQ=0")
IF DEFINED UPDT23VGEQ3REQ (
	FOR /F "tokens=3 delims=-Bb" %%I IN ('DIR /B HFXS\NDP20SP2-KB*-x86.exe') DO (
		IF %%I EQU 952883 (
			SET /A "UPDT23VGEQ3REQ=1"
		) ELSE IF %%I EQU 958252 (
			SET /A "UPDT23VGEQ3REQ=1"
		) ELSE IF %%I EQU 971030 (
			SET /A "UPDT23VGEQ3REQ=1"
		) ELSE IF %%I EQU 971601 (
			SET /A "UPDT23VGEQ3REQ=1"
		) ELSE IF %%I GEQ 960442 IF %%I LEQ 970510 (
			SET /A "UPDT23VGEQ3REQ=1"
		)
		REM KB972848 has been superseded by KB981574, although neither are easily-attainable hotfixes.
		IF %%I EQU 972848 (SET /A "UPDT23V3=1")
		IF %%I EQU 981574 (SET /A "UPDT23V3=1")
		IF %%I GEQ 971521 IF %%I NEQ 971601 IF %%I NEQ 971993 IF %%I NEQ 972848 IF %%I NEQ 981574 IF %%I NEQ 974417 (SET /A "UPDT23V4=1")
	)
	
	REM TODO: Investigate this logic more closely.
	IF !UPDT23VGEQ3REQ! EQU 1 IF NOT DEFINED UPDT23V3 IF NOT DEFINED UPDT23V4 (
		IF EXIST HFXS\~NDP20SP2-KB*-x86.exe (
			FOR /F "tokens=3 delims=-Bb" %%I IN ('DIR /B HFXS\~NDP20SP2-KB*-x86.exe') DO (
				IF %%I GEQ 971521 IF %%I NEQ 971601 IF %%I NEQ 971993 IF %%I NEQ 972848 IF %%I NEQ 981574 IF %%I NEQ 974417 (SET /A "UPDT23V4=1")
			)
		)
		IF NOT DEFINED UPDT23V4 (
			ECHO ERROR: One NDP20SP2-KB^#-x86.exe HF with ^# ^>^= 971521 ^(just not 971601, 971993, or 974417^),
			ECHO is needed to get a file. Rename to ~NDP20SP2-KB^#-x86.exe to avoid applying it.
			SET /A "MISSING=1"
		)
	)
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 1.1 Handling ----------
:DNF11
START /WAIT MSIEXEC /a "%TMPDIR%\netfx.msi" TARGETDIR="%DNF11DIR%\DNF11" /qb

IF EXIST 11ORDER.txt (
	SET "HFXORDEREDLIST=TYPE 11ORDER.txt"
) ELSE (
	ECHO/>11ORDER.txt
	ECHO/
	ECHO ERROR: Text file "11ORDER.txt" with listed .NET 1.1 updates was missing.
	ECHO Please enter the names of the .NET 1.1 updates you wish to merge into the
	ECHO newly-created "11ORDER.txt" text file, ideally in chronological then
	ECHO numerical order. Do not include language packs or special updates.
	SET /A "MISSING=1"
	GOTO :EOF
)

IF EXIST HFXS\NDP1.1*.exe (
	SET /A "SKIPHFX=0"
	MD "%TMPDIR%\HFX"
	FOR /F %%I IN ('!HFXORDEREDLIST!') DO (
		FOR /F "tokens=3 delims=Bb-_" %%J IN ("%%I") DO (
			REM I'm not sure how someone figured this out, but it's pretty accurate it would seem.
			IF %%J GEQ 946922 (
				SET /A "LONGSWITCH=1"
			)
			REM A whitelist of updates... 
			IF "%TARGETOS%"=="2K" (
				IF %%J NEQ 867460 IF %%J NEQ 971108 IF %%J NEQ 979906 (
					SET /A "SKIPHFX=1"
				)
			) ELSE (
				IF %%J NEQ 867460 IF %%J NEQ 2833941 (
					SET /A "SKIPHFX=1"
				)
			)
			IF !SKIPHFX! NEQ 1 (
				IF DEFINED LONGSWITCH (
					SET "LONGSWITCH="
					START /WAIT HFXS\%%I /extract "%TMPDIR%\HFX"
				) ELSE (
					START /WAIT HFXS\%%I /Xp:"%TMPDIR%\HFX"
				)
				ECHO Processing %%I...
				FOR /F %%K IN ('DIR /B "%TMPDIR%\HFX\*.msp"') DO (
					START /WAIT MSIEXEC /p "%TMPDIR%\HFX\%%K" /a "%DNF11DIR%\DNF11\netfx.msi" /qb
					SET "STUB=%%~nK"
					REM The .msp file for SP1 for .NET 1.1 starts with an "S" as opposed to an "M".
					REM This update also cannot be uninstalled. Once applied, you have to uninstall .NET 1.1
					REM entirely to remove SP1. :P
					REM Consequently, it also doesn't update the Control Panel support info text to mention any "SP1".
					REM Thus, there is no associated uninstallation .msp file, and therefore the update
					REM does not need to be added to DNF11REM.txt.
					IF "!STUB:~0,1!"=="N" (
						FOR /F "tokens=3 delims=Bb-" %%L IN ("!STUB!") DO (ECHO>>TMP\DNF11REM.txt M%%L)
					) ELSE IF "!STUB:~0,1!"=="M" (
						ECHO>>TMP\DNF11REM.txt !STUB!
					)
				)
				DEL /F/Q "%TMPDIR%\HFX\*.msp"
			) ELSE (
				SET "SKIPHFX=0"
			)
		)
	)
	SET "SKIPHFX="
	SET "STUB="
	RD /Q/S "%TMPDIR%\HFX"
)
SET "HFXORDEREDLIST="

REM I noticed that `NET STOP [msiexec.exe service's name]` in SNMsynth was curiously used before .NET 1.1's and 3.0's installations.
REM I did not give it much thought, so decided to have it be executed before every .NET version's installation.
REM Eventually, I thought that was dumb and decided to just have it done before the first one that got installed.
REM I then also decided for merged installers to have .NET 1.1 SP1 installed first, which makes sense - why would you install it after .NET 2.0-3.5?
REM ...
REM Those two changes resulted in .NET 3.0 SP2 not being able to be installed if .NET 1.1 SP1 was installed first with a merged installer.
REM The .NET 3.0 SP2 installer would error-out with MSI code 2337 ("Could not close file: [3] GetLastError: [2]." per Microsoft documentation).
REM The resulting rabbit hole stole away nearly 8 hours of my life.
REM ...
REM It turns out that those `NET STOP`'s were actually important.
REM For some reason, if the msiexec.exe service (under XP it's "MSIServer") is not stopped, it I guess cannot commit the changes properly made by
REM one of the .NET installers? Or perhaps some environment variables aren't cleared? I have no clue.
REM The point is, making sure the service is manually stopped before installing every .NET version helps.
ECHO/>>TMP\INSTALL1.cmd
ECHO>>TMP\INSTALL1.cmd FOR /F "delims=" %%%%I IN ('NET START ^^^| FINDSTR /BC:"   "') DO (
ECHO>>TMP\INSTALL1.cmd 	SET "SERV=%%%%I"
ECHO>>TMP\INSTALL1.cmd 	SET ^"SERV=^^!SERV:~3^^!^"
ECHO>>TMP\INSTALL1.cmd 	IF /I ^"^^!SERV^^!^"=="Windows Installer" (
ECHO>>TMP\INSTALL1.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL1.cmd 	)
ECHO>>TMP\INSTALL1.cmd 	IF /I ^"^^!SERV^^!^"=="MSIServer" (
ECHO>>TMP\INSTALL1.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL1.cmd 	)
ECHO>>TMP\INSTALL1.cmd )
ECHO>>TMP\INSTALL1.cmd SET "SERV="
ECHO>>TMP\INSTALL1.cmd IF DEFINED STOPSERV (
ECHO>>TMP\INSTALL1.cmd 	SET "STOPSERV="
ECHO>>TMP\INSTALL1.cmd 	IF "%%CURRENTOS%%"=="2K" (
ECHO>>TMP\INSTALL1.cmd 		NET STOP "Windows Installer"
ECHO>>TMP\INSTALL1.cmd 	) ELSE (
ECHO>>TMP\INSTALL1.cmd 		NET STOP MSIServer
ECHO>>TMP\INSTALL1.cmd 	)
ECHO>>TMP\INSTALL1.cmd )
ECHO/>>TMP\INSTALL1.cmd
ECHO>>TMP\INSTALL1.cmd START /WAIT DNF11\netfx.msi /l*v "%%TMP%%\DNF11install.log" REBOOT=ReallySuppress /%%VERBOSITY%%
REM Unlike .NET 2.0, the .reg file is created right now by ReSNM as oppposed to during install time.
IF EXIST TMP\DNF11REM.txt (
	ECHO>>TMP\DNF11.reg Windows Registry Editor Version 5.00
	ECHO/>>TMP\DNF11.reg
	FOR /F %%I IN (TMP\DNF11REM.txt) DO (
		COPY /Y NUL "%DNF11DIR%\DNF11\Win\Microsoft.NET\Framework\URTInstallPath\Updates\%%I\%%IUninstall.msp" >NUL
		ECHO>>TMP\DNF11.reg [-HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%%I]
	)
)
ECHO/
GOTO :EOF
REM ---------- ----------

REM This subroutine, while touched-up by me, when it was originally written seemingly did not, uh... "notice" that the .NET 1.1 language packs come with a .cab file used by the .msi installer.
REM If you try to install a given language pack without the included .cab file, the installer will throw an error about it and halt the installation.
REM Maybe there's some fancy way of combining the .msi installer with the .cab file, the included "setup.ini" file, and maybe the included "inst.exe" file (if it's necessary), but what's the point?
REM
REM The current purpose of this subroutine is simply verify the language of the langpack being processed.
REM ---------- .NET 1.1 Language Localization ----------
:DNF11LNG
START /WAIT MSIEXEC /a "%TMPDIR%\LANGPACK%LNGPROCESSCNT%\langpack.msi" TARGETDIR="%TMPDIR%\LANGPACK%LNGPROCESSCNT%\extract" /qb
FOR /F %%I IN ('DIR /B/O:D "%TMPDIR%\LANGPACK%LNGPROCESSCNT%\extract\Program Files\Internet Explorer\MUI"') DO (
	IF NOT "%%I"=="0409" (SET "DNF11LNGSTR=%%I")
)
IF DEFINED DNF11LNGSTR (
	IF "%DNF11LNGSTR%"=="0404" (
		REM Chinese "traditional" (Taiwan)
		SET "DNF11LNGSTR=tw"
	) ELSE IF "%DNF11LNGSTR%"=="0405" (
		REM Czech
		SET "DNF11LNGSTR=cs"
	) ELSE IF "%DNF11LNGSTR%"=="0406" (
		REM Danish
		SET "DNF11LNGSTR=da"
	) ELSE IF "%DNF11LNGSTR%"=="0407" (
		REM German
		SET "DNF11LNGSTR=de"
	) ELSE IF "%DNF11LNGSTR%"=="0408" (
		REM Greek
		SET "DNF11LNGSTR=el"
	) ELSE IF "%DNF11LNGSTR%"=="040B" (
		REM Finnish
		SET "DNF11LNGSTR=fi"
	) ELSE IF "%DNF11LNGSTR%"=="040C" (
		REM French
		SET "DNF11LNGSTR=fr"
	) ELSE IF "%DNF11LNGSTR%"=="040E" (
		REM Hungarian
		SET "DNF11LNGSTR=hu"
	) ELSE IF "%DNF11LNGSTR%"=="0410" (
		REM Italian
		SET "DNF11LNGSTR=it"
	) ELSE IF "%DNF11LNGSTR%"=="0411" (
		REM Japanese
		SET "DNF11LNGSTR=ja"
	) ELSE IF "%DNF11LNGSTR%"=="0412" (
		REM Korean
		SET "DNF11LNGSTR=ko"
	) ELSE IF "%DNF11LNGSTR%"=="0413" (
		REM Dutch
		SET "DNF11LNGSTR=nl"
	) ELSE IF "%DNF11LNGSTR%"=="0414" (
		REM Norwegian
		SET "DNF11LNGSTR=no"
	) ELSE IF "%DNF11LNGSTR%"=="0415" (
		REM Polish
		SET "DNF11LNGSTR=pl"
	) ELSE IF "%DNF11LNGSTR%"=="0416" (
		REM Portuguese (Brazil)
		SET "DNF11LNGSTR=br"
	) ELSE IF "%DNF11LNGSTR%"=="0419" (
		REM Russian (not on download from the Microsoft Update Catalog for some reason :P)
		SET "DNF11LNGSTR=ru"
	) ELSE IF "%DNF11LNGSTR%"=="041D" (
		REM Swedish
		SET "DNF11LNGSTR=sv"
	) ELSE IF "%DNF11LNGSTR%"=="041F" (
		REM Turkish
		SET "DNF11LNGSTR=tr"
	) ELSE IF "%DNF11LNGSTR%"=="0804" (
		REM Chinese "simplified" (China)
		SET "DNF11LNGSTR=cn"
	) ELSE IF "%DNF11LNGSTR%"=="0816" (
		REM Portuguese (Portugal)
		SET "DNF11LNGSTR=pt"
	) ELSE IF "%DNF11LNGSTR%"=="0C0A" (
		REM Spanish
		SET "DNF11LNGSTR=es"
	)
)

IF DEFINED DNF11LNGSTRSET (
	SET "DNF11LNGSTRSET=%DNF11LNGSTRSET%,%DNF11LNGSTR%"
) ELSE (
	SET "DNF11LNGSTRSET=%DNF11LNGSTR%"
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 2.0 Handling ----------
:DNF20
IF EXIST "%TMPDIR%\wcu\dotNetFramework\dotNetFX20\*64.msp" (
	DEL /F/Q "%TMPDIR%\wcu\dotNetFramework\dotNetFX20\*64.msp"
)
REM For some reason we need to extract the .msi from itself before we can make modifications to it. This process simply creates a lesser copy with some stuff inside of it missing.
REM This is also done for other .msi files in this script.
REM TODO: Determine whether this first extraction is even necessary.
START /WAIT MSIEXEC /a "%TMPDIR%\wcu\dotNetFramework\dotNetFX20\Netfx20a_x86.msi" TARGETDIR="%TMPDIR%\ADMIN20" /qb
FOR /F %%I IN ('DIR /B "%TMPDIR%\wcu\dotNetFramework\dotNetFX20\*.msp"') DO (
	START /WAIT MSIEXEC /p "%TMPDIR%\wcu\dotNetFramework\dotNetFX20\%%I" /a "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" /qb
)

ECHO/>>TMP\INSTALL2.cmd
ECHO>>TMP\INSTALL2.cmd FOR /F "delims=" %%%%I IN ('NET START ^^^| FINDSTR /BC:"   "') DO (
ECHO>>TMP\INSTALL2.cmd 	SET "SERV=%%%%I"
ECHO>>TMP\INSTALL2.cmd 	SET ^"SERV=^^!SERV:~3^^!^"
ECHO>>TMP\INSTALL2.cmd 	IF /I ^"^^!SERV^^!^"=="Windows Installer" (
ECHO>>TMP\INSTALL2.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL2.cmd 	)
ECHO>>TMP\INSTALL2.cmd 	IF /I ^"^^!SERV^^!^"=="MSIServer" (
ECHO>>TMP\INSTALL2.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL2.cmd 	)
ECHO>>TMP\INSTALL2.cmd )
ECHO>>TMP\INSTALL2.cmd SET "SERV="
ECHO>>TMP\INSTALL2.cmd IF DEFINED STOPSERV (
ECHO>>TMP\INSTALL2.cmd 	SET "STOPSERV="
ECHO>>TMP\INSTALL2.cmd 	IF "%%CURRENTOS%%"=="2K" (
ECHO>>TMP\INSTALL2.cmd 		NET STOP "Windows Installer"
ECHO>>TMP\INSTALL2.cmd 	) ELSE (
ECHO>>TMP\INSTALL2.cmd 		NET STOP MSIServer
ECHO>>TMP\INSTALL2.cmd 	)
ECHO>>TMP\INSTALL2.cmd )
ECHO/>>TMP\INSTALL2.cmd
ECHO>>TMP\INSTALL2.cmd START /WAIT DNF20\Netfx20a_x86.msi /l*v "%%TMP%%\DNF20install.log" ARPNOMODIFY=0 ARPNOREPAIR=0 REBOOT=ReallySuppress /%%VERBOSITY%%
ECHO>>TMP\INSTALL2.cmd IF NOT "%%CURRENTOS%%"=="2K" (
ECHO>>TMP\INSTALL2.cmd 	FOR /F "tokens=3" %%%%I IN ^('REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\DC3BF90CC0D3D2F398A9A6D1762F70F3\InstallProperties" /V UnfixedDBName ^^^| FINDSTR "UnfixedDBName"'^) DO ^(REN %%%%I 39d37.msi^)
ECHO>>TMP\INSTALL2.cmd 	REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\DC3BF90CC0D3D2F398A9A6D1762F70F3\InstallProperties" /V UnfixedDBName /F
ECHO>>TMP\INSTALL2.cmd )

IF EXIST 20ORDER.txt (
	SET "HFXORDEREDLIST=TYPE 20ORDER.txt"
) ELSE (
	ECHO/>20ORDER.txt
	ECHO/
	ECHO ERROR: Text file "20ORDER.txt" with listed .NET 2.0 SP2 updates was missing.
	ECHO Please enter the names of the .NET 2.0 SP2 updates you wish to merge into the
	ECHO newly-created "20ORDER.txt" text file, ideally in chronological then
	ECHO numerical order. Do not include language packs or special updates.
	SET /A "MISSING=1"
	GOTO :EOF
)

IF EXIST HFXS\NDP20SP2*.exe (
	SET /A "SKIPHFX=0"
	MD "%TMPDIR%\HFX"
	FOR /F %%I IN ('!HFXORDEREDLIST!') DO (
		FOR /F "tokens=3 delims=Bb-" %%J IN ("%%I") DO (
			IF %%J EQU 971111 (
				IF NOT "%TARGETOS%"=="2K" (
					SET /A "SKIPHFX=1"
				)
			)
			
			IF !SKIPHFX! NEQ 1 (
				7za e -o"%TMPDIR%\HFX" -y HFXS\%%I *.msp >NUL
				IF EXIST "%TMPDIR%\HFX\NDP35SP1*.msp" (
					ECHO %%I process delayed.
					IF %%J LEQ 971601 IF %%J NEQ 971521 IF %%J NEQ 971169 IF %%J NEQ 970924 (SET /A "TOUPDT22V1=1")
					IF NOT DEFINED UPDT23V4 (
						IF NOT DEFINED UPDT23V3 (
							IF %%J GEQ 970924 IF %%J LEQ 971169 IF %%J NEQ 971030 (SET /A "TOUPDT22V2=1")
							IF %%J EQU 971993 (SET /A "TOUPDT23V2=1")
						) ELSE (
							IF !UPDT23VGEQ3REQ! EQU 1 IF %%J GEQ 970924 IF %%J LEQ 971169 IF %%J NEQ 971030 (
								SET /A "TOUPDT23V3=1"
							) ELSE IF %%J EQU 971993 (
								SET /A "TOUPDT23V3=1"
							)
						)
						IF %%J EQU 972848 (SET /A "TOUPDT23V3=1")
						IF %%J EQU 981574 (SET /A "TOUPDT23V3=1")
					)
					IF DEFINED TOUPDT22V1 (
						SET "TOUPDT22V1="
						IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT22V1" (MD "%TMPDIR%\DELAYEDHFXS\UPDT22V1")
						COPY /Y "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS\UPDT22V1" >NUL
					) ELSE IF DEFINED TOUPDT22V2 (
						SET "TOUPDT22V2="
						IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT22V2" (MD "%TMPDIR%\DELAYEDHFXS\UPDT22V2")
						COPY /Y "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS\UPDT22V2" >NUL
					) ELSE IF DEFINED TOUPDT23V2 (
						SET "TOUPDT23V2="
						IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT23V2" (MD "%TMPDIR%\DELAYEDHFXS\UPDT23V2")
						COPY /Y "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS\UPDT23V2" >NUL
					) ELSE IF DEFINED TOUPDT23V3 (
						SET "TOUPDT23V3="
						IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT23V3" (MD "%TMPDIR%\DELAYEDHFXS\UPDT23V3")
						COPY /Y "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS\UPDT23V3" >NUL
					) ELSE (
						IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT23V4" (MD "%TMPDIR%\DELAYEDHFXS\UPDT23V4")
						COPY /Y "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS\UPDT23V4" >NUL
					)
				) ELSE (
					ECHO Processing %%I...
					FOR /F %%K IN ('DIR /B "%TMPDIR%\HFX\*.msp"') DO (
						START /WAIT MSIEXEC /p "%TMPDIR%\HFX\%%K" /a "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" /qb
					)
					ECHO>>TMP\DNF20REM.txt KB%%J
				)
				DEL /F/Q "%TMPDIR%\HFX\*.msp"
			) ELSE (
				SET "SKIPHFX=0"
			)
		)
	)
	SET "SKIPHFX="
	RD /Q/S "%TMPDIR%\HFX"
	
	IF EXIST "%TMPDIR%\DELAYEDHFXS" (
		IF DEFINED UPDT23V4 (
			IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT23V4\NDP35SP1-KB960043-v4.msp" (
				FOR /F "tokens=3 delims=Bb-" %%I IN ('DIR /B HFXS\~NDP20SP2-KB*-x86.exe') DO (
					IF %%I EQU 971521 IF %%I NEQ 971601 IF %%I NEQ 971993 IF %%I NEQ 972848 IF %%J NEQ 981574 IF %%I NEQ 974417 (
						7za e -o"%TMPDIR%\DELAYEDHFXS\UPDT23V4" -y ~NDP20SP2-KB%%I-x86.exe NDP35SP1-KB960043-v4.msp >NUL
					)
				)
			)
			FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\UPDT23V4\NDP35SP1-KB960043*.msp"') DO (
				SET /A "LOOPCNT+=1"
				IF !LOOPCNT! GTR 1 (DEL /F/Q "%TMPDIR%\DELAYEDHFXS\UPDT23V4\%%I")
			)
			SET "LOOPCNT="
		) ELSE IF DEFINED UPDT23V3 (
			IF NOT EXIST "%TMPDIR%\DELAYEDHFXS\UPDT23V3\NDP35SP1-KB960043-v3.msp" (
				REM TODO: If KB981574 does indeed have an updated version of the .msp file being extracted from KB972848,
				REM then that should instead be extracted. But I cannot confirm.
				IF EXIST "%TMPDIR%\NDP20SP2-KB981574-x86.exe" (
					7za e -o"%TMPDIR%\DELAYEDHFXS\UPDT23V3" -y ~NDP20SP2-KB981574-x86.exe NDP35SP1-KB960043-v3.msp >NUL
				) ELSE (
					7za e -o"%TMPDIR%\DELAYEDHFXS\UPDT23V3" -y ~NDP20SP2-KB972848-x86.exe NDP35SP1-KB960043-v3.msp >NUL
				)
			)
			FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\UPDT23V3\NDP35SP1-KB960043*.msp"') DO (
				SET /A "LOOPCNT+=1"
				IF !LOOPCNT! GTR 1 (DEL /F/Q "%TMPDIR%\DELAYEDHFXS\UPDT23V3\%%I")
			)
			SET "LOOPCNT="
		)
		ECHO Resuming delayed NET 2.0 SP2 hotfixes processes:
		FOR /F %%I IN ('DIR /B/A:D "%TMPDIR%\DELAYEDHFXS"') DO (
			FOR /F %%J IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\%%I\NDP35SP1*.msp"') DO (
				ECHO Resuming %%J... ^(this is correct^)
				START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I\%%J" /a "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" /qb
				ECHO>>TMP\DNF20REM.txt KB960043
			)
			FOR /F %%J IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\%%I\NDP20SP2*.msp"') DO (
				ECHO Resuming %%J...
				START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I\%%J" /a "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" /qb
				FOR /F "tokens=2 delims=-." %%K IN ("%%J") DO (ECHO>>TMP\DNF20REM.txt %%K)
			)
		)
		RD /Q/S "%TMPDIR%\DELAYEDHFXS"
	)
)
SET "HFXORDEREDLIST="

REM Registry edits via VB scripts (the "FIX"'s), removing `CA BlockDirectInstall Cartman MSI x86` rows located in installer tables ("REM_MSI_BLOCKING"),
REM or removing features ("REM_*"'s).
IF EXIST TMP\20SP2_*.mst (
	FOR /F %%I IN ('DIR /B TMP\20SP2_*.mst') DO (
		START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" TMP\%%I
	)
)
START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN20\Netfx20a_x86.msi" TARGETDIR="%DNF20DIR%\DNF20" /qb
IF EXIST TMP\DNF20REM.txt (
	IF NOT EXIST TMP\INSTREGDOWN.cmd (CALL :INSTREGDOWN)
	ECHO/>>TMP\INSTREGDOWN2.cmd
	ECHO>>TMP\INSTREGDOWN2.cmd ECHO^>DNF20.reg Windows Registry Editor Version 5.00
	ECHO>>TMP\INSTREGDOWN2.cmd ECHO/^>^>DNF20.reg
	FOR /F %%A IN (TMP\DNF20REM.txt) DO (
		ECHO>>TMP\INSTREGDOWN2.cmd FOR /F "delims=[]" %%%%I IN ^('FINDSTR /IR "\.%%A" DNFWIN4.txt'^) DO ^(ECHO^>^>DNF20.reg [-%%%%I]^)
	)
	ECHO>>TMP\INSTREGDOWN2.cmd %%SYSTEMROOT%%\REGEDIT /S DNF20.reg
)
ECHO/
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 2.0 Language Localization ----------
:DNF20LNG
START /WAIT MSIEXEC /a "%TMPDIR%\LANGPACK%DNF20LNGSTR%\netfx20lp\netfx20lpa_x86.msi" TARGETDIR="%TMPDIR%\ADMIN20LNG%DNF20LNGSTR%" /qb
FOR /F %%I IN ('DIR /B "%TMPDIR%\LANGPACK%DNF20LNGSTR%\netfx20lp\*.msp"') DO (
	START /WAIT MSIEXEC /p "%TMPDIR%\LANGPACK%DNF20LNGSTR%\netfx20lp\%%I" /a "%TMPDIR%\ADMIN20LNG%DNF20LNGSTR%\netfx20lpa_x86.msi" /qb
)

IF EXIST TMP\20SP?LNG*.mst (
	IF EXIST TMP\20SP?LNG_*.mst (
		FOR /F %%I IN ('DIR /B TMP\20SP?LNG_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN20LNG%DNF20LNGSTR%\netfx20lpa_x86.msi" TMP\%%I
		)
	)
	IF EXIST TMP\20SP?LNG%DNF20LNGSTR%_*.mst (
		FOR /F %%I IN ('DIR /B TMP\20SP?LNG%DNF20LNGSTR%_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN20LNG%DNF20LNGSTR%\netfx20lpa_x86.msi" TMP\%%I
		)
	)
)

START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN20LNG%DNF20LNGSTR%\netfx20lpa_x86.msi" TARGETDIR="%DNF20DIR%\DNF20\%DNF20LNGSTR%LNG" /qb
IF %LNGPROCESSCNT% EQU %DNF20LNGCNT% (
	ECHO/>>TMP\INSTALL2.cmd
	IF DEFINED LNGDNF20INPROCESS (
		ECHO>>TMP\INSTALL2.cmd FOR %%%%I IN ^(%DNF20LNGSTRSET%^) DO ^(START /WAIT DNF20\%%%%ILNG\netfx20lpa_x86.msi /l*v "%%TMP%%\DNF20%%%%ILNGinstall.log" ARPNOMODIFY=0 ARPNOREPAIR=0 REBOOT=ReallySuppress /%%VERBOSITY%%^)
	)
	IF DEFINED LNGDNF3520INPROCESS (
		ECHO>>TMP\INSTALL2.cmd FOR %%%%I IN ^(%DNF35LNGSTRSET%^) DO ^(START /WAIT DNF20\%%%%ILNG\netfx20lpa_x86.msi /l*v "%%TMP%%\DNF20%%%%ILNGinstall.log" ARPNOMODIFY=0 ARPNOREPAIR=0 REBOOT=ReallySuppress /%%VERBOSITY%%^)
	)
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 3.0 Handling ----------
:DNF30
ECHO/>>TMP\INSTALL3.cmd
ECHO>>TMP\INSTALL3.cmd FOR /F "delims=" %%%%I IN ('NET START ^^^| FINDSTR /BC:"   "') DO (
ECHO>>TMP\INSTALL3.cmd 	SET "SERV=%%%%I"
ECHO>>TMP\INSTALL3.cmd 	SET ^"SERV=^^!SERV:~3^^!^"
ECHO>>TMP\INSTALL3.cmd 	IF /I ^"^^!SERV^^!^"=="MSIServer" (
ECHO>>TMP\INSTALL3.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL3.cmd 	)
ECHO>>TMP\INSTALL3.cmd )
ECHO>>TMP\INSTALL3.cmd SET "SERV="
ECHO>>TMP\INSTALL3.cmd IF DEFINED STOPSERV (
ECHO>>TMP\INSTALL3.cmd 	SET "STOPSERV="
ECHO>>TMP\INSTALL3.cmd 	NET STOP MSIServer
ECHO>>TMP\INSTALL3.cmd )

IF "%DNF30RGBRASTERIZER%"=="1" (
	START /WAIT MSIEXEC /a "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\RGB9RAST_x86.msi" REBOOT=ReallySuppress TARGETDIR="%TMPDIR%\M5" /qb
	MD "%DNF30DIR%\DNF30\SYS32"
	COPY /Y "%TMPDIR%\M5\System32\*.*" "%DNF30DIR%\DNF30\SYS32" >NUL
	ECHO/>>TMP\INSTALL3.cmd
	ECHO>>TMP\INSTALL3.cmd FOR /F %%%%I IN ^('DIR /B DNF30\SYS32'^) DO (
	ECHO>>TMP\INSTALL3.cmd 	XCOPY /D/Y DNF30\SYS32\%%%%I "%%SYSTEMROOT%%\system32"
	ECHO>>TMP\INSTALL3.cmd 	IF /I "%%%%~xI"==".dll" ^(%%SYSTEMROOT%%\system32\regsvr32 /s "%%SYSTEMROOT%%\system32\%%%%I"^)
	ECHO>>TMP\INSTALL3.cmd ^)
)
IF NOT "%RMDNF30MSXML6%"=="1" IF DEFINED XMLFILETYPE (
	ECHO Replacing .NET 3.0 SP2's msxml6.msi with %XMLFILE%...
	IF !XMLFILETYPE! EQU 0 (
		COPY /Y HFXS\%%I "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\x86\msxml6.msi" >NUL
	) ELSE (
		DEL /F/Q "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\x86\*"
		START /WAIT HFXS\%XMLFILE% /Q /X:"%TMPDIR%\wcu\dotNetFramework\dotNetFX30\x86"
	)
	SET "XMLFILE="
	SET "XMLFILETYPE="
	START /WAIT MSIEXEC /a "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\x86\msxml6.msi" TARGETDIR="%TMPDIR%\M6" /qb
	IF NOT EXIST "%DNF30DIR%\DNF30\SYS32" (MD "%DNF30DIR%\DNF30\SYS32")
	COPY /Y "%TMPDIR%\M6\System\*.*" "%DNF30DIR%\DNF30\SYS32" >NUL
	ECHO/>>TMP\INSTALL3.cmd
	ECHO>>TMP\INSTALL3.cmd IF NOT EXIST %%SYSTEMROOT%%\system32\msxml6*.dll ^(
	ECHO>>TMP\INSTALL3.cmd 	MOVE DNF30\SYS32\msxml6*.dll %%SYSTEMROOT%%\system32
	ECHO>>TMP\INSTALL3.cmd 	%%SYSTEMROOT%%\system32\regsvr32 /s %%SYSTEMROOT%%\system32\msxml6.dll
	ECHO>>TMP\INSTALL3.cmd ^)
)
IF NOT "%RMDNF30WIC%"=="1" (
	MD "%DNF30DIR%\DNF30\WIC"
	7za x -o"%DNF30DIR%\DNF30\WIC" -y "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\WIC_x86_enu.exe" >NUL
	DEL /F/Q "%DNF30DIR%\DNF30\WIC\spupdsvc.exe"
	ECHO/>>TMP\INSTALL3.cmd
	ECHO>>TMP\INSTALL3.cmd START /WAIT DNF30\WIC\update\update.exe /%%VERBOSITY%% /norestart
) 
IF NOT "%RMDNF30XPS%"=="1" (
	IF DEFINED ORIGINALXPS (
		SET "ORIGINALXPS="
		MD "%DNF30DIR%\DNF30\XPS"
		REM We cannot use the TMPDIR variable here with the executable path given that we *need* to use quoutes with it (given spaces in the string)
		REM and the START command does not like having the executable we want to use wrapped in quoutes, but we can just use the relative path instead.
		START /WAIT TMP\TMP%TMPCNT%\wcu\dotNetFramework\dotNetFX30\XPSEPSC-x86-en-US.exe /Q /X:"%DNF30DIR%\DNF30\XPS"
		IF EXIST "%DNF30DIR%\DNF30\XPS\*.amd64.*" (
			FOR /F %%I IN ('DIR /B "%DNF30DIR%\DNF30\XPS\*.amd64.*"') DO (
				DEL /F/Q "%DNF30DIR%\DNF30\XPS\%%I"
				ECHO/>"%DNF30DIR%\DNF30\XPS\%%I"
			)
		)
	) ELSE (
		IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
			MD "%TMPDIR%\2K3-KB971276-V2"
			START /WAIT HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe /Q /X:"%TMPDIR%\2K3-KB971276-V2"
			DEL /F/Q "%TMPDIR%\2K3-KB971276-V2\update\branches.inf" "%TMPDIR%\2K3-KB971276-V2\update\updatebr.inf"
			REN "%TMPDIR%\2K3-KB971276-V2\update\update_SP2QFE.inf" update.inf
			FOR /F %%I IN ('DIR /B "%TMPDIR%\2K3-KB971276-V2\SP2QFE\*.amd64.*"') DO (
				DEL /F/Q "%TMPDIR%\2K3-KB971276-V2\SP2QFE\%%I" >NUL
				ECHO/>"%TMPDIR%\2K3-KB971276-V2\SP2QFE\%%I"
			)
		)
		
		MD "%DNF30DIR%\DNF30\XPS"
		
		IF "%TARGETOS%"=="XP" (
			IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
				ECHO Updating XPS driver with WindowsXP-KB971276-v3/Server2003-...-v2-x86-ENU.exe...
			) ELSE (
				ECHO Updating XPS driver with WindowsXP-KB971276-v3-x86-ENU.exe...
			)
			MD "%TMPDIR%\XP-KB971276-V3"
			START /WAIT HFXS\WindowsXP-KB971276-v3-x86-ENU.exe /Q /X:"%TMPDIR%\XP-KB971276-V3"
			DEL /F/Q "%TMPDIR%\XP-KB971276-V3\update\branches.inf" "%TMPDIR%\XP-KB971276-V3\update\updatebr.inf"
			REN "%TMPDIR%\XP-KB971276-V3\update\update_SP3QFE.inf" update.inf
			FOR /F %%I IN ('DIR /B "%TMPDIR%\XP-KB971276-V3\SP3QFE\*.amd64.*"') DO (
				DEL /F/Q "%TMPDIR%\XP-KB971276-V3\SP3QFE\%%I" >NUL
				ECHO/>"%TMPDIR%\XP-KB971276-V3\SP3QFE\%%I"
			)
			
			REM unidrv.hlp is already basically an empty help file, hence probably why it was originally
			REM deleted and repalced with an empty file with the same name.
			REM However, I'm not positive as to what exactly uses it and when, and some guy in the original forum
			REM thread complained about it, so I'll just... not delete it. :)
			REM The unidrv.hlp files that each update possesses are identical to each other.
			REM DEL /F/Q "%TMPDIR%\XP-KB971276-V3\SP3QFE\unidrv.hlp"
			REM ECHO/>"%TMPDIR%\XP-KB971276-V3\SP3QFE\unidrv.hlp"
			
			IF EXIST HFXS\WindowsServer2003-KB971276-v2-x86-ENU.exe (
				COPY /Y "%TMPDIR%\2K3-KB971276-V2\SP2QFE\*.*" "%TMPDIR%\XP-KB971276-V3\SP3QFE" >NUL
				FOR %%I IN (spuninst.exe,spmsg.dll,spupdsvc.exe,update\spcustom.dll,update\update.exe,update\updspapi.dll) DO (
					COPY /Y "%TMPDIR%\2K3-KB971276-V2\%%I" "%TMPDIR%\XP-KB971276-V3\%%I" >NUL
				)
			)
			XCOPY /E/Q/Y "%TMPDIR%\XP-KB971276-V3\*.*" "%DNF30DIR%\DNF30\XPS" >NUL
		) ELSE (
			ECHO Updating XPS driver with WindowsServer2003-KB971276-v2-x86-ENU.exe...
			REM DEL /F/Q "%TMPDIR%\2K3-KB971276-V2\SP2QFE\unidrv.hlp"
			REM ECHO/>"%TMPDIR%\2K3-KB971276-V2\SP2QFE\unidrv.hlp"
			XCOPY /E/Q/Y "%TMPDIR%\2K3-KB971276-V2\*.*" "%DNF30DIR%\DNF30\XPS" >NUL
		)
	)
	
	REM Given that .NET 3.0 & 3.5 can only be installed under XP and newer, it is safe to assume reg.exe is available to use.
	ECHO/>>TMP\INSTALL3.cmd
	ECHO>>TMP\INSTALL3.cmd IF %%SSIP%% EQU 0x1 ^(
	ECHO>>TMP\INSTALL3.cmd 	MD %%SYSTEMDRIVE%%\XPSDELAYED
	ECHO>>TMP\INSTALL3.cmd 	XCOPY /E/Q/Y DNF30\XPS\*.* %%SYSTEMDRIVE%%\XPSDELAYED
	ECHO>>TMP\INSTALL3.cmd 	REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx" /V Flags /T REG_DWORD /D "0x00000020" /F
	ECHO>>TMP\INSTALL3.cmd 	IF "%%XPSVERBOSITY%%"=="passive" ^(REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\###XPSDELAYED" /VE /D "XPS ^(delayed from .NET 3.0^)" /F^)
	ECHO>>TMP\INSTALL3.cmd 	REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\###XPSDELAYED" /V 1 /D "%%SYSTEMDRIVE%%\XPSDELAYED\update\update.exe /%%XPSVERBOSITY%% /norestart" /F
	IF NOT DEFINED LNGDNF3530INPROCESS (
		ECHO>>TMP\INSTALL3.cmd 	ECHO^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Option Explicit
		ECHO>>TMP\INSTALL3.cmd 	ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Dim WshShell
		ECHO>>TMP\INSTALL3.cmd 	ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Set WshShell = CreateObject^^^("WScript.Shell"^^^)
		ECHO>>TMP\INSTALL3.cmd 	ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs WshShell.Run """%%%%COMSPEC%%%%"" /C RD /Q/S %%%%SYSTEMDRIVE%%%%\XPSDELAYED", 0, True
		ECHO>>TMP\INSTALL3.cmd 	ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Set WshShell = Nothing
		ECHO>>TMP\INSTALL3.cmd 	REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\###XPSDELAYED" /V 2 /D "CSCRIPT //NOLOGO %%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs" /F
	)
	ECHO>>TMP\INSTALL3.cmd ^) ELSE ^(
	ECHO>>TMP\INSTALL3.cmd 	START /WAIT DNF30\XPS\update\update.exe /%%XPSVERBOSITY%% /norestart
	ECHO>>TMP\INSTALL3.cmd ^)
)

START /WAIT MSIEXEC /a "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\Netfx30a_x86.msi" TARGETDIR="%TMPDIR%\ADMIN30" /qb
IF EXIST "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\*64.msp" (DEL /F/Q "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\*64.msp")
FOR /F %%I IN ('DIR /B "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\*.msp"') DO (
	START /WAIT MSIEXEC /p "%TMPDIR%\wcu\dotNetFramework\dotNetFX30\%%I" /a "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" /qb
)

ECHO/>>TMP\INSTALL3.cmd
ECHO>>TMP\INSTALL3.cmd START /WAIT DNF30\Netfx30a_x86.msi /l*v "%%TMP%%\DNF30install.log" ARPNOMODIFY=0 ARPNOREPAIR=0 /%%VERBOSITY%% /norestart
ECHO>>TMP\INSTALL3.cmd FOR /F "tokens=3" %%%%I IN ^('REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0DC1503A46F231838AD88BCDDC8E8F7C\InstallProperties" /V UnfixedDBName ^^^| FINDSTR "UnfixedDBName"'^) DO ^(REN %%%%I 39d3e.msi^)
ECHO>>TMP\INSTALL3.cmd REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\0DC1503A46F231838AD88BCDDC8E8F7C\InstallProperties" /V UnfixedDBName /F

IF EXIST 30ORDER.txt (
	SET "HFXORDEREDLIST=TYPE 30ORDER.txt"
) ELSE (
	ECHO/>30ORDER.txt
	ECHO/
	ECHO ERROR: Text file "30ORDER.txt" with listed .NET 3.0 SP2 updates was missing.
	ECHO Please enter the names of the .NET 3.0 SP2 updates you wish to merge into the
	ECHO newly-created "30ORDER.txt" text file, ideally in chronological then
	ECHO numerical order. Do not include language packs or special updates.
	SET /A "MISSING=1"
	GOTO :EOF
)

IF EXIST HFXS\NDP30SP2*.exe (
	MD "%TMPDIR%\HFX"
	FOR /F %%I IN ('!HFXORDEREDLIST!') DO (
		7za e -o"%TMPDIR%\HFX" -y HFXS\%%I *.msp >NUL
		IF EXIST "%TMPDIR%\HFX\NDP35SP1*.msp" (
			ECHO %%I process delayed.
			IF NOT EXIST "%TMPDIR%\DELAYEDHFXS" (MD "%TMPDIR%\DELAYEDHFXS")
			MOVE "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS" >NUL
		) ELSE (
			ECHO Processing %%I...
			IF /I "%%I"=="ndp30sp2-kb982168-x86.exe" (
				SET /A "OKAYTOIGNORE=1"
			)
			IF /I "%%I"=="ndp30sp2-kb2756918-x86.exe" (
				SET /A "OKAYTOIGNORE=1"
			)
			IF DEFINED OKAYTOIGNORE (
				SET "OKAYTOIGNORE="
				ECHO .   ^(Ignore the error messages - click "Okay" through both of them^)   .
			)
			FOR /F %%J IN ('DIR /B "%TMPDIR%\HFX\*.msp"') DO (
				START /WAIT MSIEXEC /p "%TMPDIR%\HFX\%%J" /a "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" /qb
			)
			FOR /F "tokens=2 delims=-" %%J IN ("%%I") DO (ECHO>>TMP\DNF30REM.txt %%J)
		)
		DEL /F/Q "%TMPDIR%\HFX\*.msp"
	)
	RD /Q/S "%TMPDIR%\HFX"
	
	IF EXIST "%TMPDIR%\DELAYEDHFXS" (
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP35SP1-KB960043*.msp"') DO (
			SET /A "LOOPCNT+=1"
			IF !LOOPCNT! GTR 1 (DEL /F/Q "%TMPDIR%\DELAYEDHFXS\%%I")
		)
		SET "LOOPCNT="
		ECHO Resuming .NET 3.0 delayed hotfixes processes:
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP35SP1*.msp"') DO (
			ECHO Resuming %%I...
			START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I" /a "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" /qb
			ECHO>>TMP\DNF30REM.txt KB960043
		)
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP30SP2*.msp"') DO (
			ECHO Resuming %%I...
			START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I" /a "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" /qb
			FOR /F "tokens=2 delims=-." %%J IN ("%%I") DO (ECHO>>TMP\DNF30REM.txt %%J)
		)
		RD /Q/S "%TMPDIR%\DELAYEDHFXS"
	)
)
SET "HFXORDEREDLIST="

REM Registry edits via VB scripts as well as a WPF Firefox work-around (the "FIX"), removing `CA BlockDirectInstall Cartman MSI x86` rows located in installer tables ("REM_MSI_BLOCKING"),
REM or deleting a font cache .dat file ("REMFONTCACHEFIX").
FOR /F %%I IN ('DIR /B TMP\30SP?_*.mst') DO (
	START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" TMP\%%I
)
START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN30\Netfx30a_x86.msi" TARGETDIR="%DNF30DIR%\DNF30" /qb
IF EXIST TMP\DNF30REM.txt (
	IF NOT EXIST TMP\INSTREGDOWN.cmd (CALL :INSTREGDOWN)
	ECHO/>>TMP\INSTREGDOWN3.cmd
	FOR /F %%A IN (TMP\DNF30REM.txt) DO (
		ECHO>>TMP\INSTREGDOWN3.cmd FOR /F %%%%I IN ^('FINDSTR /IR "\.%%A" DNFWIN4.txt'^) DO ^(ECHO^>^>DNFWIN5.txt %%%%I^)
	)
	ECHO>>TMP\INSTREGDOWN3.cmd FOR /F "delims=[]" %%%%I IN ^(DNFWIN5.txt^) DO ^(REG DELETE "%%%%I" /f^)
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 3.0 Language Localization ----------
:DNF30LNG
IF NOT "%RMDNF30XPS%"=="1" IF EXIST "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\XPS*.exe" (
	MD "%DNF30DIR%\DNF30\XPS\%DNF30LNGSTR%LNG"
	FOR /F %%J IN ('DIR /B "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\XPS*.exe"') DO (
		7za x -y -o"%DNF30DIR%\DNF30\XPS\%DNF30LNGSTR%LNG" "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\%%J" >NUL
	)
	
	IF %LNGPROCESSCNT% EQU %DNF30LNGCNT% (
		ECHO>>TMP\INSTALL3.cmd IF %%SSIP%% EQU 0x1 ^(
		ECHO>>TMP\INSTALL3.cmd 	FOR %%%%I IN ^(%DNF35LNGSTRSET%^) DO ^(
		ECHO>>TMP\INSTALL3.cmd 		SET /A "LOOPCNT+=1"
		ECHO>>TMP\INSTALL3.cmd 		MD %%SYSTEMDRIVE%%\XPSDELAYED\%%%%ILNG
		ECHO>>TMP\INSTALL3.cmd 		XCOPY /E/Q/Y DNF30\XPS\%%%%ILNG\*.* %%SYSTEMDRIVE%%\XPSDELAYED\%%%%ILNG
		ECHO>>TMP\INSTALL3.cmd 		IF DEFINED ROEPOS ^(
		ECHO>>TMP\INSTALL3.cmd 			SET /A "ROEPOS+=1"
		ECHO>>TMP\INSTALL3.cmd 		^) ELSE ^(
		ECHO>>TMP\INSTALL3.cmd 			SET /A "ROEPOS=2"
		ECHO>>TMP\INSTALL3.cmd 		^)
		ECHO>>TMP\INSTALL3.cmd 		REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\###XPSDELAYED" /V ^^!ROEPOS^^! /D "%%SYSTEMDRIVE%%\XPSDELAYED\%%%%ILNG\update\update.exe /%%XPSVERBOSITY%% /norestart" /F
		ECHO>>TMP\INSTALL3.cmd 		IF ^^!LOOPCNT^^! EQU %DNF35LNGCNT% ^(
		ECHO>>TMP\INSTALL3.cmd 			SET /A "ROEPOS+=1"
		ECHO>>TMP\INSTALL3.cmd 			ECHO^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Option Explicit
		ECHO>>TMP\INSTALL3.cmd 			ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Dim WshShell
		ECHO>>TMP\INSTALL3.cmd 			ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Set WshShell = CreateObject^^^("WSCript.shell"^^^)
		ECHO>>TMP\INSTALL3.cmd 			ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs WshShell.Run """%%%%COMSPEC%%%%"" /C RD /Q/S %%%%SYSTEMDRIVE%%%%\XPSDELAYED", 0, True
		ECHO>>TMP\INSTALL3.cmd 			ECHO^>^>%%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs Set WshShell = Nothing
		ECHO>>TMP\INSTALL3.cmd 			REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx\###XPSDELAYED" /V ^^!ROEPOS^^! /D "CSCRIPT //NOLOGO %%SYSTEMDRIVE%%\XPSDELAYED\SELFREM.vbs" /F
		ECHO>>TMP\INSTALL3.cmd 		^)
		ECHO>>TMP\INSTALL3.cmd 	^)
		ECHO>>TMP\INSTALL3.cmd 	SET "LOOPCNT="
		ECHO>>TMP\INSTALL3.cmd 	SET "ROEPOS="
		ECHO>>TMP\INSTALL3.cmd ^) ELSE ^(
		ECHO>>TMP\INSTALL3.cmd 	FOR %%%%I IN ^(%DNF35LNGSTRSET%^) DO ^(START /WAIT DNF30\XPS\%%%%ILNG\update\update.exe /%%XPSVERBOSITY%%^)
		ECHO>>TMP\INSTALL3.cmd ^)
	)
)

FOR /F %%I IN ('DIR /B "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\*.msp"') DO (
	START /WAIT MSIEXEC /p "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\%%I" /a "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\netfx30lpa_x86.msi" /qb
)

IF EXIST TMP\30SP?LNG*.mst (
	IF EXIST TMP\30SP?LNG_*.mst (
		FOR /F %%I IN ('DIR /B TMP\30SP?LNG_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\netfx30lpa_x86.msi" TMP\%%I
		)
	)
	IF EXIST TMP\30SP?LNG%DNF30LNGSTR%_*.mst (
		FOR /F %%I IN ('DIR /B TMP\30SP?LNG%DNF30LNGSTR%_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\netfx30lpa_x86.msi" TMP\%%I
		)
	)
)

REM Apprently you need to *first* apply the .msp's *and* .mst's before you can "extract" the .msi from itself... before doing it again.
START /WAIT MSIEXEC /a "%TMPDIR%\LANGPACK%DNF30LNGSTR%\netfx30lp\netfx30lpa_x86.msi" TARGETDIR="%TMPDIR%\ADMIN30LNG%DNF30LNGSTR%" /qb
START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN30LNG%DNF30LNGSTR%\netfx30lpa_x86.msi" TARGETDIR="%DNF30DIR%\DNF30\%DNF30LNGSTR%LNG" /qb
IF %LNGPROCESSCNT% EQU %DNF30LNGCNT% (
	ECHO/>>TMP\INSTALL3.cmd
	ECHO>>TMP\INSTALL3.cmd FOR %%%%I IN ^(%DNF35LNGSTRSET%^) DO ^(START /WAIT DNF30\%%%%ILNG\netfx30lpa_x86.msi /l*v "%%TMP%%\DNF30%%%%ILNGinstall.log" ARPNOMODIFY=0 ARPNOREPAIR=0 /%%VERBOSITY%% /norestart^)
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 3.5 Handling ----------
:DNF35
MD "%TMPDIR%\WRAP35"
START /WAIT TMP\TMP%TMPCNT%\wcu\dotNetFramework\dotNetFX35\x86\netfx35_x86.exe /Q /X:"%TMPDIR%\WRAP35"
REM The "REM_CAB.mst" file removes a bunch of rows from the installer.
START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\WRAP35\vs_setup.msi" TMP\35SP1_REM_CAB.mst
START /WAIT MSIEXEC /a "%TMPDIR%\WRAP35\vs_setup.msi" NOVSUI=1 TARGETDIR="%TMPDIR%\ADMIN35" /qb

ECHO/>>TMP\INSTALL35.cmd
ECHO>>TMP\INSTALL35.cmd FOR /F "delims=" %%%%I IN ('NET START ^^^| FINDSTR /BC:"   "') DO (
ECHO>>TMP\INSTALL35.cmd 	SET "SERV=%%%%I"
ECHO>>TMP\INSTALL35.cmd 	SET ^"SERV=^^!SERV:~3^^!^"
ECHO>>TMP\INSTALL35.cmd 	IF /I ^"^^!SERV^^!^"=="MSIServer" (
ECHO>>TMP\INSTALL35.cmd 		SET /A "STOPSERV=1"
ECHO>>TMP\INSTALL35.cmd 	)
ECHO>>TMP\INSTALL35.cmd )
ECHO>>TMP\INSTALL35.cmd SET "SERV="
ECHO>>TMP\INSTALL35.cmd IF DEFINED STOPSERV (
ECHO>>TMP\INSTALL35.cmd 	SET "STOPSERV="
ECHO>>TMP\INSTALL35.cmd 	NET STOP MSIServer
ECHO>>TMP\INSTALL35.cmd )
ECHO/>>TMP\INSTALL35.cmd
ECHO>>TMP\INSTALL35.cmd START /WAIT DNF35\vs_setup.msi /l*v "%%TMP%%\DNF35install.log" ARPNOMODIFY=0 ARPNOREPAIR=0%%NOFFXBAP%%%%NOFFCLICKONCE%% /%%VERBOSITY%% /norestart
ECHO>>TMP\INSTALL35.cmd FOR /F "tokens=3" %%%%I IN ^('REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\26DDC2EC4210AC63483DF9D4FCC5B59D\InstallProperties" /v UnfixedDBName ^^^| FINDSTR "UnfixedDBName"'^) DO ^(REN %%%%I 39d44.msi^)
ECHO>>TMP\INSTALL35.cmd REG DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\26DDC2EC4210AC63483DF9D4FCC5B59D\InstallProperties" /v UnfixedDBName /f

IF EXIST 35ORDER.txt (
	SET "HFXORDEREDLIST=TYPE 35ORDER.txt"
) ELSE (
	ECHO/>35ORDER.txt
	ECHO/
	ECHO ERROR: Text file "35ORDER.txt" with listed .NET 3.5 SP1 updates was missing.
	ECHO Please enter the names of the .NET 3.5 SP1 updates you wish to merge into the
	ECHO newly-created "35ORDER.txt" text file, ideally in chronological then
	ECHO numerical order. Do not include language packs or special updates.
	SET /A "MISSING=1"
	GOTO :EOF
)

IF EXIST HFXS\NDP35SP1*.exe (
	SET /A "SKIPHFX=0"
	MD "%TMPDIR%\HFX"
	FOR /F %%I IN ('!HFXORDEREDLIST!') DO (
		FOR /F "tokens=3 delims=Bb-" %%J IN ("%%I") DO (
			IF "%RMDNF35FFCLICKONCEEXT%"=="1" (
				IF %%J EQU 963707 (
					SET /A "SKIPHFX=1"
				)
			)
			
			IF !SKIPHFX! NEQ 1 (
				7za e -o"%TMPDIR%\HFX" -y HFXS\%%I *.msp >NUL
				IF EXIST "%TMPDIR%\HFX\NDP35SP1-KB960043*.msp" (
					ECHO %%I process delayed.
					IF NOT EXIST "%TMPDIR%\DELAYEDHFXS" (MD "%TMPDIR%\DELAYEDHFXS")
					MOVE "%TMPDIR%\HFX\*.msp" "%TMPDIR%\DELAYEDHFXS" >NUL
				) ELSE (
					ECHO Processing %%I...
					FOR /F %%K IN ('DIR /B "%TMPDIR%\HFX\*.msp"') DO (
						START /WAIT MSIEXEC /p "%TMPDIR%\HFX\%%K" /a "%TMPDIR%\ADMIN35\vs_setup.msi" /qb
					)
					ECHO>>TMP\DNF35REM.txt KB%%J
				)
				DEL /F/Q "%TMPDIR%\HFX\*.msp"
			) ELSE (
				SET "SKIPHFX=0"
			)
		)
	)
	SET "SKIPHFX="
	RD /Q/S "%TMPDIR%\HFX"
	
	IF EXIST "%TMPDIR%\DELAYEDHFXS" (
		REM KB960043 seems to be some sort of virtual update for "Dual Branching Support."
		REM Link: https://mskb.pkisolutions.com/kb/960043
		REM None of the "required" updates have this particular .msp file, though, so...
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP35SP1-KB960043*.msp"') DO (
			SET /A "LOOPCNT+=1"
			IF !LOOPCNT! GTR 1 (DEL /F/Q "%TMPDIR%\DELAYEDHFXS\%%I")
		)
		SET "LOOPCNT="
		ECHO Resuming delayed NET 3.5 SP1 hotfixes processes:
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP35SP1-KB960043*.msp"') DO (
			ECHO Resuming %%I...
			START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I" /a "%TMPDIR%\ADMIN35\vs_setup.msi" /qb
			ECHO>>TMP\DNF35REM.txt KB960043
		)
		FOR /F %%I IN ('DIR /B "%TMPDIR%\DELAYEDHFXS\NDP35SP1-KB*.msp"') DO (
			IF /I NOT "%%I"=="NDP35SP1-KB960043.msp" IF /I NOT "%%I"=="NDP35SP1-KB960043-V4.msp" (
				ECHO Resuming %%I...
				START /WAIT MSIEXEC /p "%TMPDIR%\DELAYEDHFXS\%%I" /a "%TMPDIR%\ADMIN35\vs_setup.msi" /qb
				FOR /F "tokens=2 delims=-." %%J IN ("%%I") DO (ECHO>>TMP\DNF35REM.txt %%J)
			)
		)
		RD /Q/S "%TMPDIR%\DELAYEDHFXS"
	)
)
SET "HFXORDEREDLIST="

REM Registry edits via VB scripts ("KB951847FIX"), implementing a WPF Firefox work-around (?) and enabling ClickOnce (?) ("KB963707FIX") (I am not entirely sure),
REM removing `CA BlockDirectInstall Cartman MSI x86` rows located in installer tables ("REM_MSI_BLOCKING"), removing features ("REM_*"),
REM or toggling Firefox XBAP support (?) ("FFXBAPSWITCH").
FOR /F %%I IN ('DIR /B TMP\35SP1_*.mst') DO (
	IF /I NOT "%%I"=="35SP1_REM_CAB.mst" (
		START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN35\vs_setup.msi" TMP\%%I
	)
)
START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN35\vs_setup.msi" NOVSUI=1 TARGETDIR="!DNF35DIR!\DNF35" /qb
IF EXIST TMP\DNF35REM.txt (
	IF NOT EXIST TMP\INSTREGDOWN.cmd (CALL :INSTREGDOWN)
	ECHO/>>TMP\INSTREGDOWN35.cmd
	FOR /F %%A IN (TMP\DNF35REM.txt) DO (
		ECHO>>TMP\INSTREGDOWN35.cmd FOR /F %%%%I IN ^('FINDSTR /IR "\.%%A" DNFWIN4.txt'^) DO ^(ECHO^>^>DNFWIN6.txt %%%%I^)
	)
	ECHO>>TMP\INSTREGDOWN35.cmd FOR /F "delims=[]" %%%%I IN ^(DNFWIN6.txt^) DO ^(REG DELETE "%%%%I" /f^)
)
GOTO :EOF
REM ---------- ----------

REM ---------- .NET 3.5 Language Localization ----------
:DNF35LNG
MD "%DNF35DIR%\DNF35\%DNF35LNGSTR%LNG"
MD "%TMPDIR%\ADMIN35LNG%DNF35LNGSTR%"
COPY /Y "%TMPDIR%\LANGPACK%DNF35LNGSTR%\*.*" "%TMPDIR%\ADMIN35LNG%DNF35LNGSTR%\" >NUL

IF EXIST TMP\35SP?LNG*.mst (
	IF EXIST TMP\35SP?LNG_*.mst (
		FOR /F %%I IN ('DIR /B TMP\35SP?LNG_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN35LNG%DNF35LNGSTR%\vs_setup.msi" TMP\%%I >NUL
		)
	)
	IF EXIST TMP\35SP?LNG%DNF35LNGSTR%_*.mst (
		FOR /F %%I IN ('DIR /B TMP\35SP?LNG%DNF35LNGSTR%_*.mst') DO (
			START /B/WAIT CSCRIPT //NOLOGO TRANSFORMDB.vbs "%TMPDIR%\ADMIN35LNG%DNF35LNGSTR%\vs_setup.msi" TMP\%%I >NUL
		)
	)
)

START /WAIT MSIEXEC /a "%TMPDIR%\ADMIN35LNG%DNF35LNGSTR%\vs_setup.msi" NOVSUI=1 TARGETDIR="%DNF35DIR%\DNF35\%DNF35LNGSTR%LNG" /qb
IF %LNGPROCESSCNT% EQU %DNF35LNGCNT% (
	ECHO/>>TMP\INSTALL35.cmd
	ECHO>>TMP\INSTALL35.cmd FOR %%%%I IN ^(%DNF35LNGSTRSET%^) DO ^(START /WAIT DNF35\%%%%ILNG\vs_setup.msi /l*v "%%TMP%%\DNF35%%%%ILNGinstall.log" ARPNOMODIFY=0 ARPNOREPAIR=0 /%%VERBOSITY%% /norestart^)
)
GOTO :EOF
REM ---------- ----------


REM ******************** Ancilliary Subroutines ********************


REM ---------- Out Count ----------
:OUTCOUNT
SET /A "OUTCNT+=1"
IF EXIST OUT%OUTCNT% (GOTO :OUTCOUNT)
MD OUT%OUTCNT% 2>NUL
GOTO :EOF
REM ---------- ----------

REM ---------- TMP Count ----------
:TMPCOUNT
SET /A "TMPCNT+=1"
SET "TMPDIR=%~dp0TMP\TMP%TMPCNT%"
MD "%TMPDIR%"
GOTO :EOF
REM ---------- ----------

REM ---------- Install Registry Down? ----------
:INSTREGDOWN
ECHO/>>TMP\INSTREGDOWN.cmd
ECHO>>TMP\INSTREGDOWN.cmd %%SYSTEMROOT%%\REGEDIT /E DNFWIN2.txt "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
ECHO>>TMP\INSTREGDOWN.cmd TYPE DNFWIN2.txt^>DNFWIN3.txt
ECHO>>TMP\INSTREGDOWN.cmd FINDSTR /R "\[" DNFWIN3.txt^>DNFWIN4.txt
GOTO :EOF
REM ---------- ----------

REM ---------- Set Memory Paramter ----------
:SETMEMPARAM
IF /I "%COMPLEVEL%"=="ULTRA" (
	SET "MEMPARAM=-mx=9"
) ELSE IF /I "%COMPLEVEL%"=="NORMAL" (
	SET "MEMPARAM=-mx=5"
) ELSE IF /I "%COMPLEVEL%"=="NO" (
	SET "MEMPARAM=-mx=0"
) ELSE (
	SET "COMPLEVEL=ULTRA"
	SET "MEMPARAM=-mx=9"
)
GOTO :EOF
REM ---------- ----------

REM ---------- Change Memory Parameter ----------
:CHANGEMEMPARAM
IF "%MEMPARAM%"=="-mx=9" (
	SET "MEMPARAM=-mx=5"
) ELSE IF "%MEMPARAM%"=="-mx=5" (
	SET "MEMPARAM=-mx=0"
) ELSE IF "%MEMPARAM%"=="-mx=0" (
	SET "MEMPARAM=-mx=9"
)
GOTO :EOF
REM ---------- ----------


REM ******************** Executable Creation Subroutines ********************


REM ---------- Installation Script Creator ----------
:INSTBASE
ECHO>TMP\INSTALL.cmd ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
ECHO>>TMP\INSTALL.cmd ::                                                    ::
ECHO>>TMP\INSTALL.cmd ::          Refined Silent .NET Maker %RSNMVER%           ::
ECHO>>TMP\INSTALL.cmd ::          https://github.com/TheUltraCode           ::
ECHO>>TMP\INSTALL.cmd ::                                                    ::
ECHO>>TMP\INSTALL.cmd ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd @ECHO OFF
ECHO>>TMP\INSTALL.cmd SETLOCAL ENABLEDELAYEDEXPANSION
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd SET "FILENAME=%%0"
ECHO>>TMP\INSTALL.cmd SET "P1=%%1"
ECHO>>TMP\INSTALL.cmd SET "P2=%%2"
ECHO>>TMP\INSTALL.cmd SET "P3=%%3"
ECHO>>TMP\INSTALL.cmd SET "P4=%%4"
ECHO/>>TMP\INSTALL.cmd
REM Time for some variable voodoo magic with parameters!
REM The !EVAL! string gets "evaluated" (like in Python) and is directly referenced as a variable name for its value.
REM This only works with DelayedExpansion, however.
ECHO>>TMP\INSTALL.cmd FOR /L %%%%I IN (1,1,4) DO (
ECHO>>TMP\INSTALL.cmd 	SET "EVAL=P%%%%I"
REM If I do not escape the double-quotes in these instances, it will not write-out to the file correctly...
ECHO>>TMP\INSTALL.cmd 	FOR %%%%Z IN (^^!EVAL^^!) DO (SET ^"EVAL=^^!%%%%Z^^!^")
ECHO>>TMP\INSTALL.cmd 	IF NOT ^"^^!EVAL^^!^"=="" (
ECHO>>TMP\INSTALL.cmd 		IF /I ^"^^!EVAL:~0,1^^!^"=="-" (
ECHO>>TMP\INSTALL.cmd 			SET /A "VALIDPREFIX=1"
ECHO>>TMP\INSTALL.cmd 		) ELSE IF /I ^"^^!EVAL:~0,1^^!^"=="/" (
ECHO>>TMP\INSTALL.cmd 			SET /A "VALIDPREFIX=1"
ECHO>>TMP\INSTALL.cmd 		)
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd 		IF DEFINED VALIDPREFIX (
ECHO>>TMP\INSTALL.cmd 			SET "VALIDPREFIX="
ECHO>>TMP\INSTALL.cmd 			IF /I ^"^^!EVAL:~1^^!^"=="h" (
ECHO>>TMP\INSTALL.cmd 				SET /A "HELP=1"
ECHO>>TMP\INSTALL.cmd 			) ELSE IF /I ^"^^!EVAL:~1^^!^"=="?" (
ECHO>>TMP\INSTALL.cmd 				SET /A "HELP=1"
ECHO>>TMP\INSTALL.cmd 			) ELSE IF /I ^"^^!EVAL:~1^^!^"=="passive" (
ECHO>>TMP\INSTALL.cmd 				SET "VERBOSITY=passive"
ECHO>>TMP\INSTALL.cmd 			) ELSE IF /I ^"^^!EVAL:~1^^!^"=="quiet" (
ECHO>>TMP\INSTALL.cmd 				SET "VERBOSITY=quiet"
ECHO>>TMP\INSTALL.cmd 			) ELSE IF /I ^"^^!EVAL:~1^^!^"=="silent" (
ECHO>>TMP\INSTALL.cmd 				SET "VERBOSITY=quiet"
IF DEFINED FFXBAPINPROCESS (
	ECHO>>TMP\INSTALL.cmd 			^) ELSE IF /I ^"^^!EVAL:~1^^!^"=="noffxbap" ^(
	ECHO>>TMP\INSTALL.cmd 				SET "NOFFXBAP= NOFFXBAP=1"
)
IF DEFINED FFCLICKONCEINPROCESS (
	ECHO>>TMP\INSTALL.cmd 			^) ELSE IF /I ^"^^!EVAL:~1^^!^"=="noffclickonce" ^(
	ECHO>>TMP\INSTALL.cmd 				SET "NOFFCLICKONCE= NOFFCLICKONCE=1"
)
ECHO>>TMP\INSTALL.cmd 			) ELSE (
ECHO>>TMP\INSTALL.cmd 				IF NOT DEFINED INVALID (
ECHO>>TMP\INSTALL.cmd 					SET ERRORMSG=^^!EVAL^^! is not a valid switch. Type %%FILENAME%% /? for help.
ECHO>>TMP\INSTALL.cmd 					SET /A "INVALID=1"
ECHO>>TMP\INSTALL.cmd 				)
ECHO>>TMP\INSTALL.cmd 			)
ECHO/>>TMP\INSTALL.cmd
REM This next part is a PITA for multiple reasons:
REM   1. If we want to tell the user anything about what parameters they pass to the installer in a terminal window, the only realistic way is to create a VBScript message box. We cannot feed console output back to the parent process that is executing the installer.
REM   2. The "string" we feed into a VBScript message box object is more akin to a data stream. We have to be very careful to not have double-quotes at the beginning or end of it (those are added inside the message box function call), but we do need quotes to separate
REM      the text we want to output from the linebreaks. Therefore, my practice of encapsluating a variable SET-ing in double-quotes is not feasible, as those double-qoutes will conflict with the double-quotes inside the "string", and no amount of escape characters
REM      can help consistently as far as I can tell.
REM   3. We cannot build upon the aforementioned "string" by adding additional text to the original variable (no "x=!x!abc..."), but what we can do is add separate streams together into a new variable.
REM   4. The final variable provided to the message box cannot be referenced via DelayedExpanion. Thus the message box has to be outside of the code block where the final "string" was defined.
REM   5. Oh, and that final variable full of linebreaks? Actually, because that final variable was defined in a code block, we have to copy its contents to a new surrogate variable *outside* of the code block before passing said surrogate variable to the message box function.
REM      Why? Because screw you.
REM ...
REM I hate batch.
ECHO>>TMP\INSTALL.cmd 			IF DEFINED HELP IF NOT DEFINED RECEIVEDHELP (
ECHO>>TMP\INSTALL.cmd 				SET "HELP="
ECHO>>TMP\INSTALL.cmd 				SET HELPMSG1=Refined Silent .NET Maker %RSNMVER% %NAME% Installer for %TARGETOS%" ^& VbCrLf ^& "Default switchless unzip + install behavior: -%VERBOSITY%" ^& VbCrLf ^& VbCrLf ^& "Command line options:" ^& VbCrLf ^& "   [- /]passive : Show minimal UI during installation." ^& VbCrLf ^& "   [- /]quiet/silent : Show no UI during installation.
IF DEFINED FFXBAPINPROCESS (
	ECHO>>TMP\INSTALL.cmd 				SET HELPMSG2=" ^& VbCrLf ^& "   [- /]noffxbap : Avoid installing Windows Presentation Foundation Mozilla plugin ^^^(XBAP^^^).
)
IF DEFINED FFCLICKONCEINPROCESS (
	ECHO>>TMP\INSTALL.cmd 				SET HELPMSG3=" ^& VbCrLf ^& "   [- /]noffclickonce : Avoid installing .NET Assistant 1.0 Mozilla extension ^^^(ClickOnce^^^).
)
ECHO>>TMP\INSTALL.cmd 				SET HELPMSG4=" ^& VbCrLf ^& "   [- /]h/? : This help.
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd 				SET FINALHELPMSG=^^!HELPMSG1^^!^^!HELPMSG2^^!^^!HELPMSG3^^!^^!HELPMSG4^^!
ECHO>>TMP\INSTALL.cmd 				SET "HELPMSG1="
ECHO>>TMP\INSTALL.cmd 				SET "HELPMSG2="
ECHO>>TMP\INSTALL.cmd 				SET "HELPMSG3="
ECHO>>TMP\INSTALL.cmd 				SET "HELPMSG4="
ECHO>>TMP\INSTALL.cmd 				SET /A "RECEIVEDHELP=1"
ECHO>>TMP\INSTALL.cmd 			)
ECHO>>TMP\INSTALL.cmd 		) ELSE (
ECHO>>TMP\INSTALL.cmd 			IF NOT DEFINED INVALID (
ECHO>>TMP\INSTALL.cmd 				SET ERRORMSG=^^!EVAL^^! is not a valid switch. Type %%FILENAME%% /? for help.
ECHO>>TMP\INSTALL.cmd 				SET /A "INVALID=1"
ECHO>>TMP\INSTALL.cmd 			)
ECHO>>TMP\INSTALL.cmd 		)
ECHO>>TMP\INSTALL.cmd 	)
ECHO>>TMP\INSTALL.cmd )
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd SET "P1="
ECHO>>TMP\INSTALL.cmd SET "P2="
ECHO>>TMP\INSTALL.cmd SET "P3=" 
ECHO>>TMP\INSTALL.cmd SET "P4="
ECHO>>TMP\INSTALL.cmd SET REALFINALHELPMSG=%%FINALHELPMSG%%
ECHO>>TMP\INSTALL.cmd IF DEFINED RECEIVEDHELP (
ECHO>>TMP\INSTALL.cmd 	SET "RECEIVEDHELP="
ECHO>>TMP\INSTALL.cmd 	ECHO^>^>HELPMSGBOX.vbs help = MsgBox^^("%%REALFINALHELPMSG%%",64,"%TARGETOS%%NAME%.exe"^^)
ECHO>>TMP\INSTALL.cmd 	SET "FINALHELPMSG="
ECHO>>TMP\INSTALL.cmd 	WSCRIPT HELPMSGBOX.vbs
ECHO>>TMP\INSTALL.cmd 	DEL /F/Q HELPMSGBOX.vbs
ECHO>>TMP\INSTALL.cmd 	SET /A "CLOSE=1"
ECHO>>TMP\INSTALL.cmd )
ECHO>>TMP\INSTALL.cmd SET "REALFINALHELPMSG="
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd IF DEFINED INVALID (
ECHO>>TMP\INSTALL.cmd 	SET "INVALID="
ECHO>>TMP\INSTALL.cmd 	CALL :ERROR
ECHO>>TMP\INSTALL.cmd 	SET /A "CLOSE=1"
ECHO>>TMP\INSTALL.cmd )
ECHO>>TMP\INSTALL.cmd IF DEFINED CLOSE (
ECHO>>TMP\INSTALL.cmd 	SET "CLOSE="
ECHO>>TMP\INSTALL.cmd 	EXIT /B
ECHO>>TMP\INSTALL.cmd )
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd IF NOT DEFINED VERBOSITY (SET "VERBOSITY=%VERBOSITY%")
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd ECHO^>FILEVER.vbs Option Explicit
ECHO>>TMP\INSTALL.cmd ECHO^>^>FILEVER.vbs Dim obj
ECHO>>TMP\INSTALL.cmd ECHO^>^>FILEVER.vbs Set obj = CreateObject("Scripting.FileSystemObject")
ECHO>>TMP\INSTALL.cmd ECHO^>^>FILEVER.vbs Wscript.Echo obj.GetFileVersion(WScript.Arguments(0))
ECHO>>TMP\INSTALL.cmd ECHO^>^>FILEVER.vbs Set obj = Nothing
ECHO>>TMP\INSTALL.cmd FOR /F "tokens=1 delims=." %%%%I IN ('CSCRIPT //NOLOGO FILEVER.vbs "%%SYSTEMROOT%%\SYSTEM32\MSI.DLL"') DO (
ECHO>>TMP\INSTALL.cmd 	IF %%%%I GEQ 2 (
IF DEFINED DNF3530INPROCESS IF NOT "%RMDNF30XPS%"=="1" (
	ECHO>>TMP\INSTALL.cmd 		SET "XPSVERBOSITY=%%VERBOSITY%%"
)
ECHO>>TMP\INSTALL.cmd 		IF "%%VERBOSITY%%"=="passive" (
ECHO>>TMP\INSTALL.cmd 			SET "VERBOSITY=qb"
ECHO>>TMP\INSTALL.cmd 		) ELSE IF "%%VERBOSITY%%"=="quiet" (
ECHO>>TMP\INSTALL.cmd 			SET "VERBOSITY=qn"
ECHO>>TMP\INSTALL.cmd 		)
ECHO>>TMP\INSTALL.cmd 		DEL /F/Q FILEVER.vbs
ECHO>>TMP\INSTALL.cmd 	) ELSE (
ECHO>>TMP\INSTALL.cmd 		SET "ERRORMSG=Please update your Microsoft Windows Installer ^(MSIEXEC^) to at least version 2.0."
ECHO>>TMP\INSTALL.cmd 		DEL /F/Q FILEVER.vbs
ECHO>>TMP\INSTALL.cmd 		GOTO :ERROR
ECHO>>TMP\INSTALL.cmd 	)
ECHO>>TMP\INSTALL.cmd )
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd "%%SYSTEMROOT%%\REGEDIT" /E "%%SYSTEMROOT%%\SETUPREG.txt" "HKEY_LOCAL_MACHINE\SYSTEM\Setup"
ECHO>>TMP\INSTALL.cmd FOR /F "tokens=2 delims=:" %%%%I IN ('TYPE "%%SYSTEMROOT%%\SETUPREG.txt" ^^^| FINDSTR "SystemSetupInProgress"') DO (SET /A "SSIP=0x%%%%I")
ECHO>>TMP\INSTALL.cmd DEL /F/Q "%%SYSTEMROOT%%\SETUPREG.txt"
ECHO>>TMP\INSTALL.cmd IF %%SSIP%% EQU 0x1 (
ECHO>>TMP\INSTALL.cmd 	SET "TMP=%%SYSTEMROOT%%"
ECHO>>TMP\INSTALL.cmd ) ELSE (
ECHO>>TMP\INSTALL.cmd 	SET "TMP=%%TEMP%%"
ECHO>>TMP\INSTALL.cmd )
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd "%%SYSTEMROOT%%\REGEDIT" /E "%%TMP%%\VERREG.txt" "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
IF "%TARGETOS%"=="2K" (
	ECHO>>TMP\INSTALL.cmd FOR /F %%%%I IN ^('TYPE "%%TMP%%\VERREG.txt" ^^^| FINDSTR "ProductName" ^^^| FINDSTR "2000"'^) DO ^(SET "CURRENTOS=2K"^)
)
IF "%TARGETOS%"=="XP" (
	ECHO>>TMP\INSTALL.cmd FOR /F %%%%I IN ^('TYPE "%%TMP%%\VERREG.txt" ^^^| FINDSTR "ProductName" ^^^| FINDSTR  "XP"'^) DO ^(SET "CURRENTOS=XP"^)
)
IF "%TARGETOS%"=="2K3" (
	ECHO>>TMP\INSTALL.cmd FOR /F %%%%I IN ^('TYPE "%%TMP%%\VERREG.txt" ^^^| FINDSTR "ProductName" ^^^| FINDSTR "2003"'^) DO ^(SET "CURRENTOS=2K3"^)
)
ECHO>>TMP\INSTALL.cmd DEL /F/Q "%%TMP%%\VERREG.txt"
ECHO>>TMP\INSTALL.cmd IF NOT "%%CURRENTOS%%"=="%TARGETOS%" (
ECHO>>TMP\INSTALL.cmd 	SET "ERRORMSG=%%FILENAME%% is a Win%TARGETOS% only installer."
ECHO>>TMP\INSTALL.cmd 	GOTO :ERROR
ECHO>>TMP\INSTALL.cmd )
ECHO/>>TMP\INSTALL.cmd
ECHO>>TMP\INSTALL.cmd IF NOT "%%CURRENTOS%%"=="2K" IF %%SSIP%% EQU 0x1 (
ECHO>>TMP\INSTALL.cmd 	REG DELETE "HKLM\SOFTWARE\Microsoft\PCHealth\ErrorReporting\DW" /f
ECHO>>TMP\INSTALL.cmd 	REG ADD "HKLM\SYSTEM\Setup" /v SystemSetupInProgress /t REG_DWORD /d 0 /f
ECHO>>TMP\INSTALL.cmd )
ECHO>>TMP\INSTALL.cmd IF EXIST *.txt (DEL /F/Q *.txt)
ECHO/>>TMP\INSTALL.cmd

ECHO/>>TMP\INSTEND.cmd
ECHO>>TMP\INSTEND.cmd IF NOT "%%CURRENTOS%%"=="2K" IF %%SSIP%% EQU 0x1 (
ECHO>>TMP\INSTEND.cmd 	FOR /F %%%%I IN ('ECHO %%PROGRAMFILES%%\Common Files\Microsoft Shared') DO (SET "SHD=%%%%~sI")
ECHO>>TMP\INSTEND.cmd 	REG ADD "HKLM\SYSTEM\Setup" /v SystemSetupInProgress /t REG_DWORD /d 1 /f
ECHO>>TMP\INSTEND.cmd 	REG ADD "HKLM\SOFTWARE\Microsoft\PCHealth\ErrorReporting\DW\Installed" /v DW0200 /t REG_SZ /d !SHD!\DW\DW20.exe /f
ECHO>>TMP\INSTEND.cmd )
ECHO/>>TMP\INSTEND.cmd
ECHO>>TMP\INSTEND.cmd SET "FILENAME="
ECHO>>TMP\INSTEND.cmd SET "VERBOSITY="
IF DEFINED DNF3530INPROCESS IF NOT "%RMDNF30XPS%"=="1" (
	ECHO>>TMP\INSTEND.cmd SET "XPSVERBOSITY="
)
ECHO>>TMP\INSTEND.cmd SET "CURRENTOS="
ECHO>>TMP\INSTEND.cmd SET "SSIP="
ECHO>>TMP\INSTEND.cmd SET "SHD="

REM Fun fact: you can DelayExpansion parameters at least under Windows 10, but not under XP. :[
REM For the .NET 1.1 installer, this line is not necessary, so "0" is passed instead.
REM .NET 1.1 does have its own ngen.exe, but it seems as though the following command is not-functional(?)/irrelevant.
REM .NET 3.0/3.5 also uses the same ngen.exe located in the exact same spot for the exact same service as .NET 2.0.
REM .NET 3.0/3.5 truly are just DLC for .NET 2.0.
IF %1 EQU 1 (
	ECHO/>>TMP\INSTEND.cmd
	ECHO>>TMP\INSTEND.cmd %%SYSTEMROOT%%\Microsoft.NET\Framework\v2.0.50727\ngen.exe executequeueditems
)
ECHO>>TMP\INSTEND.cmd GOTO :EOF
ECHO/>>TMP\INSTEND.cmd
ECHO/>>TMP\INSTEND.cmd
ECHO>>TMP\INSTEND.cmd :ERROR
ECHO>>TMP\INSTEND.cmd ECHO^>^>ERRORMSGBOX.vbs error = MsgBox("%%ERRORMSG%%",16,"%TARGETOS%%NAME%.exe")
ECHO>>TMP\INSTEND.cmd SET "ERRORMSG="
ECHO>>TMP\INSTEND.cmd WSCRIPT ERRORMSGBOX.vbs
ECHO>>TMP\INSTEND.cmd DEL /F/Q ERRORMSGBOX.vbs
ECHO>>TMP\INSTEND.cmd GOTO :EOF

GOTO :EOF
REM ---------- ----------

REM ---------- Installer Maker ----------
:INSTALLERMAKER
ECHO Creating %MSG% %TARGETOS% %VERBOSITY% installer...
CALL :EXEMAKER
IF "%T13ADDONS%"=="1" (
	ECHO Creating %MSG% %TARGETOS% %VERBOSITY% T-13 add-on...
	CALL :T13ADDONMAKER
)
IF "%ROEADDONS%"=="1" (
	ECHO Creating %MSG% %TARGETOS% %VERBOSITY% RunOnceEx add-on...
	CALL :ROEADDONMAKER
)
GOTO :EOF
REM ---------- ----------

REM ---------- Executable Maker ----------
:EXEMAKER
IF EXIST TMP\config.txt (DEL /F/Q TMP\config.txt)
ECHO>TMP\config.txt ;^^!@Install@^^!UTF-8^^!
ECHO>>TMP\config.txt Title="%TARGETOS%%NAME%.exe"
ECHO>>TMP\config.txt BeginPrompt="This will install %NAME% for %TARGETOS%. Click `Yes` to proceed."
ECHO>>TMP\config.txt RunProgram="%TARGETOS%%NAME%.cmd"
ECHO>>TMP\config.txt ;^^!@InstallEnd@^^!
:EXECOMP
IF EXIST TMP\TEMP.7z (DEL /F/Q TMP\TEMP.7z)
IF "%MEMPARAM%"=="-mx=9" (
	START "Zipping using [ULTRA] compression (close to restart at [NORMAL] compression)" /WAIT 7za a TMP\TEMP.7z -r %MEMPARAM% "%~dp0%FLD%\*"
) ELSE IF "%MEMPARAM%"=="-mx=5" (
	START "Zipping using [NORMAL] compression (close to restart at [NO] compression)" /WAIT 7za a TMP\TEMP.7z -r %MEMPARAM% "%~dp0%FLD%\*"
) ELSE (
	START "Zipping using [NO] compression (close to restart at [ULTRA] compression)" /WAIT 7za a TMP\TEMP.7z -r %MEMPARAM% "%~dp0%FLD%\*"
)
IF %ERRORLEVEL% NEQ 0 (
	(CALL )
	CALL :CHANGEMEMPARAM
	GOTO :EXECOMP
)
CALL :SETMEMPARAM

IF NOT "%T13ADDONS%"=="1" (
	IF NOT "%ROEADDONS%"=="1" (
		SET /A "CREATE=1"
	) ELSE IF "%ALSOINSTALLERS%"=="1" (
		SET /A "CREATE=1"
	)
) ELSE IF "%ALSOINSTALLERS%"=="1" (
	SET /A "CREATE=1"
)
IF DEFINED CREATE (
	SET "CREATE="
	COPY /B 7zSD.sfx + TMP\config.txt + TMP\TEMP.7z "OUT%OUTCNT%\%TARGETOS%%NAME%.exe" >NUL
)
GOTO :EOF
REM ---------- ----------

REM ---------- T13 Add-on Maker ----------
:T13ADDONMAKER
CALL :TMPCOUNT
MD "%TMPDIR%\SVCPACK"
COPY /B 7zSD.sfx + TMP\config.txt + TMP\TEMP.7z "%TMPDIR%\SVCPACK\%TARGETOS%%NAME%.exe" >NUL
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" [general]
FOR /F %%I IN ('DATE /T') DO (ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" builddate=%%I)
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" description=ReSNM %RSNMVER% %TARGETOS% %VERBOSITY% T-13 installer
REM ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" language=
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" title=%MSG%
REM ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" version=
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" website=https://github.com/TheUltraCode
ECHO/>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini"
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" [EditFile]
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" I386\SVCPACK.inf,SetupHotfixesToRun,AddProgram
ECHO/>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini"
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" [AddProgram]
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" %TARGETOS%%NAME%.exe
:T13ADDONCOMP
IF "%MEMPARAM%"=="-mx=9" (
	START "Zipping using [ULTRA] compression (close to restart at [NORMAL] compression)" /WAIT 7za a "OUT%OUTCNT%\T13%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
) ELSE IF "%MEMPARAM%"=="-mx=5" (
	START "Zipping using [NORMAL] compression (close to restart at [NO] compression)" /WAIT 7za a "OUT%OUTCNT%\T13%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
) ELSE (
	START "Zipping using [NO] compression (close to restart at [ULTRA] compression)" /WAIT 7za a "OUT%OUTCNT%\T13%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
)
IF %ERRORLEVEL% NEQ 0 (
	(CALL )
	CALL :CHANGEMEMPARAM
	GOTO :T13ADDONCOMP
)
CALL :SETMEMPARAM
GOTO :EOF
REM ---------- ----------

REM ---------- Roe Add-on Maker ----------
:ROEADDONMAKER
CALL :TMPCOUNT
MD "%TMPDIR%\ROE"
COPY /B 7zSD.sfx + TMP\config.txt + TMP\TEMP.7z "%TMPDIR%\ROE\%TARGETOS%%NAME%.exe" >NUL
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" [general]
FOR /F %%I IN ('DATE /T') DO (ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" builddate=%%I)
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" description=ReSNM %RSNMVER% %TARGETOS% %VERBOSITY% RunOnceEx installer
REM ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" language=
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" title=%MSG%
REM ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" version=
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" website=https://github.com/TheUltraCode
ECHO/>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini"
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" [ExtraFileEdits]
ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" sysoc.inf^|[Components]^|[SourceDisksNames]^<NEXT^>1=,%%CDTAGFILE%%,,^<NEXT^> ^<NEXT^>[Components]^<NEXT^>%TARGETOS%%NAME%=ocgen.dll,OcEntry,%%1%%\I386\ROE\%TARGETOS%%NAME%.inf,HIDE,7^|1
IF "%TARGETOS%"=="2K" (
	ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" sysoc.inf^|[Strings]^|[Strings]^<NEXT^>CDTAGFILE = "\CDROM_NT.5"^|1
) ELSE (
	ECHO>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini" sysoc.inf^|[Strings]^|[Strings]^<NEXT^>CDTAGFILE = "\WIN51"^|1
)
ECHO/>>"%TMPDIR%\entries_%TARGETOS%%NAME%.ini"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [Version]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" signature="$Windows NT$"
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [SourceDisksNames]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" 1=,%%CDTAGFILE%%,,
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [Optional Components]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" %TARGETOS%%NAME%
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [%TARGETOS%%NAME%]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" OptionDesc="%TARGETOS% %VERBOSITY% %MSG%"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" Tip="%TARGETOS% %VERBOSITY% %MSG%"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" Modes=0,1,2,3
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" AddReg=DNFRunOnceEx
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [DNFRunOnceEx]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" HKLM,"%%KEY_WIN_CURVER%%\RunOnceEx",Flags,0x00010001,0x00000020
IF /I "%NAME:~3,1%"=="1" (
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" HKLM,"%%KEY_WIN_CURVER%%\RunOnceEx\###RUNLAST%TARGETOS%%NAME%",,,"%MSG%"
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" HKLM,"%%KEY_WIN_CURVER%%\RunOnceEx\###RUNLAST%TARGETOS%%NAME%","%TARGETOS%%NAME%Install",,"RUNDLL32 advpack.dll,LaunchINFSection %%1%%\%TARGETOS%%NAME%.inf,DefaultInstall"
) ELSE (
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" HKLM,"%%KEY_WIN_CURVER%%\RunOnceEx\###%TARGETOS%%NAME%",,,"%MSG%"
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" HKLM,"%%KEY_WIN_CURVER%%\RunOnceEx\###%TARGETOS%%NAME%","%TARGETOS%%NAME%Install",,"RUNDLL32 advpack.dll,LaunchINFSection %%1%%\%TARGETOS%%NAME%.inf,DefaultInstall"
)
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [DefaultInstall]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" RunPreSetupCommands=DNFSetup
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" SmartReboot=N
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [DNFSetup]
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" %%1%%\%TARGETOS%%NAME%.exe
ECHO/>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf"
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" [Strings]
IF "%TARGETOS%"=="2K" (
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" CDTAGFILE="\CDROM_NT.5"
) ELSE (
	ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" CDTAGFILE="\WIN51"
)
ECHO>>"%TMPDIR%\ROE\%TARGETOS%%NAME%.inf" KEY_WIN_CURVER = "Software\Microsoft\Windows\CurrentVersion"
:ROEADDONCOMP
IF "%MEMPARAM%"=="-mx=9" (
	START "Zipping using [ULTRA] compression (close to restart at [NORMAL] compression)" /WAIT 7za a "OUT%OUTCNT%\ROE%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
) ELSE IF "%MEMPARAM%"=="-mx=5" (
	START "Zipping using [NORMAL] compression (close to restart at [NO] compression)" /WAIT 7za a "OUT%OUTCNT%\ROE%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
) ELSE (
	START "Zipping using [NO] compression (close to restart at [ULTRA] compression)" /WAIT 7za a "OUT%OUTCNT%\ROE%TARGETOS%%NAME%.7z" -r %MEMPARAM% "%TMPDIR%\*" >NUL
)
IF %ERRORLEVEL% NEQ 0 (
	(CALL )
	CALL :CHANGEMEMPARAM
	GOTO :ROEADDONCOMP
)
CALL :SETMEMPARAM
GOTO :EOF
REM ---------- ----------

REM ---------- Terminate ----------
:TERMINATE
ECHO/
PAUSE
TITLE Command Prompt
EXIT /B
GOTO :EOF
REM ---------- ----------
