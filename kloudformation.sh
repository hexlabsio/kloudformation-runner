#!/bin/bash +e

VERSION="0.1.113"

STACK_FILE="Stack.kt"
STACK_CLASS="Stack"
TEMPLATE_NAME="template.yml"
QUITE=

STACK_FILE_ARG=("-stack-file" "arg" "STACK_FILE")
STACK_CLASS_ARG=("-stack-class" "arg" "STACK_CLASS")
TEMPLATE_NAME_ARG=("-template-name" "arg" "TEMPLATE_NAME")
QUITE_ARG=("-q" "toggle" "QUITE")

ARGUMENTS=("STACK_FILE_ARG" "STACK_CLASS_ARG" "QUITE_ARG")
COMMANDS=("help" "transpile" "init" "version")

SELECTED_COMMAND="transpile"


log () {
    if [[ -z ${QUITE} ]]; then echo $@; fi
}

LAST_ARG=""
for arg in "$@"; do
    if [[ "${LAST_ARG}" != "" ]]; then
        if [[ "${LAST_ARG}" != "UNKNOWN" ]]; then
            eval "${LAST_ARG}=\"${arg}\""
        fi
         LAST_ARG=""
    else
        FOUND_COMMAND=false
        for c in ${COMMANDS[@]}; do
            if [[ "$arg" == "$c" ]]; then
                FOUND_COMMAND=true
            fi
        done

        if [[ ${FOUND_COMMAND} == false ]]; then
            FOUND_ARG=false
            for a in ${ARGUMENTS[@]}; do
                eval "ARG_NAME=\${${a}[0]}"
                eval "ARG_TYPE=\${${a}[1]}"
                if [[ "${ARG_NAME}" == ${arg} ]]; then
                    if [[ "${ARG_TYPE}" == "arg" ]]; then
                         eval "LAST_ARG=\${${a}[2]}"
                     else
                        eval "TOGGLE_ARG=\${${a}[2]}"
                        eval "${TOGGLE_ARG}=true"
                     fi
                     FOUND_ARG=true
                fi
            done
            if [[ ${FOUND_ARG} == false ]]; then
                LAST_ARG="UNKNOWN"
                echo WARNING Argument ${arg} cannot be found
            fi
        else
            SELECTED_COMMAND=${arg}
        fi
    fi
done

machine () {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     echo Linux;;
        Darwin*)    echo Mac;;
        CYGWIN*)    echo Cygwin;;
        MINGW*)     echo MinGw;;
        *)          echo "UNKNOWN:${unameOut}"
    esac
}

help () {
    echo "
OPTIONS (Replace names in angle braces << Name >>)
   -q                           Makes logging less verbose (Default off)
   -stack-file <<File Name>>    Name of Kotlin file containing your stack code (Default = Stack.kt)
   -stack-class <<Class Name>>  Name of the class inside -stack-file implementing io.kloudformation.StackBuilder (Default = Stack)
   -template <<Template Name>>  Name of the output template file (Default = template.yml)
   init                         Initialise a Stack with class name matching -stack-class and filename matching -stack-file
   help                         Prints this
"
    exit 0
}

list_arguments() {
    log Machine: $( machine )
    log Arguments: \[ -stack-file: ${STACK_FILE}, -stack-class: ${STACK_CLASS}, -template-name: ${TEMPLATE_NAME} ]
}

init() {
    log Initialising ${STACK_FILE}
    if [[ -f "${STACK_FILE}" ]]; then
        echo ERROR: ${STACK_FILE} already exists
    else
        echo "import io.kloudformation.KloudFormation
import io.kloudformation.StackBuilder

class ${STACK_CLASS}: StackBuilder {
    override fun KloudFormation.create() {
    }
}" > "${STACK_FILE}"
        exit 0
    fi
}

isJava8() {
    JAVA_VERSION=`"$1" -version 2>&1 | awk -F '"' '/version/ {print $2}'`
    if [[ "${JAVA_VERSION:0:3}" == "1.8" ]]; then
        echo SUCCESS
    fi
}

javaCommand() {
    if [[ `which java` ]] && [[ `isJava8 java` ]]; then
        JAVA=java
    else
       if [[ ! -z ${JAVA_HOME} ]] && [[ `isJava8 "${JAVA_HOME}/jre/bin/java"` ]]; then
            JAVA="${JAVA_HOME}"/jre/bin/java
       elif [[ $( machine ) == "Mac" ]]; then
           if [[ -f /usr/libexec/java_home ]]; then
                JAVA_HOME=`/usr/libexec/java_home -v 1.8 2>/dev/null`
                if [[ ! -z ${JAVA_HOME} ]] && [[ `isJava8 "${JAVA_HOME}/jre/bin/java"` ]]; then
                    JAVA="${JAVA_HOME}"/jre/bin/java
                fi
           fi
       fi
    fi
    if [[ -z ${JAVA} ]]; then
        echo ERROR: Could not find Java 1.8, Install Java or set JAVA_HOME
    elif [[ $( machine ) == Linux ]]; then
        log Downloading Java 1.8;
        mkdir -p java
        cd java
        curl https://github.com/ojdkbuild/contrib_jdk8u-ci/releases/download/jdk8u202-b08/jdk-8u202-ojdkbuild-linux-x64.zip -silent -L -o openjdk.zip
        unzip -o -qq openjdk.zip 2>/dev/null 1>/dev/null
        rm -rf openjdk.zip
        JAVA=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
        cd ..
    fi
}

kotlinCommand() {
    if [[ `which kotlinc` ]]; then
        KOTLIN=`which kotlinc`
    else
        if [[ ! -d kotlin/kotlinc ]]; then
            log Downloading Kotlin Compiler 1.3.10
            mkdir -p kotlin
            cd kotlin
            curl https://github.com/JetBrains/kotlin/releases/download/v1.3.10/kotlin-compiler-1.3.10.zip -silent -L -o kotlin.zip
            unzip -o -qq kotlin.zip 2>/dev/null 1>/dev/null
            rm -f kotlin.zip
            cd ..
        fi
        KOTLIN=./kloudformation/kotlin/kotlinc/bin/kotlinc
    fi
}

kloudformationJar() {
    if [[ ! -f kloudformation-${1}.jar ]]; then
        log Downloading KloudFormation ${1}
        curl https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fkloudformation%2Fkloudformation%2F${1}%2Fkloudformation-${1}-uber.jar -silent -L -o kloudformation-${1}.jar
    fi
}

transpile() {
    list_arguments
    if [[ ! -f "${STACK_FILE}" ]]; then
        echo ERROR: Could not find ${STACK_FILE}
        exit 1
    fi
    mkdir -p kloudformation
    cd kloudformation
    javaCommand
    kotlinCommand
    kloudformationJar ${VERSION}
    cd ..
    "$KOTLIN" -classpath kloudformation/kloudformation-${VERSION}.jar "$STACK_FILE" -include-runtime -d kloudformation/stack.jar
    "$JAVA" -classpath kloudformation/stack.jar:kloudformation/kloudformation-${VERSION}.jar io.kloudformation.StackBuilderKt "$STACK_CLASS" "$TEMPLATE_NAME"
    log Template generated to ${TEMPLATE_NAME}
}

version() {
    echo ${VERSION}
}

${SELECTED_COMMAND}