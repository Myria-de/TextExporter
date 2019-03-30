<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY nbsp "&#160;">
]>
<!--
Copyright (c) 2004-2006 Nuxeo SARL <http://nuxeo.com>
Copyright (c) 2003 Stefan Rinke <stefan@stefan-rinke.de>
Copyright (c) 2002 Eric Bellot <ebellot@netcourrier.com>

Authors:
M.-A. Darche (Nuxeo)
Stefan Rinke <stefan@stefan-rinke.de>
Eric Bellot <ebellot@netcourrier.com>
Laurent Godard <lgodard@indesko.com>
Maurice TARDELLI - CERTU/SYS/ITS <Maurice.Tardelli@equipement.gouv.fr> for ODF

This script is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

See ``COPYING`` for more information.

$Id: ooo2dbk.xsl 28486 2005-10-21 13:10:18Z madarche $
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:office= "urn:oasis:names:tc:opendocument:xmlns:office:1.0" 
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
  exclude-result-prefixes="office style text table draw
  fo xlink number svg chart dr3d math form script dc meta ooo ooow oooc dom xforms xsd xsi">

  <xsl:output method="xml" indent="yes" omit-xml-declaration="no" encoding="UTF-8"
    doctype-public="-//OASIS//DTD DocBook XML V4.4//EN" doctype-system="http://www.oasis-open.org/docbook/xml/4.4/docbookx.dtd"/>
	

<!-- doctype-system="docbookx.dtd"/> -->
    
    
  <!--
doctype-system="http://www.oasis-open.org/docbook/xml/4.4/docbookx.dtd"/>
  Parameter used to determine which top element the resulting tree will have.
  This parameter can be overridden by passing a parameter to the XSLT processor.
  Supported DocBook top elements are: article, book.
  It defaults to "article".
  -->
<xsl:param name="topElementName">book</xsl:param>
<xsl:param name="topElementMetainfoName">
    <xsl:value-of select="concat($topElementName, 'info')"/>
</xsl:param>

<!-- Which unit to use -->
<xsl:param name="measureUnit">
    <xsl:choose>
        <xsl:when test="//table:table">
            <xsl:call-template name="measureUnit"/>
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="'unknown'"/>
        </xsl:otherwise>
    </xsl:choose>
</xsl:param>
  
<xsl:variable name="oooGenerator" select="/office:document/office:meta/meta:generator"/>
<xsl:variable name="oooVersion">
    <xsl:value-of select="substring-before(substring-after($oooGenerator, 'org/'), ' ')"/>
</xsl:variable>

<xsl:template name="measureUnit">
    <xsl:param name="firstValue" select="//style:page-layout-properties[1]/@fo:page-width"/>
    <xsl:if test="contains(string($firstValue), 'mm')">
      <xsl:value-of select="'mm'"/>
    </xsl:if>
    <xsl:if test="contains(string($firstValue), 'cm')">
      <xsl:value-of select="'cm'"/>
    </xsl:if>
    <xsl:if test="contains(string($firstValue), 'inch')">
      <xsl:value-of select="'inch'"/>
    </xsl:if>
    <xsl:if test="contains(string($firstValue), 'pi')">
      <xsl:value-of select="'pi'"/>
    </xsl:if>
    <xsl:if test="contains(string($firstValue), 'pt')">
      <xsl:value-of select="'pt'"/>
    </xsl:if>
    <xsl:if test="contains(string($firstValue), '%')">
      <xsl:value-of select="'%'"/>
    </xsl:if>
  </xsl:template>

  <!--
  When called with the right parameters this template ouputs a
  processing-instruction specifying the print-orientation for the element that
  has the given style.

  Examples:
  <?print-orientation portrait?>
  <?print-orientation landscape?>

  Details given in the getPrintOrientation template.
  -->
  <xsl:template name="outputPrintOrientation">
    <!-- Mandatory param -->
    <xsl:param name="styleName"/>
    <!-- Optional param -->
    <xsl:param name="parentStyleName" select="''"/>

    <xsl:variable name="printOrientation">
      <xsl:call-template name="getPrintOrientation">
	<xsl:with-param name="styleName" select="$styleName"/>
	<xsl:with-param name="parentStyleName" select="$parentStyleName"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="string($printOrientation)">
      <xsl:processing-instruction name="print-orientation">
	<xsl:value-of select="$printOrientation"/>
      </xsl:processing-instruction>
    </xsl:if>
  </xsl:template>


  <!--
  Return a string of styles having page orientation information.
  Example of output of this template:
  P1,portrait;P9,portrait;P14,portrait;P19,landscape;P20,landscape;P21,portrait;
  -->
  <xsl:variable name="styleNamesPrintOrientations">
    <xsl:for-each select="/office:document/office:automatic-styles/style:page-layout">
      <xsl:variable name="printOrientation" select="style:page-layout-properties/@style:print-orientation"/>
      <xsl:variable name="pageMasterName" select="@style:name"/>

        <!--<DEBUG><xsl:value-of select="$printOrientation"/></DEBUG>
        <DEBUG><xsl:value-of select="$pageMasterName"/></DEBUG> -->

      <xsl:for-each select="//style:master-page[@style:page-layout-name = $pageMasterName]">
            <xsl:variable name="masterPageName" select="@style:name"/>
            <!--<DEBUG><xsl:value-of select="$masterPageName"/></DEBUG>-->

            <xsl:for-each select="//style:style[@style:master-page-name = $masterPageName]">
                <xsl:value-of select="concat(@style:name, ',')"/>
                <xsl:value-of select="concat($printOrientation, ';')"/>
            </xsl:for-each>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:variable>

  <!--
  When called with the right parameters this template returns the
  print-orientation for the element that has the given style.

  Details:
  The style given to this template should be used the style of a text:h element
  used for defining a part (not in the DocBook or OOo sense) of the OOo
  document. So for example the style could be the one of the title (text:h) of
  the main content or an appendix.

  How it works:
  1. It looks for the page corresponding to the style:master-page-name of the
     given style (contained in the styles.xml file).
  2. It looks for the print-orientation of the page.
  -->
  <xsl:template name="getPrintOrientation">
    <!-- Mandatory param -->
    <xsl:param name="styleName"/>
    <!-- Optional param -->
    <xsl:param name="parentStyleName" select="''"/>
    
    <!-- Implementation finding print-orientation from precomputed list -->
    <xsl:value-of select="substring-before(
      substring-after($styleNamesPrintOrientations, concat($styleName, ',')),
      ';')"/>
    <xsl:if test="string($parentStyleName)">
      <xsl:value-of select="substring-before(
	substring-after($styleNamesPrintOrientations, concat($parentStyleName, ',')),
	';')"/>
    </xsl:if>

    <!-- Implementation finding print-orientation dynamically -->
    <!--
    <xsl:for-each select="//style:style[@style:name = $styleName]">
      <xsl:variable name="masterPageName" select="@style:master-page-name"/>
      <xsl:for-each select="//style:master-page[@style:name = $masterPageName]">
	<xsl:variable name="pageMasterName" select="@style:page-master-name"/>
	<xsl:for-each select="//style:page-master[@style:name = $pageMasterName]">
	  <xsl:value-of select="style:properties/@style:print-orientation"/>
	</xsl:for-each>
      </xsl:for-each>
    </xsl:for-each>
    -->
  </xsl:template>

  <!--
  =============
  DOCUMENT ROOT
  =============
  -->
  <xsl:template match="/">
    <xsl:element name="{$topElementName}">
      <xsl:attribute name="lang">
	   <xsl:text>de</xsl:text>
	<!--<xsl:value-of select="/office:document/office:meta/dc:language"/>-->
	
	
      </xsl:attribute>

      <xsl:processing-instruction name="ooogenerator">
	<xsl:value-of select="$oooGenerator"/>
      </xsl:processing-instruction>
      <xsl:processing-instruction name="oooversion">
	<xsl:value-of select="$oooVersion"/>
      </xsl:processing-instruction>

<!--
    <DEBUG><xsl:value-of select="$measureUnit"/></DEBUG>
    <DEBUG><xsl:value-of select="$styleNamesPrintOrientations"/></DEBUG>
-->
    <xsl:call-template name="metaInfo"/>

      <!--
      Only books can have preface elements.
      A book might have both a Foreword and an Introduction.
      Both should be tagged as preface.
      -->
    <xsl:if test="$topElementName='book'">
        <xsl:call-template name="preface"/>
    </xsl:if>

      <!-- We start with the first title of level 1 -->
      <xsl:choose>
        <xsl:when test="/office:document/office:body/office:text/text:h[@text:outline-level='1']">
            <xsl:apply-templates
            select="/office:document/office:body/office:text/text:h[@text:outline-level='1'][1]"
            mode="hierarchy">
            <xsl:with-param name="source" select="$topElementName"/>
            </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
            <xsl:apply-templates select="/office:document/office:body/office:text"
            mode="noHierarchy"/>
        </xsl:otherwise>
      </xsl:choose>

      <xsl:call-template name="appendix"/>
      <xsl:call-template name="bibliography"/>
      <xsl:call-template name="glossary"/>
      <xsl:call-template name="index"/>
    </xsl:element>
  </xsl:template>


  <!--
  =============================
  CHAPTER AND SECTION HIERARCHY
  =============================
  -->

  <xsl:template match="*|@*" name="hierarchy" mode="hierarchy">
    <!-- Specify which element calls this template (optional) -->
    <xsl:param name="source"/>
    <!-- Store the current depth level (1, 2, etc.) (optional) -->
    <xsl:param name="level" select="'0'"/>
    <!--
    Specify the id of the node you don't want to have in the result set
    (optional)
    -->
    <xsl:param name="excludeNodeId"/>

    <xsl:choose>

      <!-- If the matched element is not a title (text:h) -->
      <xsl:when test="name(.) != 'text:h'">
            <xsl:call-template name="allTags">
              <xsl:with-param name="source" select="'hierarchy'"/>
            </xsl:call-template>
            <xsl:apply-templates select="following-sibling::*[1]" mode="hierarchy">
              <xsl:with-param name="level" select="$level"/>
            </xsl:apply-templates>
      </xsl:when>

      <!-- If the matched element is a title (text:h)
      and is deeper (level) than the preceding title -->
      <xsl:when test="@text:outline-level > $level">

	<!--
	If we want to produce an article it is possible to have paras
	preceding the 1st title at level 1. We want to have those paras too
	when a preface or an appendix is encountered.
	So those instructions are used to display paras that could occur
	before any title is encountered.
	The only case when we don't want to have preceding paras is when the
	source is a book element, the source being the element calling the
	template, which means that a preface in a book can have paras before its
	first title, but chapters in a book cannot have paras before their
	first title.
	-->
	<xsl:if test="$source != 'book'
	  and count(preceding-sibling::text:h[@text:outline-level='1']) = 0">
	  <xsl:apply-templates select="preceding-sibling::*[
	    generate-id(.) != $excludeNodeId]" mode="noHierarchy"/>
	</xsl:if>

	<!--
	We construct a new section (sectn) and the content of the "h" source
	element is placed into the "title" output element.
	-->
	    <!-- Debug 
	    <level><xsl:value-of select="$level"/></level>
	    <source><xsl:value-of select="$source"/></source>-->

	<xsl:if test="$level >= 0">
	  <xsl:variable name="structuringElementName">
	    <xsl:choose>
	      <xsl:when test="$level=0 and $source='book'">
		<xsl:value-of select="'chapter'"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="'section'"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:variable>
	  <xsl:element name="{$structuringElementName}">

        <!-- rajout MT recherche si bookmark pour les titres et sections
                     si oui on met un id -->
	    <xsl:call-template name="GenereIdSection" select="/text:bookmark-start"/>
        <!-- fin rajout MT-->

	    <xsl:call-template name="outputPrintOrientation">
	      <xsl:with-param name="styleName" select="@text:style-name"/>
	    </xsl:call-template>
	    <title><xsl:apply-templates/></title>
	    <xsl:apply-templates select="following-sibling::*[1]" mode="hierarchy">
	      <xsl:with-param name="level" select="@text:outline-level"/>
	      <xsl:with-param name="source" select="$source"/>
	    </xsl:apply-templates>
	  </xsl:element>
	</xsl:if>

	<xsl:apply-templates select="following-sibling::*[1]" mode="scanLevel">
	  <xsl:with-param name="level" select="@text:outline-level"/>
	  <xsl:with-param name="source" select="$source"/>
	</xsl:apply-templates>

      </xsl:when>

    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="scanLevel">
    <xsl:param name="level" select="'0'"/>
    <xsl:param name="source"/>
    <xsl:choose>
      <xsl:when test="@text:outline-level &lt; $level"/>
      <xsl:when test="@text:outline-level = $level">
	<xsl:call-template name="hierarchy">
	  <xsl:with-param name="level" select="$level - 1"/>
	  <xsl:with-param name="source" select="$source"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="following-sibling::*[1]" mode="scanLevel">
	  <xsl:with-param name="level" select="$level"/>
	  <xsl:with-param name="source" select="$source"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/office:document/office:body/office:text" mode="noHierarchy">
    <xsl:apply-templates mode="noHierarchy"/>
  </xsl:template>

  <xsl:template match="*|@*" mode="noHierarchy">
    <xsl:call-template name="allTags"/>
  </xsl:template>

<xsl:template name="allTags">
    <xsl:param name="source"/>

    <xsl:choose>

        <xsl:when test="name(current())='text:h'">
            <xsl:choose>
                <xsl:when test="$source='hierarchy'"/>
            <xsl:otherwise>
                <para>ERROR: Title hierarchy is wrong, section title is in bad position.</para>
            </xsl:otherwise>
            </xsl:choose>
        </xsl:when>

        <xsl:when test="name(current())='text:p'">
            <xsl:call-template name="para">
                <xsl:with-param name="source" select="$source"/>
            </xsl:call-template>
        </xsl:when>

    <!-- Traitement des liste avec la version 2-->

        <xsl:when test="name(current())='text:list'">
            <xsl:call-template name="ListesV2"/>
        </xsl:when>


        <xsl:when test="name(current())='table:table'">
            <xsl:choose>
                <xsl:when test="$source='cellTable'">
                    <para>ERROR: Section title should not be in a cell.</para>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="table"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:when>

    </xsl:choose>
