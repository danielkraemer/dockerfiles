#!/bin/sh

set -e
export HOME=/data
cd $HOME
sed -i "/^minecraft/s#1000#$UID#g" /etc/passwd
sed -i "/^minecraft/s#1000#$GID#g" /etc/group

SHARED_PATH=$(echo $JVM_OPTS|grep shareclasses| cut -d'=' -f2|cut -d' ' -f1)
if [ -n "$SHARED_PATH" ]; then
  chmod go+rwx $SHARED_PATH
fi

if [ ! -e $HOME/eula.txt ]; then
  if [ "$EULA" != "" ]; then
    echo "# Generated via Docker on $(date)" > eula.txt
    echo "eula=$EULA" >> eula.txt
  else
    echo ""
    echo "Please accept the Minecraft EULA at"
    echo "  https://account.mojang.com/documents/minecraft_eula"
    echo "by adding the following immediately after 'docker run':"
    echo "  -e EULA=TRUE"
    echo ""
    exit 1
  fi
fi

VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json

echo "Checking version information."
case "X$VERSION" in
  X|XLATEST|Xlatest)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
  XSNAPSHOT|Xsnapshot)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.snapshot'`
  ;;
  X[1-9]*)
    VANILLA_VERSION=$VERSION
  ;;
  *)
    VANILLA_VERSION=`curl -sSL $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
esac

SERVER="minecraft_server.$VANILLA_VERSION.jar"

if [ ! -e $SERVER ]; then
  echo "Downloading $SERVER ..."
  wget -q https://s3.amazonaws.com/Minecraft.Download/versions/$VANILLA_VERSION/$SERVER
fi

setServerProp() {
  local prop=$1
  local var=$2
  if [ -n "$var" ]; then
    echo "Setting $prop to $var"
    sed -i "/$prop\s*=/ c $prop=$var" $HOME/server.properties
  fi

}

if [ ! -e server.properties ]; then
  echo "Creating server.properties"
  cp /tmp/server.properties .

  if [ -n "$WHITELIST" ]; then
    echo "Creating whitelist"
    sed -i "/whitelist\s*=/ c whitelist=true" $HOME/server.properties
    sed -i "/white-list\s*=/ c white-list=true" $HOME/server.properties
  fi

  setServerProp "motd" "$MOTD"
  setServerProp "allow-nether" "$ALLOW_NETHER"
  setServerProp "announce-player-achievements" "$ANNOUNCE_PLAYER_ACHIEVEMENTS"
  setServerProp "enable-command-block" "$ENABLE_COMMAND_BLOCK"
  setServerProp "spawn-animals" "$SPAWN_ANIMAILS"
  setServerProp "spawn-monsters" "$SPAWN_MONSTERS"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "generate-structures" "$GENERATE_STRUCTURES"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "view-distance" "$VIEW_DISTANCE"
  setServerProp "hardcore" "$HARDCORE"
  setServerProp "max-build-height" "$MAX_BUILD_HEIGHT"
  setServerProp "force-gamemode" "$FORCE_GAMEMODE"
  setServerProp "hardmax-tick-timecore" "$MAX_TICK_TIME"
  setServerProp "enable-query" "$ENABLE_QUERY"
  setServerProp "query.port" "$QUERY_PORT"
  setServerProp "enable-rcon" "$ENABLE_RCON"
  setServerProp "rcon.password" "$RCON_PASSWORD"
  setServerProp "rcon.port" "$RCON_PORT"
  setServerProp "max-players" "$MAX_PLAYERS"
  setServerProp "max-world-size" "$MAX_WORLD_SIZE"
  setServerProp "level-name" "$LEVEL"
  setServerProp "level-seed" "$SEED"
  setServerProp "pvp" "$PVP"
  setServerProp "generator-settings" "$GENERATOR_SETTINGS"
  setServerProp "online-mode" "$ONLINE_MODE"

  if [ -n "$LEVEL_TYPE" ]; then
    # normalize to uppercase
    LEVEL_TYPE=$(echo $LEVEL_TYPE|tr '[:lower:]' '[:upper:]')
    echo "Setting level type to $LEVEL_TYPE"
    # check for valid values and only then set
    case $LEVEL_TYPE in
      DEFAULT|FLAT|LARGEBIOMES|AMPLIFIED|CUSTOMIZED)
        sed -i "/level-type\s*=/ c level-type=$LEVEL_TYPE" $HOME/server.properties
        ;;
      *)
        echo "Invalid LEVEL_TYPE: $LEVEL_TYPE"
	exit 1
	;;
    esac
  fi

  if [ -n "$DIFFICULTY" ]; then
    case $DIFFICULTY in
      peaceful|0)
        DIFFICULTY=0
        ;;
      easy|1)
        DIFFICULTY=1
        ;;
      normal|2)
        DIFFICULTY=2
        ;;
      hard|3)
        DIFFICULTY=3
        ;;
      *)
        echo "DIFFICULTY must be peaceful, easy, normal, or hard."
        exit 1
        ;;
    esac
    echo "Setting difficulty to $DIFFICULTY"
    sed -i "/difficulty\s*=/ c difficulty=$DIFFICULTY" $HOME/server.properties
  fi

  if [ -n "$MODE" ]; then
    # normalize to lowercase
    MODE=$(echo $MODE|tr '[:upper:]' '[:lower:]')
    echo "Setting mode"
    case ${MODE} in
      0|1|2|3)
        ;;
      s*)
        MODE=0
        ;;
      c*)
        MODE=1
        ;;
      a*)
        MODE=2
        ;;
      s*)
        MODE=3
        ;;
      *)
        echo "ERROR: Invalid game mode: $MODE"
        exit 1
        ;;
    esac

    sed -i "/gamemode\s*=/ c gamemode=$MODE" $HOME/server.properties
  fi
fi


if [ -n "$OPS" -a ! -e ops.txt.converted ]; then
  echo "Setting ops"
  echo $OPS | awk -v RS=, '{print}' >> ops.txt
fi

if [ -n "$WHITELIST" -a ! -e white-list.txt.converted ]; then
  echo "Setting whitelist"
  echo $WHITELIST | awk -v RS=, '{print}' >> white-list.txt
fi

if [ -n "$ICON" -a ! -e server-icon.png ]; then
  echo "Using server icon from $ICON..."
  #converting with rsz.io
  CONVERT_SERVICE_URL=$(echo -e $ICON | awk '
    BEGIN{
      FS="/";
      proto="http://"
    }
    {
      domcol=3;
      if($1 !~ /http/)
      {
        proto="http://";
        domcol=1
      }
      printf("%s%s.rsz.io",proto,$domcol);
      for(i=(domcol+1); i<=NF;i++)
      {
        printf("/%s",$i)
      }
      printf("?width=64&hight=64&format=png\n")
    }')
  wget -q -O $HOME/server-icon.png $CONVERT_SERVICE_URL
fi

# Make sure files exist to avoid errors
if [ ! -e banned-players.json ]; then
	echo '' > banned-players.json
fi
if [ ! -e banned-ips.json ]; then
	echo '' > banned-ips.json
fi

# If any modules have been provided, copy them over
[ -d $HOME/mods ] || mkdir $HOME/mods
for m in /mods/*.jar
do
  if [ -f "$m" ]; then
    echo Copying mod `basename "$m"`
    cp -f "$m" $HOME/mods
  fi
done
[ -d $HOME/config ] || mkdir $HOME/config
for c in /config/*
do
  if [ -f "$c" ]; then
    echo Copying configuration `basename "$c"`
    cp -rf "$c" $HOME/config
  fi
done

chown -R minecraft:minecraft $HOME
chmod -R g+wX $HOME

echo "starting minecraft-server"
exec su -s /bin/sh -c "java $JVM_OPTS -jar $SERVER $@" minecraft 
