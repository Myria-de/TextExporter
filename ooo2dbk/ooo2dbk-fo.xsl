<?xml version='1.0'?>
<!--
Copyright (c) 2004 Nuxeo SARL <http://nuxeo.com>

Authors:
M.-A. Darche (Nuxeo)

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

$Id$
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format">

  <xsl:import href="docbook/fo/docbook.xsl"/>

  <xsl:param name="paper.type" select="'A4'"/>
  <xsl:param name="draft.mode" select="'no'"/>
  <xsl:param name="shade.verbatim" select="1"/>

  <!--
  Print section label (number) along with the section, in the
  document body as well as in the toc.
  -->
  <xsl:param name="section.autolabel" select="1"/>

  <!--
  Up to heading8 in the toc
  -->
  <xsl:param name="toc.section.depth" select="8"/>
  <xsl:param name="toc.max.depth" select="8"/>


  <xsl:param name="xep.extensions" select="1"/>

  <!-- ==================================================================== -->
  <!-- This is the support for symbol characters -->
  <xsl:template match="phrase[starts-with(@role, 'font-name')]">
    <fo:inline>
      <xsl:attribute name="font-family">
	<xsl:value-of select="normalize-space(substring-after(@role, ':'))"/>
      </xsl:attribute>
      <xsl:apply-templates/>
    </fo:inline>
  </xsl:template>


  <!-- ==================================================================== -->
  <!--
  This is the support for table cell borders.
  Principle: Put no border on table and only borders on a per cell basis.
  -->
  <xsl:param name="table.frame.border.style" select="'none'"/>
  <xsl:template name="table.cell.properties">
    <xsl:param name="bgcolor.pi" select="''"/>
    <xsl:param name="rowsep.inherit" select="1"/>
    <xsl:param name="colsep.inherit" select="1"/>
    <xsl:param name="col" select="1"/>
    <xsl:param name="valign.inherit" select="''"/>
    <xsl:param name="align.inherit" select="''"/>
    <xsl:param name="char.inherit" select="''"/>

    <xsl:if test="$bgcolor.pi != ''">
      <xsl:attribute name="background-color">
        <xsl:value-of select="$bgcolor.pi"/>
      </xsl:attribute>
    </xsl:if>

    <!--
    This commented block is the default DocBook cell properties processing
    -->
    <!--
    <xsl:if test="$rowsep.inherit &gt; 0">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'bottom'"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$colsep.inherit &gt; 0 and
      $col &lt; ancestor::tgroup/@cols">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'right'"/>
      </xsl:call-template>
    </xsl:if>
    -->

    <xsl:if test="ancestor-or-self::entry/processing-instruction('border-top')">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'top'"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="ancestor-or-self::entry/processing-instruction('border-bottom')">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'bottom'"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="ancestor-or-self::entry/processing-instruction('border-left')">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'left'"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="ancestor-or-self::entry/processing-instruction('border-right')">
      <xsl:call-template name="border">
        <xsl:with-param name="side" select="'right'"/>
      </xsl:call-template>
    </xsl:if>

    <xsl:if test="$valign.inherit != ''">
      <xsl:attribute name="display-align">
        <xsl:choose>
          <xsl:when test="$valign.inherit='top'">before</xsl:when>
          <xsl:when test="$valign.inherit='middle'">center</xsl:when>
          <xsl:when test="$valign.inherit='bottom'">after</xsl:when>
          <xsl:otherwise>
            <xsl:message>
              <xsl:text>Unexpected valign value: </xsl:text>
              <xsl:value-of select="$valign.inherit"/>
              <xsl:text>, center used.</xsl:text>
            </xsl:message>
            <xsl:text>center</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
    </xsl:if>

    <xsl:if test="$align.inherit != ''">
      <xsl:attribute name="text-align">
        <xsl:value-of select="$align.inherit"/>
      </xsl:attribute>
    </xsl:if>

    <xsl:if test="$char.inherit != ''">
      <xsl:attribute name="text-align">
        <xsl:value-of select="$char.inherit"/>
      </xsl:attribute>
    </xsl:if>

  </xsl:template>


</xsl:stylesheet>
