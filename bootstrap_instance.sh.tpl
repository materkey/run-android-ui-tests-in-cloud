#!/bin/bash

set -xe
pwd

export ANDROID_HOME=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools/:$ANDROID_HOME/platform-tools:$ANDROID_HOME/platform-tools/bin:$ANDROID_HOME/tools/bin:$ANDROID_HOME/cmdline-tools/latest/bin

sudo service docker start

emulator_google=us-docker.pkg.dev/android-emulator-268719/images/p-playstore-x64-no-metrics:30.0.23
emulator_avito=materkey/android-emulator-29:smp2c9e604744de4
emulator_image=$emulator_avito

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
  docker run -d -e ADBKEY="$(cat ~/.android/adbkey)" \
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