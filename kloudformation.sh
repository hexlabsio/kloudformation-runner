#!/bin/bash -e

KOTLIN_VERSION="1.3.21"
KOTLIN_LIBRARIES=("stdlib" "stdlib-common" "stdlib-jdk8" "reflect")
RUNNER_VERSION="1.1.XXXXX"
DEFAULT_VERSION="YYYYY"
VERSION=${DEFAULT_VERSION}
INSTALL_DIRECTORY=~/.kloudformation

STACK_FILE="stack/Stack.kt"
STACK_CLASS="Stack"
STACK_NAME=""
TEMPLATE_NAME="template.yml"
REGION="eu-west-1"
QUITE=
FORCE=
JSON=
MODULES=()
EXTRA_ARGS=()

BUCKET_ARG=("-bucket" "arg" "BUCKET" "Name of S3 Bucket to upload to")
KEY_ARG=("-key" "arg" "KEY" "Location in S3 to upload to")
LOCATION_ARG=("-location" "arg" "LOCATION" "Location of File or Directory to upload from")
VERSION_ARG=("-version" "arg" "VERSION" "Sets KloudFormation Version (Default = ${DEFAULT_VERSION})")
V_ARG=("-v" "arg" "VERSION" "Sets KloudFormation Version (Default = ${DEFAULT_VERSION})")
STACK_FILE_ARG=("-stack-file" "arg" "STACK_FILE" "Name of Kotlin file containing your stack code (Default = stack/Stack.kt)")
STACK_NAME_ARG=("-stack-name" "arg" "STACK_NAME" "Name of CloudFormation stack used for deploying")
STACK_CLASS_ARG=("-stack-class" "arg" "STACK_CLASS" "Name of the class inside -stack-file implementing io.kloudformation.StackBuilder (Default = Stack)")
TEMPLATE_NAME_ARG=("-template" "arg" "TEMPLATE_NAME" "Name of the output template file (Default = template.yml)")
INSTALL_DIRECTORY_ARG=("-install-dir" "arg" "INSTALL_DIRECTORY" "Directory to install kloudformation to (Default = ~/.kloudformation)")
REGION_ARG=("-region" "arg" "REGION" "An AWS region")
R_ARG=("-r" "arg" "REGION")
FUNCTION_NAME_ARG=("-function-name" "arg" "FUNCTION_NAME")
INVOCATION_TYPE_ARG=("-invocation-type" "arg" "INVOCATION_TYPE")
QUALIFIER_ARG=("-qualifier" "arg" "QUALIFIER")
CONTEXT_ARG=("-context" "arg" "CONTEXT")
PAYLOAD_ARG=("-payload" "arg" "PAYLOAD")
OUTPUT_ARG=("-output" "arg" "OUTPUT")
STACK_OUTPUTS_FILE_ARG=("-stack-outputs-file" "arg" "STACK_OUTPUTS_FILE")
SF_ARG=("-sf" "arg" "STACK_OUTPUTS_FILE")

MODULE_ARG=("-module" "array" "MODULES" "Includes a KloudFormation Module Named kloudformation-<<Module>>-module")
EXTRAS_ARG_ARG=("-arg" "array" "EXTRA_ARGS")
A_ARG=("-a" "array" "EXTRA_ARGS")

STACKS_ARG_ARG=("-stack-outputs" "array" "STACKS_ARGS")
S_ARG=("-s" "array" "STACKS_ARGS")

M_ARG=("-m" "array" "MODULES")
QUITE_ARG=("-quite" "toggle" "QUITE")
Q_ARG=("-q" "toggle" "QUITE")
FORCE_ARG=("-force" "toggle" "FORCE")
F_ARG=("-f" "toggle" "FORCE")
JSON_ARG=("-json" "toggle" "JSON")

