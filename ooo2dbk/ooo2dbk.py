#!/usr/bin/python
# (C) Copyright 2003-2007 Nuxeo SAS <http://nuxeo.com>
# (C) Copyright 2002 Eric Bellot <ebellot@netcourrier.com>
#
# Authors:
# M.-A. Darche (Nuxeo)
# Ruslan Spivak (Nuxeo)
# Eric Bellot <ebellot@netcourrier.com>
# Laurent Godard (lgodard@indesko.com)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.
#
# See ``COPYING`` for more information
#
# $Id$

import zipfile
import os, os.path, sys
from string import join, split, find
import codecs
from xml.dom import minidom
import time, base64
import re
import xml.sax
import shutil
import locale
from optparse import OptionParser

VERSION = '2.0'

CONF_FILE_NAME = 'ooo2dbk.xml'

# OpenOffice.org canonical XML files
OOO_META_FILE_NAME = 'meta.xml'
OOO_STYLES_FILE_NAME = 'styles.xml'
OOO_CONTENT_FILE_NAME = 'content.xml'

DOCBOOK_FILE_SUFFIX = '.docb.xml'

# ZIP entries paths are stored in "code page 437" encoding (cp437).
# One cannot use UTF-8 for the ZIP entries paths.
# Read [ 878120 ] Zipfile archive name can't be unicode
# https://sourceforge.net/tracker/?func=detail&atid=105470&aid=878120&group_id=5470
ZIP_FILE_ENCODING = 'cp437'

# Initialization (attempt to remove some global statements)
oooVersion = 'ooo1'
docbookXSL = None
verbose = True
zipfile_target = None
docbook_top_element = 'book'
process_ole_objects = False

def execArgs():
    """Analyze command line arguments.
    """
    usage = "usage: %prog [options] openoffice.org-file"
    parser = OptionParser(usage=usage, version="%prog " + VERSION)

    parser.add_option('-z', '--zipfile',
                      action='store',
                      dest='zipfile_target',
                      type='string',
                      metavar='FILE',
                      default=None,
                      help="Use FILE as the filename for "
                      "the generated ZIP archive")

    parser.add_option('-d', '--dbkfile',
                      action='store',
                      dest='dbkfile',
                      type='string',
                      metavar='FILE',
                      default=None,
                      help="Use FILE as the filename for "
                      "the generated DocBook XML file. "
                      "This option has no effect if the "
                      "-z/--zipfile option is used.")

    parser.add_option('-b', '--book',
                      action='store_true',
                      dest='book',
                      default=False,
                      help="Produce a DocBook XML book. "
                      "This is the default.")

    parser.add_option('-a', '--article',
                      action='store_true',
                      dest='article',
                      default=False,
                      help="Produce a DocBook XML article.")

    parser.add_option('--ole',
                      action='store_true',
                      dest='ole',
                      default=False,
                      help="Include potential OLE objects as images in the "
                      "resulting DocBook XML document. This option needs that "
                      "a listening OpenOffice.org instance be running.")

    parser.add_option('-c', '--config',
                      action='store',
                      dest='config',
                      type='string',
                      metavar='FILE',
                      default=None,
                      help="Use FILE as the file path for the program configuration file. "
                      "Defaults to the global /etc/%s configuration file or to the "
                      "%s configuration file in the ooo2dbk executable directory."
                      % (CONF_FILE_NAME, CONF_FILE_NAME))

    parser.add_option('-x', '--xslt',
                      action='store',
                      dest='xslt',
                      type='string',
                      metavar='FILE',
                      default=None,
                      help="Use FILE as the file path for the XSLT stylesheet. "
                      "Defaults to the ooo2dbk ooo2dbk.xsl stylesheet.")

    parser.add_option('-m', '--cmdxslt',
                      action='store',
                      dest='cmdxslt',
                      type='string',
                      metavar='NAME',
                      default=None,
                      help="Use command NAME as the XSLT processor. "
                      "Available command names are defined in the "
                      "ooo2dbk configuration file. "
                      "Defaults to xsltproc.")

    parser.add_option('-f', '--flatxml',
                      action='store_false',
                      dest='flatxml',
                      default=True,
                      help="Preserve the intermediate OpenOffice.org "
                      "XML file (global.xml)")

    parser.add_option('-v', '--verbose',
                      action='store_true',
                      dest='verbose',
                      default=False,
                      help="Print additional information to stdout "
                      "when running conversion")

    if len(sys.argv) < 2:
        parser.print_help()
        # Command line syntax errors return the error code "2"
        sys.exit(2)

    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.error("incorrect number of arguments")

    ooo_file_path = args[0]

    if options.book:
        docbook_top_element = 'book'
    elif options.article:
        docbook_top_element = 'article'
    else:
        docbook_top_element = 'book'
    xslParams = []
    xslParams.append('topElementName')
    xslParams.append(docbook_top_element)

    process_ole_objects = options.ole

    convert(ooo_file_path,
            conf_file_path=options.config,
            command=options.cmdxslt,
            xslt_file_path=options.xslt,
            xslParams=xslParams,
            docbook_file_path=options.dbkfile,
            deltemp=options.flatxml,
            verbose=options.verbose,
            zipfile_target=options.zipfile_target,
            docbook_top_element=docbook_top_element,
            process_ole_objects=options.ole,
            docbookXSL=None,
            )
    return