</xsl:template>


  <!--
  ========
  METAINFO
  ========
  -->

  <xsl:template match="/office:document/office:meta"/>
  <xsl:template match="text:p"/>

  <xsl:template name="metaInfo">
    <xsl:param name="bodyRootPara" select="/office:document/office:body/office:text/text:p"/>
    <xsl:element name="{$topElementMetainfoName}">
      <xsl:apply-templates select="$bodyRootPara" mode="metaInfo"/>
      <xsl:apply-templates select="/office:document/office:meta/dc:title"/>
      <xsl:apply-templates select="/office:document/office:meta/dc:date"/>
      <xsl:apply-templates select="/office:document/office:meta/dc:subject"/>
      <xsl:element name="keywordset">
        <xsl:apply-templates select="/office:document/office:meta/meta:keyword"/>
      </xsl:element>
      <xsl:call-template name="abstract"/>
      <xsl:call-template name="userFields"/>
    </xsl:element>
  </xsl:template>


  <xsl:template name="userFields">
    <xsl:call-template name="metainfoUserFields"/>
    <xsl:call-template name="authorUserFields"/>
    <xsl:call-template name="publisherUserFields"/>
    <xsl:call-template name="contractsponsorUserFields"/>
    <xsl:call-template name="conferenceUserFields"/>
  </xsl:template>


  <xsl:template name="metainfoUserFields">
    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
      text:user-field-decl[@office:string-value!=''
      and starts-with(@text:name, 'metainfo_')]">
      <xsl:if test="@text:name='metainfo_subtitle'">
            <subtitle>
              <xsl:value-of select="@office:string-value"/>
            </subtitle>
      </xsl:if>
      <xsl:if test="@text:name='metainfo_date'">
            <date>
              <xsl:value-of select="@office:string-value"/>
            </date>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_abstract'">
            <abstract>
              <para>
                <xsl:value-of select="@office:string-value"/>
              </para>
            </abstract>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_bibliomisc'">
            <bibliomisc>
              <xsl:value-of select="@office:string-value"/>
            </bibliomisc>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_volumenum'">
            <volumenum>
              <xsl:value-of select="@office:string-value"/>
            </volumenum>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_seriesvolnums'">
            <seriesvolnums>
              <xsl:value-of select="@office:string-value"/>
            </seriesvolnums>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_contractnum'">
            <contractnum>
              <xsl:value-of select="@office:string-value"/>
            </contractnum>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_isbn'">
            <biblioid class="isbn">
              <xsl:value-of select="@office:string-value"/>
            </biblioid>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_issn'">
            <biblioid class="issn">
              <xsl:value-of select="@office:string-value"/>
            </biblioid>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_isrn'">
            <biblioid class="isrn">
              <xsl:value-of select="@office:string-value"/>
            </biblioid>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="conferenceUserFields">
    <confgroup>
    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
      text:user-field-decl[@office:string-value!=''
      and starts-with(@text:name, 'metainfo_confgroup')]">
      <xsl:if test="@text:name='metainfo_confgroup_address'">
    <address>
      <xsl:value-of select="@office:string-value"/>
    </address>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_confgroup_confdates'">
    <confdates>
      <xsl:value-of select="@office:string-value"/>
    </confdates>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_confgroup_confnum'">
    <confnum>
      <xsl:value-of select="@office:string-value"/>
    </confnum>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_confgroup_confsponsor'">
    <confsponsor>
      <xsl:value-of select="@office:string-value"/>
    </confsponsor>
      </xsl:if>

      <xsl:if test="@text:name='metainfo_confgroup_conftitle'">
    <conftitle>
      <xsl:value-of select="@office:string-value"/>
    </conftitle>
      </xsl:if>

    </xsl:for-each>
    </confgroup>
  </xsl:template>

  <xsl:template name="authorUserFields">
    <!--
    Testing if there are authors to put in the authorgroup element because
    this element cannot be empty.
    XXX: Maybe there is way to optimize the treatments below where we test if
    there are some nodes (text:user-field-decl) and then look for those same
    nodes over again.
    -->
    <!-- tests if any author metadata exists -->
      <xsl:variable name="hasAuthor">
        <xsl:for-each select="/office:document/office:body/office:user-field-decls/text:user-field-decl[@text:string-value!=''
        and starts-with(@text:name, 'metainfo_author')]">
          <xsl:value-of select="@text:string-value"/>
        </xsl:for-each>
      </xsl:variable>

    <xsl:if test="string($hasAuthor)">
    <authorgroup>
      <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	text:user-field-decl[@office:string-value!=''
	and starts-with(@text:name, 'metainfo_author')
	and contains(@text:name, '_surname')]">
	<!-- Getting the "namexxx_" string -->
	<xsl:variable name="authorBase"
	  select="concat(substring-before(@text:name, '_'), '_',
                     substring-before(substring-after(@text:name, '_'), '_'), '_')"/>
	<author>
	  <xsl:variable name="firstname">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'firstname')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:if test="string($firstname)">
	    <firstname><xsl:value-of select="$firstname"/></firstname>
	  </xsl:if>

	  <xsl:variable name="surname">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'surname')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:if test="string($surname)">
	    <surname><xsl:value-of select="$surname"/></surname>
	  </xsl:if>

	  <xsl:variable name="honorific">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'honorific')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:if test="string($honorific)">
	    <honorific><xsl:value-of select="$honorific"/></honorific>
	  </xsl:if>

        <xsl:variable name="email">
            <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
            text:user-field-decl[@text:name=concat($authorBase, 'email')]">
            <xsl:value-of select="@office:string-value"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:if test="string($email)">
            <email><xsl:value-of select="$email"/></email>
        </xsl:if>

	  <xsl:variable name="orgabbrev">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'orgname_acronym')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>

	  <xsl:variable name="jobtitle">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'jobtitle')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>

	  <xsl:variable name="orgname">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'orgname')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:variable name="orgdiv">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'orgdiv')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:variable name="address">
	    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	      text:user-field-decl[@text:name=concat($authorBase, 'address')]">
	      <xsl:value-of select="@office:string-value"/>
	    </xsl:for-each>
	  </xsl:variable>
	  <xsl:if test="string($jobtitle)
	    or string($orgname) or string($orgdiv) or string($orgabbrev) or string($address)">
	    <affiliation>
	      <xsl:if test="string($orgabbrev)">
		<shortaffil role="orgabbrev"><xsl:value-of select="$orgabbrev"/></shortaffil>
	      </xsl:if>
	      <xsl:if test="string($jobtitle)">
		<jobtitle><xsl:value-of select="$jobtitle"/></jobtitle>
	      </xsl:if>
	      <xsl:if test="string($orgname)">
		<orgname><xsl:value-of select="$orgname"/></orgname>
	      </xsl:if>
	      <xsl:if test="string($orgdiv)">
		<orgdiv><xsl:value-of select="$orgdiv"/></orgdiv>
	      </xsl:if>
	      <xsl:if test="string($address)">
		<address><xsl:value-of select="$address"/></address>
	      </xsl:if>
	    </affiliation>
	  </xsl:if>
	</author>
      </xsl:for-each>
    </authorgroup>
   </xsl:if>
  </xsl:template>


  <xsl:template name="publisherUserFields">
    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
      text:user-field-decl[
      @office:string-value != ''
      and starts-with(@text:name, 'metainfo_corpauthor')
      and contains(@text:name, '_orgname')
      and substring-after(@text:name, '_orgname') = ''
      ]">
      <!-- Getting the "corpauthorxxx_" string -->
      <xsl:variable name="authorBase"
      select="concat(substring-before(@text:name, '_'), '_',
                     substring-before(substring-after(@text:name, '_'), '_'), '_')"/>
      <publisher>
	<xsl:variable name="name">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'orgname')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:if test="string($name)">
	  <publishername><xsl:value-of select="$name"/></publishername>
	</xsl:if>

	<!--
	Unused variable because there is no markup for this information
	in DocBook yet.
	-->
	<xsl:variable name="orgabbrev">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'orgname_acronym')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<!--
	Unused variable because there is no markup for this information
	in DocBook yet.
	-->
	<xsl:variable name="orgdiv">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'orgdiv')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>

	<xsl:variable name="street">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'address')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="pob">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'pob')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="postcode">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'postcode')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="city">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'city')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="state">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'state')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="phone">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'phone')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="fax">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'fax')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="email">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'email')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>
	<xsl:variable name="ulink">
	  <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
	    text:user-field-decl[@text:name=concat($authorBase, 'ulink')]">
	    <xsl:value-of select="@office:string-value"/>
	  </xsl:for-each>
	</xsl:variable>

	<xsl:if test="string($street) or string($pob) or string($postcode)
	  or string($city) or string($state)
	  or string($phone) or string($fax) or string($email) or string($ulink)">
	  <address>
	    <xsl:if test="string($street)">
	      <street><xsl:value-of select="$street"/></street>
	    </xsl:if>
	    <xsl:if test="string($pob)">
	      <pob><xsl:value-of select="$pob"/></pob>
	    </xsl:if>
	    <xsl:if test="string($postcode)">
	      <postcode><xsl:value-of select="$postcode"/></postcode>
	    </xsl:if>
	    <xsl:if test="string($city)">
	      <city><xsl:value-of select="$city"/></city>
	    </xsl:if>
	    <xsl:if test="string($state)">
	      <state><xsl:value-of select="$state"/></state>
	    </xsl:if>
	    <xsl:if test="string($phone)">
	      <phone><xsl:value-of select="$phone"/></phone>
	    </xsl:if>
	    <xsl:if test="string($fax)">
	      <fax><xsl:value-of select="$fax"/></fax>
	    </xsl:if>
	    <xsl:if test="string($email)">
	      <email><xsl:value-of select="$email"/></email>
	    </xsl:if>
	    <xsl:if test="string($ulink)">
	      <otheraddr>
		<ulink>
		  <xsl:attribute name="url">
		    <xsl:value-of select="$ulink"/>
		  </xsl:attribute>
		  <xsl:value-of select="$ulink"/>
		</ulink>
	      </otheraddr>
	    </xsl:if>
	  </address>
	</xsl:if>
      </publisher>
    </xsl:for-each>
  </xsl:template>


  <xsl:template name="contractsponsorUserFields">
    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
      text:user-field-decl[
      @office:string-value!=''
      and starts-with(@text:name, 'metainfo_contractsponsor')
      and contains(@text:name, '_orgname')
      and substring-after(@text:name, '_orgname') = ''
      ]">
      <!-- Getting the "contractsponsorxxx_" string -->
      <xsl:variable name="authorBase"
      select="concat(substring-before(@text:name, '_'), '_',
                     substring-before(substring-after(@text:name, '_'), '_'), '_')"/>
      <xsl:variable name="name">
    <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
      text:user-field-decl[@text:name=concat($authorBase, 'orgname')]">
      <xsl:value-of select="@office:string-value"/>
    </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="street">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'address')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pob">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'pob')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="postcode">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'postcode')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="city">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'city')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="state">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'state')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="phone">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'phone')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="fax">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'fax')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="email">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'email')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="ulink">
        <xsl:for-each select="/office:document/office:body/office:text/text:user-field-decls/
          text:user-field-decl[@text:name=concat($authorBase, 'ulink')]">
          <xsl:value-of select="@office:string-value"/>
        </xsl:for-each>
      </xsl:variable>

      <contractsponsor>
        <xsl:value-of select="$name"/>
        <xsl:if test="string($street) or string($pob) or string($postcode)
          or string($city) or string($state)
          or string($phone) or string($fax) or string($email) or string($ulink)">
          <xsl:comment>Address</xsl:comment>
        </xsl:if>
        <xsl:if test="string($street)">
          <xsl:processing-instruction name="street">
            <xsl:value-of select="$street"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($pob)">
          <xsl:processing-instruction name="pob">
            <xsl:value-of select="$pob"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($postcode)">
          <xsl:processing-instruction name="postcode">
            <xsl:value-of select="$postcode"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($city)">
          <xsl:processing-instruction name="city">
            <xsl:value-of select="$city"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($state)">
          <xsl:processing-instruction name="state">
            <xsl:value-of select="$state"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($phone)">
          <xsl:processing-instruction name="phone">
            <xsl:value-of select="$phone"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($fax)">
          <xsl:processing-instruction name="fax">
            <xsl:value-of select="$fax"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($email)">
          <xsl:processing-instruction name="email">
            <xsl:value-of select="$email"/>
          </xsl:processing-instruction>
        </xsl:if>
        <xsl:if test="string($ulink)">
          <xsl:processing-instruction name="ulink">
            <xsl:value-of select="$ulink"/>
          </xsl:processing-instruction>
        </xsl:if>
      </contractsponsor>
    </xsl:for-each>
  </xsl:template>


  <xsl:template name="keywordsetContent">
    <!--
    keywordsString is a string of coma separated keywords
    Spaces can appear before or after the comas.
    A so called keyword can contain spaces.
    Examples:
    keywordsString = "aaa, bbb, ccc"
    keywordsString = "aaa  ,  bbb  ,ccc"
    keywordsString = "a aa, b bb, ccc"
    keywordsString = "a aa  ,  b bb  ,ccc"
    -->
    <xsl:param name="keywordsString"/>
    <xsl:if test="$keywordsString">
      <xsl:choose>
	<xsl:when test="contains($keywordsString, ',')">
	  <keyword><xsl:value-of select="normalize-space(substring-before($keywordsString, ','))"/></keyword>
	  <xsl:call-template name="keywordsetContent">
	    <xsl:with-param name="keywordsString" select="substring-after($keywordsString, ',')"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>
	  <keyword><xsl:value-of select="normalize-space($keywordsString)"/></keyword>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>


  <xsl:template name="authorGroupContent">
    <!--
    authorsString is a string of semi-colon separated authors
    Spaces can appear before or after the semi-colons.
    A so called author can contain spaces and a coma.
    If there is a coma for an author, the surname is first and then comes the
    surname. This could have been the other way but this is how it is defined
    in OOo.
    Examples:
    authorsString = "aaa; bbb; ccc"
    authorsString = "aaa  ;  bbb  ;ccc"
    authorsString = "a aa; b bb; ccc"
    authorsString = "a aa  ;  b bb  ;ccc"
    authorsString = " DOE, John  ;  Monroe, Marilyn  ;Buzz"
    -->
    <xsl:param name="authorsString"/>
    <xsl:if test="$authorsString">
      <xsl:choose>
	<xsl:when test="contains($authorsString, ';')">
	  <xsl:call-template name="authorGroupContent">
	    <xsl:with-param name="authorsString" select="substring-after($authorsString, ';')"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>
	  <author>
	    <personname>
	      <xsl:choose>
		<xsl:when test="contains($authorsString , ',')">
		  <xsl:variable name="surname"
		    select="normalize-space(substring-before($authorsString, ','))"/>
		  <xsl:variable name="firstname"
		    select="normalize-space(substring-after($authorsString, ','))"/>
		  <surname>
		    <xsl:value-of select="$surname"/>
		  </surname>
		  <xsl:if test="string($firstname)">
		    <firstname>
		      <xsl:value-of select="$firstname"/>
		    </firstname>
		  </xsl:if>
		</xsl:when>
		<xsl:otherwise>
		  <surname>
		    <xsl:value-of select="$authorsString"/>
		  </surname>
		</xsl:otherwise>
	      </xsl:choose>
	    </personname>
	  </author>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>


  <xsl:template match="text:p" mode="metaInfo">
    <xsl:param name="inAuthor" select="'false'"/>

    <xsl:variable name="parentStyleName"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/@text:style-name)]/@style:parent-style-name"/>

    <xsl:if test="@text:style-name='Title' or
      $parentStyleName='Title'">
      <title><xsl:apply-templates/></title>
    </xsl:if>
    <xsl:if test="@text:style-name='Subtitle' or
      $parentStyleName='Subtitle'">
      <subtitle><xsl:apply-templates/></subtitle>
    </xsl:if>
    <xsl:if test="@text:style-name='Pubdate' or
      $parentStyleName='Pubdate'">
      <pubdate><xsl:apply-templates/></pubdate>
    </xsl:if>
    <xsl:if test="@text:style-name='Pubsnumber' or
      $parentStyleName='Pubsnumber'">
      <releaseinfo><xsl:apply-templates/></releaseinfo>
    </xsl:if>
    <xsl:if test="@text:style-name='Author' or
      $parentStyleName='Author'">
      <author><xsl:call-template name="authorContent"/></author>
    </xsl:if>
    <xsl:if test="@text:style-name='Editor' or
      $parentStyleName='Editor'">
      <editor><xsl:call-template name="authorContent"/></editor>
    </xsl:if>
    <xsl:if test="@text:style-name='Authorblurb' or 
      $parentStyleName='Authorblurb'">
      <xsl:if test="$inAuthor='true'">
	<authorblurb><xsl:apply-templates/></authorblurb>
      </xsl:if>
    </xsl:if>
    <xsl:if test="@text:style-name='Othercredit' or
      $parentStyleName='Othercredit'">
      <othercredit><xsl:call-template name="authorContent"/></othercredit>
    </xsl:if>
    <xsl:if test="@text:style-name='Corpauthor' or
      $parentStyleName='Corpauthor'">
      <corpauthor><xsl:apply-templates/></corpauthor>
    </xsl:if>
    <xsl:if test="@text:style-name='Copyright' or
      $parentStyleName='Copyright'">
      <copyright><xsl:apply-templates select="text:span"/></copyright>
    </xsl:if>
    <xsl:if test="@text:style-name='Bibliomisc' or
      $parentStyleName='Bibliomisc'">
      <bibliomisc><xsl:apply-templates/></bibliomisc>
    </xsl:if>
    <xsl:if test="@text:style-name='Legalnotice' or
      $parentStyleName='Legalnotice'">
      <legalnotice>
        <xsl:call-template name="paraWithBreakLine"/>
      </legalnotice>
    </xsl:if>
    <xsl:if test="@text:style-name='Bibliocoverage' or
      $parentStyleName='Bibliocoverage'">
      <bibliocoverage><xsl:apply-templates/></bibliocoverage>
    </xsl:if>
    <xsl:if test="@text:style-name='Bibliosource' or
      $parentStyleName='Bibliosource'">
      <bibliosource><xsl:apply-templates/></bibliosource>
    </xsl:if>
    <xsl:if test="@text:style-name='Bibliorelation' or
      $parentStyleName='Bibliorelation'">
      <xsl:variable name="url" select="."/>
      <bibliorelation>
	<ulink>
	  <xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
	  <xsl:value-of select="$url"/>
	</ulink>
      </bibliorelation>
    </xsl:if>

    <!-- Suppress those styles -->
    <xsl:if test="@text:style-name='Remark' or $parentStyleName='Remark'"/>

    <!--
    If this call is uncommented one gets mediaobjects inside the metainfo
    which is not what one wants.
    -->
    <!-- <xsl:call-template name="multimedia.bottom"/> -->
  </xsl:template>

  <xsl:template name="abstract">
    <!-- Testing if there is at least a non-empty Abstract para -->
    <xsl:if test="string(//text:p[@text:style-name='Abstract'])">
      <abstract>
	<!-- Selects all matching elements anywhere in the document -->
	<xsl:for-each select="//text:p[@text:style-name='Abstract']">
	  <para>
	    <xsl:apply-templates/>
	  </para>
	</xsl:for-each>
      </abstract>
    </xsl:if>
  </xsl:template>

  <xsl:template name="authorContent">
    <xsl:param name="inAuthor"/>

    <xsl:variable name="parentStyleName"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/@text:style-name)]/
      @style:parent-style-name"/>
    <xsl:variable name="parentStyleNameOfFollowing" select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/following-sibling::*[1]/@text:style-name]/
      @style:parent-style-name"/>
    <xsl:variable name="parentStyleNameOfChild" select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/*/@text:style-name]/
      @style:parent-style-name"/>

    <xsl:apply-templates
      select="text:span[@text:style-name='Honorific' or
      $parentStyleNameOfChild='Honorific']|
      text:span[@text:style-name='Firstname' or
      $parentStyleNameOfChild='Firstname']|
      text:span[@text:style-name='Othername' or
      $parentStyleNameOfChild='Othername']|
      text:span[@text:style-name='Surname' or
      $parentStyleNameOfChild='Surname']|
      text:span[@text:style-name='Lineage' or
      $parentStyleNameOfChild='Lineage']"/>
    <xsl:if test="text:span[@text:style-name='Jobtitle' or
      $parentStyleNameOfChild='Jobtitle']|
      text:span[@text:style-name='Orgname' or
      $parentStyleNameOfChild='Orgname']">
      <affiliation>
	<xsl:apply-templates
	  select="text:span[@text:style-name='Jobtitle' or
	  $parentStyleNameOfChild='Jobtitle']|
	  text:span[@text:style-name='Orgname' or
	  $parentStyleNameOfChild='Orgname']"/>
      </affiliation>
    </xsl:if>
    <xsl:if test="following-sibling::*[1]
      [@text:style-name='Authorblurb' or
      $parentStyleNameOfFollowing='Authorblurb']">
      <xsl:apply-templates select="following-sibling::*[1]" mode="metaInfo">
	<xsl:with-param name="inAuthor" select="'true'"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>

  <xsl:template match="dc:title">
    <title><xsl:apply-templates/></title>
  </xsl:template>

  <xsl:template match="dc:date">
    <date><xsl:apply-templates/></date>
  </xsl:template>

  <xsl:template match="dc:subject">
    <xsl:param name="content" select="text()"/>
    <subjectset>
      <xsl:if test="normalize-space(substring-before($content,':'))">
	<xsl:attribute name="scheme">
	  <xsl:value-of
	    select="normalize-space(substring-before($content,':'))"/>
	</xsl:attribute>
      </xsl:if>
      <subject>
	<xsl:call-template name="subjectElements">
	  <xsl:with-param name="content" select="substring-after($content,':')"/>
	</xsl:call-template>
      </subject>
    </subjectset>
  </xsl:template>

  <xsl:template name="subjectElements">
    <xsl:param name="content"/>
    <xsl:choose>
      <xsl:when test="contains($content,',')">
	<subjectterm>
	  <xsl:value-of
	    select="normalize-space(substring-before($content,','))"/>
	</subjectterm>
	<xsl:call-template name="subjectElements">
	  <xsl:with-param name="content" select="substring-after($content,',')"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<subjectterm><xsl:value-of select="normalize-space($content)"/></subjectterm>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="meta:keyword">
    <keyword><xsl:apply-templates/></keyword>
  </xsl:template>


  <!--
  =======
  PREFACE
  =======

  Prefaces are found when an OOo section has an Preface Title in it.
  IMPORTANT:
  Preface must have a "Preface Title" at its top.
  Preface may have no other title than the Preface Title.
  Preface may have other titles than the Preface Title, in this case
  the Title hierarchy must be strictly followed (Title 1, Title 2, etc.)
  otherwise one get the "ERROR: Title hierarchy is wrong" error message.
  -->
  <xsl:template name="preface">
    <!--
    Using string(@text:display)!='none' is important here because some sections
    may not have the text:display attribute (actually all the visible
    sections ;-) ) and thus the test will fail on them.
    -->
    <xsl:for-each select="/office:document/office:body/office:text/text:section[string(@text:display)!='none']">

      <xsl:variable name="prefaceTitleNodeId">
        <!--
        <xsl:value-of select="generate-id()"/>
                    -->
        <xsl:call-template name="prefaceTitleNodeId">
            <xsl:with-param name="fromNode" select="current()"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:if test="string($prefaceTitleNodeId)">
	<!-- Retrieve the prefaceTitle node through its id -->
        <!--<DEBUG><xsl:value-of select="$prefaceTitleNodeId"/></DEBUG>-->

	<xsl:variable name="prefaceTitle"
	  select="//node()[generate-id() = $prefaceTitleNodeId]"/>
	<preface>

      <!-- rajout MT recherche bookmark si oui rajout attribut id -->
      <xsl:if test="$prefaceTitle/text:bookmark-start/@text:name">
        <xsl:attribute name="id">
            <xsl:value-of select="$prefaceTitle/text:bookmark-start/@text:name"/>
        </xsl:attribute>
      </xsl:if>
      <!-- fin rajout MT recherche bookmark si oui rajout attribut id -->

	  <xsl:call-template name="outputPrintOrientation">
	    <xsl:with-param name="styleName" select="$prefaceTitle/@text:style-name"/>
	  </xsl:call-template>
	  
      <title><xsl:value-of select="$prefaceTitle"/></title>
	  
      <xsl:choose>
	    <xsl:when test="text:h[@text:outline-level='1']">
            <xsl:apply-templates
            select="text:h[@text:outline-level='1'][1]" mode="hierarchy">
            <xsl:with-param name="source" select="'preface'"/>
            <xsl:with-param name="excludeNodeId" select="$prefaceTitleNodeId"/>
            </xsl:apply-templates>
	    </xsl:when>
	    <xsl:otherwise>
	      <!--
          <xsl:apply-templates select="child::*[generate-id(.) != $prefaceTitleNodeId]" mode="noHierarchy"/>
          -->
          <xsl:apply-templates select="child::*[generate-id(.) != $prefaceTitleNodeId]" mode="noHierarchy"/>

	    </xsl:otherwise>
	  </xsl:choose>
	</preface>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- Return the node id of the Preface Title if one is found -->
  <xsl:template name="prefaceTitleNodeId">
    <!-- fromNode is the node on which to start finding the text:p elements -->
    <xsl:param name="fromNode"/>
    <xsl:for-each select="$fromNode/text:p|$fromNode/text:h">
        <xsl:variable name="parentStyleName"
        select="/office:document/office:automatic-styles/
        style:style[@style:name=(current()/@text:style-name)]/@style:parent-style-name"/>
        
        <xsl:if test="(@text:style-name='Preface_20_Title'
        or $parentStyleName='Preface_20_Title')
        and position() = 1">
        <xsl:value-of select="generate-id()"/>
        </xsl:if>
    </xsl:for-each>
  </xsl:template>


  <!--
  ========
  APPENDIX
  ========

  Appendices are found when an OOo section has an Appendix Title in it.
  IMPORTANT:
  Appendix must have an Appendix Title at its top.
  Appendix may have no other title than the Appendix Title.
  Appendix may have other titles than the Appendix Title, in this case
  the Title hierarchy must be strictly followed (Title 1, Title 2, etc.)
  otherwise one get the "ERROR: Title hierarchy is wrong" error message.
  -->
<xsl:template name="appendix">
    <!--
    Using string(@text:display)!='none' is important here because some sections
    may not have the text:display attribute (actually all the visible
    sections ;-) ) and thus the test will fail on them.
    -->
    <xsl:for-each select="/office:document/office:body/office:text/text:section[string(@text:display)!='none']">

        <xsl:variable name="appendixTitleNodeId">
            <xsl:call-template name="appendixTitleNodeId">
                <xsl:with-param name="fromNode" select="current()"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:if test="string($appendixTitleNodeId)">
	<!-- Retrieve the appendixTitle node through its id -->
            <!--<DEBUG><xsl:value-of select="$appendixTitleNodeId"/></DEBUG>-->
            <xsl:variable name="appendixTitle" select="//node()[generate-id() = $appendixTitleNodeId]"/>
            <appendix>

            <!-- rajout MT recherche bookmark si oui rajout attribut id -->
            <xsl:if test="$appendixTitle/text:bookmark-start/@text:name">
            <xsl:attribute name="id">
                <xsl:value-of select="$appendixTitle/text:bookmark-start/@text:name"/>
            </xsl:attribute>
            </xsl:if>
            <!-- fin rajout MT recherche bookmark si oui rajout attribut id -->

            <xsl:call-template name="outputPrintOrientation">
                <xsl:with-param name="styleName" select="$appendixTitle/@text:style-name"/>
            </xsl:call-template>
            <title><xsl:value-of select="$appendixTitle"/></title>
            <xsl:choose>
                <xsl:when test="text:h[@text:outline-level='1']">
                    <xsl:apply-templates
                    select="text:h[@text:outline-level='1'][1]" mode="hierarchy">
                    <xsl:with-param name="source" select="'appendix'"/>
                    <xsl:with-param name="excludeNodeId" select="$appendixTitleNodeId"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <!--
                    <xsl:apply-templates select="child::*[generate-id(.) != $appendixTitleNodeId]" mode="noHierarchy"/>
                    -->
                    <xsl:apply-templates select="child::*[generate-id(.) != $appendixTitleNodeId]" mode="noHierarchy"/>
                </xsl:otherwise>
            </xsl:choose>
            </appendix>
        </xsl:if>
    </xsl:for-each>
</xsl:template>

  <!-- Return the node id of the Appendix Title if one is found -->
<xsl:template name="appendixTitleNodeId">
    <!-- fromNode is the node on which to start finding the text:p elements -->
    <xsl:param name="fromNode"/>
    <xsl:for-each select="$fromNode/text:p|$fromNode/text:h">
      <xsl:variable name="parentStyleName"
	select="/office:document/office:automatic-styles/
	style:style[@style:name=(current()/@text:style-name)]/@style:parent-style-name"/>
      <xsl:if test="(@text:style-name='Appendix_20_Title'
	or $parentStyleName='Appendix_20_Title')
	and position() = 1">

	<xsl:value-of select="generate-id()"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>


  <!--
  ============
  BIBLIOGRAPHY
  ============

  Examples of OOo markup:
  <text:bibliography-mark text:author="Borges, Malte; Schumacher, Jörg" text:bibliography-type="book" text:identifier="BOR02a" text:isbn="3827262763" text:pages="900" text:publisher="Markt &amp; Technik Verlag" text:title="StarOffice 6.0 Kompendium" text:year="2002">
  <text:bibliography-mark text:author="Bob" text:bibliography-type="book" text:identifier="XSLT" text:title="XSLT Poet">
  -->
<xsl:template name="bibliography">
    <xsl:variable name="biblioEntries" select="/office:document/office:body//text:bibliography-mark"/>
    <xsl:if test="$biblioEntries">
        <bibliography>
            <xsl:for-each select="$biblioEntries">
                <biblioentry>
                    <xsl:attribute name="id"><xsl:value-of select="generate-id(current())"/></xsl:attribute>
                    <xsl:variable name="abbrev" select="@text:identifier"/>
                    <xsl:if test="string($abbrev)">
                        <abbrev><xsl:value-of select="$abbrev"/></abbrev>
                    </xsl:if>

                    <xsl:variable name="url" select="@text:url"/>
                    <xsl:choose>
                        <xsl:when test="string($url)">
                            <title>
                                <ulink>
                                    <xsl:attribute name="url"><xsl:value-of select="$url"/></xsl:attribute>
                                    <xsl:value-of select="@text:title"/>
                                </ulink>
                            </title>
                        </xsl:when>
                        <xsl:otherwise>
                            <title><xsl:value-of select="@text:title"/></title>
                        </xsl:otherwise>
                    </xsl:choose>

                    <xsl:variable name="authorsString" select="@text:author"/>
                    <xsl:if test="string($authorsString)">
                        <authorgroup>
                            <xsl:call-template name="authorGroupContent">
                                <xsl:with-param name="authorsString" select="@text:author"/>
                            </xsl:call-template>
                        </authorgroup>
                    </xsl:if>

                    <xsl:variable name="pubdate" select="@text:year"/>
                    <xsl:if test="string($pubdate)">
                        <pubdate><xsl:value-of select="$pubdate"/></pubdate>
                    </xsl:if>

                    <xsl:variable name="publisher" select="@text:publisher"/>
                    <xsl:if test="string($publisher)">
                        <publisher>
                            <publishername><xsl:value-of select="$publisher"/></publishername>
                        </publisher>
                    </xsl:if>

                    <xsl:variable name="isbn" select="@text:isbn"/>
                    <xsl:if test="string($isbn)">
                        <biblioid class="isbn"><xsl:value-of select="$isbn"/></biblioid>
                    </xsl:if>

                </biblioentry>
            </xsl:for-each>
        </bibliography>
    </xsl:if>
</xsl:template>


  <!--
  =============
  LEXICAL INDEX
  =============

  Examples of OOo markup:
  Le <text:alphabetical-index-mark-start text:id="IMark1219739116" text:key1="web" text:key2="www"/>W3C<text:alphabetical-index-mark-end text:id="IMark1219739116"/> est une instance de normalisation des standards du <text:alphabetical-index-mark-start text:id="IMark1219743716" text:key1="web" text:key2="www"/>Web<text:alphabetical-index-mark-end text:id="IMark1219743716"/>.
  <text:alphabetical-index-mark-start text:id="IMark1219744572" text:key1="corba"/>CORBA<text:alphabetical-index-mark-end text:id="IMark1219744572"/> est aussi un standard.
  -->
<xsl:template name="index">
    <xsl:variable name="indexEntries" select="/office:document/office:body//text:alphabetical-index-mark-start"/>
    <xsl:if test="$indexEntries">
      <index/>
    </xsl:if>
</xsl:template>


  <!--
  ========
  GLOSSARY
  ========

  Glossaries are found when an OOo section has an Glossary Title in it.
  IMPORTANT:
  Glossary must have an Glossary Title at its top.
  Glossary may have no other title than the Glossary Title.
  -->
<xsl:template name="glossary">
    <!--
    Using string(@text:display)!='none' is important here because some sections
    may not have the text:display attribute (actually all the visible
    sections ;-) ) and thus the test will fail on them.
    -->
    <xsl:for-each select="/office:document/office:body//text:section[string(@text:display)!='none']">
<!--<xsl:message>glossary : <xsl:value-of select="./@text:name"/></xsl:message>-->
        <xsl:variable name="glossaryTitleNodeId">
            <xsl:call-template name="glossaryTitleNodeId">
                <xsl:with-param name="fromNode" select="current()"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:if test="string($glossaryTitleNodeId)">
	<!-- Retrieve the glossaryTitle node through its id -->
            <xsl:variable name="glossaryTitle" select="//node()[generate-id() = $glossaryTitleNodeId]"/>
            <glossary>
                <xsl:call-template name="outputPrintOrientation">
                    <xsl:with-param name="styleName" select="$glossaryTitle/@text:style-name"/>
                </xsl:call-template>
                <title><xsl:value-of select="$glossaryTitle"/></title>
                <xsl:for-each select="text:p">
                    <xsl:variable name="parentStyleName"
                        select="/office:document/office:automatic-styles/
                        style:style[@style:name=(current()/@text:style-name)]/
                        @style:parent-style-name"/>
                    <xsl:if test="@text:style-name='Glossary_20_Term' or
                        $parentStyleName='Glossary_20_Term'">
                        <xsl:variable name="glossTermId" select="generate-id()"/>
                        <glossentry>
                            <glossterm><xsl:value-of select="string(.)"/></glossterm>
                            <glossdef>
		  <!--
		  The glossdef paras are found by selecting the next text:p
		  elements which have the previously selected glossterm para
		  as the closest glossterm para predecessor.
		  -->
                                <xsl:for-each select="following-sibling::text:p">

                                    <xsl:variable name="precedingGlossTerms"
                                    select="preceding-sibling::text:p[
                                    @text:style-name='Glossary_20_Term'
                                    or
                                    /office:document/office:automatic-styles/
                                    style:style[@style:name=(current()/@text:style-name)]/
                                    @style:parent-style-name = 'Glossary_20_Term'
                                    ]"/>
                                    <xsl:variable name="closestPrecedingGlossTerm"
                                    select="$precedingGlossTerms[position() = last()]"/>

                                    <xsl:variable name="parentStyleName2"
                                    select="/office:document/office:automatic-styles/
                                    style:style[@style:name=(current()/@text:style-name)]/
                                    @style:parent-style-name"/>
                                    <xsl:if test="(@text:style-name='Glossary_20_Definition'
                                    or $parentStyleName2='Glossary_20_Definition')
                                    and generate-id($closestPrecedingGlossTerm) = $glossTermId">
                                        <para>
                                            <xsl:call-template name="paraWithBreakLine"/>
                                            <!--<xsl:apply-templates/>-->
                                        </para>
                                    </xsl:if>
                                </xsl:for-each>
                            </glossdef>
                        </glossentry>
                    </xsl:if>
                </xsl:for-each>
            </glossary>
        </xsl:if>
    </xsl:for-each>
</xsl:template>

  <!-- Return the node id of the Glossary Title if one is found -->
<xsl:template name="glossaryTitleNodeId">
    <!-- fromNode is the node on which to start finding the text:p elements -->
    <xsl:param name="fromNode"/>
    <xsl:for-each select="$fromNode/text:p|$fromNode/text:h">
      <xsl:variable name="parentStyleName"
	select="/office:document/office:automatic-styles/
	style:style[@style:name=(current()/@text:style-name)]/@style:parent-style-name"/>

      <xsl:if test="(@text:style-name='Glossary_20_Title'
	or $parentStyleName='Glossary_20_Title')
	and position() = 1">
	<xsl:value-of select="generate-id()"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>


  <!--
  =============
  DOCUMENT BODY
  =============
  -->

  <!--
  BLOCKS TAGS
  ===========
  -->

  <!-- Blocks - Standards blocks -->

<xsl:template name="para">
    <xsl:param name="source"/>
    <xsl:param name="pos"/>
    <xsl:param name="parent"/>

    <!--
    Only output elements that have text or other elements (children) in them.
    This avoids for example empty paras in the output.
    -->
    <!-- Test original <xsl:if test="string(.) or count(./*) > 0">-->
    <xsl:if test="string(.) or count(./*[node() != '']) > 0">
        <xsl:variable name="StyleName" select="current()/@text:style-name"/>
        <xsl:variable name="parentStyleName"
        select="/office:document/office:automatic-styles/
        style:style[@style:name=(current()/@text:style-name)]/
        @style:parent-style-name"/>

        <xsl:variable name="parentStyleNameOfPreceding"
        select="/office:document/office:automatic-styles/
        style:style[@style:name=current()/
        preceding-sibling::*[1]/@text:style-name]/
        @style:parent-style-name"/>

        <xsl:variable name="parentStyleNameOfFollowing"
        select="/office:document/office:automatic-styles/
        style:style[@style:name=current()/
        following-sibling::*[1]/@text:style-name]/
        @style:parent-style-name"/>
    
<!--
        <DEBUG>
        StyleName : <xsl:value-of select="$StyleName"/>
        parentStyleName : <xsl:value-of select="$parentStyleName"/>
        parentStyleNameOfPreceding : <xsl:value-of select="$parentStyleNameOfPreceding"/>
        parentStyleNameOfFollowing : <xsl:value-of select="$parentStyleNameOfFollowing"/>
        </DEBUG>
-->

<!--<DEBUG>para</DEBUG>-->
<!--
        <mm>
        <xsl:attribute name="S">
            <xsl:value-of select="$StyleName"/>
        </xsl:attribute>
        <xsl:attribute name="PS">
            <xsl:value-of select="$parentStyleName"/>
        </xsl:attribute>
        <xsl:attribute name="Sprece">
            <xsl:value-of select="$parentStyleNameOfPreceding"/>
        </xsl:attribute>
        <xsl:attribute name="Sfolow">
            <xsl:value-of select="$parentStyleNameOfFollowing"/>
        </xsl:attribute>
        <xsl:attribute name="String">
            <xsl:value-of select="string(.)"/>
        </xsl:attribute>
        <xsl:attribute name="Count">
            <xsl:value-of select="count(./*)"/>
        </xsl:attribute>
        <xsl:attribute name="StringA">
            <xsl:value-of select="count(./*[node() != ''])"/>
        </xsl:attribute>
        </mm>
-->
        <xsl:call-template name="multimedia.top"/>

        <xsl:choose>

            <xsl:when test="@text:style-name='Epigraph' or $parentStyleName='Epigraph'">
              <epigraph>
                <xsl:if test="following-sibling::*[1][name()='text:p' and
                  @text:style-name='Attribution' or
                  $parentStyleNameOfFollowing='Attribution']">
                  <xsl:apply-templates select="following-sibling::*[1]"
                mode="attribution"/>
                </xsl:if>
                <xsl:call-template name="paraWithBreakLine"/>
              </epigraph>
            </xsl:when>
        
            <xsl:when test="@text:style-name='Quotations' or
              $parentStyleName='Quotations' or
              @text:style-name='Blockquote' or
              $parentStyleName='Blockquote'">
              <blockquote>
                <xsl:if test="following-sibling::*[1][name()='text:p' and
                  @text:style-name='Attribution' or
                  $parentStyleNameOfFollowing='Attribution']">
                  <xsl:apply-templates select="following-sibling::*[1]"
                mode="attribution"/>
                </xsl:if>
                <xsl:call-template name="paraWithBreakLine"/>
              </blockquote>
            </xsl:when>

            <xsl:when test="@text:style-name='Preformatted_20_Text' or
              $parentStyleName='Preformatted_20_Text' or
              @text:style-name='ProgramListing' or
              $parentStyleName='ProgramListing'">
              <programlisting><xsl:apply-templates>
                  <xsl:with-param name="parent" select="'programListing'"/>
                </xsl:apply-templates></programlisting>
            </xsl:when>

            <xsl:when test="@text:style-name='Literallayout' or
              $parentStyleName='Literallayout'">
              <literallayout>
                <xsl:apply-templates>
                  <xsl:with-param name="parent" select="'programListing'"/>
                </xsl:apply-templates>
              </literallayout>
            </xsl:when>
        
            <xsl:when test="@text:style-name='Term' or $parentStyleName='Term'">
              <xsl:if
                test="(preceding-sibling::*[1]/
                @text:style-name != 'Definition' or
                $parentStyleNameOfPreceding != 'Definition') and
                (preceding-sibling::*[1]/@text:style-name != 'Term'
                or $parentStyleNameOfPreceding != 'Term')">
                <xsl:call-template name="varlistterm"/>
              </xsl:if>
              <xsl:if test="$source='varlist' and
                (preceding-sibling::*[1]/
                @text:style-name='Definition' or
                $parentStyleNameOfPreceding='Definition')">
                <xsl:call-template name="varlist"/>
              </xsl:if>
            </xsl:when>
        
            <xsl:when test="@text:style-name='Definition' or
              $parentStyleName='Definition'">
              <xsl:if test="$source='varlist'">
                <xsl:call-template name="paraWithBreakLine"/>
              </xsl:if>
              <!--<xsl:if test="following-sibling::*[1][name()='text:p'
              and (@text:style-name='Definition' or
              $parentStyleNameOfFollowing='Definition')]">
              <xsl:apply-templates select="following-sibling::*[1]"
              mode="varlist"/>
            </xsl:if>-->
            </xsl:when>

            <!-- Rajoute par Mt pour gerer les styles de notes important|warning|caution|tip -->
            <xsl:when test="@text:style-name='Note' or $parentStyleName='Note'">
              <note>
                <xsl:if test="preceding-sibling::*[1][name()='text:p' and
                  @text:style-name='NoteTitle' or
                  $parentStyleNameOfPreceding='NoteTitle']">
                  <xsl:apply-templates select="preceding-sibling::*[1]"
                mode="NoteTitle"/>
                </xsl:if>
              <!--<xsl:apply-templates/>-->
              <xsl:call-template name="paraWithBreakLine"/>
              </note>
            </xsl:when>
            <xsl:when test="@text:style-name='NoteWarning' or $parentStyleName='NoteWarning'">
              <warning>
                <xsl:if test="preceding-sibling::*[1][name()='text:p' and
                  @text:style-name='NoteTitle' or
                  $parentStyleNameOfPreceding='NoteTitle']">
                  <xsl:apply-templates select="preceding-sibling::*[1]"
                mode="NoteTitle"/>
                </xsl:if>
              <!--<xsl:apply-templates/>-->
              <xsl:call-template name="paraWithBreakLine"/>
              </warning>
            </xsl:when>
            <xsl:when test="@text:style-name='NoteImportant' or $parentStyleName='NoteImportant'">
              <important>
                <xsl:if test="preceding-sibling::*[1][name()='text:p' and
                  @text:style-name='NoteTitle' or
                  $parentStyleNameOfPreceding='NoteTitle']">
                  <xsl:apply-templates select="preceding-sibling::*[1]"
                mode="NoteTitle"/>
                </xsl:if>
              <!--<xsl:apply-templates/>-->
              <xsl:call-template name="paraWithBreakLine"/>
              </important>
            </xsl:when>
            <xsl:when test="@text:style-name='NoteCaution' or $parentStyleName='NoteCaution'">
              <caution>
                <xsl:if test="preceding-sibling::*[1][name()='text:p' and
                  @text:style-name='NoteTitle' or
                  $parentStyleNameOfPreceding='NoteTitle']">
                  <xsl:apply-templates select="preceding-sibling::*[1]"
                mode="NoteTitle"/>
                </xsl:if>
              <!--<xsl:apply-templates/>-->
              <xsl:call-template name="paraWithBreakLine"/>
              </caution>
            </xsl:when>
            <xsl:when test="@text:style-name='NoteTip' or $parentStyleName='NoteTip'">
              <tip>
                <xsl:if test="preceding-sibling::*[1][name()='text:p' and
                  @text:style-name='NoteTitle' or
                  $parentStyleNameOfPreceding='NoteTitle']">
                  <xsl:apply-templates select="preceding-sibling::*[1]"
                mode="NoteTitle"/>
                </xsl:if>
              <!--<xsl:apply-templates/>-->
              <xsl:call-template name="paraWithBreakLine"/>
              </tip>
            </xsl:when>
            <!-- fin rajout MT-->

            <!-- Suppress those styles -->
            <xsl:when test="@text:style-name='Remark' or $parentStyleName='Remark'"/>
        
            <xsl:when test="@text:style-name='Heading' or $parentStyleName='Heading'"/>
        
            <xsl:when test="@text:style-name='Attribution' or $parentStyleName='Attribution'"/>
        
            <!-- rajoute par MT si le style est utilise seul il n est pas affiche -->
            <xsl:when test="@text:style-name='NoteTitle' or $parentStyleName='NoteTitle'"/>
            <!-- fin rajout MT-->
        
            <xsl:when test="text:sequence"/>

            <!-- suppress metaInfo styles -->
            <xsl:when test="@text:style-name='Title' or $parentStyleName='Title'"/>
            <xsl:when test="@text:style-name='Subtitle' or $parentStyleName='Subtitle'"/>
            <xsl:when test="@text:style-name='Pubsnumber' or $parentStyleName='Pubsnumber'"/>
            <xsl:when test="@text:style-name='Pubdate' or $parentStyleName='Pubdate'"/>
            <xsl:when test="@text:style-name='Author' or $parentStyleName='Author'"/>
            <xsl:when test="@text:style-name='Editor' or $parentStyleName='Editor'"/>
            <xsl:when test="@text:style-name='Authorblurb' or $parentStyleName='Authorblurb'"/>
            <xsl:when test="@text:style-name='Othercredit' or $parentStyleName='Othercredit'"/>
            <xsl:when test="@text:style-name='Corpauthor' or $parentStyleName='Corpauthor'"/>
            <xsl:when test="@text:style-name='Copyright' or $parentStyleName='Copyright'"/>
            <xsl:when test="@text:style-name='Bibliomisc' or $parentStyleName='Bibliomisc'"/>
            <xsl:when test="@text:style-name='Bibliocoverage' or $parentStyleName='Bibliocoverage'"/>
            <xsl:when test="@text:style-name='Bibliosource' or $parentStyleName='Bibliosource'"/>
            <xsl:when test="@text:style-name='Bibliorelation' or $parentStyleName='Bibliorelation'"/>
            <xsl:when test="@text:style-name='Abstract' or $parentStyleName='Abstract'"/>
            <xsl:when test="@text:style-name='Legalnotice' or $parentStyleName='Legalnotice'"/>
            <xsl:when test="@text:style-name='Keywordset' or $parentStyleName='Keywordset'"/>
            <!-- +++++ -->
        
            <xsl:otherwise>
          <!-- No breaklines in paras -->
	  <!-- <para><xsl:apply-templates/></para> -->

          <!-- Allow breaklines in paras -->
            <xsl:call-template name="paraWithBreakLine"/>
            </xsl:otherwise>

        </xsl:choose>

        <xsl:call-template name="multimedia.bottom"/>
    </xsl:if>
</xsl:template>


<xsl:template name="paraWithBreakLine">
    <!--
    Parameter to pass a particular role is necessary so that it can propagate to
    the split paras.
    -->
    <xsl:param name="role"/>
    <xsl:if test="text:line-break">
        <xsl:apply-templates select="text:line-break" mode="break2para">
            <xsl:with-param name="role" select="$role"/>
        </xsl:apply-templates>
    </xsl:if>
    <xsl:if test="not(text:line-break)">
        <para>
            <xsl:if test="string($role)">
                <xsl:attribute name="role">
                    <xsl:value-of select="$role"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </para>
    </xsl:if>
</xsl:template>

<xsl:template match="text:line-break" mode="break2para">
    <xsl:param name="role"/>
    <xsl:variable name="br-before" select="preceding-sibling::text:line-break[1]"/>
    <xsl:variable name="content"
      select="preceding-sibling::node()[not($br-before) or
      generate-id(preceding-sibling::text:line-break[1])
      =generate-id($br-before)]"/>
    <xsl:if test="$content">
        <para>
            <xsl:if test="string($role)">
                <xsl:attribute name="role">
                    <xsl:value-of select="$role"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="$content" />
        </para>
    </xsl:if>
    <xsl:if test="position()=last()">
        <xsl:variable name="roleWithLineBreak"
            select="normalize-space(concat('lineBreak ', $role))"/>
        <para>
            <xsl:attribute name="role">
                <xsl:value-of select="$roleWithLineBreak"/>
            </xsl:attribute>
            <xsl:apply-templates select="following-sibling::node()"/>
        </para>
    </xsl:if>
</xsl:template>

  <!-- Template added by Nuxeo, experimental, kept for reference -->
<xsl:template name="breakLineToPara">
    <xsl:param name="role"/>
    <xsl:for-each select="*|text()">
      <xsl:choose>
	<xsl:when test="name(.) != 'text:line-break'">
	  <para>
	    <xsl:attribute name="role">
	      <xsl:value-of select="$role"/>
	    </xsl:attribute>
	    <xsl:apply-templates select="."/>
	  </para>
	</xsl:when>
	<xsl:when test="text:span">
	  <xsl:apply-templates select="."/>
	</xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>


<xsl:template match="office:annotation">
    <xsl:value-of disable-output-escaping="yes" select="text:p"/>
  </xsl:template>

<xsl:template match="text:line-break">
    <xsl:param name="parent"/>
    <xsl:if test="$parent='programListing'">
      <xsl:text disable-output-escaping="yes">&#013;</xsl:text>
    </xsl:if>
  </xsl:template>

<xsl:template match="text:tab-stop">
    <xsl:param name="parent"/>
    <xsl:if test="$parent='programListing'">
      <xsl:text
	disable-output-escaping="yes">&nbsp;&nbsp;&nbsp;&nbsp;</xsl:text>
    </xsl:if>
  </xsl:template>

<xsl:template match="text:s">
    <xsl:param name="parent"/>
    <xsl:param name="spaceOccurence" select="@text:c + 1"/>
    <xsl:if test="$parent='programListing'">
      <xsl:call-template name="spaceRecursif">
	<xsl:with-param name="spaceOccurence"
	  select="$spaceOccurence"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

<xsl:template name="spaceRecursif">
    <xsl:param name="spaceOccurence"/>
    <xsl:if test="$spaceOccurence > 0">
      <xsl:text disable-output-escaping="yes">&nbsp;</xsl:text>
      <xsl:call-template name="spaceRecursif">
	<xsl:with-param name="spaceOccurence"
	  select="$spaceOccurence - 1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Blocks - Attribution -->

<xsl:template match="text:p" mode="attribution">
    <attribution><xsl:apply-templates/></attribution>
  </xsl:template>

  <!-- Rajout MT : Blocks - NoteTitle -->
<xsl:template match="text:p" mode="NoteTitle">
    <title><xsl:apply-templates/></title>
  </xsl:template>

  <!-- Block - Heading (local title) -->

<xsl:template name="paraWithTitle">
    <xsl:call-template name="precedingTitle"/>
    <xsl:call-template name="paraWithBreakLine"/>
  </xsl:template>

<xsl:template name="precedingTitle">
    <xsl:variable name="parentStyleNameOfPreceding"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/preceding-sibling::*[1]/
      @text:style-name]/@style:parent-style-name"/>
    <xsl:if test="preceding-sibling::*[1][name()='text:p'
      and (@text:style-name='Heading' or
      $parentStyleNameOfPreceding ='Heading')]">
      <xsl:apply-templates select="current()/preceding-sibling::*[1]"
	mode="includeTitle"/>
    </xsl:if>
  </xsl:template>

<xsl:template match="text:p" mode="includeTitle">
    <title><xsl:apply-templates/></title>
  </xsl:template>

  <!--
  LISTS
  =====
  -->

  <!-- Lists - VariableList
  'Term' and 'Definition' : not defaults styles of OpenOffice -->

<xsl:template name="varlistterm">
    <variablelist>
      <xsl:call-template name="varlist"/>
    </variablelist>
  </xsl:template>

<xsl:template name="varlist">
    <xsl:variable name="parentStyleNameOfFollowing"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/
      following-sibling::*[1]/@text:style-name]/
      @style:parent-style-name"/>
    <xsl:variable name="parentStyleNameOfFollowing2"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/
      following-sibling::*[2]/@text:style-name]/
      @style:parent-style-name"/>
    <varlistentry>
      <term><xsl:apply-templates/></term>
      <listitem>
	<para>
	<xsl:if test="following-sibling::*[1][name()='text:p'
	  and (@text:style-name='Definition'
	  or $parentStyleNameOfFollowing='Definition')]">
	  <xsl:apply-templates select="following-sibling::*[1]"
	    mode="varlist"/>
	</xsl:if>
	</para>
      </listitem>
    </varlistentry>
    <!--<xsl:choose>
    <xsl:when test="following-sibling::*[1][name()='text:p' and
    (@text:style-name='Term' or
    $parentStyleNameOfFollowing='Term')]">
    <xsl:apply-templates select="following-sibling::*[1]"
    mode="varlist"/>
  </xsl:when>
    <xsl:when test="following-sibling::*[2][name()='text:p' and
    (@text:style-name='Term' or
    $parentStyleNameOfFollowing2='Term')]">
    <xsl:apply-templates select="following-sibling::*[2]"
    mode="varlist"/>
  </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
    <xsl:if test="following-sibling::*[1][name()='text:p' and
    (@text:style-name='Term' or
    $parentStyleNameOfFollowing='Term')]">
    <xsl:apply-templates select="following-sibling::*[1]"
    mode="varlist"/>
  </xsl:if>-->
    <xsl:if test="following-sibling::*[2][name()='text:p' and
      (@text:style-name='Term' or
      $parentStyleNameOfFollowing2='Term')]">
      <xsl:apply-templates select="following-sibling::*[2]"
	mode="varlist"/>
    </xsl:if>
  </xsl:template>

  <!-- Nouvelles Listes - Version 2 -->

<xsl:template match="text:list" name="ListesV2">
    <xsl:variable name="Laliste" select="ancestor-or-self::text:list"/>
    <xsl:variable name="StyleMM" select="$Laliste[1]/@text:style-name"/>
    <xsl:variable name="style" select="//text:list-style[@style:name=$StyleMM]"/>
    <xsl:variable name="level" select="count(ancestor-or-self::text:list)"/>
    <xsl:variable name="typelevel" select="name($style/*[@text:level = $level])"/>

    <!--<DEBUG>typelevel : <xsl:value-of select="$typelevel"/></DEBUG>-->

    <xsl:if test="$typelevel = 'text:list-level-style-number'">
    <orderedlist>
        <xsl:variable name="ConsecutiveNumbering" select="$style/@text:consecutive-numbering"/>

        <xsl:attribute name="continuation">
                <xsl:choose>
                    <xsl:when test="$ConsecutiveNumbering='true'">
                        <xsl:text>continues</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>restarts</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
        </xsl:attribute>
        <xsl:variable name="numFormat" 
        select="$style/text:list-level-style-number[@text:level = $level]/@style:num-format"/>
        <xsl:if test="$numFormat">
            <xsl:attribute name="numeration">
                <xsl:choose>
                <xsl:when test="$numFormat='a'">
                  <xsl:text>loweralpha</xsl:text>
                </xsl:when>
                <xsl:when test="$numFormat='A'">
                  <xsl:text>upperalpha</xsl:text>
                </xsl:when>
                <xsl:when test="$numFormat='1'">
                  <xsl:text>arabic</xsl:text>
                </xsl:when>
                <xsl:when test="$numFormat='i'">
                  <xsl:text>lowerroman</xsl:text>
                </xsl:when>
                <xsl:when test="$numFormat='I'">
                  <xsl:text>upperroman</xsl:text>
                </xsl:when>
                </xsl:choose>
            </xsl:attribute>
        </xsl:if>
        <xsl:apply-templates/>

    </orderedlist>
    </xsl:if>
    <xsl:if test="$typelevel = 'text:list-level-style-bullet'">
    <itemizedlist>
        <xsl:apply-templates/>
    </itemizedlist>
    </xsl:if>

</xsl:template>



  <!-- Lists - Common tags -->

<xsl:template match="text:list-item">
    <xsl:param name="parent"/>
    <xsl:choose>
      <xsl:when test="$parent = 'calloutlist'">
	<callout>
	  <xsl:attribute name="arearefs"><xsl:value-of select="text:p/text:reference-ref/@text:ref-name"/></xsl:attribute>
	  <xsl:apply-templates/></callout></xsl:when>
      <xsl:otherwise>
	<listitem><xsl:apply-templates/></listitem>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="text:list-item/text:p">
    <!--<DEBUG>text:list-item/text:p</DEBUG>-->

    <xsl:call-template name="multimedia.top"/>
    <xsl:call-template name="paraWithBreakLine"/>
    <xsl:call-template name="multimedia.bottom"/>
</xsl:template>


  <!--
  INLINES TAGS
  ============
  -->

<xsl:template match="text:span">
    <xsl:variable name="fontStyle"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/@text:style-name)]
      /style:text-properties/@fo:font-style"/>
    <xsl:variable name="fontWeight"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/
      @text:style-name)]/style:text-properties/
      @fo:font-weight"/>
    <xsl:variable name="fontName"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/
      @text:style-name)]/style:text-properties/
      @style:font-name"/>
    <xsl:variable name="textPosition"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/
      @text:style-name)]/style:text-properties/
      @style:text-position"/>
    <xsl:variable name="parentStyleName"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/
      @text:style-name)]/@style:parent-style-name"/>

    <xsl:choose>
        <xsl:when test="$fontStyle='italic'">
            <emphasis><xsl:apply-templates/></emphasis>
        </xsl:when>
        <xsl:when test="$fontWeight='bold'">
            <emphasis role="strong"><xsl:apply-templates/></emphasis>
        </xsl:when>
        <xsl:when test="@text:style-name='Emphasis' or $parentStyleName='Emphasis'">
            <emphasis><xsl:apply-templates/></emphasis>
        </xsl:when>
        <xsl:when test="@text:style-name='Strong_20_Emphasis' or $parentStyleName='Strong_20_Emphasis'">
            <emphasis>
                <xsl:attribute name="role">strong</xsl:attribute>
                <xsl:apply-templates/>
                </emphasis>
        </xsl:when>

      <!--
      Here we keep the font names of the following fonts because they mark the
      fact that symbols are used and we want to pass this information to the
      next XSLT stylesheet that will transform this DocBook XML into, for
      example XHTML or PDF:
      "OpenSymbol"
      "Standard Symbols L"
      "Zapf Dingbats"
      "Bitstream Charter"
      Note that "Bitstream" is the name of a provider providing more than just
      one font.
      -->
        <xsl:when test="$fontName != ''
            and (
            contains($fontName, 'Symbol')
            or contains($fontName, 'Dingbats')
            or $fontName = 'Bitstream Charter'
            or $fontName = 'Andale Mono'
            )">
            <phrase>
                <xsl:attribute name="role">
                    <xsl:value-of select="concat('font-name: ', 'Symbol')"/>
                </xsl:attribute>
                <xsl:apply-templates/>
            </phrase>
        </xsl:when>

        <xsl:when test="starts-with($textPosition, 'sup')">
            <superscript><xsl:apply-templates/></superscript>
        </xsl:when>
        <xsl:when test="starts-with($textPosition, 'sub')">
            <subscript><xsl:apply-templates/></subscript>
        </xsl:when>

        <xsl:when test="@text:style-name='Citation' or $parentStyleName='Citation'">
            <quote><xsl:apply-templates/></quote>
      </xsl:when>

      <xsl:when test="@text:style-name='Source Text'
	or @text:style-name='Example'
	or @text:style-name='Teletype'
	or @text:style-name='Literal'
	or $parentStyleName='Source Text'
	or $parentStyleName='Example'
	or $parentStyleName='Teletype'
	or $parentStyleName='Literal'">
	<literal><xsl:apply-templates/></literal>
      </xsl:when>

      <xsl:when test="@text:style-name='User Entry'
	or $parentStyleName='User Entry'
	or @text:style-name='Userentry'
	or $parentStyleName='Userentry'">
	<userinput><xsl:apply-templates/></userinput>
      </xsl:when>

      <xsl:when test="@text:style-name='Filename'
	or $parentStyleName='Filename'">
	<filename><xsl:apply-templates/></filename>
      </xsl:when>

      <xsl:when test="@text:style-name='Computeroutput'
	or $parentStyleName='Computeroutput'">
	<computeroutput><xsl:apply-templates/></computeroutput>
      </xsl:when>

      <xsl:when test="@text:style-name='Command'
	or $parentStyleName='Command'">
	<command><xsl:apply-templates/></command>
      </xsl:when>

      <xsl:when test="@text:style-name='Option'
	or $parentStyleName='Option'">
	<option><xsl:apply-templates/></option>
      </xsl:when>

      <xsl:when test="@text:style-name='Acronym'
	or $parentStyleName='Acronym'">
	<acronym><xsl:apply-templates/></acronym>
      </xsl:when>

      <xsl:when test="@text:style-name='Lineannotation'
	or $parentStyleName='Lineannotation'">
	<lineannotation><xsl:apply-templates/></lineannotation>
      </xsl:when>

      <xsl:when test="@text:style-name='Replaceable'
	or $parentStyleName='Replaceable'">
	<replaceable><xsl:apply-templates/></replaceable>
      </xsl:when>

      <xsl:when test="@text:style-name='Attribution'
	or $parentStyleName='Attribution'">
	<attribution><xsl:apply-templates/></attribution>
      </xsl:when>

      <xsl:when test="@text:style-name='Honorific'
	or $parentStyleName='Honorific'">
	<honorific><xsl:apply-templates/></honorific>
      </xsl:when>

      <xsl:when test="@text:style-name='Firstname'
	or $parentStyleName='Firstname'">
	<firstname><xsl:apply-templates/></firstname>
      </xsl:when>

      <xsl:when test="@text:style-name='Othername'
	or $parentStyleName='Othername'">
	<othername><xsl:apply-templates/></othername>
      </xsl:when>

      <xsl:when test="@text:style-name='Surname'
	or $parentStyleName='Surname'">
	<surname><xsl:apply-templates/></surname>
      </xsl:when>

      <xsl:when test="@text:style-name='Lineage'
	or $parentStyleName='Lineage'">
	<lineage><xsl:apply-templates/></lineage>
      </xsl:when>

      <xsl:when test="@text:style-name='Year'
	or $parentStyleName='Year'">
	<year><xsl:apply-templates/></year>
      </xsl:when>

      <xsl:when test="@text:style-name='Holder'
	or $parentStyleName='Holder'">
	<holder><xsl:apply-templates/></holder>
      </xsl:when>

      <xsl:when test="(@text:style-name='Email'
	or $parentStyleName='Email')">
	<email><xsl:apply-templates/></email>
      </xsl:when>

      <xsl:when test="@text:style-name='Jobtitle'
	or $parentStyleName='Jobtitle'">
	<jobtitle><xsl:apply-templates/></jobtitle>
      </xsl:when>

      <xsl:when test="@text:style-name='Orgname'
	or $parentStyleName='Orgname'">
	<orgname><xsl:apply-templates/></orgname>
      </xsl:when>

      <xsl:when test="@text:style-name='Citation Title'
	or $parentStyleName='Citation Title'">
	<citetitle><xsl:apply-templates/></citetitle>
      </xsl:when>

      <xsl:otherwise>
	<xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
  FOOTNOTES
  =========
  -->

<xsl:template match="text:note">
    <footnote>
        <xsl:attribute name="id"><xsl:value-of select="@text:id"/></xsl:attribute>
        <xsl:if test="text:note-citation[@text:label]">
            <xsl:attribute name="label">
                <xsl:value-of select="text:note-citation/@text:label"/>
            </xsl:attribute>
        </xsl:if>
        <xsl:apply-templates select="text:note-body/*" mode="footnote"/>

    </footnote>
</xsl:template>

<xsl:template match="text:note-citation"/>

<xsl:template match="*" mode="footnote">
    <xsl:call-template name="allTags">
        <xsl:with-param name="source" select="'footnote'"/>
    </xsl:call-template>
</xsl:template>

<xsl:template match="text:note-ref">
    <footnoteref>
        <xsl:attribute name="linkend">
            <xsl:value-of select="@text:ref-name"/>
        </xsl:attribute>
    </footnoteref>
</xsl:template>

  <!--
  HYPERLINKS AND CROSS REFERENCES
  ===============================
  -->
<!-- Gestion des liens dans les refs biblio -->
<xsl:template match="text:bibliography-mark">
    <xsl:variable name="abbrev" select="@text:identifier"/>
    <xsl:if test="string($abbrev)">
        <link>
            <xsl:attribute name="linkend"><xsl:value-of select="generate-id(current())"/></xsl:attribute>
            <xsl:text>[</xsl:text>
            <xsl:value-of select="$abbrev"/>
            <xsl:text>]</xsl:text>
        </link>
    </xsl:if>
</xsl:template>



  <!-- The id attribute goes to the tags parent -->
  <xsl:template match="text:reference-mark|text:bookmark|
    text:reference-mark-start|text:bookmark-start">
    <xsl:choose>
      <xsl:when test="starts-with(@text:name, 'co.')">
	<!-- generate a callout ref co -->
	<co>
	  <xsl:attribute name="id">
	    <xsl:value-of select="@text:name"/>
	  </xsl:attribute>
	</co>
      </xsl:when>
      <xsl:otherwise>
	<!-- generate a phrase ref -->
    <!-- en commentaire par MT
	<phrase>
	  <xsl:attribute name="id">
	    <xsl:value-of select="@text:name"/>
	  </xsl:attribute>
	</phrase>
           -->
    <!-- rajouter par MT -->
    <!-- on ajoute l'attribut Id au noeud uniquement s'il ne s'agit pas d'un titre
           dans le cas d'un titre, le lien Id est ajoute au niveau superieur par le template GenereIDSection -->
   	<xsl:if test="not(name(..) = 'text:h')">
            <phrase>
              <xsl:attribute name="id">
                <xsl:value-of select="@text:name"/>
              </xsl:attribute>
            </phrase>
	</xsl:if>
    <!-- fin rajout MT -->

      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<xsl:template match="text:reference-mark-end|text:bookmark-end"/>

<xsl:template match="text:reference-ref|text:bookmark-ref|
    text:sequence-ref">
    <xsl:choose>
      <xsl:when test="starts-with(@text:ref-name, 'co.')">
	<!-- generate a nothing, will be used by callout -->
      </xsl:when>
      <xsl:otherwise>
	<link>
	  <xsl:attribute name="linkend">
	    <xsl:value-of select="@text:ref-name"/>
	  </xsl:attribute>
	  <xsl:apply-templates/>
	</link>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<xsl:template match="text:a">
    <xsl:choose>
      <xsl:when test="text:span/@text:style-name='Email'">
	<xsl:apply-templates/>
      </xsl:when>
      <xsl:otherwise>
	<ulink>
	  <xsl:attribute name="url">
	    <xsl:value-of select="@xlink:href"/>
	  </xsl:attribute>
	  <xsl:attribute name="type">
	    <xsl:value-of select="@office:target-frame-name"/>
	  </xsl:attribute>
	  <xsl:apply-templates/>
	</ulink>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
  INDEX TERMS
  ===========

  Examples of OOo markup:
  Le <text:alphabetical-index-mark-start text:id="IMark1219739116" text:key1="web" text:key2="www"/>W3C<text:alphabetical-index-mark-end text:id="IMark1219739116"/> est une instance de normalisation des standards du <text:alphabetical-index-mark-start text:id="IMark1219743716" text:key1="web" text:key2="www"/>Web<text:alphabetical-index-mark-end text:id="IMark1219743716"/>.
  <text:alphabetical-index-mark-start text:id="IMark1219744572" text:key1="corba"/>CORBA<text:alphabetical-index-mark-end text:id="IMark1219744572"/> est aussi un standard.

  Outputs the text between text:alphabetical-index-mark-start and
  text:alphabetical-index-mark-end.
  -->
  <xsl:template name="indexTerm" match="text:alphabetical-index-mark-start">
    <xsl:variable name="indexId" select="@text:id"/>
    <xsl:variable name="indexMarkEnd"
      select="text:alphabetical-index-mark-end[@text:id = $indexId]"/>
    <!--
    The text is what follows the text:alphabetical-index-mark-start and which
    following text:alphabetical-index-mark-end is the computed indexMarkEnd.
    -->
    <xsl:variable name="indexText"
      select="following-sibling::node()[not($indexMarkEnd) or
      generate-id(following-sibling::text:alphabetical-index-mark-end[1])
      = generate-id($indexMarkEnd)
      ]"/>
    <xsl:if test="$indexText">
      <indexterm>
<!--	<xsl:variable name="primary" select="$indexText"/>
	<xsl:variable name="secondary" select="@text:key1"/> -->
	<xsl:variable name="secondary" select="$indexText"/>
	<xsl:variable name="primary" select="@text:key1"/>
	<xsl:variable name="tertiary" select="@text:key2"/>
	<xsl:element name="primary">
	  <xsl:value-of select="$primary"/>
	</xsl:element>
	<xsl:if test="string($secondary)">
	  <xsl:element name="secondary">
	    <xsl:value-of select="$secondary"/>
	  </xsl:element>
	</xsl:if>
	<xsl:if test="string($tertiary)">
	  <xsl:element name="tertiary">
	    <xsl:value-of select="$tertiary"/>
	  </xsl:element>
	</xsl:if>
      </indexterm>
    </xsl:if>
  </xsl:template>


  <!--
  ======
  FRAMES
  ======
  -->

  <!-- Frame's position treatment -->

  <xsl:template match="draw:text-box"/>
  <xsl:template match="draw:a[draw:text-box]"/>

  <xsl:template match="draw:image[../@text:anchor-type='page']"/>
  <xsl:template match="draw:image[(../@text:anchor-type='paragraph')
    or (../@text:anchor-type='char')]"/>

  <xsl:template match="draw:a[draw:image[../@text:anchor-type='page']]"/>
  <xsl:template match="draw:a[draw:image[(../@text:anchor-type='paragraph')
    or (../@text:anchor-type='char')]]"/>

  <!--
  multimedia.top and multimedia.bottom have the same code, there only difference
  are:
  - the calledPos parameter
  - the fact that OLE objects are only treated in the first template, otherwise
  we get them twice
  -->
<xsl:template name="multimedia.top">
    <xsl:param name="calledPos" select="'top'"/>
    <!--<DEBUG>MultimediaTop sur : <xsl:value-of select="name(current())"/></DEBUG>-->
    <xsl:apply-templates
      select=".//draw:image[(../@text:anchor-type='paragraph'
      or ../@text:anchor-type='char')
      and not(ancestor::draw:text-box)]
      | .//draw:text-box"
      mode="extract">
      <xsl:with-param name="calledPos" select="$calledPos"/>
    </xsl:apply-templates>

<!-- Original
    <xsl:apply-templates
      select=".//draw:image[(../@text:anchor-type='paragraph'
      or ../@text:anchor-type='char')
      and not(ancestor::draw:text-box)]
      | .//draw:object[not(ancestor::draw:text-box)]
      | .//draw:object-ole[not(ancestor::draw:text-box)]
      | .//draw:text-box"
      mode="extract">
      <xsl:with-param name="calledPos" select="$calledPos"/>
    </xsl:apply-templates>
-->
    
</xsl:template>


<xsl:template name="multimedia.bottom">
    <xsl:param name="calledPos" select="'bottom'"/>
    <!--<DEBUG>MultimediaBottom sur : <xsl:value-of select="name(current())"/></DEBUG>-->

    <xsl:apply-templates
      select=".//draw:image[(../@text:anchor-type='paragraph'
      or ../text:anchor-type='as-char')
      and not(ancestor::draw:text-box)]
      | .//draw:text-box"
      mode="extract">
      <xsl:with-param name="calledPos" select="$calledPos"/>
    </xsl:apply-templates>
</xsl:template>

  <!-- Frames - Dispatch -->

<xsl:template match="draw:text-box" mode="extract">
    <xsl:param name="calledPos"/>

    <xsl:variable name="StyleMM" select=".//draw:frame/@draw:style-name"/>
    <xsl:variable name="style" select="/office:document/office:automatic-styles/style:style[@style:name=$StyleMM]"/>

    <xsl:variable name="currentPos">
    <xsl:choose>
        <xsl:when test="$style/style:graphic-properties/@style:vertical-pos!=''">
            <xsl:value-of select="$style/style:graphic-properties/@style:vertical-pos"/>
        </xsl:when>
        <xsl:otherwise>top</xsl:otherwise>
    </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="parentStyleName"
      select="$style/@style:parent-style-name"/>

    <!--<DEBUG>DRAW:TEXT-BOX-EXTRACT :
        Called-pos :<xsl:value-of select="$calledPos"/>
        Current-pos :<xsl:value-of select="$currentPos"/>
        StyleMM :<xsl:value-of select="$StyleMM"/>
        parentStyleName :<xsl:value-of select="$parentStyleName"/>
    </DEBUG>-->

    <xsl:if test="$calledPos=$currentPos or
      ($calledPos='top' and $currentPos!='bottom')">
        <xsl:if test="$parentStyleName='Note'">
            <xsl:call-template name="note"/>
        </xsl:if>
        <xsl:if test="$parentStyleName='Frame' or $parentStyleName='Graphics' or $parentStyleName='Formula'">
            <xsl:call-template name="figure"/>
        </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- Frames - Figure -->

  <xsl:template name="figure">
    <!--<DEBUG>figure sur : <xsl:value-of select="name(current())"/></DEBUG>-->
    <figure>
      <xsl:attribute name="id">
            <xsl:value-of select="text:p/text:sequence/@text:ref-name"/>
      </xsl:attribute>
      <title>
            <xsl:apply-templates select="text:p"/>
      </title>
      <mediaobject>
        <xsl:if test=".//draw:frame[(@text:anchor-type='paragraph')
              or (@text:anchor-type='as-char')]">
            <xsl:apply-templates select=".//draw:image | .//draw:object | .//draw:object-ole" mode="extract">
                <xsl:with-param name="inbox" select="1"/>
            </xsl:apply-templates>
        </xsl:if>
<!-- remplace par script ci-dessus
            <xsl:apply-templates select="
              .//draw:image[(@text:anchor-type='paragraph')
              or (@text:anchor-type='as-char')]
              |
              .//draw:object[(@text:anchor-type='paragraph')
              or (@text:anchor-type='as-char')]
              |
              .//draw:object-ole[(@text:anchor-type='paragraph')
              or (@text:anchor-type='as-char')]
              "
              mode="extract">
            <xsl:with-param name="inbox" select="1"/>
            </xsl:apply-templates>
-->
      </mediaobject>
    </figure>
  </xsl:template>

  <!-- Frames - Note -->

  <xsl:template name="note">
    <xsl:variable name="parentStyleName"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/@text:style-name)]/
      @style:parent-style-name"/>
    <note>
      <xsl:apply-templates select="text:p[@text:style-name='Heading'
	or $parentStyleName='Heading']"
	mode="includeTitle"/>
      <xsl:apply-templates mode="frame"/>
    </note>
  </xsl:template>

  <xsl:template match="*" mode="frame">
    <xsl:call-template name="allTags">
      <xsl:with-param name="source" select="'frame'"/>
    </xsl:call-template>
  </xsl:template>

  <!--
  ======
  IMAGES
  ======
  -->
<xsl:template match="draw:image[not(preceding-sibling::draw:object)]" mode="extract">
    <xsl:param name="inbox"/>
    <xsl:param name="calledPos"/>
    <xsl:variable name="StyleMM" select="../@draw:style-name"/>

    <xsl:variable name="style" select="/office:document/office:automatic-styles/style:style[@style:name=$StyleMM]"/>
    <xsl:variable name="parentStyleName" select="$style/@style:parent-style-name"/>
    <xsl:variable name="currentPos">
      <xsl:choose>
	<xsl:when test="$style/style:graphic-properties/@style:vertical-pos!=''">
	  <xsl:value-of select="$style/style:graphic-properties/@style:vertical-pos"/>
	</xsl:when>
	<xsl:otherwise>top</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!--<DEBUG>draw:image sur : <xsl:value-of select="name(current())"/></DEBUG>-->

<!--
    <DEBUG>DRAW:IMAGE-EXTRACT :
        Called-pos :<xsl:value-of select="$calledPos"/>
        Current-pos :<xsl:value-of select="$currentPos"/>
        StyleMM :<xsl:value-of select="$StyleMM"/>
        parentStyleName :<xsl:value-of select="$parentStyleName"/>
        Inbox :<xsl:value-of select="$inbox"/>
    </DEBUG>
-->
    <xsl:choose>
        <xsl:when test="substring-before(@xlink:href,'/')='#Pictures'
            or office:binary-data">
                <xsl:if test="$calledPos=$currentPos or ($calledPos='top' and $currentPos!='bottom')">
                <para>WARNING ! Incorporated graphics are not supported.</para>
            </xsl:if>
        </xsl:when>
        <xsl:otherwise>
            <xsl:choose>
                <xsl:when test="$inbox=1">
                    <xsl:call-template name="image"/>
                </xsl:when>
            <xsl:otherwise>
                <xsl:if test="$calledPos=$currentPos or ($calledPos='top' and $currentPos!='bottom')">
                    <mediaobject>
                        <xsl:call-template name="image"/>
                    </mediaobject>
                </xsl:if>
            </xsl:otherwise>
            </xsl:choose>
        </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<xsl:template name="image">
    <imageobject>
        <imagedata>
            <xsl:attribute name="fileref">
                <xsl:value-of select="@xlink:href"/>
            </xsl:attribute>
            <xsl:attribute name="width">
                <xsl:value-of select="../@svg:width"/>
            </xsl:attribute>
            <xsl:attribute name="depth">
                <xsl:value-of select="../@svg:height"/>
            </xsl:attribute>
        </imagedata>
    </imageobject>
    <xsl:apply-templates/>
</xsl:template>

<xsl:template name="inlineobject">
    <imageobject>
        <imagedata>
            <xsl:attribute name="fileref">
                <xsl:value-of select="concat('images/', ../@draw:name, '.png')"/>
            </xsl:attribute>
            <xsl:attribute name="width">
                <xsl:value-of select="../@svg:width"/>
            </xsl:attribute>
            <xsl:attribute name="depth">
                <xsl:value-of select="../@svg:height"/>
            </xsl:attribute>
        </imagedata>
    </imageobject>
    <xsl:apply-templates/>
</xsl:template>



<xsl:template match="text:p[@text:style-name='Illustration']|
    text:p[@text:style-name='Figure']">
    <xsl:choose>
      <xsl:when test="text:sequence">
	<xsl:apply-templates
	  select="text:sequence/following-sibling::node()"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!-- Inlines images -->
<xsl:template match="draw:image[(../@text:anchor-type='as-char') and not(preceding-sibling::draw:object)]">
    <!--<DEBUG>Inlines images sur : <xsl:value-of select="name(current())"/></DEBUG>-->
    <inlinemediaobject>
      <xsl:call-template name="image"/>
      <xsl:apply-templates select="following-sibling::svg:desc" mode="inlinemediaobject"/>
    </inlinemediaobject>
</xsl:template>

<!-- Inlines object -->
<xsl:template match="draw:image[(../@text:anchor-type='as-char') and (preceding-sibling::draw:object)]">
    <!--<DEBUG>Inlines object sur : <xsl:value-of select="name(current())"/></DEBUG>-->
    <inlinemediaobject>
      <xsl:call-template name="inlineobject"/>
      <xsl:apply-templates select="following-sibling::svg:desc" mode="inlinemediaobject"/>
    </inlinemediaobject>
</xsl:template>

  <xsl:template match="draw:a[draw:image[../@text:anchor-type='as-char']]">
    <ulink>
      <xsl:attribute name="url">
	<xsl:value-of select="@xlink:href"/>
      </xsl:attribute>
      <xsl:if test="@office:target-frame-name!=''">
	<xsl:attribute name="type">
	  <xsl:value-of select="@office:target-frame-name"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates/>
    </ulink>
  </xsl:template>

  <xsl:template match="svg:desc" mode="inlinemediaobject">
    <textobject><phrase><xsl:apply-templates/></phrase></textobject>
  </xsl:template>
  <xsl:template match="svg:desc"/>

  <!--
  ====================
  OBJECTS, OLE OBJECTS
  ====================

  We treat objects and OLE objects as images
  -->
<xsl:template match="draw:object|draw:object-ole" mode="extract">
    <!--
    Tells wether this object is contained within a box (a text-box for example)
    -->
    <xsl:param name="inbox"/>

    <!--<DEBUG>draw:object|draw:object-ole sur : <xsl:value-of select="name(current())"/>
    inbox <xsl:value-of select="$inbox"/></DEBUG>-->

    <xsl:variable name="imageref" select="concat('images/', ../@draw:name, '.png')"/>
    <xsl:choose>
        <xsl:when test="$inbox = 1">
            <xsl:call-template name="inlineobject"/>
            <!--
            <xsl:call-template name="objectImage">
              <xsl:with-param name="fileref" select="$imageref"/>
            </xsl:call-template>
            -->
        </xsl:when>
        <xsl:otherwise>
            <mediaobject>
                <xsl:call-template name="inlineobject"/>
            </mediaobject>
        <!--
            <mediaobject>
                <xsl:call-template name="objectImage">
                    <xsl:with-param name="fileref" select="$imageref"/>
                </xsl:call-template>
            </mediaobject>
            -->
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<!-- n'est plus utilise
<xsl:template name="objectImage">
    <xsl:param name="fileref"/>
    <imageobject>
      <imagedata>
	<xsl:attribute name="fileref">
	  <xsl:value-of select="$fileref"/>
	</xsl:attribute>
      </imagedata>
    </imageobject>
    <xsl:apply-templates/>
  </xsl:template>
-->
  <!--
  ======
  TABLES
  ======
  -->
<xsl:template match="table:table" name="table">
    <xsl:param name="titlePosition" select="''"/>
    <xsl:param name="colsListBrut">
        <xsl:call-template name="colsList"/>
    </xsl:param>

    <!-- Retrait des doublons et ordonnancement de la liste -->
    <xsl:param name="fineColsList">
        <xsl:call-template name="fineColsList">
            <xsl:with-param name="colsListBrut" select="$colsListBrut"/>
        </xsl:call-template>
    </xsl:param>
    <xsl:param name="colsList">
        <xsl:call-template name="ascendantcolsList">
            <xsl:with-param name="colsList" select="$fineColsList"/>
        </xsl:call-template>
    </xsl:param>
    <xsl:param name="colsNumber2">
        <xsl:call-template name="colsNumber2">
            <xsl:with-param name="colsList" select="$colsList"/>
        </xsl:call-template>
    </xsl:param>

<!--
    <DEBUG>TABLE:TABLE :
        titlePosition :<xsl:value-of select="$titlePosition"/>
        colsListBrut :<xsl:value-of select="count($colsListBrut)"/>
        fineColsList :<xsl:value-of select="count($fineColsList)"/>
        colsList :<xsl:value-of select="($colsList)"/>
        colsNumber2 :<xsl:value-of select="$colsNumber2"/>
    </DEBUG>
-->


    <xsl:choose>
        <xsl:when test="following-sibling::*[1]/text:sequence/@text:name='Table'">
            <xsl:call-template name="formalTable">
                <xsl:with-param name="titlePosition" select="'after'"/>
                <xsl:with-param name="colsList" select="$colsList"/>
                <xsl:with-param name="colsNumber" select="$colsNumber2"/>
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
            <xsl:choose>
                <xsl:when test="preceding-sibling::*[1]/text:sequence/@text:name='Table'">
                    <xsl:call-template name="formalTable">
                        <xsl:with-param name="titlePosition" select="'before'"/>
                        <xsl:with-param name="colsList" select="$colsList"/>
                        <xsl:with-param name="colsNumber" select="$colsNumber2"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="informalTable">
                        <xsl:with-param name="colsList" select="$colsList"/>
                        <xsl:with-param name="colsNumber" select="$colsNumber2"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>



  <!-- Tables - "Formal" Table -->
  <xsl:template name="formalTable">
    <xsl:param name="titlePosition"/>
    <xsl:param name="colsList"/>
    <xsl:param name="colsNumber"/>
    <table>
      <!-- Title and 'id' attribute -->
      <xsl:if test="$titlePosition='before'">
	<xsl:attribute name="id">
	  <xsl:value-of
	    select="preceding-sibling::*[1]/text:sequence/@text:ref-name"/>
	</xsl:attribute>
	<xsl:apply-templates select="preceding-sibling::*[1]" mode="tableTitle"/>
      </xsl:if>
      <xsl:if test="$titlePosition='after'">
	<xsl:attribute name="id">
	  <xsl:value-of
	    select="following-sibling::*[1]/text:sequence/@text:ref-name"/>
	</xsl:attribute>
	<xsl:apply-templates select="following-sibling::*[1]" mode="tableTitle"/>
      </xsl:if>
      <tgroup>
	<xsl:attribute name="cols">
	  <xsl:value-of select="$colsNumber"/>
	</xsl:attribute>
	<xsl:call-template name="colspecAttrib">
	  <xsl:with-param name="colsList" select="$colsList"/>
	  <xsl:with-param name="colsNumber" select="$colsNumber"/>
	</xsl:call-template>
	<xsl:apply-templates select="table:table-row|table:table-header-rows/table:table-row">
	  <xsl:with-param name="colsList" select="$colsList"/>
	</xsl:apply-templates>
      </tgroup>
    </table>
  </xsl:template>


  <!-- Table - Formaltable title -->
<xsl:template match="*[text:sequence]" mode="tableTitle">
    <title>
        <xsl:apply-templates select="text:sequence/following-sibling::node()"/>
    </title>
</xsl:template>


  <!-- Tables - InformalTables -->
<xsl:template name="informalTable">
    <xsl:param name="colsList"/>
    <xsl:param name="colsNumber"/>

<!--
    <DEBUG>informalTable :
        colsList :<xsl:value-of select="($colsList)"/>
        colsNumber :<xsl:value-of select="$colsNumber"/>
    </DEBUG>
-->
    <informaltable>
        <tgroup>
            <xsl:attribute name="cols">
                <xsl:value-of select="$colsNumber"/>
            </xsl:attribute>
            <xsl:call-template name="colspecAttrib">
                <xsl:with-param name="colsList" select="$colsList"/>
                <xsl:with-param name="colsNumber" select="$colsNumber"/>
            </xsl:call-template>
            <xsl:apply-templates select="table:table-row|table:table-header-rows/table:table-row">
                <xsl:with-param name="colsList" select="$colsList"/>
            </xsl:apply-templates>
        </tgroup>
    </informaltable>
</xsl:template>

  <!--
  =================
  COLUMNS & COLSPEC
  =================
  -->

  <!-- Tables - Colspec attribute -->
<xsl:template name="colspecAttrib">
    <xsl:param name="colsList"/>
    <xsl:param name="colsNumber"/>
    <xsl:param name="val1" select="0"/>
    <xsl:param name="val2" select="substring-before($colsList,';')"/>
    <xsl:param name="width">
      <xsl:call-template name="roundValue">
	<xsl:with-param name="inputValue" select="$val2 - $val1"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="cycle" select="1"/>
    <xsl:if test="$colsNumber >= $cycle">
      <colspec>
	<xsl:attribute name="colname">
	  <xsl:value-of select="concat('c',$cycle)"/>
	</xsl:attribute>
	<xsl:attribute name="colwidth">
	  <xsl:value-of select="concat($width,$measureUnit)"/>
	</xsl:attribute>
      </colspec>
      <xsl:call-template name="colspecAttrib">
	<xsl:with-param name="colsList" select="substring-after($colsList,';')"/>
	<xsl:with-param name="cycle" select="$cycle + 1"/>
	<xsl:with-param name="val1" select="$val2"/>
	<xsl:with-param name="colsNumber" select="$colsNumber"/>
      </xsl:call-template>
    </xsl:if>
</xsl:template>

  <!--
  Tables - ascendantcolsList, colsListtrunc, littleElt
  Ordonnent de facon ascendante les elements de 'colsList"
  -->
<xsl:template name="ascendantcolsList">
    <xsl:param name="colsList"/>
    <xsl:param name="eltNumber">
      <xsl:call-template name="colsNumber2">
	<xsl:with-param name="colsList" select="$colsList"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="littleElt">
      <xsl:call-template name="littleElt">
	<xsl:with-param name="colsListTest" select="$colsList"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="colsListtrunc">
      <xsl:call-template name="colsListtrunc">
	<xsl:with-param name="colsListTest" select="$colsList"/>
	<xsl:with-param name="littleElt" select="$littleElt"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="newList" select="''"/>
    <xsl:choose>
      <xsl:when test="not(contains($colsListtrunc,';'))">
	<xsl:value-of select="concat($newList, $littleElt,';')"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="ascendantcolsList">
	  <xsl:with-param name="newList" select="concat($newList, $littleElt,';')"/>
	  <xsl:with-param name="colsList" select="$colsListtrunc"/>
	</xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="colsListtrunc">
    <xsl:param name="colsListTest"/>
    <xsl:param name="littleElt"/>
    <xsl:param name="eltCompare" select="substring-before($colsListTest,';')"/>
    <xsl:param name="fragmentBefore" select="''"/>
    <xsl:param name="fragmentAfter" select="substring-after($colsListTest,';')"/>
    <xsl:choose>
      <xsl:when test="($littleElt != $eltCompare) and ($fragmentAfter != '')">
	<xsl:call-template name="colsListtrunc">
	  <xsl:with-param name="fragmentBefore">
	    <xsl:value-of select="concat($fragmentBefore,';',$eltCompare)"/>
	  </xsl:with-param>
	  <xsl:with-param name="littleElt" select="$littleElt"/>
	  <xsl:with-param name="colsListTest" select="$fragmentAfter"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:choose>
	  <xsl:when test="starts-with(concat($fragmentBefore,';',$fragmentAfter),';')">
	    <xsl:value-of select="substring-after(concat($fragmentBefore,';',$fragmentAfter),';')"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of select="concat($fragmentBefore,';',$fragmentAfter)"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="littleElt">
    <xsl:param name="colsListTest"/>
    <xsl:param name="eltBaseTest" select="substring-before($colsListTest,';')"/>
    <xsl:param name="eltNumber">
      <xsl:call-template name="colsNumber2">
	<xsl:with-param name="colsList" select="$colsListTest"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="actualMinDiff" select="$eltBaseTest"/>
    <xsl:choose>
      <xsl:when test="$eltNumber > 0">
	<xsl:call-template name="littleElt">
	  <xsl:with-param name="actualMinDiff">
	    <xsl:choose>
	      <xsl:when test="$actualMinDiff > $eltBaseTest">
		<xsl:value-of select="$eltBaseTest"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="$actualMinDiff"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:with-param>
	  <xsl:with-param name="colsListTest" select="substring-after($colsListTest,';')"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$actualMinDiff"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>


  <!--
  Tables - fineColsList et testDoublon
  Elimine les blancs et les doublon de "colsList"
  -->
<xsl:template name="fineColsList">
    <xsl:param name="colsListBrut"/>
    <xsl:param name="eltNumber">
      <xsl:call-template name="colsNumber2">
	<xsl:with-param name="colsList" select="$colsListBrut"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="colsListTest" select="substring-after($colsListBrut,';')"/>
    <xsl:param name="eltBaseTest" select="normalize-space(substring-before($colsListBrut,';'))"/>
    <xsl:param name="eltTestresult"><!-- 'True' if this is a double -->
      <xsl:call-template name="testDoublon">
	<xsl:with-param name="colsListTest" select="$colsListTest"/>
	<xsl:with-param name="eltBaseTest" select="$eltBaseTest"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="newList" select="''"/>
    <xsl:choose>
      <xsl:when test="$eltNumber = 1">
	<xsl:value-of select="concat(normalize-space($eltBaseTest),';',$newList)"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="fineColsList">
	  <xsl:with-param name="newList">
	    <xsl:choose>
	      <xsl:when test="$eltTestresult = 'false'">
		<xsl:value-of select="concat($eltBaseTest,';', $newList)"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="$newList"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:with-param>
	  <xsl:with-param name="colsListBrut" select="$colsListTest"/>
	</xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="testDoublon">
    <xsl:param name="colsListTest"/>
    <xsl:param name="eltNumber">
      <xsl:call-template name="colsNumber2">
	<xsl:with-param name="colsList" select="$colsListTest"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="eltBaseTest"/>
    <xsl:param name="eltListTest" select="normalize-space(substring-before($colsListTest,';'))"/>

    <xsl:choose>
      <xsl:when test="$eltBaseTest = $eltListTest">
	<xsl:value-of select="'true'"/>
      </xsl:when>
      <xsl:when test="$eltListTest =''">
	<xsl:value-of select="'false'"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:choose>
	  <xsl:when test="$eltNumber >= 1">
	    <xsl:call-template name="testDoublon">
	      <xsl:with-param name="colsListTest" select="substring-after($colsListTest,';')"/>
	      <xsl:with-param name="eltBaseTest" select="$eltBaseTest"/>
	    </xsl:call-template>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of select="'false'"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!--
  Tables - colsNumber2
  Cree les numeros (1, 2, etc.) qui formeront les element de colspec (c1,c2, etc)
  -->
<xsl:template name="colsNumber2">
    <xsl:param name="colsList"/>
    <xsl:param name="cycle" select="0"/>
    <xsl:choose>
      <xsl:when test="contains($colsList,';')">
	<xsl:call-template name="colsNumber2">
	  <xsl:with-param name="colsList" select="substring-after($colsList,';')"/>
	  <xsl:with-param name="cycle" select="$cycle + 1"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$cycle"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!-- Tables - colsList -->

<xsl:template name="colsList">
    <xsl:param name="stylesURI" select="/office:document/office:automatic-styles/style:style"/>
    <xsl:param name="repeatCol"/>
    <xsl:param name="cellAncestorNbr"/>
    <xsl:for-each select="descendant::table:table-column">
        
        <!--
        <xsl:variable name="mmm" select="@table:style-name"/>
        <xsl:variable name="nnn" select="$stylesURI[@style:name = $mmm]"/>
        <xsl:message>
        template name="colsList"
        noeud pere : <xsl:value-of select="../@table:name"/>
        table:number-columns-repeated : <xsl:value-of select="@table:number-columns-repeated"/>
        Style pere : <xsl:value-of select="../@table:style-name"/>
        Style noeud : <xsl:value-of select="$mmm"/>
        stylesURI : <xsl:value-of select="$stylesURI"/>
        Style trouve : <xsl:value-of select="$nnn/@style:family"/>
        Style trouve : <xsl:value-of select="$nnn/style:table-column-properties/@style:column-width"/>
        </xsl:message>
        -->

        <xsl:call-template name="colPosition">
            <xsl:with-param name="origineValue">
                  <!-- retourne la distance d'origine de la sous-table
                  depuis la cellule-ancetre la plus elevee -->
                <xsl:choose>
                    <xsl:when test="parent::table:table[@table:is-sub-table = 'true']">
                        <xsl:call-template name="subtableOrigine">
                            <xsl:with-param name="cellAncestorNbr" select="count(ancestor::table:table-cell)"/>
                            <xsl:with-param name="stylesURI" select="$stylesURI"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>
                </xsl:choose>
            </xsl:with-param>
            <xsl:with-param name="stylesURI" select="$stylesURI"/>
            <xsl:with-param name="repeatCol">
                <xsl:choose>
                    <xsl:when test="@table:number-columns-repeated">
                      <xsl:value-of select="@table:number-columns-repeated"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="1"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:for-each>
</xsl:template>

  <!--
  Determine le distance a laquelle debute la sous-table / a la table
  pour la colonne en cours
  -->
<xsl:template name="subtableOrigine">
    <xsl:param name="cumulOrigineValue" select="0"/>
    <xsl:param name="cellAncestorNbr"/>
    <xsl:param name="stylesURI"/>
    <xsl:param name="precedingCellNumber"
      select="count(ancestor::table:table-cell[$cellAncestorNbr]
      /preceding-sibling::table:table-cell) -
      count(ancestor::table:table-cell[$cellAncestorNbr]
      /preceding-sibling::table:table-cell[@table:number-columns-spanned]) +
      sum(ancestor::table:table-cell[$cellAncestorNbr]/
      preceding-sibling::table:table-cell/@table:number-columns-spanned)"
      />

    <xsl:param name="columnValue">
        <xsl:choose>
            <xsl:when test="$precedingCellNumber > 0">
                <xsl:apply-templates
                    select="ancestor::table:table-cell[$cellAncestorNbr]/parent::table:table-row/
                    parent::table:table/child::table:table-column[1]|
                    ancestor::table:table-cell[$cellAncestorNbr]/parent::table:table-row/
                    parent::table:table-header-rows/parent::table:table/child::table:table-column[1]"
                    mode="cellOrigine">
                    <xsl:with-param name="precedingCellNumber" select="$precedingCellNumber"/>
                    <xsl:with-param name="stylesURI" select="$stylesURI"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:param>

<!--
<xsl:message>
template name="subtableOrigine"
cellAncestorNbr : <xsl:value-of select="$cellAncestorNbr"/>
precedingCellNumber : <xsl:value-of select="$precedingCellNumber"/>
columnValue : <xsl:value-of select="$columnValue"/>
</xsl:message>
-->
    <!-- Appel de l'ancetre no X -->
    <xsl:choose>
      <xsl:when test="$cellAncestorNbr > 1">
	<xsl:call-template name="subtableOrigine">
	  <xsl:with-param name="cellAncestorNbr" select="$cellAncestorNbr - 1"/>
	  <xsl:with-param name="cumulOrigineValue" select="$cumulOrigineValue + $columnValue"/>
	  <xsl:with-param name="stylesURI" select="$stylesURI"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$cumulOrigineValue + $columnValue"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="table:table-column" mode="cellOrigine" name="cellOrigine">
    <xsl:param name="stylesURI"/>
    <xsl:param name="precedingCellNumber"/>
    <xsl:param name="colName" select="string(@table:style-name)"/>
    
    <xsl:param name="repetingCol">
        <xsl:choose>
            <xsl:when test="@table:number-columns-repeated">
                <xsl:value-of select="@table:number-columns-repeated"/>
            </xsl:when>
            <xsl:otherwise>1</xsl:otherwise>
        </xsl:choose>
    </xsl:param>

    <xsl:param name="colsNamesList" select="''"/>
    <xsl:param name="origineValue" select="0"/>
    <xsl:param name="actualWidth">
        <xsl:value-of select="substring-before($stylesURI[@style:name=$colName]
	/style:table-column-properties/@style:column-width,$measureUnit)"/>
    </xsl:param>
    
<!--
<xsl:message>
template name="cellOrigine"
precedingCellNumber : <xsl:value-of select="$precedingCellNumber"/>
colName : <xsl:value-of select="$colName"/>
colsNamesList : <xsl:value-of select="$colsNamesList"/>
origineValue : <xsl:value-of select="$origineValue"/>
repetingCol : <xsl:value-of select="$repetingCol"/>
actualWidth : <xsl:value-of select="$actualWidth"/>
</xsl:message>
-->
    <xsl:choose>
        <xsl:when test="$repetingCol >= $precedingCellNumber">
            <xsl:value-of select="$origineValue + ($actualWidth * $precedingCellNumber)"/>
        </xsl:when>
        <xsl:otherwise>
            <xsl:apply-templates select="following-sibling::table:table-column[1]" mode="cellOrigine">
                <xsl:with-param name="precedingCellNumber" select="$precedingCellNumber -  $repetingCol"/>
                <xsl:with-param name="colsNamesList" select="concat($colsNamesList,';',$colName)"/>
                <xsl:with-param name="origineValue" select="$origineValue + ($actualWidth * $repetingCol)"/>
                <xsl:with-param name="stylesURI" select="$stylesURI"/>
            </xsl:apply-templates>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="colPosition">
    <!-- externes -->
    <xsl:param name="stylesURI"/>
    <xsl:param name="origineValue"/>
    <xsl:param name="concat"/>
    <xsl:param name="repeatCol"/>
    <xsl:param name="content"/>
    <xsl:param name="precedingColsSum">
        <xsl:choose>
            <xsl:when test="preceding-sibling::table:table-column">
                <xsl:call-template name="precedingColsSum">
                    <xsl:with-param name="stylesURI" select="$stylesURI"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:param>
    <xsl:param name="actualColWidth">
        <xsl:value-of select="
            $stylesURI[@style:name=current()/@table:style-name]/*/@style:column-width
            "/>
    </xsl:param>
    <xsl:param name="colWidthValue">
        <xsl:value-of select="substring-before($actualColWidth,$measureUnit)"/>
    </xsl:param>
    <xsl:param name="colWidthRounded">
        <xsl:call-template name="roundValue">
            <xsl:with-param name="inputValue" select="$origineValue + $precedingColsSum + ($colWidthValue * $repeatCol)"/>
        </xsl:call-template>
    </xsl:param>
    <xsl:value-of select="$colWidthRounded"/>;

