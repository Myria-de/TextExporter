#!/usr/bin/python
# -*- coding: utf-8 -*-
#convert odt -> pdf, odt -> html
#script v0.2
#02-2019
#
#using ooo2sdbk by Eric Bellot
#
import os
import sys
import os.path
workdir=sys.path[0]
sys.path.append(workdir + "/ooo2dbk")

import shutil
import ConfigParser
import ooo2dbk
import options
import zipfile
#
# Bei Bedarf Pfad anpassen
#
#DocbookPath = "/usr/share/xml/docbook/stylesheet/nwalsh/"
TargetDir = workdir + "/Ausgabe"
DocbookPath = workdir + "/DOCBOOK/"
if not os.path.isdir(DocbookPath):
	print	
	print "Fehler: " + DocbookPath + " nicht gefunden"
	print "Bitte installieren Sie die erforderlichen Docbook-Pakete"
	print
	raise SystemExit

#ok=0
#auf 0 setzen, um temporaere Dateien zu behalten
clean=0
print
print 'lwTextExporter.py v0.2 by Thorsten Eggeling'

def CleanUp(filename):
    os.remove(filename)

def zipdir(path, ziph):
    # ziph is zipfile handle
	for root, dirs, files in os.walk(path):
		for file in files:
			ziph.write(os.path.join(root, file), 
				os.path.relpath(os.path.join(root, file),
						os.path.join(path, '..')))
			#(os.path.join(root, file), os.path.join(path, '..'))
			#ziph.write(os.path.join(root, file))

def zipit(dir_list, zip_name):
    zipf = zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED)
    for dir in dir_list:
        zipdir(dir, zipf)
    zipf.close()
    
def PrintUsage():
    print 'Anwendung: lwTextExporter.py -c <html | html_nav | pdf | epub | webhelp>'
    print '                             [-d <path>] [-x Stylesheet]'
    print '                             [-a ] [-p <profile_id>] filename'
    print
    print '-d Ausgabeverzeichnis (muss existieren), Standard ist "Ausgabe"'
    print '-c Ausgabeformat'
    print '-x Pfad zum XSL-Stylesheet (optional)'
    print '-a Verwende Dokumenttyp "article". Standard ist "book" (optional)'
    print '-p Indexnummer aus der Datei config/profiles.cfg.'
    print '   Parameter für die Umwandlung (optional)'
    print
    print 'Beispiele:'
    print
    print 'Umwandlung in HTML (eine große HTML-Datei)'
    print 'lwTextExporter.py -d ~/texte -c html ~/lwTextExporter/Beispiele/beispiel_de.odt'
    print
    print 'Umwandlung in PDF, verwenden Profil ID 5'
    print 'lwTextExporter.py -d /home/te/Dokumente -c pdf -p 5 /home/te/Dokumente/datei.odt'
    print 
    print 'Wichtig: Alle Pfade müssen absolut angegeben werden'
    print 'Relative Pfadangaben funktionieren nicht'
    print

def execArgs ():
#    from ooo2sdbk import options
    global argDbk, argOOo, argCmd, argProfile, argXSL, argArticle
   
    options.GetOptions(("d|dbkfile=s"),("h|?|help"),("c|command=s"),("p|profile=s"),("x|style=s"),("a:i"))
    args=sys.argv
    
    if len(args) <= 1:
	PrintUsage()
	sys.exit()
    
    argOOo = args[0]
 
    argDbk = options.myOptions.d
    if argDbk == None:
	argDbk = TargetDir # default wordir + "Ausgabe"
    
    argXSL = options.myOptions.x
    if argXSL == None:
	argXSL = ""

    argArticle = options.myOptions.a
    if argArticle == None:
	argArticle = "book"
    if argArticle == 0:
	argArticle = "article"
    
    argCmd = options.myOptions.c    
    if argCmd == None:
	argCmd=0
	print "Fehler: Ausgabe-Format fehlt"
	print

    argProfile = options.myOptions.p
    if argProfile == None:
    	argProfile = "-1"
	
    
    #test cmd argument
    ok=0
    a= ['html', 'html_nav', 'pdf', 'epub', 'webhelp']
    for x in a:
	if argCmd==x:
	    ok=1
    if ok<>1:
	print "Fehler: Ausgabe-Format nicht bekannt :", argCmd
	print
	PrintUsage()
	sys.exit()

    
    argHelp = options.myOptions.h
    if argHelp == None:
	argHelp = 0
    else:
	PrintUsage()
	sys.exit()

print

#parse args
execArgs()

#check output path and create
if os.path.exists(argDbk) == 0:
    os.mkdir(argDbk)
    print "Erstelle :", argDbk

if os.path.exists(argDbk) == 0:
    print "Konnte Ausgabe-Verzeichnis nicht erstellen", argDbk