# ---------
# Utilities
# ---------

def getModulePath():
    """Return the path of the directory in which the ooo2dbk executable resides.
    """
    moduleFullname = os.path.abspath(execArgs.func_code.co_filename)
    modulePath = os.path.split(moduleFullname)[0]
    return modulePath

def fileExist(file):
    if file != '':
        return os.path.isfile(file)
    else:
        print "Bad filename: ", file
        sys.exit(1)

def writeFile(file,strContent):
    b = open(file, 'w')
    b.write(strContent)
    b.close()


def verifSys():
    """Current system identification.
    """
    global preferred_encoding
    preferred_encoding = locale.getpreferredencoding()

    global currentSys
    if sys.platform == 'win32':
        currentSys = 'windows'
    else:
        currentSys = 'unix'


def verifPath(path):
    """Syntax path verification.
    """
    global currentSys
    if currentSys == 'windows':
        modPathWin = re.compile(r"^(([a-zA-Z]:\\)?|(\.\.\\)*)([^\?:/\*\"<>\|]+[^\s\?:/\*\"<>\|]\\)*[^\?:/\*\"<>\|]+(\.[a-zA-Z0-9]+)?$")
        verifPath = modPathWin.match(path)
    if currentSys == 'unix':
        modPathUnix = re.compile(r"^(~|(\.\./)*)?([^\\\?:\*\"<>\|]+[^\\\s\?:\*\"<>\|]/)*[^\\\?:\*\"<>\|]+(\.[a-zA-Z0-9]+)*$")
        verifPath = modPathUnix.match(path)
    if verifPath == None:
        print "Bad path :\n", path
        sys.exit(1)
    else:
        return verifPath.group()


def createDirectory(path):
    drive = ''
    if currentSys == 'windows' and os.path.isabs(path):
        dualWin = os.path.splitdrive(path)
        drive = dualWin[0]
        path = dualWin[1][1:]
    listDir = split(path, os.sep)
    i = 1
    while i <= len(listDir):
        testPath = join(listDir[:i], os.sep)
        if drive != '':
            testPath = join([drive, testPath], os.sep)
        if os.path.isdir(testPath) == 0:
            os.mkdir(testPath)
        i += 1

# --------
# SETTINGS
# --------

def getXSLfile(oooVersion):

    # Using the XSLT stylesheets specified in the CONF_FILE_NAME file
    stylesheet_file_name = getConfigValue('xslt-stylesheet',
                                              'stylesheetPath',
                                              name=oooVersion)
    stylesheet_file_name = verifPath(stylesheet_file_name)
    if stylesheet_file_name == None:
        print "Bad filename %s for 'xslt-stylesheet' %s in '%s'" % (
                                                stylesheet_file_name,
                                                oooVersion,
                                                CONF_FILE_NAME,
						)

    xsltfile = os.path.join(getModulePath(), stylesheet_file_name)

    return xsltfile