<!--
<xsl:message>ColPos origineValue : <xsl:value-of select="$origineValue"/> - repeatCol <xsl:value-of select="$repeatCol"/> - precedingColsSum <xsl:value-of select="$precedingColsSum"/> - actualColWidth <xsl:value-of select="$actualColWidth"/>
</xsl:message>
-->

    <xsl:if test="$repeatCol > 1">
        <xsl:call-template name="colPosition">
            <xsl:with-param name="repeatCol" select="$repeatCol - 1"/>
            <xsl:with-param name="stylesURI" select="$stylesURI"/>
            <xsl:with-param name="origineValue" select="$origineValue"/>
        </xsl:call-template>
    </xsl:if>
</xsl:template>

<xsl:template name="precedingColsSum">
    <!-- externe -->
    <xsl:param name="stylesURI"/>
    <!--interne -->
    <xsl:param name="cpt" select="'1'"/>
    <xsl:param name="cumul" select="'0'"/>
    <xsl:param name="precNodeNumber" select="count(preceding-sibling::table:table-column)"/>

<!--
<xsl:messageprecedingColsSum precNodeNumber : <xsl:value-of select="$precNodeNumber"/>
</xsl:message>
-->

<xsl:param name="content">
      <xsl:choose>
	<xsl:when test="
	  $stylesURI[@style:name=current()/
	  preceding-sibling::table:table-column[$precNodeNumber]/
	  @table:style-name]/
	  */@style:column-width">
	  <xsl:value-of select="
	    $stylesURI[@style:name=current()/
	    preceding-sibling::table:table-column[$precNodeNumber]/
	    @table:style-name]/
	    */@style:column-width"/>
	</xsl:when>
	<xsl:otherwise>0pt</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="repetCols">
      <xsl:choose>
	<xsl:when test="preceding-sibling::table:table-column[$precNodeNumber]/
	  @table:number-columns-repeated">
	  <xsl:value-of select="number(preceding-sibling::table:table-column
	    [$precNodeNumber]/@table:number-columns-repeated)"/>
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="brutValue">
      <xsl:value-of select="substring-before(string($content), $measureUnit)"/>
    </xsl:param>
    <xsl:param name="actualValue" select="$brutValue * $repetCols"/>
    <xsl:if test="$precNodeNumber > 0">
      <xsl:call-template name="precedingColsSum">
	<xsl:with-param name="precNodeNumber" select="$precNodeNumber - 1"/>
	<xsl:with-param name="cumul" select="$cumul + $actualValue"/>
	<xsl:with-param name="stylesURI" select="$stylesURI"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="$precNodeNumber = 1">
      <xsl:value-of select="$actualValue + $cumul"/>
    </xsl:if>
