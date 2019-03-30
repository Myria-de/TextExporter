<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:d="http://docbook.org/ns/docbook"
xmlns:exsl="http://exslt.org/common"
  xmlns="http://www.w3.org/1999/xhtml"
  xmlns:stbl="http://nwalsh.com/xslt/ext/com.nwalsh.saxon.Table"
  xmlns:xtbl="xalan://com.nwalsh.xalan.Table"
  xmlns:lxslt="http://xml.apache.org/xslt"
  xmlns:ptbl="http://nwalsh.com/xslt/ext/xsltproc/python/Table"
  exclude-result-prefixes="exsl stbl xtbl lxslt ptbl d"
  version="1.0">

<xsl:import href="xhtml5/docbook.xsl"/>
<xsl:output
        method="xml" indent="yes" encoding="UTF-8" omit-xml-declaration="yes"
    />


<xsl:template name="user.head.content">
<xsl:param name="node" select="."/>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</xsl:template>

			
<xsl:param name="formal.title.placement">
figure after
example before
equation before
table before
procedure before
</xsl:param>


</xsl:stylesheet> 