convertto=argCmd
    
print "Konvertiere: " + argOOo + " nach " + argCmd
    
# Input OpenOffice-Writer file
oooFile = argOOo

#build basename
radical = os.path.basename(argOOo)
radical = radical[:-4]

# Output simple Docbook file
docbookFile = argDbk +"/" +  radical +"/" + radical + "-dbk.xml"

xslStringParams=""
epubBaseDir=""
use_admon_graphics=""
    
htmlSimple = argDbk + "/" + radical + "/" + radical + ".html"

htmlMultiple =  r"index.htm"

# create path
if not os.path.exists(argDbk + "/" + radical):
	os.makedirs(argDbk + "/" + radical)

output_dir=argDbk + "/" + radical

oldWorkDir=os.getcwd()
print 'Workdir: ' + argDbk + "/" + radical
os.chdir (argDbk + "/" + radical)

# output file names
foFile =  output_dir +"/" + radical + ".fo"
pdfFile =  output_dir +"/" + radical + ".pdf"
rtfFile =  output_dir +"/" + radical + ".rtf"
epubfile = output_dir +"/" + radical + ".epub"


#Stylesheets
if argXSL == "":
	# XSL stylesheet html with navigation (multiple html files)
	htmlMultipleXSL = DocbookPath + "html/chunk.xsl"

	# XSL stylesheet single html
	#htmlSimpleXSL = DocbookPath + "html/docbook.xsl"
	htmlSimpleXSL = DocbookPath + "Custom_html_2.xsl"
	
	# XSL stylesheet epub
	epub3xsl = DocbookPath + "epub3/chunk.xsl"

	#fo -> pdf
	FOXSL = DocbookPath + "fo/docbook.xsl"
	#FOXSL = workdir + "/xsl/custom_fo.xsl"
else:
	#custom stylesheet
	htmlMultipleXSL = argXSL
	htmlSimpleXSL = argXSL
	epub3xsl = argXSL
	FOXSL = argXSL

if argArticle == "":
	docbook_top_elem = 'book'

if argArticle == "book":
	docbook_top_elem = 'book'
else:
	docbook_top_elem = 'article'	

# auto profile 0 - 4
if argProfile == "-1":
	if convertto == "html": argProfile="0"
	if convertto == "html_nav": argProfile="1"
	if convertto == "pdf": argProfile="2"
	if convertto == "epub": argProfile="3"
	if convertto == "webhelp": argProfile="4"

cp = ConfigParser.ConfigParser()
cp.readfp (open(workdir + '/config/profiles.cfg'))

xslStringParams =  ' --stringparam "topElementName" "' + docbook_top_elem + '"'
for item in cp.items(argProfile):
	xslStringParams = xslStringParams + ' --stringparam ' + '"' + item[0] + '"' + ' "' + item[1] + '"'
	if item[0] == 'base.dir':
		epubBaseDir=item[1]
	if item[0] == 'admon.graphics':
		use_admon_graphics=item[1]	
	
# odt-> dbk.xml

ooo2dbk.convert(oooFile, docbook_file_path=docbookFile, deltemp=0, command="xsltproc", xslParams=xslStringParams, conf_file_path=workdir + "/ooo2dbk/ooo2dbk.xml",imagesrew=1,docbook_top_element=docbook_top_elem)
    
#Multi-HTML - mehrere Dateien
if convertto == "html_nav":
    ooo2dbk.convert2(xmlinput=docbookFile, file_output="s", xslt_file_path=htmlMultipleXSL, command="xsltproc",xslParams=xslStringParams,conf_file_path=workdir +"/ooo2dbk/ooo2dbk.xml",docbook_top_element=docbook_top_elem)
    
#Simple HTML - ein grosse Datei
if convertto == "html":
    ooo2dbk.convert2(xmlinput=docbookFile, file_output=htmlSimple, xslt_file_path=htmlSimpleXSL, command="xsltproc",xslParams=xslStringParams,conf_file_path=workdir + "/ooo2dbk/ooo2dbk.xml",docbook_top_element=docbook_top_elem)

#pdf	
if convertto == "pdf":
	print foFile

	ooo2dbk.convert2(xmlinput=docbookFile, file_output=foFile, xslt_file_path=FOXSL, command="xsltproc", xslParams=xslStringParams, conf_file_path=workdir + "/ooo2dbk/ooo2dbk.xml",docbook_top_element=docbook_top_elem)
	# Create pdf file
	ooo2dbk.convert2(xmlinput=foFile, file_output=pdfFile, command="fop-pdf2",docbook_top_element=docbook_top_elem)
	if clean == 1:
		CleanUp(foFile)
	