TRANSPILE_ARGS=("STACK_FILE_ARG" "STACK_CLASS_ARG" "TEMPLATE_NAME_ARG" "JSON_ARG" "STACKS_ARG_ARG" "STACK_OUTPUTS_FILE_ARG")
INVERT_ARGS=("STACK_FILE_ARG" "TEMPLATE_NAME_ARG")
COMMON_ARGS=("QUITE_ARG" "MODULE_ARG" "VERSION_ARG" "INSTALL_DIRECTORY_ARG" "REGION_ARG" "EXTRAS_ARG_ARG")
SHORT_ARGS=("Q_ARG" "M_ARG" "V_ARG" "R_ARG" "F_ARG" "A_ARG" "S_ARG" "SF_ARG")
UPLOAD_ARGS=("BUCKET_ARG")
UPLOAD_NOT_REQUIRED_ARGS=("KEY_ARG" "LOCATION_ARG")
DEPLOY_ARGS=("STACK_NAME_ARG" "STACK_FILE_ARG" "STACK_CLASS_ARG" "TEMPLATE_NAME_ARG" "JSON_ARG")
DEPLOY_NOT_REQUIRED_ARGS=(${UPLOAD_ARGS[@]} "OUTPUT_ARG" "STACKS_ARG_ARG" "STACK_OUTPUTS_FILE_ARG")
LIST_ARGS=("REGION_ARG")
DELETE_ARGS=("STACK_NAME_ARG" "FORCE_ARG")
INVOKE_ARGS=("FUNCTION_NAME_ARG")
INVOKE_NOT_REQUIRED_ARGS=("INVOCATION_TYPE_ARG" "QUALIFIER_ARG" "CONTEXT_ARG" "PAYLOAD_ARG")
ARGUMENTS=(${COMMON_ARGS[@]} ${TRANSPILE_ARGS[@]} ${SHORT_ARGS[@]} ${UPLOAD_ARGS[@]} ${UPLOAD_NOT_REQUIRED_ARGS[@]} ${DEPLOY_ARGS[@]} ${DEPLOY_NOT_REQUIRED_ARGS[@]} ${LIST_ARGS[@]} ${DELETE_ARGS[@]} ${INVERT_ARGS[@]} ${INVOKE_ARGS[@]} ${INVOKE_NOT_REQUIRED_ARGS[@]})
COMMANDS=("help" "transpile" "init" "version" "update"  "deploy" "invert" "idea" "delete" "list" "upload" "invoke")

EXTRA_ARGS=()
STACKS_ARGS=()

SELECTED_COMMAND="transpile"

REQUIRED_COMMANDS=("curl" "unzip")

log () {
    if [[ -z ${QUITE} ]]; then echo $@; fi
}

error () {
    echo "ERROR: $@"
    echo
    exit 1
}

log_arguments() {
    for ARG in $@; do
     eval "ACTUAL_ARG=\${${ARG}[2]}"
     eval "ARG_TYPE=\${${ARG}[1]}"
     if [[ "${ARG_TYPE}" == "toggle" ]]; then
        eval "ARG_VALUE=\${${ACTUAL_ARG}}"
        if [[ -z "${ARG_VALUE}" ]]; then
            eval "log \${${ARG}[0]} = off"
        else
            eval "log \${${ARG}[0]} = on"
        fi
     elif [[ "${ARG_TYPE}" == "array" ]]; then
        if [[ "${ACTUAL_ARG}" != "EXTRA_ARGS" ]]; then
            eval "ARG_VALUE=\${${ARG}[2]}"
            eval "ARG_VALUE_LIST=\${${ARG_VALUE}[@]}"
            local ARG_VALUES=""
            for ARG_VAL in ${ARG_VALUE_LIST[@]}; do
                ARG_VALUES="${ARG_VALUES} ${ARG_VAL}"
            done
            eval "log \${${ARG}[0]} = ${ARG_VALUES}"
        fi
     else
        eval "log \${${ARG}[0]} = \${${ACTUAL_ARG}}"
     fi
    done
    log
}
require_arguments() {
    REQUIRED_ARGS_NOT_SET=
    for ARG in $@; do
     eval "ACTUAL_ARG=\${${ARG}[2]}"
     eval "ARG_TYPE=\${${ARG}[1]}"
     if [[ "${ARG_TYPE}" == "arg" ]]; then
        eval "ARG_VALUE=\${${ACTUAL_ARG}}"
        if [[ -z "${ARG_VALUE}" ]]; then
            eval "NOT_SET=\${${ARG}[0]}"
            eval "DESCRIPTION=\${${ARG}[3]}"
            REQUIRED_ARGS_NOT_SET="${REQUIRED_ARGS_NOT_SET}${NOT_SET} "
            if [[ -z ${DESCRIPTION} ]]; then
                eval "echo Argument not set \${${ARG}[0]}"
            else
                eval "echo Argument not set \${${ARG}[0]} \(${DESCRIPTION}\)"
            fi
        fi
     fi
    done
    if [[ ! -z "${REQUIRED_ARGS_NOT_SET}" ]]; then
        echo
        error "Required Arguments not set: ${REQUIRED_ARGS_NOT_SET}"
    fi
}

