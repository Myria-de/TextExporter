<?xml version="1.0"?>
<!--
Copyright (c) 2003 David Cramer
http://www.thingbag.net/docbook/tabletest/docbook-psmi.xsl
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:psmi="http://www.CraneSoftwrights.com/resources/psmi"
                exclude-result-prefixes="psmi"
                version="1.0">


<xsl:import href="docbook/fo/docbook.xsl"/>

<!--
<xsl:param name="double.sided" select="'1'"/>
-->

  <xsl:template match="*[(@orient='land' or ./processing-instruction('landscape')) and (parent::chapter or parent::article or (parent::appendix and ancestor::book))]" priority="200">
	<psmi:page-sequence master-reference="body-landscape">
	  <fo:flow flow-name="region-body-landscape">
		<xsl:apply-imports/>
	  </fo:flow>
	</psmi:page-sequence>
  </xsl:template>

  <xsl:template match="*[(@orient='land' or ./processing-instruction('landscape'))]">
	<xsl:message>
	  <xsl:text disable-output-escaping="yes">
Note: psmi not supported elements that are not direct descendants of
article, chapter, or appendix. An in this document with orient='land' or
&lt;?landscape?&gt; will not be flagged for landscaping through psmi.
	  </xsl:text>
	</xsl:message>
	<xsl:apply-imports/>
  </xsl:template>

  <xsl:template name="user.pagemasters">


    <fo:simple-page-master master-name="body-landscape-odd"
                           page-width="{$page.width}"
                           page-height="{$page.height}"
                           margin-top="{$page.margin.top}"
                           margin-bottom="{$page.margin.bottom}"
                           margin-left="{$page.margin.inner}"
                           margin-right="{$page.margin.outer}">
      <fo:region-body
		region-name="region-body-landscape"
		margin-bottom="1in"
		reference-orientation="90"
		margin-top="1in"
		column-count="{$column.count.body}">
      </fo:region-body>
      <fo:region-before region-name="xsl-region-before-odd"
                        extent="{$region.before.extent}"
                        display-align="before"/>
      <fo:region-after region-name="xsl-region-after-odd"
                       extent="{$region.after.extent}"
                       display-align="after"/>
    </fo:simple-page-master>
    <fo:simple-page-master master-name="body-landscape-even"
                           page-width="{$page.width}"
                           page-height="{$page.height}"
                           margin-top="{$page.margin.top}"
                           margin-bottom="{$page.margin.bottom}"
                           margin-left="{$page.margin.inner}"
                           margin-right="{$page.margin.outer}">
      <fo:region-body
		region-name="region-body-landscape"
		margin-bottom="1in"
		reference-orientation="90"
                      margin-top="1in"
                      column-count="{$column.count.body}">
      </fo:region-body>
      <fo:region-before region-name="xsl-region-before-even"
                        extent="{$region.before.extent}"
                        display-align="before"/>
      <fo:region-after region-name="xsl-region-after-even"
                       extent="{$region.after.extent}"
                       display-align="after"/>
    </fo:simple-page-master>

    <!-- setup for body pages -->
    <fo:page-sequence-master master-name="body-landscape">
      <fo:repeatable-page-master-alternatives>
        <fo:conditional-page-master-reference master-reference="body-landscape-odd"
                                              odd-or-even="odd"/>
        <fo:conditional-page-master-reference master-reference="body-landscape-even"
                                              odd-or-even="even"/>
      </fo:repeatable-page-master-alternatives>
    </fo:page-sequence-master>



  </xsl:template>

</xsl:stylesheet>
