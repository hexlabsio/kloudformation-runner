mkdir -p kotlin
cd kotlin
if [ ! -d kotlinc ]; then
    echo Downloading Kotlin Compiler 1.3.10
    curl https://github.com/JetBrains/kotlin/releases/download/v1.3.10/kotlin-compiler-1.3.10.zip -silent -L -o kotlin.zip
    unzip -qq kotlin.zip
    rm -f kotlin.zip
fi

if [ ! -f kloudformation.jar ]; then
    echo Downloading KloudFormation 0.1.35
    curl https://bintray.com/hexlabsio/kloudformation/download_file?file_path=io%2Fkloudformation%2Fkloudformation%2F0.1.35%2Fkloudformation-0.1.35-uber.jar -silent -L -o kloudformation.jar
fi
cd ..

kotlin/kotlinc/bin/kotlinc -classpath kotlin/kloudformation.jar "$1" -include-runtime -d kotlin/stack.jar
java -classpath kotlin/stack.jar:kotlin/kloudformation.jar io.kloudformation.StackBuilderKt "$2" "$3"