</xsl:template>

  <!--
  ====
  ROWS
  ====
  -->

  <!-- Tables - Rows in table-header -->

<xsl:template match="table:table-header-rows/table:table-row">
    <xsl:param name="colsList"/>
    <xsl:choose>
      <xsl:when test="count(preceding-sibling::table:table-row) != 0"/>
      <xsl:otherwise>
	<thead>
	  <xsl:apply-templates select="current()" mode="pas">
	    <xsl:with-param name="colsList" select="$colsList"/>
	  </xsl:apply-templates>
	</thead>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!-- Tables - Rows directly in table or sub-table (body) -->

<xsl:template match="table:table/table:table-row">
    <xsl:param name="colsList"/>

    <xsl:choose>
      <xsl:when test="count(preceding-sibling::table:table-row) != 0"/>
      <xsl:otherwise>
	<tbody>
	  <xsl:apply-templates select="current()" mode="pas">
	    <xsl:with-param name="colsList" select="$colsList"/>
	  </xsl:apply-templates>
	</tbody>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!-- Tables - process rows -->

<xsl:template match="table:table-row" mode="pas">
    <xsl:param name="colsList"/>
    <xsl:param name="rowID" select="generate-id(current())"/>
    <xsl:call-template name="rowsProcess">
      <xsl:with-param name="colsList" select="$colsList"/>
      <xsl:with-param name="rowID" select="$rowID"/>
    </xsl:call-template>
    <xsl:apply-templates
      select="following-sibling::table:table-row[1]"
      mode="pas">
      <xsl:with-param name="colsList" select="$colsList"/>
    </xsl:apply-templates>
