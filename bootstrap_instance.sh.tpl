#!/bin/bash

set -xe
pwd

sudo yum -y install unzip java
sudo mkdir -p /opt/android-sdk/cmdline-tools
export ANDROID_HOME=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools/:$ANDROID_HOME/platform-tools:$ANDROID_HOME/platform-tools/bin:$ANDROID_HOME/tools/bin:$ANDROID_HOME/cmdline-tools/latest/bin
# https://developer.android.com/studio/index.html#command-tools
export ANDROID_SDK_URL=https://dl.google.com/android/repository/commandlinetools-linux-7302050_latest.zip
export ANDROID_SDK_FILE_NAME=android-sdk.zip

curl $ANDROID_SDK_URL --progress-bar --location --output $ANDROID_SDK_FILE_NAME && \
  sudo unzip $ANDROID_SDK_FILE_NAME -d $ANDROID_HOME/cmdline-tools && \
  rm -f $ANDROID_SDK_FILE_NAME && sudo mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest

sudo touch $ANDROID_HOME/packages.txt
sudo chmod 777 $ANDROID_HOME/packages.txt
{
  echo "platform-tools"
  echo "tools"
  echo "extras;google;m2repository"
} >> $ANDROID_HOME/packages.txt

# Update sdk and install components
mkdir $HOME/.android && \
  echo "y" | sudo /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --verbose \
    --sdk_root=$ANDROID_HOME \
    --package_file=$ANDROID_HOME/packages.txt && \
  sudo chmod -R o+rwX $ANDROID_HOME

#sudo yum -y install android-tools
sudo pip3 install awscli --force-reinstall --upgrade

# remove old containers
emulator_google=us-docker.pkg.dev/android-emulator-268719/images/p-playstore-x64-no-metrics:30.0.23
emulator_avito=materkey/android-emulator-play-29:3
emulator_image=$emulator_avito

function remove_containers() {
  sudo docker ps -a | awk '{ print $1,$2 }' | grep $1 | awk '{print $1 }' | xargs -I {} sudo docker rm -f {}
}

remove_containers android-emulator-play-29
remove_containers p-playstore-x64-no-metrics

/usr/local/bin/aws s3 sync s3://my-tf-test-bucket-dc/${task_name} ./task
cd task


if [ -d marathon ]; then rm -rf marathon; fi
/usr/local/bin/aws s3 sync s3://my-tf-test-bucket-dc/marathon ./marathon && \

# connect android emulators
n=40

/opt/android-sdk/platform-tools/adb start-server
for ((i=0; i<n; i++))
do
  adb_port=$((5555 + i))
  sudo docker run -d -e ADBKEY="$(cat ~/.android/adbkey)" \
     --device /dev/kvm \
     --publish "$adb_port":5555/tcp \
     --cpus="2" \
     --memory="5g" \
     --restart=always \
     $emulator_image
done

for ((i=1; i<=n; i++))
do
  adb_port=$((5555 + i))
  /opt/android-sdk/platform-tools/adb connect localhost:$adb_port
done

# run marathon
chmod +x marathon/bin/marathon
set +e
marathon/bin/marathon -m Marathonfile
set -e

/usr/local/bin/aws s3 sync ./build s3://my-tf-test-bucket-dc/${task_name}/build

queue_url_unquoted=$(sed -e 's/^"//' -e 's/"$//' <<<"${queue_url}")
/usr/local/bin/aws sqs send-message --queue-url "$queue_url_unquoted" --message-body ${task_name} --region=${region}