def setConfFileSettings(conf_file_path=None):
    global configXML
    global configElts, imgRelDir, imgRootName
    global oooserver_host, oooserver_port
    global ole_img_format, ole2img_script_path, ooopython_path

    # Configuration file
    # look at options.config priorities for parameters file
    #   1- c file.xml
    #   2- /etc/ooo2dbk.xml
    #   3- ooo2dbk.xml in the cuurent directory
    if conf_file_path is not None:
        configXML = conf_file_path
    else:
        conf_file_path_global = os.path.join('/etc', CONF_FILE_NAME)
        if os.path.isfile(conf_file_path_global):
            configXML = conf_file_path_global
        else:
            configXML = os.path.join(getModulePath(), CONF_FILE_NAME)

    configParse = minidom.parse(configXML)
    configDocElt = configParse.documentElement
    eltsParse = configDocElt.childNodes
    configElts = []
    for node in eltsParse:
        if node.nodeType == node.ELEMENT_NODE:
            lenAtt = node.attributes.length
            dictAtt = {}
            i = 0
            while i < lenAtt:
                att = node.attributes.item(i)
                dictAtt[att.name] = att.value
                i += 1
            tupleElt = (node.nodeName, dictAtt)
            configElts.append(tupleElt)



    # Images relative directory
    imgRelDir = getConfigValue('images', 'imagesRelativeDirectory')
    verifPathIRD = re.match(r"^[a-zA-Z0-9]+$", imgRelDir)
    if verifPathIRD == None:
        msg = ("Only one depth relative directory (no '%s') "
               "and only alphanum chars for 'imagesRelativeDirectory' in '%s'\n"
               "Actual name is : '%s'"
               % (os.sep, CONF_FILE_NAME, imgRelDir))
        print msg
        sys.exit(1)
    # Images root name
    imgRootName = getConfigValue('images', 'imageNameRoot')
    verifPathIR = re.match(r"^[a-zA-Z0-9]+$", imgRootName)
    if verifPathIR == None:
        print "Only alphanum chars for 'imageNameRoot' in '%s'" % CONF_FILE_NAME
        print "Actual name is :", imgRootName
        sys.exit(1)

    oooserver_host = getConfigValue('oooserver', 'host')
    oooserver_port = getConfigValue('oooserver', 'port')
    ole_img_format = getConfigValue('ole', 'imgFormat')
    ole2img_script_path = getConfigValue('ole', 'scriptPath')
    ooopython_path = getConfigValue('ooopython', 'path')


def getConfigValue(element, attribute, name=''):
    """
    Return from the CONF_FILE_NAME file the value of the specified attribute
    ('command', 'param-syntax', etc.) for the specified element type
    'xslt-command', 'xslt-stylesheet', etc.) with its 'name' attribute having
    the name value.
    """
    global configElts
    value = ''
    i = len(configElts) - 1
    while i >= 0 :
        elt = configElts[i]
        if name != '':
            if elt[0] == element and elt[1]['name'] == name:
                value = elt[1][attribute]
        else:
            # We take the default element
            if elt[0] == element:
                value = elt[1][attribute]
        i = i - 1
    if value != '':
        return value
    else:
        if name != '':
            print ("There isn't any value for this parameter. "
                   "There should be an error in your %s." % CONF_FILE_NAME)
            sys.exit(1)


