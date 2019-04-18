# how-to-maven-central

Reference project for deploying a Maven project to Maven Central via Sonatype
OSSRH.

[![Build
Status](https://travis-ci.com/gilday/how-to-maven-central.svg?branch=master)](https://travis-ci.com/gilday/how-to-maven-central)

Deploying to Sonatype OSSRH is more complicated than just `mvn deploy`: it
requires users to become familiar with the [Sonatype Nexus Staging
workflow](https://help.sonatype.com/repomanager2/staging-releases) and its
associated tooling the
[nexus-staging-maven-plugin](https://github.com/sonatype/nexus-maven-plugins/tree/master/staging/maven-plugin).

There are different ways to use the nexus-staging-maven-plugin. This example
project demonstrates two different ways.

## staging-deploy workflow

The nexus-staging-maven-plugin can perform the whole staging and release
workflow as part of the Maven project's build. This is the simplest way to
configure releases to Maven Central and should work for most OSS projects.

```xml
<plugin>
  <groupId>org.sonatype.plugins</groupId>
  <artifactId>nexus-staging-maven-plugin</artifactId>
  <version>1.6.8</version>
  <extensions>true</extensions>
  <configuration>
   <serverId>ossrh</serverId>
   <nexusUrl>https://oss.sonatype.org/</nexusUrl>
   <autoReleaseAfterClose>true</autoReleaseAfterClose>
  </configuration>
</plugin>
```

There are plenty of blog posts and guides on how to configure the
nexus-staging-maven-plugin in this configuration. Tag `v1.1` of this project was
deployed using this configuration.

## Manual Staging Bundle Creation and Deployment

Examples using the [Manual Staging Bundle Creation and
Deployment](https://central.sonatype.org/pages/manual-staging-bundle-creation-and-deployment.html)
workflow are less common. In this workflow, users use scripts to manually create
and deploy artifacts to the staging repository in OSSRH. The
nexus-staging-maven-plugin is still involved, but instead of being integrated
into a Maven build, this workflow calls for using the plugin's "rc" goals to
manually open, close, release, list, and drop staging repositories. The
`deploy.sh` shows an example of using these goals in a script.