</xsl:template>

<xsl:template name="rowsProcess">
    <xsl:param name="colsList"/>
    <xsl:param name="rowID"/>
    <xsl:param name="maxRowsInSubtablesList">
      <xsl:choose>
	<xsl:when test="table:table-cell/table:table[@table:is-sub-table = 'true']">
	  <xsl:apply-templates
	    select="table:table-cell[table:table[@table:is-sub-table = 'true']][1]"
	    mode="pas"/>
	</xsl:when>
	<xsl:otherwise>1;</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="maxRowsInSubtables">
      <xsl:value-of select="substring-before($maxRowsInSubtablesList,';')"/>
    </xsl:param>
    <xsl:param name="cycle" select="0"/>
    <xsl:param name="lastRow">
      <xsl:choose>
	<xsl:when test="$maxRowsInSubtables = $cycle">yes</xsl:when>
	<xsl:otherwise>no</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:if test="$maxRowsInSubtables > $cycle">
      <row>
	<xsl:apply-templates
	  select="descendant::table:table-cell[not(table:table[@table:is-sub-table = 'true'])]"
	  mode="rowProcess">
	  <xsl:with-param name="cycle" select="$cycle"/>
	  <xsl:with-param name="rowID" select="$rowID"/>
	  <xsl:with-param name="colsList" select="$colsList"/>
	  <xsl:with-param name="lastRow" select="$lastRow"/>
	  <xsl:with-param name="maxRowsInSubtables"
	    select="$maxRowsInSubtables"/>
	</xsl:apply-templates>
      </row>
      <xsl:call-template name="rowsProcess">
	<xsl:with-param name="cycle" select="$cycle + 1"/>
	<xsl:with-param name="colsList" select="$colsList"/>
      </xsl:call-template>
    </xsl:if>
