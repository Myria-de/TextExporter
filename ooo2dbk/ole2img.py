#!/usr/bin/python
# Copyright (c) 2004-2005 Nuxeo SARL <http://nuxeo.com>
# Authors:
# Laurent Godard <lgodard@indesko.com>
# M.-A. Darche (Nuxeo)
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

# UNO
import uno, unohelper
from com.sun.star.beans import PropertyValue
from com.sun.star.connection import NoConnectException

import sys
import getopt
import os.path
from os import sep
from os import remove
import time

VERSION = '0.6'

#filter parameters
FILTER_PARAMS = {
    'png': ('.png', 'image/png'),
    'svg': ('.svg', 'image/svg+xml'),
    'jpg': ('.jpg', 'image/jpeg'),
    'tiff': ('.tiff', 'image/tiff'),
    'eps': ('.eps', 'application/postscript'),
    'bmp-ms': ('.bmp', 'image/x-MS-bmp'),
    'bmp-portable': ('.bmp', 'image/x-portable-bitmap'),
    'gif': ('.gif', 'image/gif'),
    }


def usage():
    lst_formats = str(FILTER_PARAMS.keys())
    print "usage: ole2img [options] openoffice.org-file"
    print
    print "options:"
    print "  --target    target directory (mandatory)"
    print "  --oooserverhost the name of server running OpenOffice.org (defaults to localhost)"
    print "  --oooserverport the port of the server running OpenOffice.org (defaults to 2002)"
    print "  --format    exported image format (defaults to png)"
    print "              %s" % lst_formats.replace("'","")
    print "  --version   show version and exit"
    print "  --help      show this help message and exit"
    print
    print "Example:"
    print "~/OpenOffice.org1.1.2/program/python ole2img --format png --target ~/outputdir/ ~/exampleFile.sxw"
    print
    print "OpenOffice.org must run in listen mode"
    print './soffice "-accept=socket,host=localhost,port=2002;urp;"'


def version():
    print "Converts all OLE objects of a .sxw OpenOffice.org document as images in a target directory"
    print "ole2img version: " + VERSION


def exec_args():
    """Analyze command line arguments.
    """
    source = None
    target = None
    # Default server having running OpenOffice.org instance(s) is localhost
    oooserver_host = 'localhost'
    oooserver_port = '2002'
    # Default format is PNG
    format = 'png'
    try:
        opts, args = getopt.getopt(sys.argv[1:], '',
                                   ['target=',
                                    'oooserverhost=',
                                    'oooserverport=',
                                    'format=',
                                    'version', 'help'])
    except:
        usage()
        # Command line syntax errors return the error code "2"
        sys.exit(2)

    if len(args) == 1:
        source = args[0]

    for opt in opts:
        if opt[0] == '--target':
            target = opt[1]
        elif opt[0] == '--oooserverhost':
            oooserver_host = opt[1]
        elif opt[0] == '--oooserverport':
            oooserver_port = opt[1]
        elif opt[0] == '--format':
            format = opt[1]
        elif opt[0] == '--version':
            version()
            sys.exit(0)
        elif opt[0] == '--help':
            usage()
            sys.exit(0)
    error = False

    if source == None:
        error = True
        print "\nOne and only one OpenOffice.org file must be given"
    else:
        source = os.path.abspath(os.path.expanduser(source))
        if not os.path.isfile(source):
            error = True
            print "\n--source Invalid file"

    if target == None:
        error = True
        print "\n--target Missing Parameter"
    else:
        target = os.path.abspath(os.path.expanduser(target))
        if not os.path.isdir(target):
            error = True
            print "\n--target Invalid directory"

    if not FILTER_PARAMS.has_key(format):
        error = True
        print "\n--format Undefined value"

    if error:
        usage()
        # Command line syntax errors return the error code "2"
        sys.exit(2)

    #add Os separator if missing to target
    if target[len(target) - 1] != os.sep:
        target += os.sep

    return source, target, oooserver_host, oooserver_port, format