def setUserSettings(ooofile, docbook, command, imagesrew, deltemp, dtd,
                    xslt_file_path, xslParams, verbose):
    global docOOoSXW, docbookXML, globalXML
    global imgRelDir, imgAbsDir, rewriteImg
    global XSLCmdTemplate, dtdPublic, dtdSystem, XSLParams

    # OpenOffice.org filename
    ooofile = verifPath(ooofile)
    if fileExist(ooofile) == 0:
        errorMsg = ("\n>>  ERROR : Incorrect OpenOffice.org file : \n>>  "
                    + ooofile + "\n")
        print errorMsg
        sys.exit(1)
    else:
        docOOoSXW = ooofile
    # DocBook filename
    if docbook is not None:
        docbook = verifPath(docbook)
        path = os.path.split(docbook)[0]
        docbookXML = docbook
    else:
        OOoSplit = os.path.split(docOOoSXW)
        #path = OOoSplit[0]
        # This line will result producing subobjects(images) and
        # OOo & DocBook xml under directory where ooo2dbk.py resides
        #path = os.path.abspath(os.path.dirname(__file__))
        # This line will result producing subobjects(images) and
        # OOo & DocBook xml under directory from which ooo2dbk.py was launched
        path = os.getcwd()
        rootName = os.path.splitext(OOoSplit[1])[0]
        docbookXML = os.path.join(path, rootName) + DOCBOOK_FILE_SUFFIX
        # Replace spaces in Writer document name with '_'
        docbookXML = re.sub('\s', '_', docbookXML)
    # Destination directory
    if path != '' and os.path.isdir(path) == 0:
        createDirectory(path)
    # Temporary files names
    if deltemp == 0:
        globalXML = os.path.join(path, 'global.xml')
    else:
        import tempfile
        tempfile.tempdir = path
        globalXML = tempfile.mktemp('g.xml')

    # Images Directory
    imgAbsDir = os.path.join(toUnicode(path), imgRelDir)

    # Force image rewriting (0|1)
    rewriteImg = imagesrew

    # XSL processor command
    if command is not None:
        XSLCmdTemplate = getConfigValue('xslt-command', 'command', command)
    else:
        XSLCmdTemplate = getConfigValue('xslt-command', 'command')

    # DTD
    if dtd is not None:
        dtdPublic = getConfigValue('dtd', 'doctype-public', dtd)
        dtdSystem = getConfigValue('dtd', 'doctype-system', dtd)
    else:
        dtdPublic = getConfigValue('dtd', 'doctype-public')
        dtdSystem = getConfigValue('dtd', 'doctype-system')

    # XSLT stylesheet
    if xslt_file_path is not None:
        docbookXSL = xslt_file_path

    # XSLT Params
    if xslParams is not None:
        if command is not None:
            param_syntax = getConfigValue('xslt-command', 'param-syntax',
                                          command)
        else:
            param_syntax = getConfigValue('xslt-command', 'param-syntax')
        # Retrieve the XSLT params and set them according to the param syntax.
        # This is done because XSLT processors have different command line
        # options.      
	#XSLParams=''
	#XSLParams = ("%s" % (param_syntax)) % tuple(xslParams)
	if xslParams != 0:
		XSLParams = xslParams
	else:
		XSLParams = " "
	print "XSL-Parameter:" + XSLParams
    else:
        XSLParams = ' '
    if verbose:
        print "       - xslParams = %s" % xslParams
        print "       - param_syntax = %s" % param_syntax
        print "       - XSLParams = %s" % XSLParams


def initializeSets(ooo_file_path, docbook, command, imagesrew, deltemp, dtd,
                   conf_file_path, xslt_file_path, xslParams, verbose):
    verifSys()
    setConfFileSettings(conf_file_path)
    setUserSettings(ooo_file_path, docbook, command, imagesrew, deltemp, dtd,
                    xslt_file_path, xslParams, verbose)

# --------------------
# Conversion functions
# --------------------

def extractOooArchive(docOOoSXW, XMLFile):
    """Generic XML files extraction.
    """
    # Checking that the OOo file is truly of the ZIP format
    if zipfile.is_zipfile(docOOoSXW):
        zip_file = zipfile.ZipFile(docOOoSXW, 'r')
        # Listing the file content
        contentListZip = zip_file.namelist()
        # Checking that a "content.xml" file is truly present
        for i in contentListZip:
            if i == XMLFile:
                # If "content.xml" is truly present, we open it.
                # The result, "docOOoXML" is the content as text.
                docOOoXMLExist = 1
                strOOoXML = zip_file.read(XMLFile)
                zip_file.close()
                return strOOoXML