list_arguments() {
    log Machine: $( machine )
    log
    log Arguments:
    log_arguments $@
    if [[ "${MODULE_LIST}" != "" ]]; then
        log Modules: ${MODULE_LIST}
    fi
}

checkRequirements() {
    local FAILED=
    for requirement in ${REQUIRED_COMMANDS[@]}; do
        if [[ ! `which $requirement` ]]; then
            echo "ERROR: Could not find $requirement command"
            FAILED=true
        fi
    done
    if [[ ! -z ${FAILED} ]]; then exit 1; fi
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
                error Argument ${arg} cannot be found
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
        CYGWIN*)    echo Windows;;
        MINGW*)     echo Windows;;
        *)          echo "UNKNOWN:${unameOut}"
    esac
}

help () {
    echo "
OPTIONS (Replace names in angle braces << Name >>)
   -quite, -q                         Makes logging less verbose (Default off)
   -arg, -a                           Add extra arg to pass to Stack
   -force, -f                         Used to force Deletes without prompt
   -stack-file <<File Name>>          Name of Kotlin file containing your stack code (Default = stack/Stack.kt)
   -stack-name <<Stack Name>>         Name of CloudFormation stack used for deploying (Not set by Default)
   -stack-class <<Class Name>>        Name of the class inside -stack-file implementing io.kloudformation.StackBuilder (Default = Stack)
   -template <<Template Name>>        Name of the output template file (Default = template.yml)
   -region, -r <<Region>>             The AWS Region to deploy to (Default = eu-west-1)
   -module, -m <<Module>>@<<Version>> Includes a KloudFormation Module Named kloudformation-<<Module>>-module
   -version, -v <<Version>>           Sets KloudFormation Version (Default = ${DEFAULT_VERSION})
   -install-dir <Directory>>          Directory to install kloudformation to (Default = ~/.kloudformation)
   init                               Initialise a Stack with class name matching -stack-class and filename matching -stack-file
   deploy                             Deploys -template to AWS with Stack Named -stack-name
   delete                             Deletes -stack-name in -region (Use comma delimited names for multiple)
   list                               Lists all stacks in -region
   invert                             Inverts -template (CloudFormation) into a KloudFormation stack
   version                            Prints the Version of KloudFormation
   update                             Downloads the latest version of this script and installs it
   help                               Prints this
"
    exit 0
}

