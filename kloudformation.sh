#!/bin/bash -e

KOTLIN_VERSION="1.3.21"
KOTLIN_LIBRARIES=("stdlib" "stdlib-common" "stdlib-jdk8" "reflect")
RUNNER_VERSION="0.1.32"
DEFAULT_VERSION="0.1.116"
VERSION=${DEFAULT_VERSION}

STACK_FILE="Stack.kt"
STACK_CLASS="Stack"
STACK_NAME=""
TEMPLATE_NAME="template.yml"
REGION="eu-west-1"
QUITE=
JSON=
MODULES=()

VERSION_ARG=("-version" "arg" "VERSION")
V_ARG=("-v" "arg" "VERSION")
STACK_FILE_ARG=("-stack-file" "arg" "STACK_FILE")
STACK_NAME_ARG=("-stack-name" "arg" "STACK_NAME")
STACK_CLASS_ARG=("-stack-class" "arg" "STACK_CLASS")
TEMPLATE_NAME_ARG=("-template" "arg" "TEMPLATE_NAME")
REGION_ARG=("-region" "arg" "REGION")
R_ARG=("-r" "arg" "REGION")
MODULE_ARG=("-module" "array" "MODULES")
M_ARG=("-m" "array" "MODULES")
QUITE_ARG=("-quite" "toggle" "QUITE")
Q_ARG=("-q" "toggle" "QUITE")
JSON_ARG=("-json" "toggle" "JSON")

ARGUMENTS=("STACK_FILE_ARG" "STACK_CLASS_ARG" "TEMPLATE_NAME_ARG" "QUITE_ARG" "Q_ARG" "MODULE_ARG" "M_ARG" "VERSION_ARG" "V_ARG" "JSON_ARG" "REGION_ARG" "R_ARG" "STACK_NAME_ARG")
COMMANDS=("help" "transpile" "init" "version" "update"  "deploy" "invert")

SELECTED_COMMAND="transpile"


log () {
    if [[ -z ${QUITE} ]]; then echo $@; fi
}

LAST_ARG=""
LAST_ARG_ARRAY=false
for arg in "$@"; do
    if [[ "${LAST_ARG}" != "" ]]; then
        if [[ "${LAST_ARG}" != "UNKNOWN" ]]; then
            if [[ "${LAST_ARG_ARRAY}" == "true" ]]; then
                eval ${LAST_ARG}\+=\( \"${arg}\" \)
            else
                eval "${LAST_ARG}=\"${arg}\""
            fi
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
                    LAST_ARG_ARRAY=false
                    if [[ "${ARG_TYPE}" == "arg" ]]; then
                         eval "LAST_ARG=\${${a}[2]}"
                     elif [[ "${ARG_TYPE}" == "array" ]]; then
                         eval "LAST_ARG=\${${a}[2]}"
                         LAST_ARG_ARRAY=true
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
   -q, -quite                         Makes logging less verbose (Default off)
   -stack-file <<File Name>>          Name of Kotlin file containing your stack code (Default = Stack.kt)
   -stack-name <<Stack Name>>         Name of CloudFormation stack used for deploying (Not set by Default)
   -stack-class <<Class Name>>        Name of the class inside -stack-file implementing io.kloudformation.StackBuilder (Default = Stack)
   -template <<Template Name>>        Name of the output template file (Default = template.yml)
   -region, -r <<Region>>             The AWS Region to deploy to (Default = eu-west-1)
   -module, -m <<Module>>@<<Version>> Includes a KloudFormation Module Named kloudformation-<<Module>>-module
   -version, -v <<Version>>           Sets KloudFormation Version (Default = ${DEFAULT_VERSION})
   init                               Initialise a Stack with class name matching -stack-class and filename matching -stack-file
   deploy                             Deploys -template to AWS with Stack Named -stack-name
   invert                             Inverts -tempate (CloudFormation) into a KloudFormation stack
   version                            Prints the Version of KloudFormation
   update                             Downloads the latest version of this script and installs it
   help                               Prints this
"
    exit 0
}

list_arguments() {
    log Machine: $( machine )
    local MODULE_LIST=""
    for module in ${MODULES[@]}; do
        MODULE_VERSION=( ${module/@/ } )
        MODULE_LIST="${MODULE_LIST} kloudformation-${MODULE_VERSION[0]}-module-${MODULE_VERSION[1]}"
    done
    if [[ "${MODULE_LIST}" != "" ]]; then
        log Modules: ${MODULE_LIST}
    fi
    log Arguments: \[ -stack-file: ${STACK_FILE}, -stack-class: ${STACK_CLASS}, -template: ${TEMPLATE_NAME} ]
}