def listChildNodes(docOOoSXW, XMLFile, ooo_file_path, verbose):
    """Extract and parse Zip XML files for concat.
    """
    # Extract and parse XML file
    strXML = extractOooArchive(docOOoSXW, XMLFile)
    XMLparse = minidom.parseString(strXML)
    rootNode = XMLparse.documentElement
    vChildNodes = rootNode.childNodes
    # Images treatment
    if XMLFile == OOO_CONTENT_FILE_NAME:
        global dictImg, myZip, numImg, dictNamespace
        numImg = 0
        dictImg = {}
        dictNamespace = {}
        myZip = zipfile.ZipFile(docOOoSXW, 'r')
        # Creating the directory where the images will be dropped.
        # The exported OLE images go in this directory too.
        if not (os.path.exists(imgAbsDir)
                and os.path.isdir(imgAbsDir)):
            os.mkdir(imgAbsDir)
        if process_ole_objects:
            cmd = (('%s %s --target "%s" '
                    '--oooserverhost %s --oooserverport %s '
                    '--format %s "%s"')
                   % (
                ooopython_path,
                ole2img_script_path,
                imgAbsDir,
                oooserver_host, oooserver_port,
                ole_img_format, ooo_file_path))
            if verbose:
                print cmd
            os.system(cmd)
        replaceImageNode(vChildNodes)
        myZip.close()
    # Extract all root element's childs
    listChildElts = []
    for node in vChildNodes:
        if node.nodeType == node.ELEMENT_NODE:
            listChildElts.append(node)
    return listChildElts


def replaceImageNode(vChildNodes):
    """Replace the incorporated images links by the new images links
    and extract and copy all incorporated images.
    XXX: Why renaming images (apart from making their path relative)?
    Please add comment if you know.
    """
    global numImg
    for node in vChildNodes:
        if node.nodeName == 'draw:image':
            hRefValue = node.attributes['xlink:href'].value
            if find(hRefValue, 'Pictures/', 0) != -1:
                nameImgOld = os.path.split(hRefValue)[1]

                # XXX: What is this block for? Please add comment if you know.
                if dictImg.has_key(nameImgOld):
                    node.attributes['xlink:href'].value = dictImg[nameImgOld]
                else:
                    extImg = os.path.splitext(nameImgOld)[1]
                    numImg += 1
                    nameImgNew = imgRootName + "%03i" % numImg + extImg
                    hrefImgNew = os.path.join(imgRelDir, nameImgNew)
                    pathImgNew = os.path.join(imgAbsDir, nameImgNew)
                    if hRefValue.startswith('#'):
                        # OOo 1
                        pathImgZip = hRefValue[1:]
                    else:
                        # OOo 2
                        pathImgZip = hRefValue
                    zipImg = myZip.read(pathImgZip)
                    if os.path.isfile(pathImgNew) and rewriteImg:
                        os.remove(pathImgNew)
                    if not os.path.isfile(pathImgNew):
                        imgNew = open(pathImgNew, 'wb')
                        imgNew.write(zipImg)
                        imgNew.close()
                    dictImg[nameImgOld] = hrefImgNew
                    node.attributes['xlink:href'].value = dictImg[nameImgOld]
            else:
                pass

        # XXX: What is this block for? Please add comment if you know.
        if node.hasChildNodes():
            wChilNodes = node.childNodes
            replaceImageNode(wChilNodes)


