#!/bin/env bash

##################################################
# use `-f` param to force install latest version #
##################################################

# searching for latest ALSA release tag...
LATEST_TAG=$(curl https://api.github.com/repos/alsa-project/alsa-ucm-conf/tags -s | jq -r '.[0].name')
TARGET_FILENAME="alsa-ucm-conf-${LATEST_TAG}.zip"
TARGET_PATH="$HOME/alsa-ucm-conf"
TARGET_FULLNAME="${TARGET_PATH}/${TARGET_FILENAME}"

# latest config already exist (have been already downloaded), nothing to do
if [ -f "$TARGET_FULLNAME" ] && [ "$1" != '-f' ]
then
  echo "already on latest version (${LATEST_TAG}), use '-f' param to force update"
  exit 0
fi

mkdir "$TARGET_PATH" -p

# download & unzip latest ALSA release into TARGET_PATH
ARCHIVE_LINK="https://github.com/alsa-project/alsa-ucm-conf/archive/refs/tags/${LATEST_TAG}.zip"
curl "$ARCHIVE_LINK" --max-time 10 -o "$TARGET_FULLNAME" -L
unzip -o "$TARGET_FULLNAME" -d "$TARGET_PATH" 1>/dev/null

# creating current version files backup
NOW=$(date +%F_%H%M)
BACKUP_DIR="/usr/share/alsa/_backup.${NOW}"
sudo mkdir "$BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]
then
  echo "backup directory ${BACKUP_DIR} does not exist"
  exit 1
fi
sudo cp -r /usr/share/alsa/ucm /usr/share/alsa/ucm2 "${BACKUP_DIR}"

#####################################
# delete current ucm & ucm2 folders #
#####################################
sudo rm -f -r /usr/share/alsa/ucm /usr/share/alsa/ucm2

# copy new one
LATEST_VERSION=${LATEST_TAG//v/}
ROOT_ARCHIVE_DIR="/alsa-ucm-conf-${LATEST_VERSION}"
FULL_ROOT_ARCHIVE_DIR="${TARGET_PATH}${ROOT_ARCHIVE_DIR}"

sudo cp -r "${FULL_ROOT_ARCHIVE_DIR}/ucm" /usr/share/alsa
sudo cp -r "${FULL_ROOT_ARCHIVE_DIR}/ucm2" /usr/share/alsa

# At the moment, Ubuntu 22 can't read configuration files in version 6, but new files use this version
# o we must replace "Syntax 6" with "Syntax 4"
sudo sed -i 's/Syntax 6/Syntax 4/g' /usr/share/alsa/ucm2/USB-Audio/USB-Audio.conf

# Let's check if everything's okay with the sound config...
SOUND_DEVICE_ID=$(aplay -l | grep -m1 -F "[USB Audio]" | grep -Eo "card\s[0-9]+" | grep -Eo "[0-9]+")
alsaucm -c hw:"$SOUND_DEVICE_ID" dump text 1>/dev/null
SOUND_CONFIG_ERROR_CODE=$?

if [ $SOUND_CONFIG_ERROR_CODE -ne 0 ]; then
  echo "error in sound config, command: 'alsaucm -c hw:$SOUND_DEVICE_ID dump text'"
  exit $SOUND_CONFIG_ERROR_CODE
fi

echo reloading sound system with fresh config...
pulseaudio -k && sudo alsa force-reload