init() {
    downloadClasspath
    log
    log Initialising ${STACK_FILE}
    log
    if [[ -f "${STACK_FILE}" ]]; then
        error ${STACK_FILE} already exists
    else
        if [[ ${STACK_FILE} == *"/"* ]]; then mkdir -p ${STACK_FILE%/*}; fi
        echo "import io.kloudformation.KloudFormation
import io.kloudformation.StackBuilder

class ${STACK_CLASS}: StackBuilder {
    override fun KloudFormation.create(args: List<String>) {
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
            if [[ ! -f ${INSTALL_DIRECTORY}/java/jdk-8u202-ojdkbuild-linux-x64/bin/java ]]; then
                log Downloading Java 1.8;
                mkdir -p ${INSTALL_DIRECTORY}/java
                local CURRENT_DIR=${PWD}
                cd ${INSTALL_DIRECTORY}/java
                curl https://github.com/ojdkbuild/contrib_jdk8u-ci/releases/download/jdk8u202-b08/jdk-8u202-ojdkbuild-linux-x64.zip -silent -L -o openjdk.zip
                set +e
                unzip -o -qq openjdk.zip 2>/dev/null 1>/dev/null
                set -e
                rm -rf openjdk.zip
                cd ${CURRENT_DIR}
            fi
            export JAVA_HOME=${INSTALL_DIRECTORY}/java/jdk-8u202-ojdkbuild-linux-x64
            JAVA=${INSTALL_DIRECTORY}/java/jdk-8u202-ojdkbuild-linux-x64/bin/java
        else
            error Could not find Java 1.8, Install Java or set JAVA_HOME
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
        KOTLIN=${INSTALL_DIRECTORY}/kotlin/kotlinc/bin/kotlinc
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
        else
           error Could not download ${NAME} from ${URL}
        fi
    fi
}

kloudformationRunnerJar() {
    local FILE="kloudformation-runner-${RUNNER_VERSION}-all.jar"
    local URL=https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fhexlabs%2Fkloudformation-runner%2F${RUNNER_VERSION}%2F${FILE}
    if [[ ! -f "${INSTALL_DIRECTORY}/${FILE}" ]]; then
        log Downloading kloudformation-runner from ${URL}
        curl "${URL}" -slient -L -o "${INSTALL_DIRECTORY}/${FILE}"
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
    CLASSPATH="${INSTALL_DIRECTORY}/kloudformation-${VERSION}.jar"
    local SEPARATOR=":"
    if [[ $( machine ) == "Windows" ]]; then SEPARATOR="\;"; fi
    for module in ${MODULES[@]}; do
        MODULE_VERSION=( ${module/@/ } )
        moduleDownload ${MODULE_VERSION[@]}
        CLASSPATH=${CLASSPATH}${SEPARATOR}${INSTALL_DIRECTORY}/kloudformation-${MODULE_VERSION[0]}-module-${MODULE_VERSION[1]}.jar
    done
    for jar in ${KOTLIN_LIBRARIES[@]}; do
        CLASSPATH=${CLASSPATH}${SEPARATOR}${INSTALL_DIRECTORY}/kotlin-${jar}-${KOTLIN_VERSION}.jar
    done
}

downloadClasspath() {
    checkRequirements
    mkdir -p ${INSTALL_DIRECTORY}
    local CURRENT_DIR=${PWD}
    cd ${INSTALL_DIRECTORY}
    javaCommand
    kotlinCommand
    kloudformationJar ${VERSION}
    kotlinJars
    setClasspath
    cd ${CURRENT_DIR}
}

setEnvironment() {
    for OUTPUT in $@; do
        IFS='='
        read -ra KEYVALUE <<< "$OUTPUT"
        IFS=' '
        export ${KEYVALUE[0]}=${KEYVALUE[1]}
    done
}

join_by() { local IFS="$1"; shift; echo "$*"; }

transpile() {
    log_arguments ${TRANSPILE_ARGS[@]}
    log
    log Transpiling ${STACK_FILE}
    log
    if [[ ! -f "${STACK_FILE}" ]]; then error Could not find ${STACK_FILE}; fi
    downloadClasspath
    kloudformationRunnerJar
    local JSON_YAML=yaml
    if [[ ! -z "$JSON" ]]; then JSON_YAML=json; fi
    if [[ ! -z "$STACK_OUTPUTS_FILE" ]]; then OUTPUTSTACKOUTPUTARG='-stack-output-file '${STACK_OUTPUTS_FILE}; fi
    local STACKS=`join_by , ${STACKS_ARGS[@]}`
    log ${OUTPUTSTACKOUTPUTARG}
    local OUTPUTS=( $("$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar outputs ${REGION_ARG[0]} "$REGION" -stacks ${STACKS} ${OUTPUTSTACKOUTPUTARG}) )
    setEnvironment ${OUTPUTS[@]}
    "$KOTLIN" -classpath ${CLASSPATH} "$STACK_FILE" -include-runtime -d ${INSTALL_DIRECTORY}/stack.jar
    "$JAVA" -classpath ${INSTALL_DIRECTORY}/stack.jar:${CLASSPATH} io.kloudformation.StackBuilderKt "$STACK_CLASS" "$TEMPLATE_NAME" "$JSON_YAML" $@
    log
    log Template generated to ${TEMPLATE_NAME}
    log
}

invert() {
    log_arguments ${INVERT_ARGS[@]}
    downloadClasspath
    log Inverting ${TEMPLATE_NAME}
    log
    "$JAVA" -classpath ${CLASSPATH} io.kloudformation.InverterKt "$TEMPLATE_NAME" "" "$STACK_FILE"
    log Stack File created at "$STACK_FILE"
    log
}

version() {
    echo ${DEFAULT_VERSION}
}

update() {
    curl -sSL install.kloudformation.hexlabs.io | sh
    echo Updated to version `kloudformation version`
}

deploy() {
    log_arguments ${DEPLOY_ARGS[@]} ${DEPLOY_NOT_REQUIRED_ARGS[@]}
    require_arguments ${DEPLOY_ARGS[@]}
    downloadClasspath
    kloudformationRunnerJar
    QUITE=true
    for MODULE in ${MODULES[@]}; do
        MODULE_VERSION=( ${module/@/ } )
        if [[ "${MODULE_VERSION[0]}" == "serverless" ]]; then
            upload
            break
        fi
    done
    transpile ${KEY} $@
    if [[ ! -z "${OUTPUT}" ]]; then OUTPUT_COMMAND=" -output ${OUTPUT}"; fi
    "$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar ${STACK_NAME_ARG[0]} "$STACK_NAME" ${TEMPLATE_NAME_ARG[0]} "$TEMPLATE_NAME" ${REGION_ARG[0]} "$REGION"${OUTPUT_COMMAND}
}

delete() {
    log_arguments ${DELETE_ARGS[@]}
    require_arguments ${DELETE_ARGS[@]}
    local FORCEFLAG=""
    if [[ ! -z "${FORCE}" ]]; then FORCEFLAG="--force ";fi
    downloadClasspath
    kloudformationRunnerJar
    "$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar delete ${FORCEFLAG}${STACK_NAME_ARG[0]} "$STACK_NAME" ${REGION_ARG[0]} "$REGION"
}

list() {
    log_arguments ${LIST_ARGS[@]}
    require_arguments ${LIST_ARGS[@]}
    downloadClasspath
    kloudformationRunnerJar
    "$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar list ${REGION_ARG[0]} "$REGION"
}

idea() {
    if [[ ! `ls` ]]; then
    init
    fi
    DIRECTORY_NAME=${PWD##*/}
    mkdir -p .idea/libraries
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<module type=\"JAVA_MODULE\" version=\"4\">
  <component name=\"NewModuleRootManager\" inherit-compiler-output=\"true\">
    <exclude-output />
    <content url=\"file://\$MODULE_DIR\$\">
      <sourceFolder url=\"file://\$MODULE_DIR\$/stack\" isTestSource=\"false\" />
    </content>
    <orderEntry type=\"inheritedJdk\" />
    <orderEntry type=\"sourceFolder\" forTests=\"false\" />
    <orderEntry type=\"library\" name=\"kloudformation\" level=\"project\" />
  </component>
</module>" > ".idea/${DIRECTORY_NAME}.iml"

    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<project version=\"4\">
  <component name=\"ProjectModuleManager\">
    <modules>
      <module fileurl=\"file://\$PROJECT_DIR\$/.idea/${DIRECTORY_NAME}.iml\" filepath=\"\$PROJECT_DIR\$/.idea/${DIRECTORY_NAME}.iml\" />
    </modules>
  </component>
</project>" > ".idea/modules.xml"

    echo "<component name=\"libraryTable\">
  <library name=\"kloudformation\">
    <CLASSES>
      <root url=\"jar://${INSTALL_DIRECTORY}/kloudformation-${VERSION}.jar!/\" />" > ".idea/libraries/kloudformation.xml"
    for JAR in ${KOTLIN_LIBRARIES[@]}; do
      echo "      <root url=\"jar://${INSTALL_DIRECTORY}/kotlin-${JAR}-${KOTLIN_VERSION}.jar!/\" />" >> ".idea/libraries/kloudformation.xml"
    done
    for module in ${MODULES[@]}; do
        MODULE_VERSION=( ${module/@/ } )
        JAR="kloudformation-${MODULE_VERSION[0]}-module-${MODULE_VERSION[1]}"
        echo "      <root url=\"jar://${INSTALL_DIRECTORY}/${JAR}.jar!/\" />" >> ".idea/libraries/kloudformation.xml"
    done
    echo "    </CLASSES>
    <JAVADOC />
    <SOURCES />
  </library>
</component>" >> ".idea/libraries/kloudformation.xml"
    if [[ `which idea` ]]; then
        `which idea` .
    else
        echo
        echo Open this directory in intelliJ to build your stack
        echo
    fi
}