</xsl:template>

  <!-- Table - Rows tools -->

  <!-- Ce modele retourne le nombre de lignes (au sens de la DocBook)
  qui precedent la ligne courante -->

<xsl:template match="table:table-row" mode="precedingDepth">
    <xsl:param name="rowID"/>
    <xsl:param name="depthCumul"  select="0"/>
    <xsl:param name="precedingSiblingDepth">
      <xsl:for-each select="preceding-sibling::table:table-row">
	<xsl:apply-templates select="table:table-cell[1]" mode="pas"/>
      </xsl:for-each>
    </xsl:param>
    <xsl:param name="precedingSiblingDepthValue">
      <xsl:choose>
	<xsl:when test="$precedingSiblingDepth != ''">
	  <xsl:call-template name="sumOfList">
	    <xsl:with-param name="list" select="$precedingSiblingDepth"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:choose>
      <xsl:when
	test="generate-id(ancestor::table:table-cell[1]/
	parent::table:table-row) != $rowID">
	<xsl:apply-templates
	  select="ancestor::table:table-cell[1]/parent::table:table-row"
	  mode="precedingDepth">
	  <xsl:with-param
	    name="depthCumul"
	    select="$depthCumul + $precedingSiblingDepthValue"/>
	  <xsl:with-param name="rowID" select="$rowID"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$depthCumul"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!--
  This template returns the number of lines (in the DocBook meaning)
  following the current line.
  -->
