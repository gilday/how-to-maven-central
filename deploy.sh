#!/bin/bash -ex
# deploy.sh
# script for releasing to Maven Central via OSSRH using the Manual Staging
# Bundle Creation and Deployment workflow (see
# https://central.sonatype.org/pages/manual-staging-bundle-creation-and-deployment.html).

function show_usage {
    echo "$(basename $0) [--drop-existing]"
    echo -e "\t--drop-existing\toptional flag which when provided configures the script to drop all existing OSSRH Nexus staging repositories before implicitly creating a new repository. When this flag is not provided, the script halts when there are existing repositories"
    echo "Script will fail if it cannot find the maven version from the pom.xml in the pwd"
    exit 1
}

drop_existing=false
while (( "$#" )); do
    case $1 in
        --drop-existing)
            drop_existing=true;;
    esac
    shift
done


maven='./mvnw --settings .maven.xml'
# use rc-list-profiles goal to find staging profile ID
staging_profile_id=ad25c0429192f7
# get version from pom
version=$($maven --batch-mode help:evaluate -Dexpression=project.version | grep -v Download | tail -n+10 | head -n 1)
if [ -z "$version" ]; then
    echo -e "Failed to find Maven project version\n"
    show_usage
fi


# opens a new staging repository and record its ID
function open_staging_repository {
    staging_repository_id=$($maven --batch-mode org.sonatype.plugins:nexus-staging-maven-plugin:rc-open \
        -DserverId=ossrh \
        -DnexusUrl=https://oss.sonatype.org/ \
        -DstagingProfileId=$staging_profile_id \
        -DstagingDescription="com.johnathangilday:how-to-maven-central:$version"\
        -DautoReleaseAfterClose=true \
        -DopenedRepositoryMessageFormat="opened-repository-id=%s" \
        | egrep -o 'opened-repository-id=(.+)$' | awk -F= '{ print $2 }')
    echo "Opened staging repository ID $staging_repository_id"
}

function fail_if_staging_repository_exists {
    existing_repositories_count=$($maven --batch-mode org.sonatype.plugins:nexus-staging-maven-plugin:rc-list \
        -DserverId=ossrh \
        -DnexusUrl=https://oss.sonatype.org/ \
        | awk 'BEGIN{ found=0 } /Getting list of available staging repositories\.\.\./{found=1}  {if (found) print }' \
        | tail -n+4 | head -n-6 \
        | awk '{ print $2 }' \
        | grep comjohnathangilday \
        | wc -l)
    if [ "$existing_repositories_count" != "0" ]; then
        echo "Staging repository already exists. Halting release because the Nexus Staging Maven Plugin will append these release artifacts to the existing staging repository and this could lead to errors wherein we deploy artifacts from previous builds which we did not expect to deploy"
        exit -1
    fi
}

function list_staging_repositories {
    $maven --batch-mode org.sonatype.plugins:nexus-staging-maven-plugin:rc-list \
        -DserverId=ossrh \
        -DnexusUrl=https://oss.sonatype.org/ \
        | awk 'BEGIN{ found=0 } /Getting list of available staging repositories\.\.\./{found=1}  {if (found) print }' \
        | tail -n+4 | head -n-6 \
        | awk '{ print $2 }' \
        | grep comjohnathangilday
}

function drop_existing_staging_repositories {
    existing_repositories_csv=$(list_staging_repositories \
        | head -c -1 \
        | tr '\n' ,)
    if [ -n "$existing_repositories_csv" ]; then
        echo "Dropping existing repos $existing_repositories_csv"
        $maven --batch-mode org.sonatype.plugins:nexus-staging-maven-plugin:rc-drop \
            -DserverId=ossrh \
            -DnexusUrl=https://oss.sonatype.org/ \
            -DstagingRepositoryId=$existing_repositories_csv
    fi
}

function deploy_to_staging_repository {
    # https://issues.sonatype.org/browse/OSSRH-47921?page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel&focusedCommentId=768474#comment-768474
    $maven -X --batch-mode -Prelease gpg:sign-and-deploy-file \
        -DpomFile=.flattened-pom.xml \
        -Dfile=target/how-to-maven-central-$version.jar \
        -Djavadoc=target/how-to-maven-central-$version-javadoc.jar \
        -Dsources=target/how-to-maven-central-$version-sources.jar \
        -Durl=https://oss.sonatype.org/service/local/staging/deploy/maven2/ \
        -DrepositoryId=ossrh \
        --fail-at-end
}

function close_release_drop_staging_repositories {
    $maven --batch-mode \
        org.sonatype.plugins:nexus-staging-maven-plugin:rc-close \
        org.sonatype.plugins:nexus-staging-maven-plugin:rc-release \
        org.sonatype.plugins:nexus-staging-maven-plugin:rc-drop \
        -DserverId=ossrh \
        -DnexusUrl=https://oss.sonatype.org/ \
        -DstagingRepositoryId=$1
}

if $drop_existing; then
    drop_existing_staging_repositories
else
    fail_if_staging_repository_exists
fi

# deploys using the gpg:sign-and-deploy-file goal which always creates an implicit staging repository
deploy_to_staging_repository
# query for the ID of the staging repository implicitly created in the previous step
repositories=$(list_staging_repositories | head -c -1)
if [ "$(echo $repositories | wc -l)" != "1" ]; then
    echo "Expected exactly one repository - check https://oss.sonatype.org/#stagingRepositories"
    exit 1
fi
close_release_drop_staging_repositories $repositories