upload() {
    log_arguments ${UPLOAD_ARGS[@]} ${UPLOAD_NOT_REQUIRED_ARGS[@]}
    require_arguments ${UPLOAD_ARGS[@]}
    downloadClasspath
    kloudformationRunnerJar
    if [[ -z "${LOCATION}" ]]; then LOCATION="${PWD}"; fi
    if [[ -z "${KEY}" ]]; then
        if [[ ! -f ${LOCATION} ]]; then KEYEND=.zip; fi
        if [[ ! -z ${STACK_NAME} ]]; then KEYPRE=${STACK_NAME}/; fi
        KEY=$KEYPRE$RANDOM$RANDOM$RANDOM-`date '+%Y-%m-%d-%H:%M:%S'`/${LOCATION##*/}${KEYEND};
    fi
    "$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar uploadZip ${REGION_ARG[0]} "$REGION" -bucket ${BUCKET} -key ${KEY} -location "${LOCATION}"
}

invoke() {
    log_arguments ${INVOKE_ARGS[@]} ${INVOKE_NOT_REQUIRED_ARGS[@]}
    require_arguments ${INVOKE_ARGS[@]}
    downloadClasspath
    kloudformationRunnerJar
    local COMMAND_STRING="-function-name ${FUNCTION_NAME}"
    if [[ ! -z "${INVOCATION_TYPE}" ]]; then COMMAND_STRING=${COMMAND_STRING}" -invocation-type ${INVOCATION_TYPE}"; fi
    if [[ ! -z "${QUALIFIER}" ]]; then COMMAND_STRING=${COMMAND_STRING}" -qualifier ${QUALIFIER}"; fi
    if [[ ! -z "${CONTEXT}" ]]; then COMMAND_STRING=${COMMAND_STRING}" -context ${CONTEXT}"; fi
    if [[ ! -z "${PAYLOAD}" ]]; then COMMAND_STRING=${COMMAND_STRING}" -payload ${PAYLOAD}"; fi
    if [[ ! -z "${QUITE}" ]]; then COMMAND_STRING=${COMMAND_STRING}" --disable-logs"; fi
    log
    log "Invoking Lambda [ ${FUNCTION_NAME} ]"
    log
    "$JAVA" -jar ${INSTALL_DIRECTORY}/kloudformation-runner-${RUNNER_VERSION}-all.jar invoke ${REGION_ARG[0]} "$REGION" ${COMMAND_STRING}
}

log
log "############### KloudFormation ${VERSION} ##################"
log
log Command: ${SELECTED_COMMAND}
log
list_arguments ${COMMON_ARGS[@]}

${SELECTED_COMMAND} ${EXTRA_ARGS[@]}