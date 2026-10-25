@echo off
rem Command-line build of DelphiRestReceiver.exe with dcc32.
rem Adjust the three paths below (or set them before calling this script).

if "%BDS%"=="" set BDS=C:\Program Files (x86)\CodeGear\RAD Studio\6.0
if "%INDY%"=="" set INDY=..\..\Indy\Lib
if "%JSONDATAOBJECTS%"=="" set JSONDATAOBJECTS=..\..\JsonDataObjects\Source

if not exist dcu mkdir dcu

"%BDS%\bin\dcc32.exe" -B -Q ^
  "-U%BDS%\lib;%INDY%\Core;%INDY%\Protocols;%INDY%\System;%JSONDATAOBJECTS%" ^
  "-I%INDY%\Core;%INDY%\System" ^
  -Ndcu -E. DelphiRestReceiver.dpr
