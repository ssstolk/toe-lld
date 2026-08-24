@echo off
set DIR_START=%cd%

rem Below is a list of configurable variables required for input.
SET CONV_DIR_INPUT=C:\Users\Sander\Documents\TOE-LLD\input\2026-07-29\
SET CONV_DATE_INPUT=2026-07-29
SET CONV_FILE_INPUT_CATEGORY=category.csv
SET CONV_FILE_INPUT_XREF=category-xref.csv
SET CONV_FILE_INPUT_LEXEME=lexeme.csv
SET CONV_FILE_INPUT_TOELLDPREVIOUS=toe-lld_2017-05-26.ttl

SET CONV_DIR_TEMP=C:\Users\Sander\Documents\TOE-LLD\temp\
SET CONV_DIR_OUTPUT=C:\Users\Sander\Documents\TOE-LLD\output\
SET CONV_DIR_QUERIES=%DIR_START%
SET CONV_DIR_SCHEMAS=%DIR_START%

SET CONV_RDF4J_SERVER=http://127.0.0.1:8080/rdf4j-server
SET CONV_RDF4J_REPO=toe


:intro
echo Making TOE suitable for the Semantic Web.
echo NOTE: This requires the following:
echo       (1) riot and curl are available as commands
echo       (2) rdf4j-server is running
echo           and the indicated repository is available and empty
echo       (3) conversion variables are set correctly
echo           and point to the correct input files

echo.

goto :step1

:step1
echo ... performing step 1: obtaining graph format.
cd /d %CONV_DIR_INPUT%
call riot "%CONV_FILE_INPUT_CATEGORY%" > "%CONV_DIR_TEMP%category_graph.ttl"
call riot "%CONV_FILE_INPUT_XREF%"     > "%CONV_DIR_TEMP%category-xref_graph.ttl"
call riot "%CONV_FILE_INPUT_LEXEME%"   > "%CONV_DIR_TEMP%lexeme_graph.ttl"

SET owlVersionInfoDate=%CONV_DATE_INPUT:-=% 
echo @prefix owl: ^<http://www.w3.org/2002/07/owl#^> . @prefix dct: ^<http://purl.org/dc/terms/^> . @prefix toe: ^<http://oldenglishthesaurus.arts.gla.ac.uk/^> . toe: dct:modified "%CONV_DATE_INPUT%"^^^^xsd:date . toe: owl:versionInfo "3.%owlVersionInfoDate%"^^^^xsd:decimal . > "%CONV_DIR_TEMP%toelld_currentversion_metadata.ttl"

cd /d %DIR_START%

:step2
echo ... performing step 2: loading into triplestore.
echo .... (for category data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%category_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category%%3E" || goto :error
echo .... (for category-xref data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%category-xref_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category-xref%%3E" || goto :error
echo .... (for lexeme data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%lexeme_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:lexeme%%3E" || goto :error
echo .... (for previous version of TOE-LLD)
IF "%CONV_FILE_INPUT_TOELLDPREVIOUS%"=="" goto :missingtoelldprevious
IF NOT EXIST "%CONV_DIR_INPUT%%CONV_FILE_INPUT_TOELLDPREVIOUS%" goto :missingtoelldprevious
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_INPUT%%CONV_FILE_INPUT_TOELLDPREVIOUS%" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:toePrevious%%3E" || goto :error
goto :step3
:missingtoelldprevious
echo ...... (WARNING: previous version of TOE-LLD was not found or specified)
CHOICE /C YN /M "Continue regardless? Press Y for Yes or N for No."
echo "%ERRORLEVEL%"
IF "%ERRORLEVEL%" == "2" goto :error

:step3
echo ... performing step 3: interpreting semantics.

cd /d %CONV_DIR_QUERIES%
for /F "delims=" %%f in ('dir /b *.sparql') do ^
echo .... (by means of query "%%f") && ^
curl -X POST -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" --data-urlencode "update@%%f" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements" || goto :error
cd /d %DIR_START%

:step4
echo ... adding definitions for thesaurus.
cd /d %CONV_DIR_SCHEMAS%
for /F "delims=" %%f in ('dir /b *.ttl') do ^
echo .... (by means of schema "%%f") && ^
curl -X POST -H "Content-Type: text/turtle; charset=UTF-8" --data-binary "@%%f" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:def:%%f%%3E" || goto :error
echo .... (by means of version date metadata)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%toelld_currentversion_metadata.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:versionInfo%%3E" || goto :error
cd /d %DIR_START%

:clean
echo ... performing clean up
echo .... (removing intermediate files)
del "%CONV_DIR_TEMP%category_graph.ttl"
del "%CONV_DIR_TEMP%category-xref_graph.ttl"
del "%CONV_DIR_TEMP%lexeme_graph.ttl"
del "%CONV_DIR_TEMP%toelld_currentversion_metadata.ttl"
echo .... (removing intermediate graphs)
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category%%3E" || goto :error
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category-xref%%3E" || goto :error
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:lexeme%%3E" || goto :error
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:toePrevious%%3E" || goto :error

:finish
echo.

echo Process finished.
echo TOE-LLD is now available in the triplestore.
CHOICE /C YN /M "Download TOE-LLD as a Turtle file (.ttl)? Press Y for Yes or N for No."
echo "%ERRORLEVEL%"
IF "%ERRORLEVEL%" == "2" goto :EOF
curl -X GET -H "Accept: text/turtle; charset=UTF-8" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements" > "%CONV_DIR_OUTPUT%toe-lld_%CONV_DATE_INPUT%.ttl" || goto :error
goto :EOF

:error
echo Process terminated.
cd /d %DIR_START%
exit /b %errorlevel%
