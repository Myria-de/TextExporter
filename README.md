# TextExporter
Convert Libre Office Files to DocBook
Libre Office is not rquired. 
Conversion is done by Python scripts and XSLT transformation (Linux)

**Requirements (Ubuntu)**

`sudo apt install python xsltproc default-jre fop ant xterm`

**Usage**

`./lwTextExporter.py -c html ~/lwText/Beispiele/beispiel_de.odt`

Converted files: "Ausgabe/beispiel_de"
"-c" defines the output format

Possible values:

**html**: one HTML file with table of contents.

**html_nav**: one HTML file for each chapter. The first file is called "index.html". Navigation links like "Weiter" an "Back" are included.

**pdf**: creates a PDF file with title page and bookmarks.

**epub**: Ebup file with table of contents and cover image from "Vorlagen/epub3/cover/cover.jpg".

**webhelp**: similar to „html_nav“. One HTML file for each chapter, the first file is "index.html". Contents navigation with sidebar. Search funktion ist included. Template see "Webhelp/template".

**Credits**

**OOo2DBK**: OOo2DBK is an OpenOffice.org document to DocBook XML converter.

Copyright 2003-2007 Nuxeo SAS <http://nuxeo.com>

Copyright 2002 Eric Bellot

**DocBook**: https://tdg.docbook.org/tdg/4.5/index.html