def getGlobalRootHead(sourcefile, XMLFile):

  strXML = extractOooArchive(docOOoSXW, XMLFile)
  XMLparse = minidom.parseString(strXML)
  rootNode = XMLparse.documentElement

  if rootNode.attributes['xmlns:office'].value == 'http://openoffice.org/2000/office':
      oooVersion = 'ooo1'
  elif rootNode.attributes['xmlns:office'].value == 'urn:oasis:names:tc:opendocument:xmlns:office:1.0':
      oooVersion = 'ooo2'

  if oooVersion == 'ooo1':
    # OpenOffice.org 1.x
    globalRootHead = """\
<?xml version="1.0" encoding="UTF-8"?>

<office:document xmlns:office="http://openoffice.org/2000/office"
                 xmlns:style="http://openoffice.org/2000/style"
                 xmlns:text="http://openoffice.org/2000/text"
                 xmlns:table="http://openoffice.org/2000/table"
                 xmlns:draw="http://openoffice.org/2000/drawing"
                 xmlns:fo="http://www.w3.org/1999/XSL/Format"
                 xmlns:xlink="http://www.w3.org/1999/xlink"
                 xmlns:number="http://openoffice.org/2000/datastyle"
                 xmlns:svg="http://www.w3.org/2000/svg"
                 xmlns:chart="http://openoffice.org/2000/chart"
                 xmlns:dr3d="http://openoffice.org/2000/dr3d"
                 xmlns:math="http://www.w3.org/1998/Math/MathML"
                 xmlns:form="http://openoffice.org/2000/form"
                 xmlns:script="http://openoffice.org/2000/script"
                 xmlns:dc="http://purl.org/dc/elements/1.1/"
                 xmlns:meta="http://openoffice.org/2000/meta"
                 office:class="text"
                 office:version="1.0">
"""

  elif oooVersion == 'ooo2':
    # OpenOffice.org 2.x - OpenDocument
    globalRootHead = """\
<?xml version="1.0" encoding="UTF-8"?>
<office:document
xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
 xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
 xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
 xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
 xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
 xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"
 xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0"
 xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
 xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0"
 xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0"
 xmlns:math="http://www.w3.org/1998/Math/MathML"
 xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0"
 xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0"
 xmlns:ooo="http://openoffice.org/2004/office"
 xmlns:ooow="http://openoffice.org/2004/writer"
 xmlns:oooc="http://openoffice.org/2004/calc"
 xmlns:dom="http://www.w3.org/2001/xml-events" 
 xmlns:xforms="http://www.w3.org/2002/xforms"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns:rpt="http://openoffice.org/2005/report"
 xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2"
 xmlns:xhtml="http://www.w3.org/1999/xhtml"
 xmlns:grddl="http://www.w3.org/2003/g/data-view#"
 xmlns:officeooo="http://openoffice.org/2009/office" 
 xmlns:tableooo="http://openoffice.org/2009/table"
 xmlns:drawooo="http://openoffice.org/2010/draw"
 xmlns:calcext="urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0"
 xmlns:loext="urn:org:documentfoundation:names:experimental:office:xmlns:loext:1.0"
 xmlns:field="urn:openoffice:names:experimental:ooo-ms-interop:xmlns:field:1.0" 
 xmlns:formx="urn:openoffice:names:experimental:ooxml-odf-interop:xmlns:form:1.0"
 xmlns:css3t="http://www.w3.org/TR/css3-text/"
 office:version="1.2">
"""

  globalRootFoot = """\
</office:document>
"""


  return globalRootHead, globalRootFoot, oooVersion

def createGlobalXML(globalFile, ooo_file_path, verbose):
    """
    Create a global XML file by concatening the different XML files contained
    within a .sxw OOo file (meta.xml, styles.xml, content.xml).
    """
    # First let's delete any previous images directory, because if we don't
    # delete it there might be a previous directory with content in it and we
    # don't want to get this unrequested content in a generated archive.
    if os.path.exists(imgAbsDir):
        shutil.rmtree(imgAbsDir)

    globalRootHead, globalRootFoot, oooVersion = getGlobalRootHead(docOOoSXW,
                                                                   OOO_META_FILE_NAME)
    globalRootStr = globalRootHead + globalRootFoot

    globalStrParse = minidom.parseString(globalRootStr)
    globalRoot = globalStrParse.documentElement
    metaListElts = listChildNodes(docOOoSXW, OOO_META_FILE_NAME, ooo_file_path, verbose)
    stylesListElts = listChildNodes(docOOoSXW, OOO_STYLES_FILE_NAME, ooo_file_path, verbose)
    contentListElts = listChildNodes(docOOoSXW, OOO_CONTENT_FILE_NAME, ooo_file_path, verbose)
    globalListElts = metaListElts + stylesListElts + contentListElts
    for node in globalListElts:
        globalRoot.appendChild(node)
    strXML = globalRoot.toxml()
    listLine = split(strXML, '\n')[1:]
    strXMLNS = join([globalRootHead, join(listLine, u"\n")], u"\n")
    fileXML = codecs.open(globalFile, 'w', 'utf-8')
    fileXML.write(strXMLNS)
    fileXML.close()

    return oooVersion


def tempFilesDelete(deltemp):
    if deltemp == 1:
        os.remove(globalXML)


