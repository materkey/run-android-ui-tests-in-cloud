set -xe

export ANDROID_SDK_ROOT=/home/materkey/Android/Sdk

[ -d kaspresso ] || git clone git@github.com:KasperskyLab/Kaspresso.git kaspresso

cd kaspresso
./gradlew samples:kaspresso-sample:assembleDebug
./gradlew samples:kaspresso-sample:assembleAndroidTest
mv samples/kaspresso-sample/build/outputs/apk/debug/kaspresso-sample-debug.apk ../app.apk
mv samples/kaspresso-sample/build/outputs/apk/androidTest/debug/kaspresso-sample-debug-androidTest.apk ../test.apk
