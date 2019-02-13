<?xml version='1.0'?>

<!--
  This stylesheet is used for the Firebird Release Notes fo
  (Formatting Objects) generation.
  It imports the standard Firebird docs fo.xsl stylesheet, and then
  includes param-rlsnotes.xsl in which some stuff is overridden.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:exsl="http://exslt.org/common"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:axf="http://www.antennahouse.com/names/XSL/Extensions"
                exclude-result-prefixes="exsl"
                version='1.0'>
  <!-- Import default Firebirddocs stylesheet for fo generation: -->
  <xsl:import href="fo.xsl"/>


<xsl:template name="head.sep.rule">
  <xsl:param name="pageclass"/>
  <xsl:param name="sequence"/>
  <xsl:param name="gentext-key"/>

  <xsl:if test="$header.rule != 0">
    <xsl:attribute name="border-bottom-width">1pt</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
    <xsl:attribute name="border-bottom-color">red</xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template name="foot.sep.rule">
  <xsl:param name="pageclass"/>
  <xsl:param name="sequence"/>
  <xsl:param name="gentext-key"/>

  <xsl:if test="$footer.rule != 0">
    <xsl:attribute name="border-top-width">1pt</xsl:attribute>
    <xsl:attribute name="border-top-style">solid</xsl:attribute>
    <xsl:attribute name="border-top-color">red</xsl:attribute>
  </xsl:if>
</xsl:template>



  <!-- Then include customizations for the Release Notes: -->
  <xsl:include href="fo/param-rlsnotes.xsl"/>

</xsl:stylesheet>