<xsl:template match="table:table-row" mode="followingDepth">
    <xsl:param name="rowID"/>
    <xsl:param name="depthCumul"  select="0"/>
    <xsl:param name="followingSiblingDepth">
      <xsl:for-each select="following-sibling::table:table-row">
	<xsl:apply-templates select="table:table-cell[1]" mode="pas"/>
      </xsl:for-each>
    </xsl:param>
    <xsl:param name="followingSiblingDepthValue">
      <xsl:choose>
	<xsl:when test="$followingSiblingDepth != ''">
	  <xsl:call-template name="sumOfList">
	    <xsl:with-param name="list" select="$followingSiblingDepth"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:choose>
      <xsl:when
	test="generate-id(ancestor::table:table-cell[1]/
	parent::table:table-row) != $rowID">
	<xsl:apply-templates
	  select="ancestor::table:table-cell[1]/parent::table:table-row"
	  mode="followingDepth">
	  <xsl:with-param
	    name="depthCumul"
	    select="$depthCumul + $followingSiblingDepthValue"/>
	  <xsl:with-param name="rowID" select="$rowID"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$depthCumul"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>


  <!--
  This template return the line depth of the current line if this line contains
  cells with a sub-table.
  It returns a value of type x (to make it a list if needed).
  It doesn't return anything if there isn't any sub-table.
  -->
<xsl:template match="table:table-cell" mode="pas">
    <xsl:param name="depth" select="'table'"/>
    <xsl:param name="nucleon" select="'sub'"/>
    <xsl:param name="maxDepthRows" select="1"/>
    <xsl:param name="subtablesDepthRows">
      <xsl:choose>
	<xsl:when
	  test="table:table[@table:is-sub-table = 'true']/table:table-row/
	  table:table-cell/table:table[@table:is-sub-table = 'true']">
	  <xsl:apply-templates
	    select="table:table[@table:is-sub-table = 'true']/table:table-row/
	    table:table-cell[table:table[@table:is-sub-table = 'true']][1]"
	    mode="pas">
	    <xsl:with-param name="depth" select="concat($nucleon, '-', $depth)"/>
	  </xsl:apply-templates>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="stDepthRowsSum">
      <xsl:call-template name="sumOfList">
	<xsl:with-param name="list" select="$subtablesDepthRows"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param	name="depthRows"
      select="count(table:table[@table:is-sub-table = 'true']/table:table-row
      [not(descendant::table:table[@table:is-sub-table = 'true'])])"/>
    <xsl:param name="totalDepthRows" select="$depthRows + $stDepthRowsSum"/>
    <xsl:choose>
      <xsl:when test="following-sibling::table:table-cell[table:table[@table:is-sub-table = 'true']]">
	<xsl:apply-templates
	  select="following-sibling::table:table-cell[table:table[@table:is-sub-table = 'true']][1]"
	  mode="pas">
	  <xsl:with-param name="maxDepthRows">
	    <xsl:choose>
	      <xsl:when test="$totalDepthRows > $maxDepthRows">
		<xsl:value-of select="$totalDepthRows"/>
	      </xsl:when>
	      <xsl:otherwise>
		<xsl:value-of select="$maxDepthRows"/>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:with-param>
	  <xsl:with-param name="depth" select="$depth"/>
	</xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
	<xsl:choose>
	  <xsl:when test="$totalDepthRows > $maxDepthRows">
	    <xsl:value-of select="concat($totalDepthRows,';')"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of select="concat($maxDepthRows,';')"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!--
  ===========
  TABLE CELLS
  ===========
  -->

  <!-- This template does the main processing for table cells -->