def getXsltCommand(input_file_path, output_file_path, stylesheet, verbose):
    """Return the actual XSLT processing command.
    """
    global XSLCmdTemplate
    cmd = XSLCmdTemplate
    gListVar = ['%o', '%i', '%s', '%p', '%y', '%v']
    listVar = []
    for var in gListVar:
        if find(cmd, var) != -1:
            listVar.append(var)
    for var in listVar:
        varSplit = split(cmd, var)
        if var == '%o':
            # Note that the file path has to be protected by "" in case it
            # contains special characters such as spaces.
            varSplit = '%s"%s"%s' % (varSplit[0], toUnicode(output_file_path), varSplit[1])
        elif var == '%i':
            # Note that the file path has to be protected by "" in case it
            # contains special characters such as spaces.
            varSplit = '%s"%s"%s' % (varSplit[0], toUnicode(input_file_path), varSplit[1])
        elif var == '%s':
            varSplit = '%s"%s"%s' % (varSplit[0], stylesheet, varSplit[1])
        elif var == '%p':
            varSplit = '%s%s%s' % (varSplit[0], dtdPublic, varSplit[1])
        elif var == '%y':
            varSplit = '%s%s%s' % (varSplit[0], dtdSystem, varSplit[1])
        elif var == '%v':
            varSplit = '%s%s%s' % (varSplit[0], XSLParams, varSplit[1])
        cmd = join(varSplit, '')
    if verbose:
        print cmd
    return cmd.encode(preferred_encoding)


def toUnicode(s):
    return unicode(s, preferred_encoding)


def o2dConvert(input, output, stylesheet, verbose):
    """Generic conversion.
    """
    startTime = time.time()
    os.system(getXsltCommand(input, output, stylesheet,verbose))
    endTime = time.time()
    duration = round(endTime - startTime, 2)

# Generic conversion changed by te
def o2dConvert2(input, output, stylesheet, xslParams):
	startTime = time.time()
	os.system(getXsltCommand(xslParams,input, output, stylesheet,verbose))
	endTime = time.time()
	duree = round(endTime - startTime, 2)
	print "       ==>", duree, "sec."


# -------------
# User commands
# -------------

def createDocbookArchive(zipfile_target):
    pjoin = os.path.join
    psplit = os.path.split
    psplitext = os.path.splitext
    pbasename = os.path.basename

    arch_dest_dir = psplit(zipfile_target)[0]
    arch_top_dir = psplitext(pbasename(zipfile_target))[0]
    arch_path = pjoin(arch_dest_dir, arch_top_dir + '.zip')
    arch = zipfile.ZipFile(arch_path, 'w', zipfile.ZIP_DEFLATED)
    docbook_fname = pbasename(docbookXML)
    docbook_path_in_arch = pjoin(arch_top_dir, docbook_fname)
    # ZIP entries paths are stored in "code page 437" encoding (cp437).
    # One cannot use UTF-8 for the ZIP entries paths.
    docbook_path_in_arch_enc = toUnicode(docbook_path_in_arch).encode(ZIP_FILE_ENCODING)
    arch.write(docbookXML, docbook_path_in_arch_enc)
    # Adding in the arch the images contained in the original OOo arch
    if os.path.exists(imgAbsDir):
        for img_name in os.listdir(imgAbsDir):
            img_path = pjoin(imgAbsDir, img_name)
            img_path_in_arch = pjoin(arch_top_dir, 'images', img_name)
            # ZIP entries paths are stored in "code page 437" encoding (cp437).
            # One cannot use UTF-8 for the ZIP entries paths.
            img_path_in_arch_enc = img_path_in_arch.encode(ZIP_FILE_ENCODING)
            arch.write(img_path, img_path_in_arch_enc)
    arch.close()
    # Remove created DocBook XML and subobjects, if any
    os.remove(docbookXML)
    if os.path.exists(imgAbsDir):
        shutil.rmtree(imgAbsDir)

