@echo off
@setlocal
SET PATH=..\java\bin;%PATH%
SET JAVA_HOME=..\java
SET ANT_HOME=../apache-ant
SET CLASSPATH=../lib/saxon.jar;../lib/resolver.jar
SET OUTDIR=%1
SET SRCFILE=%2
REM parametes-Dadmon.graphics=1 -Dsuppress.footer.navigation=0
if ""%1""=="""" goto error_outputdir
if ""%2""=="""" goto error_src
call ..\apache-ant\bin\ant webhelp %3 %4 %5 %6 %7 %8 %9 -Doutput-dir=%OUTDIR% -Dinput-xml=%SRCFILE%
goto end

:error_src
echo.
echo Fehler: Keine Quelldatei angegeben
echo.
goto end

:error_outputdir
echo.
echo Fehler: Keine Ausgabeverzeichnis angegeben
echo.
goto end

:end


