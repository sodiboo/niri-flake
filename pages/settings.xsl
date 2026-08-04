<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html"
              version="5"
              indent="no" />

  <xsl:param name="rev"
             select="/options/@rev" />
  <xsl:param name="repo-base-url">https://github.com/sodiboo/niri-flake/blob</xsl:param>

  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta name="viewport"
              content="width=device-width, initial-scale=1.0" />
        <meta name="color-scheme"
              content="dark light" />
        <link rel="stylesheet"
              href="settings.css" />
        <title>niri-flake settings</title>

        <script defer=""
                src="settings.js" />
      </head>

      <body>
        <header>
          <nav aria-label="breadcrumb">
            <ul>
              <li>
                <a href="/">niri-flake</a>
              </li>
              <li>
                <a href="#"
                   aria-current="page">settings</a>
              </li>
            </ul>
          </nav>
        </header>

        <hr />

        <main>
          <xsl:apply-templates select="options" />
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="options"
                match="options">
    <ul class="options">
      <xsl:apply-templates />
    </ul>
  </xsl:template>

  <xsl:template name="option-fragment">
    <xsl:param name="path"
               select="." />
    <xsl:for-each select="$path/path-segment">
      <xsl:if test="position() != 1">
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:value-of select="." />
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="render-path-segments">
    <xsl:param name="path"
               select="." />
    <xsl:for-each select="$path/path-segment">
      <path-segment>
        <xsl:copy-of select="@*|node()" />
      </path-segment>
      <xsl:if test="position() &lt; last()">
        <xsl:text>.</xsl:text>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="render-path-segments-with-ancestor">
    <xsl:param name="path"
               select="." />

    <xsl:for-each select="$path/path-segment[last()]">
      <xsl:if test="preceding-sibling::*">
        <ancestor-path>
          <xsl:for-each select="preceding-sibling::*">
            <path-segment>
              <xsl:copy-of select="@*|node()" />
            </path-segment>
            <xsl:text>.</xsl:text>
          </xsl:for-each>
        </ancestor-path>
      </xsl:if>

      <path-segment>
        <xsl:copy-of select="@*|node()" />
      </path-segment>
    </xsl:for-each>
    <!-- <xsl:variable name="last"
                  select="$path/path-segment[last()]" />
    <xsl:variable name="ancestors"
                  select="$last/preceding::" />
    <xsl:if test="count(path-segment) > 1" />

    <xsl:for-each select="path-segment[last()]" /> -->
  </xsl:template>

  <xsl:template match="option">
    <details class="option">
      <xsl:apply-templates mode="option">
        <xsl:with-param name="is-section"
                        select="spec/type = 'submodule' and spec/default = '{ }'" />
      </xsl:apply-templates>
    </details>
  </xsl:template>

  <xsl:template match="loc"
                mode="option">
    <xsl:variable name="fragment">
      <xsl:call-template name="option-fragment" />
    </xsl:variable>
    <summary>
      <option-name>
        <a href="#{$fragment}">
          <!-- <xsl:attribute name="class">option-name</xsl:attribute> -->
          <xsl:call-template name="render-path-segments-with-ancestor" />
        </a>
      </option-name>
    </summary>
    <a class="option-anchor"
       id="{$fragment}" />
  </xsl:template>

  <xsl:template match="declarations"
                mode="option">
    <option-content class="declarations">
      <dt>declarations</dt>
      <xsl:for-each select="declaration">
        <xsl:variable name="hash">
          <xsl:if test="@line">
            <xsl:text>#L</xsl:text>
            <xsl:value-of select="@line" />
          </xsl:if>
        </xsl:variable>
        <dd>
          <a target="_blank"
             href="{$repo-base-url}/{$rev}/{@file}{$hash}">
            <xsl:value-of select="@file" />
          </a>
        </dd>
      </xsl:for-each>
    </option-content>
  </xsl:template>

  <xsl:template match="hierarchy"
                mode="option">
    <xsl:param name="is-section" />

    <xsl:if test="*">

      <option-content class="hierarchy">
        <xsl:if test="before">
          <dt>
            <xsl:choose>
              <xsl:when test="$is-section">refines</xsl:when>
              <xsl:otherwise>overrides</xsl:otherwise>
            </xsl:choose>
          </dt>
          <xsl:for-each select="before">
            <xsl:variable name="fragment">
              <xsl:call-template name="option-fragment" />
            </xsl:variable>
            <dd>
              <a href="#{$fragment}">
                <xsl:call-template name="render-path-segments" />
              </a>
            </dd>
          </xsl:for-each>
        </xsl:if>

        <xsl:if test="after">
          <dt>
            <xsl:choose>
              <xsl:when test="$is-section">refined by</xsl:when>
              <xsl:otherwise>overridden by</xsl:otherwise>
            </xsl:choose>
          </dt>
          <xsl:for-each select="after">
            <xsl:variable name="fragment">
              <xsl:call-template name="option-fragment" />
            </xsl:variable>
            <dd>
              <a href="#{$fragment}">
                <xsl:call-template name="render-path-segments" />
              </a>
            </dd>
          </xsl:for-each>
        </xsl:if>
      </option-content>

    </xsl:if>
  </xsl:template>

  <xsl:template match="spec"
                mode="option">
    <xsl:param name="is-section" />

    <xsl:if test="not ($is-section)">
      <option-content class="spec">
        <xsl:apply-templates mode="spec" />
      </option-content>
    </xsl:if>
  </xsl:template>

  <xsl:template match="type"
                mode="spec">
    <dt>type</dt>
    <dd>
      <option-type>
        <xsl:value-of select="." />
      </option-type>
    </dd>
  </xsl:template>

  <xsl:template match="default"
                mode="spec">
    <xsl:if test="not(. = '[ ]' or . = '{ }')">
      <dt>default</dt>
      <dd>
        <option-default>
          <xsl:value-of select="." />
        </option-default>
      </dd>
    </xsl:if>
  </xsl:template>

  <xsl:template match="options"
                mode="option">
    <xsl:call-template name="options" />
  </xsl:template>

  <xsl:template match="description"
                mode="option">
    <option-content class="description">
      <xsl:apply-templates mode="description" />
    </option-content>
  </xsl:template>

  <xsl:template match="codeblock"
                mode="description">
    <pre><code class="language-nix"><xsl:copy-of select="text()"></xsl:copy-of></code></pre>
  </xsl:template>

  <xsl:template match="option-link"
                mode="description">
    <xsl:variable name="fragment">
      <xsl:call-template name="option-fragment">
        <xsl:with-param name="path"
                        select="path" />
      </xsl:call-template>
    </xsl:variable>
    <a href="#{$fragment}">
      <xsl:choose>
        <xsl:when test="text">
          <xsl:apply-templates select="text/*" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="render-path-segments">
            <xsl:with-param name="path"
                            select="path" />
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </a>
  </xsl:template>

  <xsl:template match="admonition"
                mode="description">
    <div class="admonition {@kind}">
      <xsl:apply-templates mode="description" />
    </div>
  </xsl:template>

  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/1999/xhtml']"
                mode="description">
    <xsl:element name="{local-name()}">
      <xsl:for-each select="@*">
        <xsl:copy />
      </xsl:for-each>
      <xsl:apply-templates mode="description" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="*"
                mode="option">
    <xsl:message>what: <xsl:value-of select="name()" /></xsl:message>
  </xsl:template>
  <xsl:template match="*"
                mode="spec">
    <xsl:message>what: <xsl:value-of select="name()" /></xsl:message>
  </xsl:template>
  <xsl:template match="*"
                mode="description">
    <xsl:message>what: <xsl:value-of select="name()" /></xsl:message>
  </xsl:template>
</xsl:stylesheet>