# Free XSL conversion
def convert2(xmlinput=None,
            command=None,
            file_output=None,
            imagesrew=1,
            deltemp=1,
            dtd=None,
            conf_file_path=None,
            xslt_file_path=None,
            xslParams=None,
            verbose=False,
            zipfile_target=False,
            docbook_top_element='book',
            process_ole_objects=False,
            docbookXSL=None,
            ):
	print """
OOo2sDBK - Free conversion
--------------------------
"""
	print "Run conversion..."
	print "   1 - Initialization"
	startTime = time.time()
	#initializeSets(input, output, command, 0, 0, 0, xslParams)

	initializeSets(xmlinput, file_output, command, imagesrew,
                   deltemp, dtd, conf_file_path, xslt_file_path, xslParams,
                   verbose)

	endTime = time.time()
	duree = round(endTime - startTime, 2)
	print "       - Input file :", xmlinput
	print "       - Stylesheet :", xslt_file_path
	print "       - Output file :", file_output,"\n"
	print "       - top element is      : %s" % docbook_top_element
	print "       - current dir is:", os.getcwd()
	print "       ==>", duree, "sec."
	print "   2 - Conversion"

	o2dConvert(xmlinput, file_output, xslt_file_path,verbose)
        #o2dConvert(globalXML, docbookXML, docbookXSL, verbose)
	print "Conversion completed"

def convert(ooo_file_path,
            command=None,
            docbook_file_path=None,
            imagesrew=1,
            deltemp=1,
            dtd=None,
            conf_file_path=None,
            xslt_file_path=None,
            xslParams=None,
            verbose=False,
            zipfile_target=False,
            docbook_top_element='book',
            process_ole_objects=False,
            docbookXSL=None,
            ):
    """Convert OpenOffice.org Writer file to DocBook XML.
    """
    startTime = time.time()

    if verbose:
        print "   1 - Command line options"
        print "       - OOo2DBK config file : %s" % conf_file_path
        print "       - OpenOffice.org file : %s" % ooo_file_path
        print "       - DocBook file        : %s" % docbook_file_path
        print "       - top element is      : %s" % docbook_top_element
        print "       - process OLE objects : %s" % process_ole_objects

    initializeSets(ooo_file_path, docbook_file_path, command, imagesrew,
                   deltemp, dtd, conf_file_path, xslt_file_path, xslParams,
                   verbose)

    ooo_file_path = toUnicode(ooo_file_path)
    if docbook_file_path is not None:
        docbook_file_path = toUnicode(docbook_file_path)
    if xslt_file_path is not None:
        xslt_file_path = toUnicode(xslt_file_path)

    endTime = time.time()
    duration = round(endTime - startTime, 2)

    if verbose:
        print "       ==>", duration, "sec.\n"
        print "   2 - Unzip and concat OpenOffice.org XML files"

    startTime = time.time()

    oooVersion = createGlobalXML(globalXML, ooo_file_path, verbose)

    endTime = time.time()
    duration = round(endTime - startTime, 2)

    if verbose:
        print "       - Detected file format: %s" % (oooVersion)
        print "       ==>", duration, "sec.\n"
        print "   3 - Initialization (configuration file and computed options)"

    if docbookXSL is None:
        # Get XSLT file to use from configuration file
        docbookXSL = getXSLfile(oooVersion)

    if verbose:
        global configXML
        print "       - preferred encoding       : %s" % preferred_encoding
        print "       - OOo2DBK config file      : %s" % configXML
        print "       - XSLT file                : %s" % docbookXSL
        print "       - OpenOffice.org file path : %s" % docOOoSXW
        print "       - DocBook file path        : %s" % docbookXML
        if process_ole_objects:
            print "       - oooserver host            : %s" % oooserver_host
            print "       - oooserver port            : %s" % oooserver_port
            print "       - exported OLE image format : %s" % ole_img_format
            print "       - OOo Python path: %s" % ooopython_path
        print "\n   4 - DocBook file creation"

    startTime = time.time()
    o2dConvert(globalXML, docbookXML, docbookXSL, verbose)

    tempFilesDelete(deltemp)
    endTime = time.time()
    duration = round(endTime - startTime, 2)
    if verbose:
        print "       ==>", duration, "sec.\n"
        print "Conversion completed\n"

    if zipfile_target:
        createDocbookArchive(zipfile_target)
        if verbose:
            print "Zip archive created\n"

# Shell conversion
if __name__ == "__main__":
    execArgs()