init() {
    log Initialising ${STACK_FILE}
    if [[ -f "${STACK_FILE}" ]]; then
        echo ERROR: ${STACK_FILE} already exists
    else
        if [[ ${STACK_FILE} == *"/"* ]]; then mkdir -p ${STACK_FILE%/*}; fi
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
        if [[ $( machine ) == Linux ]]; then
            if [[ ! -f java/jdk-8u202-ojdkbuild-linux-x64/bin/java ]]; then
                log Downloading Java 1.8;
                mkdir -p java
                cd java
                curl https://github.com/ojdkbuild/contrib_jdk8u-ci/releases/download/jdk8u202-b08/jdk-8u202-ojdkbuild-linux-x64.zip -silent -L -o openjdk.zip
                set +e
                unzip -o -qq openjdk.zip 2>/dev/null 1>/dev/null
                set -e
                rm -rf openjdk.zip
                export JAVA_HOME=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64
                JAVA=./kloudformation/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
                cd ..
            fi
        else
            echo ERROR: Could not find Java 1.8, Install Java or set JAVA_HOME
            exit 1
        fi
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
            set +e
            unzip -o -qq kotlin.zip 2>/dev/null 1>/dev/null
            set -e
            rm -f kotlin.zip
            cd ..
        fi
        KOTLIN=./kloudformation/kotlin/kotlinc/bin/kotlinc
    fi
}

moduleDownload() {
    local NAME=kloudformation-${1}-module
    local VERSION=${2}
    local FILE_NAME=${NAME}-${VERSION}.jar
    local URL=https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fhexlabs%2F${NAME}%2F${VERSION}%2F${FILE_NAME}
    if [[ ! -f "${FILE_NAME}" ]]; then
        log Downloading ${NAME} ${VERSION} from ${URL}
        if [[ `curl -sSL -D - ${URL} -o /dev/null | grep 200` ]]; then
            curl -sSL ${URL} -o ${FILE_NAME}
            MODULES+=( "${FILE_NAME}" )
        else
           echo ERROR: Could not download ${NAME} from ${URL}
           exit 1
        fi
    fi
}

kloudformationRunnerJar() {
    local FILE="kloudformation-runner-${RUNNER_VERSION}-uber.jar"
    local URL=https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fhexlabs%2Fkloudformation-runner%2F${RUNNER_VERSION}%2F${FILE}
    if [[ ! -f "kloudformation/${FILE}" ]]; then
        log Downloading kloudformation-runner from ${URL}
        curl "${URL}" -slient -L -o "kloudformation/${FILE}"
    fi
}

kloudformationJar() {
    if [[ ! -f kloudformation-${1}.jar ]]; then
        log Downloading KloudFormation ${1}
        curl https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fkloudformation%2Fkloudformation%2F${1}%2Fkloudformation-${1}-uber.jar -silent -L -o kloudformation-${1}.jar
    fi
}

kotlinJar() {
    local NAME=kotlin-${1}
    local FILE="${NAME}-${KOTLIN_VERSION}.jar"
    local URL=https://bintray.com/bintray/jcenter/download_file?file_path=org%2Fjetbrains%2Fkotlin%2F${NAME}%2F${KOTLIN_VERSION}%2F${NAME}-${KOTLIN_VERSION}.jar
    if [[ ! -f "${FILE}" ]]; then
        log Downloading ${NAME} from ${URL}
        curl "${URL}" -slient -L -o "${FILE}"
    fi
}

kotlinJars() {
    for jar in ${KOTLIN_LIBRARIES[@]}; do
      kotlinJar ${jar}
    done
}

setClasspath() {
    CLASSPATH="kloudformation/kloudformation-${VERSION}.jar"
    for module in ${MODULES[@]}; do
        MODULE_VERSION=( ${module/@/ } )
        moduleDownload ${MODULE_VERSION[@]}
        CLASSPATH=${CLASSPATH}:kloudformation/kloudformation-${MODULE_VERSION[0]}-module-${MODULE_VERSION[1]}.jar
    done
    for jar in ${KOTLIN_LIBRARIES[@]}; do
        CLASSPATH=${CLASSPATH}:kloudformation/kotlin-${jar}-${KOTLIN_VERSION}.jar
    done
}

downloadClasspath() {
    list_arguments
    mkdir -p kloudformation
    cd kloudformation
    javaCommand
    kotlinCommand
    kloudformationJar ${VERSION}
    kotlinJars
    setClasspath
    cd ..
}

transpile() {
    if [[ ! -f "${STACK_FILE}" ]]; then
        echo ERROR: Could not find ${STACK_FILE}
        exit 1
    fi
    downloadClasspath
    local JSON_YAML=yaml
    if [[ ! -z "$JSON" ]]; then JSON_YAML=json; fi
    "$KOTLIN" -classpath ${CLASSPATH} "$STACK_FILE" -include-runtime -d kloudformation/stack.jar
    "$JAVA" -classpath kloudformation/stack.jar:${CLASSPATH} io.kloudformation.StackBuilderKt "$STACK_CLASS" "$TEMPLATE_NAME" "$JSON_YAML"
    log Template generated to ${TEMPLATE_NAME}
}

invert() {
    downloadClasspath
    "$JAVA" -classpath ${CLASSPATH} io.kloudformation.InverterKt "$TEMPLATE_NAME" "" "$STACK_FILE"
    log Stack File created at "$STACK_FILE"
}

version() {
    echo ${DEFAULT_VERSION}
}

update() {
    curl -sSL install.kloudformation.hexlabs.io | sh
    echo Updated to version `kloudformation version`
}

deploy() {
    if [[ -z "${STACK_NAME}" ]]; then
        echo Argument -stack-name must be set to deploy to AWS
        exit 1
    fi
    transpile
    kloudformationRunnerJar
    "$JAVA" -jar kloudformation/kloudformation-runner-${RUNNER_VERSION}-uber.jar ${STACK_NAME_ARG[0]} "$STACK_NAME" ${TEMPLATE_NAME_ARG[0]} "$TEMPLATE_NAME" ${REGION_ARG[0]} "$REGION"
}

${SELECTED_COMMAND}