def ole2img(source, target,
            oooserver_host='localhost', oooserver_port='2002', format='png'):
    #fileter parameters
    extension, theFilter = FILTER_PARAMS[format]

    #Connect to OOo

    # get the uno component context from the PyUNO runtime
    localContext = uno.getComponentContext()
    # create the UnoUrlResolver
    resolver = localContext.ServiceManager.createInstanceWithContext(
                                'com.sun.star.bridge.UnoUrlResolver', localContext )

    # connect to the running office
    try:
        print "Connecting to server %s:%s ..." % (oooserver_host, oooserver_port)
        ctx = resolver.resolve(
            'uno:socket,host=%s,port=%s;urp;StarOffice.ComponentContext'
            % (oooserver_host, oooserver_port))
    except NoConnectException:
        print "Unable to connect to OpenOffice.org instance"
        sys.exit(1)

    smgr = ctx.ServiceManager

    # get the central desktop object
    desktop = smgr.createInstanceWithContext('com.sun.star.frame.Desktop', ctx)

    # Now connected to OOo

    # load source file
    args = (PropertyValue('Hidden', 0, True, 0),)
    url = unohelper.systemPathToFileUrl(source)
    sourceDoc = desktop.loadComponentFromURL(url, '_blank', 0, args)

    # Hack/Bug : Needed to sanitize the object hierarchy for use with CurrentController
    url = unohelper.systemPathToFileUrl(target + 'temp.sxw')
    sourceDoc.storeToURL(url,())
    os.remove(target + 'temp.sxw')

    oGraphic=smgr.createInstanceWithContext(
                            'com.sun.star.drawing.GraphicExportFilter', ctx)

    #dispatcher for copy-paste
    dispatcher = smgr.createInstanceWithContext(
                    'com.sun.star.frame.DispatchHelper', ctx)

    #creates an hidden draw docuement
    args = (PropertyValue('Hidden', 0, True, 0),)
    url = 'private:factory/sdraw'
    drawDoc = desktop.loadComponentFromURL(url, '_blank', 0, args)

    theOleObjects = sourceDoc.EmbeddedObjects

    for i in range(theOleObjects.Count):
        oleObject = theOleObjects.getByIndex(i)
        print oleObject.Name
        # Selection
        sourceDoc.CurrentController.select(oleObject)

        # XXX : OOo
        # strange random bug on importing documents from previous OOo version
        # sometimes the current object may not be selected
        # the selection remains on the previous in the loop

        # May be not needed any more as done previously ?

        # Verify the selection is ok
        obj = sourceDoc.CurrentController.getSelection()
        if obj.Name != oleObject.Name:
            # Save the file and select again the object
            # Updates the object and the can be selected
            url = unohelper.systemPathToFileUrl(target + 'temp.sxw')
            sourceDoc.storeToURL(url,())
            os.remove(target + 'temp.sxw')
            sourceDoc.CurrentController.select(theOleObjects.getByIndex(i))
            obj = sourceDoc.CurrentController.Selection

        # if the previous did not work
        # creates an image telling a problem occured
        if obj.Name != oleObject.Name:
            print "unable to process " + oleObject.Name
            drawingShape = drawDoc.createInstance("com.sun.star.drawing.TextShape")
            theSapeSize = drawingShape.Size
            drawDoc.DrawPages.getByIndex(0).add(drawingShape)
            theSapeSize.Width = 5000
            theSapeSize.Height = 2500
            drawingShape.setSize(theSapeSize)
            drawingShape.String = oleObject.Name + " - Unable to process OLE object"
            drawingShape.CharColor = 255
            drawingShape.CharHeight = 8
            objDraw = drawingShape
        else:
        # Normal behaviour
            # Copy
            dispatcher.executeDispatch(sourceDoc.CurrentController.Frame,
                                       '.uno:Copy',
                                       '',
                                       0,
                                       ())
            # Paste into draw
            dispatcher.executeDispatch(drawDoc.CurrentController.Frame,
                                       '.uno:Paste',
                                       '',
                                       0,
                                       ())

            # get draw object
            objDraw = drawDoc.CurrentController.Selection

            # Export
            oGraphic.setSourceDocument(objDraw)
            url = unohelper.systemPathToFileUrl(target + oleObject.Name + extension)
            argsExport = (PropertyValue('URL' , 0 , url, 0 ),
                          PropertyValue('MediaType' , 0 , theFilter, 0 ))
            oGraphic.filter(argsExport)

    # Close files
    drawDoc.close(True)
    sourceDoc.close(True)


# Shell access
if __name__ == "__main__":
    startTime = time.time()
    source, target, oooserver_host, oooserver_port, format = exec_args()
    print "Exporting into %s format to target %s..." % (format, target)
    ole2img(source, target, oooserver_host, oooserver_port, format)
    endTime = time.time()
    duration = round(endTime - startTime, 2)
    print 'duration : %s sec' % duration