#rtf funktioniert nicht optimal / nicht mehr unterstützt
#if convertto == "rtf":
#	cmd="openjade -G -c /usr/share/xml/docbook/schema/dtd/4.4/docbook.cat -t rtf -V rtf-backend -#o " + rtfFile + " -d /home/te/lwTextExporter/config/myStyle2.dsl /usr/share/sgml/declaration/xml.dcl #" + docbookFile
#	print cmd
#	os.system (cmd)

#webhelp
if convertto == "webhelp":
	if not os.path.exists(argDbk + "/" + radical + '/webhelp-files'):
		os.makedirs(argDbk + "/" + radical + '/webhelp-files')

	antParams=""
	for item in cp.items(argProfile):
		antParams =  antParams + ' "'+ "-D" + item[0] + "=" + item[1] + '"'

	os.chdir (workdir + "/Webhelp")	
	#os.environ['CLASSPATH']="../lib/saxon.jar:../lib/resolver.jar"	
	os.environ['CLASSPATH']="/usr/share/java:/usr/share/java/saxon.jar:/usr/share/java/xml-resolver.jar"
	cmd="/usr/bin/ant -v webhelp " +antParams + " -Doutput-dir=" + argDbk + "/" + radical + "/webhelp-files " + "-Dinput-xml=" + docbookFile
	print cmd
	os.system (cmd)
	

#epub
if convertto == "epub":
	print "epubBaseDir:" + epubBaseDir
	ooo2dbk.convert2(xmlinput=docbookFile, file_output=epubfile,  docbook_top_element=docbook_top_elem, xslt_file_path=epub3xsl, xslParams=xslStringParams, command="xsltproc", conf_file_path=workdir + "/ooo2dbk/ooo2dbk.xml")
	
	# file copy
	destination = epubBaseDir +'images/'
	if os.path.exists(output_dir + '/images'):
		if not os.path.exists(epubBaseDir +'images'):
			os.makedirs(epubBaseDir +'images')
		source = os.listdir(output_dir + '/images/')
		for files in source:
			print 'Kopiere Datei: ' + files
		        shutil.copy(output_dir + '/images/' + files,destination)

	if use_admon_graphics == "1":
		if not os.path.exists(epubBaseDir +'images'):
			os.makedirs(epubBaseDir +'images')
		source = os.listdir(workdir + '/Vorlagen/epub3/images/')
		for files in source:
			print 'Kopiere Datei: ' + files
		        shutil.copy(workdir + '/Vorlagen/epub3/images/' + files,destination)
			
	# Cover
	shutil.copy(workdir + '/Vorlagen/epub3/cover/cover.jpg' ,destination)
	destination = epubBaseDir	
	shutil.copy(workdir + '/Vorlagen/epub3/cover/CoverImage.xhtml' ,destination)
	
	#package
	f2 = open(epubBaseDir +'package.opf.tmp','w+')
	f = open(epubBaseDir +'package.opf')
	try:
	    for line in f:
		f2.write(line)
		stripped_line=line.strip()
		if stripped_line == '<metadata>':
			f2.write('    <meta content="cover.jpg" name="cover" />\n')				
		if stripped_line == '<manifest>':
			f2.write('    <item id="cover.jpg" href="CoverImage.xhtml" media-type="application/xhtml+xml"/>\n')
			if use_admon_graphics == "1":
				source = os.listdir(workdir + '/Vorlagen/epub3/images/')
				for file in source:
					f2.write('    <item id="' + file + '" href="images/' + file +'" media-type="image/png"/>\n')
		if stripped_line == '<spine toc="ncx">':
			f2.write('    <itemref idref="cover.jpg"/>\n')
		if stripped_line == '<guide>':
			f2.write('    <reference href="CoverImage.xhtml" title="Cover" type="cover"/>\n')
	finally:
		f.close()
		f2.close()
	os.remove(epubBaseDir +'package.opf')
	os.rename(epubBaseDir +'package.opf.tmp', epubBaseDir +'package.opf')

	#zip erstellen
	myPath=output_dir + '/ebook'
	os.chdir(myPath)
	print "Erstelle epub:" + myPath
	myZip=zipfile.ZipFile(epubfile, 'w', zipfile.ZIP_DEFLATED)
	myZip.write('mimetype',compress_type=zipfile.ZIP_STORED)
	os.remove(output_dir + '/ebook/mimetype')
	
	for root, dirs, files in os.walk(myPath):
		for file in files:
			absfn = os.path.join(root, file)
			zfn = absfn[len(myPath)+len(os.sep):] 
			myZip.write(absfn, zfn)
	myZip.close()
    	
if clean == 1:
    CleanUp(docbookFile)
    CleanUp(argDbk + "/" + "global.xml")
        
os.chdir(oldWorkDir)
