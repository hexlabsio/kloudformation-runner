#!/bin/bash

STACK_FILE="Stack.kt"
STACK_CLASS="Stack"
TEMPLATE_NAME="template.yml"
LAST_ARG=""

mkdir -p kloudformation
cd kloudformation

for arg in "$@"
do
    if [[ ${arg} =~ ^-.* ]]; then
        LAST_ARG=${arg}
    elif [[ ! -z ${LAST_ARG} ]]; then
        if [[ "$LAST_ARG" == "-stack-file" ]]; then
            STACK_FILE="$arg"
        elif [[ "$LAST_ARG" == "-template" ]]; then
            TEMPLATE_NAME="$arg"
        elif [[ "$LAST_ARG" == "-stack-class" ]]; then
            STACK_CLASS="$arg"
        else
            echo invalid argument ${arg}
            exit 1
        fi
    else
       echo invalid argument ${arg}
       exit 1
    fi
done

echo STACK_FILE=${STACK_FILE}
echo STACK_CLASS=${STACK_CLASS}
echo TEMPLATE_NAME=${TEMPLATE_NAME}


if [[ `which kotlinc` ]]; then
    KOTLIN=`which kotlinc`
else
    if [[ ! -d kotlinc ]]; then
        echo Downloading Kotlin Compiler 1.3.10
        mkdir -p kotlin
        curl https://github.com/JetBrains/kotlin/releases/download/v1.3.10/kotlin-compiler-1.3.10.zip -silent -L -o kotlin/kotlin.zip
        unzip -qq kotlin.zip
        rm -f kotlin.zip
    fi
    KOTLIN=kloudformation/kotlin/kotlinc/bin/kotlinc
fi

"$KOTLIN" -version

if [[ ! -f kloudformation.jar ]]; then
    echo Downloading KloudFormation 0.1.35
    curl https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fkloudformation%2Fkloudformation%2F0.1.35%2Fkloudformation-0.1.35-uber.jar -silent -L -o kloudformation.jar
fi

DOWNLOAD_JAVA=false
if [[ -z "$JAVA_HOME" ]]; then
    if [[ `which java` ]]; then
        JAVA=java
    elif [[ -d "./java/jdk-8u202-ojdkbuild-linux-x64" ]]; then
        JAVA=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
    else
        DOWNLOAD_JAVA=true
    fi
else
    JAVA="$JAVA_HOME"/jre/bin/java
fi

if [[ ! -z "$JAVA" ]]; then
    JAVA_VERSION=`"$JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}'`
    if [[ "${JAVA_VERSION:0:3}" != "1.8" ]]; then
        if [[ -d "./java/jdk-8u202-ojdkbuild-linux-x64" ]]; then
            JAVA=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
        else
            DOWNLOAD_JAVA=true
        fi
    fi
fi

if [[ "$DOWNLOAD_JAVA" == "true" ]]; then
    echo Downloading Java 1.8
    mkdir -p java
    cd java
    curl https://github.com/ojdkbuild/contrib_jdk8u-ci/releases/download/jdk8u202-b08/jdk-8u202-ojdkbuild-linux-x64.zip -silent -L -o openjdk.zip
    unzip -qq openjdk.zip
    rm -rf openjdk.zip
    JAVA=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
    cd ..
fi
cd ..
"$KOTLIN" -classpath kloudformation/kloudformation.jar "$STACK_FILE" -include-runtime -d kloudformation/stack.jar
"$JAVA" -classpath kloudformation/stack.jar:kloudformation/kloudformation.jar io.kloudformation.StackBuilderKt "$STACK_CLASS" "$TEMPLATE_NAME"