<xsl:template match="table:table-cell" mode="rowProcess">
    <xsl:param name="colsList"/>
    <xsl:param name="cycle"/>
    <xsl:param name="maxRowsInSubtables"/>
    <xsl:param name="rowID"/>
    <xsl:param name="lastRow"/>
    <xsl:param name="namest">
      <xsl:call-template name="cellStart">
	<xsl:with-param name="colsList" select="$colsList"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="nameend">
      <xsl:call-template name="cellEnd">
	<xsl:with-param name="colsList" select="$colsList"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="precedingDepth">
      <xsl:choose>
	<xsl:when test="generate-id(parent::table:table-row) != $rowID">
	  <xsl:apply-templates
	    select="parent::table:table-row"
	    mode="precedingDepth"/>
	</xsl:when>
	<xsl:otherwise>false</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="precedingDepthValue">
      <xsl:choose>
	<xsl:when test="$precedingDepth != 'false'">
	  <xsl:value-of select="$precedingDepth"/>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="followingDepth">
      <xsl:choose>
	<xsl:when test="generate-id(parent::table:table-row) != $rowID">
	  <xsl:apply-templates
	    select="parent::table:table-row"
	    mode="followingDepth"/>
	</xsl:when>
	<xsl:otherwise>false</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="followingDepthValue">
      <xsl:choose>
	<xsl:when test="$followingDepth != 'false'">
	  <xsl:value-of select="$followingDepth"/>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="moreRowsBrut">
      <xsl:choose>
	<xsl:when test="parent::table:table-row/
	  child::table:table-cell[table:table[@table:is-sub-table = 'true']]
	  and not(table:table[@table:is-sub-table = 'true'])">
	  <xsl:apply-templates
	    select="parent::table:table-row/child::table:table-cell
	    [table:table[@table:is-sub-table = 'true']][1]"
	    mode="pas"/>
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="moreRowsValue">
      <xsl:choose>
	<xsl:when test="$moreRowsBrut != ''">
	  <xsl:call-template name="sumOfList">
	    <xsl:with-param name="list" select="$moreRowsBrut"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="moreRows">
      <xsl:choose>
	<xsl:when test="($followingDepthValue = 0) and
	  $maxRowsInSubtables > ($precedingDepthValue + $moreRowsValue)">
	  <xsl:value-of select="$maxRowsInSubtables - $precedingDepthValue "/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="$moreRowsValue"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:param>

    <xsl:param name="contenu" select="text:p/text()"/>
    <xsl:if test="$cycle = $precedingDepthValue">
      <xsl:call-template name="entryNormal">
	<xsl:with-param name="moreRowsValue" select="$moreRows - 1"/>
	<xsl:with-param name="namestValue" select="$namest"/>
	<xsl:with-param name="nameendValue" select="$nameend"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Retourne le debut  de la cellule appelante au sens DocBook (namest)-->
<xsl:template name="cellStart">
    <xsl:param name="colsList"/>
    <xsl:param name="extremite" select="'start'"/>
    <xsl:param name="cellPosition">
      <xsl:choose>
	<xsl:when test="preceding-sibling::table:table-cell">
	  <xsl:apply-templates
	    select="preceding-sibling::table:table-cell[1]"
	    mode="cellPosition">
	    <xsl:with-param name="extremite" select="$extremite"/>
	  </xsl:apply-templates>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:choose>
	    <xsl:when test="../parent::table:table[@table:is-sub-table = 'true']">
	      <xsl:apply-templates
		select="../../table:table-column[1]"
		mode="subtablePosition"/>
	    </xsl:when>
	    <xsl:otherwise>0</xsl:otherwise>
	  </xsl:choose>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="order">
      <xsl:choose>
	<xsl:when test="$cellPosition != 0">
	  <xsl:call-template name="position2order">
	    <xsl:with-param name="colsList" select="$colsList"/>
	    <xsl:with-param name="cellPosition" select="$cellPosition"/>
	  </xsl:call-template>
	</xsl:when>
	<xsl:otherwise>0</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:value-of select="$order"/>
  </xsl:template>

  <!-- Retourne la fin de la cellule appelante au sens DocBook (nameend) -->
<xsl:template name="cellEnd">
    <xsl:param name="colsList"/>
    <xsl:param name="extremite" select="'end'"/>
    <xsl:param name="cellPosition">
      <xsl:apply-templates select="current()"
	mode="cellPosition">
	<xsl:with-param name="extremite" select="$extremite"/>
	<xsl:with-param name="colsList" select="$colsList"/>
      </xsl:apply-templates>
    </xsl:param>
    <xsl:param name="order">
      <xsl:call-template name="position2order">
	<xsl:with-param name="colsList" select="$colsList"/>
	<xsl:with-param name="cellPosition" select="$cellPosition"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:value-of select="$order"/>
  </xsl:template>

  <!--
  Retourne le numero de colonne de la cellule en fonction de sa
  position absolue dans le tableau.
  Requiert :
  - "colsList" = liste des position absolues de colonnes
  - "cellPosition" = position absolue de la cellule
  -->
<xsl:template name="position2order">
    <xsl:param name="colsList"/>
    <xsl:param name="cellPosition"/>
    <xsl:param name="cycle" select="1"/>
    <xsl:param name="colsListElt" select="substring-before($colsList,';')"/>
<!--
<xsl:message>
template name="position2order"
colsList : <xsl:value-of select="$colsList"/>
cellPosition : <xsl:value-of select="$cellPosition"/>
cycle : <xsl:value-of select="$cycle"/>
colsListElt : <xsl:value-of select="$colsListElt"/>
</xsl:message>
-->
    <xsl:choose>
        <xsl:when test="$colsList != ''">
        <!-- nouveau test pour eviter une boucle infinie-->
            <xsl:choose>
                <xsl:when test="$cellPosition != $colsListElt">
                    <xsl:call-template name="position2order">
                        <xsl:with-param name="cycle" select="$cycle + 1"/>
                        <xsl:with-param name="colsList" select="substring-after($colsList,';')"/>
                        <xsl:with-param name="cellPosition" select="$cellPosition"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$cycle"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:when>
        <!-- nouveau test pour eviter une boucle infinie ; on renvoie 0 dans ce cas !-->
        <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!--
  Retourne la position de la cellule numero "placeOfCell" dont l'etendue OOo
  "repeatCol" est donnee
  -->
<xsl:template match="table:table-cell" mode="cellPosition">
    <xsl:param name="extremite"/>
    <xsl:param name="currentCellSpan">
      <xsl:choose>
	<xsl:when test="@table:number-columns-spanned">
	  <xsl:value-of select="@table:number-columns-spanned"/>
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="precedingCellsNbr"
      select="count(preceding-sibling::table:table-cell
      [not(@table:number-columns-spanned)]) +
      sum(preceding-sibling::table:table-cell/
      @table:number-columns-spanned)"/>
    <xsl:param name="placeOfCol">
      <xsl:choose>
	<xsl:when test="parent::table:table-row/parent::table:table">
	  <xsl:apply-templates select="../../table:table-column[1]"
	    mode="placeOfColl">
	    <xsl:with-param name="placeOfCell" select="$precedingCellsNbr + $currentCellSpan"/>
	  </xsl:apply-templates>
	</xsl:when>
	<xsl:otherwise><!-- table:table-header-rows -->
	  <xsl:apply-templates select="../../../table:table-column[1]"
	    mode="placeOfColl">
	    <xsl:with-param name="placeOfCell" select="$precedingCellsNbr + $currentCellSpan"/>
	  </xsl:apply-templates>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:param name="content"  select="text:p/text()"/>
    <xsl:param name="numCol" select="substring-before($placeOfCol,';')"/>
    <xsl:param name="repeatCol" select="substring-after($placeOfCol,';')"/>

    <xsl:param name="colposition">
      <xsl:choose>
	<xsl:when test="parent::table:table-row/parent::table:table">
	  <xsl:apply-templates select="../../table:table-column[position()=$numCol]" mode="colposition">
	    <xsl:with-param name="repeatCol" select="$repeatCol"/>
	  </xsl:apply-templates>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates
	    select="../../../table:table-column[position()=$numCol]"
	    mode="colposition">
	    <xsl:with-param name="repeatCol" select="$repeatCol"/>
	  </xsl:apply-templates>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:value-of select="$colposition"/>
</xsl:template>

  <!--
  Retourne le numero de la colonne
  correspondant a une position de cellule donnee (placeofCell)
  pour le conteneur table ou sub-table courant
  -->
<xsl:template match="table:table-column" mode="placeOfColl">
    <xsl:param name="placeOfCell"/>
    <xsl:param name="placeOfColl" select="1"/>
    <xsl:param name="repeatOfCol">
      <xsl:choose>
	<xsl:when test="@table:number-columns-repeated">
	  <xsl:value-of select="@table:number-columns-repeated"/>
	</xsl:when>
	<xsl:otherwise>1</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:choose>
      <xsl:when test="$placeOfCell > 0">
	<xsl:choose>
	  <xsl:when test="$placeOfCell > $repeatOfCol">
	    <xsl:apply-templates
	      select="following-sibling::table:table-column[1]"
	      mode="placeOfColl">
	      <xsl:with-param name="placeOfCell" select="$placeOfCell - $repeatOfCol"/>
	      <xsl:with-param name="placeOfColl" select="$placeOfColl + 1"/>
	    </xsl:apply-templates>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of select="concat($placeOfColl,';',$placeOfCell)"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="concat($placeOfColl,';',1)"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!--
  Retourne la position absolue de la colonne (distance entre la fin
  de la colonne et le bord gauche du tableau)dans l'unite de mesure courante du document
  -->
<xsl:template match="table:table-column" mode="colposition">
    <xsl:param name="stylesURI" select="/office:document/office:automatic-styles/style:style"/>
    <xsl:param name="repeatCol"/>
    <xsl:param name="cellAncestorNbr"/>
    <xsl:param name="precedingCellsNbr" select="count(preceding-sibling::table:table-cell)"/>
    <xsl:param name="colPosition">
      <xsl:call-template name="colPosition">
	<xsl:with-param name="origineValue">
	  <xsl:choose>
	    <xsl:when test="parent::table:table[@table:is-sub-table = 'true']">
	      <xsl:call-template name="subtableOrigine">
		<xsl:with-param name="cellAncestorNbr"
		  select="count(ancestor::table:table-cell)"/>
		<xsl:with-param name="stylesURI" select="$stylesURI"/>
	      </xsl:call-template>
	    </xsl:when>
	    <xsl:otherwise>0</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
	<xsl:with-param name="stylesURI" select="$stylesURI"/>
	<xsl:with-param name="repeatCol" select="$repeatCol"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="colposfine" select="substring-before($colPosition,';')"/>
    <xsl:value-of select="$colposfine"/>
</xsl:template>

  <!-- Retourne la position absolue de la sous-table qui incorpore la colonne courante
  (postion absolue = distance entre bord gauche de la sous-table
  et bord gauche du tableau) -->
<xsl:template match="table:table-column" mode="subtablePosition">
    <xsl:param name="stylesURI" select="/office:document/office:automatic-styles/style:style"/>
    <xsl:param name="repeatCol"/>
    <xsl:param name="cellAncestorNbr"/>
    <xsl:param name="precedingCellsNbr" select="count(preceding-sibling::table:table-cell)"/>
    <xsl:param name="subtablePosition">
      <xsl:call-template name="subtableOrigine">
	<xsl:with-param name="cellAncestorNbr"
	  select="count(ancestor::table:table-cell)"/>
	<xsl:with-param name="stylesURI" select="$stylesURI"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:param name="colposfine">
      <xsl:call-template name="roundValue">
	<xsl:with-param name="inputValue" select="$subtablePosition"/>
      </xsl:call-template>
    </xsl:param>
    <xsl:value-of select="$colposfine"/>
  </xsl:template>

  <!--
  Retourne la somme des elements de la liste passee en parametre
  La liste doit etre du type a;b;c; (le ';' final est requit)
  -->
<xsl:template name="sumOfList">
    <xsl:param name="list"/>
    <xsl:param name="sum" select="0"/>
    <xsl:choose>
      <xsl:when test="substring-before($list,';') != ''">
	<xsl:call-template name="sumOfList">
	  <xsl:with-param name="sum" select="$sum + substring-before($list,';')"/>
	  <xsl:with-param name="list" select="substring-after($list,';')"/>
	</xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
	<xsl:value-of select="$sum"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Retourne la valeur arrondie adaptee a l'unite de messure en cour du document-->
<xsl:template name="roundValue">
    <xsl:param name="inputValue"/>
    <xsl:choose>
      <xsl:when test="$measureUnit = 'pt' or $measureUnit = 'pi' or $measureUnit = '%'">
	<xsl:value-of select="round($inputValue)"/>
      </xsl:when>
      <xsl:when test="$measureUnit = 'cm' or $measureUnit = 'inch'">
	<xsl:value-of select="round($inputValue * 10) div 10"/>
      </xsl:when>
      <xsl:otherwise><!-- mm -->
	<xsl:value-of select="round($inputValue)"/>
      </xsl:otherwise>
    </xsl:choose>
</xsl:template>

  <!-- Table - Table-cell -->
  <!-- Final treatment of table cells -->
<xsl:template name="entryNormal">
    <xsl:param name="namestValue"/>
    <xsl:param name="nameendValue"/>
    <xsl:param name="moreRowsValue" select="'0'"/>

    <xsl:variable name="stylecellule" select="/office:document/office:automatic-styles/
      style:style[@style:name=current()/@table:style-name]"/>
    <xsl:variable name="valign"
      select="$stylecellule/style:table-cell-properties/@style:vertical-align"/>

    <!--
    The align attribute handling here is a bit tricky because the
    information we rely on is the align attribute located in the
    first element contained in the table cell (current()/child::*[1]).
    So this treatment assumes that all the elements contains in this
    table cell will have the same alignment. This is not a very bad
    assumption because doing complicated layout settings in table is
    bad.
    -->
    <xsl:variable name="align"
      select="/office:document/office:automatic-styles/
      style:style[@style:name=(current()/child::*[1]/@text:style-name)]/
      */@fo:text-align"/>

    <xsl:variable name="border"
      select="$stylecellule/style:table-cell-properties/@fo:border"/>
    <xsl:variable name="border-top"
      select="$stylecellule/style:table-cell-properties/@fo:border-top"/>
    <xsl:variable name="border-right"
      select="$stylecellule/style:table-cell-properties/@fo:border-right"/>
    <xsl:variable name="border-bottom"
      select="$stylecellule/style:table-cell-properties/@fo:border-bottom"/>
    <xsl:variable name="border-left"
      select="$stylecellule/style:table-cell-properties/@fo:border-left"/>

<!--
<xsl:message>
stylecellule <xsl:value-of select="$stylecellule/@style:family"/>
valign <xsl:value-of select="$valign"/>
border <xsl:value-of select="$border"/>
border-top <xsl:value-of select="$border-top"/>
border-right <xsl:value-of select="$border-right"/>
border-left <xsl:value-of select="$border-left"/>
border-bottom <xsl:value-of select="$border-bottom"/>
</xsl:message>
-->




    <entry>
      <xsl:if test="($nameendValue - $namestValue) > 1">
	<xsl:attribute name="namest">
	  <xsl:value-of select="concat('c', ($namestValue + 1))"/>
	</xsl:attribute>
	<xsl:attribute name="nameend">
	  <xsl:value-of select="concat('c', $nameendValue)"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="$moreRowsValue >= 1">
	<xsl:attribute name="morerows">
	  <xsl:value-of select="$moreRowsValue"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="$valign">
	<xsl:attribute name="valign">
	  <xsl:value-of select="$valign"/>
	</xsl:attribute>
      </xsl:if>
      <xsl:if test="$align">
	<xsl:attribute name="align">
	  <xsl:choose>
	    <xsl:when test="$align='start'">
	      <xsl:value-of select="'left'"/>
	    </xsl:when>
	    <xsl:when test="$align='end'">
	      <xsl:value-of select="'right'"/>
	    </xsl:when>
	    <xsl:when test="$align='center'">
	      <xsl:value-of select="'center'"/>
	    </xsl:when>
	    <xsl:when test="$align='justify'">
	      <xsl:value-of select="'justify'"/>
	    </xsl:when>
	  </xsl:choose>
	</xsl:attribute>
      </xsl:if>

      <!-- Border specification as processing instructions -->
      <xsl:if test="$border and $border != 'none'">
	<xsl:processing-instruction name="border">
	  <xsl:value-of select="$border"/>
	</xsl:processing-instruction>
      </xsl:if>
      <xsl:if test="$border-top and $border-top != 'none'">
	<xsl:processing-instruction name="border-top">
	  <xsl:value-of select="$border-top"/>
	</xsl:processing-instruction>
      </xsl:if>
      <xsl:if test="$border-right and $border-right != 'none'">
	<xsl:processing-instruction name="border-right">
	  <xsl:value-of select="$border-right"/>
	</xsl:processing-instruction>
      </xsl:if>
      <xsl:if test="$border-bottom and $border-bottom != 'none'">
	<xsl:processing-instruction name="border-bottom">
	  <xsl:value-of select="$border-bottom"/>
	</xsl:processing-instruction>
      </xsl:if>
      <xsl:if test="$border-left and $border-left != 'none'">
	<xsl:processing-instruction name="border-left">
	  <xsl:value-of select="$border-left"/>
	</xsl:processing-instruction>
      </xsl:if>

      <xsl:apply-templates mode="inCellTable"/>
    </entry>
  </xsl:template>

  <!-- Tables - Cell content -->
<xsl:template match="*" mode="inCellTable">
    <xsl:call-template name="allTags">
        <xsl:with-param name="source" select="'cellTable'"/>
    </xsl:call-template>
</xsl:template>


  <!-- Deleted styles -->
<xsl:template match="text:sequence-decls"/>
<xsl:template match="text:table-of-content"/>
  
<!--Modif MT generation fils Id -->
<xsl:template name="GenereIdSection">
	<xsl:if test="text:bookmark-start">
        <xsl:attribute name="id">
            <xsl:value-of select="text:bookmark-start/@text:name"/>
        </xsl:attribute>
    </xsl:if>
</xsl:template>
<!-- Fin modif MT    -->

<!--Rajoute par MT pour gerer la correspondance des styles Notes - important|warning|caution|tip-->
  <xsl:template name="NoteImportant">
    <important>
        <xsl:value-of select="@text:name"/>
    </important>
  </xsl:template>
  <xsl:template name="NoteWarning">
    <warning>
        <xsl:value-of select="@text:name"/>
    </warning>
  </xsl:template>
  <xsl:template name="NoteCaution">
    <caution>
        <xsl:value-of select="@text:name"/>
    </caution>
  </xsl:template>
  <xsl:template name="NoteTip">
    <tip>
        <xsl:value-of select="@text:name"/>
    </tip>
  </xsl:template>

</xsl:stylesheet>
