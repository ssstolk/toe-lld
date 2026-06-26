@echo off
set DIR_START=%cd%

rem Below is a list of configurable variables required for input.
SET CONV_DIR_INPUT=C:\Users\Sander\Documents\TOE database extracted\input\
SET CONV_FILE_INPUT_CATEGORY=TOE_category_20170526.csv
SET CONV_FILE_INPUT_XREF=TOE_category-xref_20170526.csv
SET CONV_FILE_INPUT_LEXEME=TOE_lexeme_20170526.csv

SET CONV_DIR_TEMP=C:\Users\Sander\Documents\TOE database extracted\temp\
SET CONV_DIR_QUERIES=%DIR_START%
SET CONV_DIR_SCHEMAS=%DIR_START%

SET CONV_RDF4J_SERVER=http://127.0.0.1:8080/rdf4j-server
set CONV_RDF4J_REPO=toe


:intro
echo Making TOE suitable for the Semantic Web.
echo NOTE: This requires the following:
echo       (1) riot and curl are available as commands
echo       (2) rdf4j-server is running
echo           and the indicated repository is available and empty
echo       (3) input to be set correctly, etc, etc...

echo.

goto :step1

:step1
echo ... performing step 1: obtaining graph format.
cd /d %CONV_DIR_INPUT%
call riot "%CONV_FILE_INPUT_CATEGORY%" > "%CONV_DIR_TEMP%TOE_category_graph.ttl"
call riot "%CONV_FILE_INPUT_XREF%"     > "%CONV_DIR_TEMP%TOE_category-xref_graph.ttl"
call riot "%CONV_FILE_INPUT_LEXEME%"   > "%CONV_DIR_TEMP%TOE_lexeme_graph.ttl"
cd /d %DIR_START%

:step2
echo ... performing step 2: loading into triplestore.
echo .... (for category data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%TOE_category_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category%%3E" || goto :error
echo .... (for category-xref data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%TOE_category-xref_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category-xref%%3E" || goto :error
echo .... (for lexeme data)
curl -X POST -H "Content-Type: text/turtle" --data-binary "@%CONV_DIR_TEMP%TOE_lexeme_graph.ttl" "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:lexeme%%3E" || goto :error

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
cd /d %DIR_START%

:clean
echo ... performing clean up
echo .... (removing intermediate files)
del "%CONV_DIR_TEMP%TOE_category_graph.ttl"
del "%CONV_DIR_TEMP%TOE_category-xref_graph.ttl"
del "%CONV_DIR_TEMP%TOE_lexeme_graph.ttl"
echo .... (removing intermediate graphs)
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category%%3E" || goto :error
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:category-xref%%3E" || goto :error
curl -X DELETE "%CONV_RDF4J_SERVER%/repositories/%CONV_RDF4J_REPO%/statements?context=%%3Curn:toe:input:lexeme%%3E" || goto :error

:finish
echo.

echo Process finished.
echo TOE is now available in the triplestore.

goto :EOF



:error
echo Process terminated.
cd /d %DIR_START%
exit /b %errorlevel%
