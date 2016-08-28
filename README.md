This docker image provides the latest (see *Versions* section) vanilla Minecraft server runnig with IBMs Small Footprint JRE ([SFJ](http://www.ibm.com/support/knowledgecenter/en/SSYKE2_8.0.0/com.ibm.java.lnx.80.doc/user/small_jre.html))

IBMs Small Footprint JRE requires less memory and cpu. This images is also based on alpine, so less disk space is needed

To simply use the latest stable version, run

    docker run -d -p 25565:25565 --name mc luitzifa/minecraft-server-light

where the standard server port, 25565, will be exposed on your host machine.

If you want to serve up multiple Minecraft servers or just use an alternate port, change the host-side port mapping such as

    docker run -p 25566:25565 ...

will serve your Minecraft server on your host's port 25566 since the `-p` syntax is
`host-port`:`container-port`.

Speaking of multiple servers, it's handy to give your containers explicit names using `--name`, such as

    docker run -d -p 25565:25565 --name mc luitzifa/minecraft-server-light

With that you can easily view the logs, stop, or re-start the container:

    docker logs -f mc
        ( Ctrl-C to exit logs action )

    docker stop mc

    docker start mc


## Interacting with the server

In order to attach and interact with the Minecraft server, add `-it` when starting the container, such as

    docker run -d -it -p 25565:25565 --name mc luitzifa/minecraft-server-light

With that you can attach and interact at any time using

    docker attach mc

and then Control-p Control-q to **detach**.

For remote access, configure your Docker daemon to use a `tcp` socket (such as `-H tcp://0.0.0.0:2375`) and attach from another machine:

    docker -H $HOST:2375 attach mc

Unless you're on a home/private LAN, you should [enable TLS access](https://docs.docker.com/articles/https/).


## EULA Support

Mojang requires accepting the [Minecraft EULA](https://account.mojang.com/documents/minecraft_eula). To accept add

        -e EULA=TRUE

such as

        docker run -d -it -e EULA=TRUE -p 25565:25565 --name mc luitzifa/minecraft-server-light


## Attaching data directory to host filesystem

In order to readily access the Minecraft data, use the `-v` argument to map a directory on your host machine to the container's `/data` directory, such as:

    docker run -d -v /path/on/host:/data ...

When attached in this way you can stop the server, edit the configuration under your attached `/path/on/host` and start the server again with `docker start CONTAINERID` to pick up the new configuration.

**NOTE**: By default, the files in the attached directory will be owned by the host user with UID of 1000 and host group with GID of 1000.
You can use an different UID and GID by passing the options:

    -e UID=1000 -e GID=1000

replacing 1000 with a UID and GID that is present on the host.
Here is one way to find the UID and GID:

    id some_host_user
    getent group some_host_group


## Versions

To use a different Minecraft version, pass the `VERSION` environment variable, which can have the value

* LATEST
* SNAPSHOT
* (or a specific version, such as "1.7.9")

For example, to use the latest snapshot:

    docker run -d -e VERSION=SNAPSHOT ...

or a specific version:

    docker run -d -e VERSION=1.7.9 ...


### Using the /data volume

This is the easiest way if you are using a persistent `/data` mount.

To do this, you will need to attach the container's `/data` directory (see "Attaching data directory to host filesystem”). Then, you can add mods to the `/path/on/host/mods` folder you chose. From the example above, the `/path/on/host` folder contents look like:

```
/path/on/host
├── mods
│   └── ... INSTALL MODS HERE ...
├── config
│   └── ... CONFIGURE MODS HERE ...
├── ops.json
├── server.properties
├── whitelist.json
└── ...
```

If you add mods while the container is running, you'll need to restart it to pick those up:

    docker stop mc
    docker start mc


### Using separate mounts

This is the easiest way if you are using an ephemeral `/data` filesystem, or downloading a world with the `WORLD` option.

There are two additional volumes that can be mounted; `/mods` and `/config`. Any files in either of these filesystems will be copied over to the main `/data` filesystem before starting Minecraft.

This works well if you want to have a common set of modules in a separate location, but still have multiple worlds with different server requirements in either persistent volumes or a downloadable archive.


## Using Docker Compose

Rather than type the server options below, the port mappings above, etc every time you want to create new Minecraft server, you can now use [Docker Compose](https://docs.docker.com/compose/). Start two Servers with a `docker-compose.yml` file like the following:

```
version: '2'
volumes:
  mc-sharedclasses:
    driver: local
services:
  mc1:
    ports:
      - "25565:25565"
    volumes:
      - /home/luitzifa/mc1:/data
      - mc-sharedclasses:/shared
    image: luitzifa/minecraft-server-light
    environment:
      ICON: 'http://i.imgur.com/6V9U5hZ.png'
      MOTD: 'strange things gonna happen here'
      JVM_OPTS: '-Xmx1024M -Xms1024M -Xshareclasses:cacheDir=/shared'
      EULA: 'TRUE'
      OPS: 'Luitzifa,nobody'
      WHITELIST: 'Luitzifa,nobody'
      MODE: 'survival'
      DIFFICULTY: 'normal'
      ALLOW_NETHER: 'true'
      SPAWN_ANIMALS: 'true'
      SPAWN_MONSTERS: 'true'
      SPAWN_NPCS: 'true'
      GENERATE_STRUCTURES: 'true'
      UID: 1000
      GID: 1000
    network_mode: "bridge"
    tty: true
    stdin_open: true
    restart: always
  mc2:
    ports:
      - "25566:25565"
    volumes:
      - /home/luitzifa/mc2:/data
      - mc-sharedclasses:/shared
    image: luitzifa/minecraft-server-light
    environment:
      ICON: 'http://i.imgur.com/6V9U5hZ.png'
      MOTD: 'strange things gonna happen here'
      JVM_OPTS: '-Xmx1024M -Xms1024M -Xshareclasses:cacheDir=/shared'
      EULA: 'TRUE'
      OPS: 'Luitzifa,nobody'
      WHITELIST: 'Luitzifa,nobody'
      MODE: 'creative'
      DIFFICULTY: 'normal'
      ALLOW_NETHER: 'true'
      SPAWN_ANIMALS: 'false'
      SPAWN_MONSTERS: 'false'
      SPAWN_NPCS: 'false'
      GENERATE_STRUCTURES: 'true'
      UID: 1000
      GID: 1000
    network_mode: "bridge"
    tty: true
    stdin_open: true
    restart: always
```

and in the same directory as that file run

    docker-compose -d up

Now, go play...or adjust the  `environment` section to configure this server instance.    


## Server configuration

### Difficulty

The difficulty level (default: `easy`) can be set like:

    docker run -d -e DIFFICULTY=hard ...

Valid values are: `peaceful`, `easy`, `normal`, and `hard`, and an error message will be output in the logs if it's not one of these values.


### Whitelist Players

To whitelist players for your Minecraft server, pass the Minecraft usernames separated by commas via the `WHITELIST` environment variable, such as

	docker run -d -e WHITELIST=user1,user2 ...

If the `WHITELIST` environment variable is not used, any user can join your Minecraft server if it's publicly accessible.


### Op/Administrator Players

To add more "op" (aka adminstrator) users to your Minecraft server, pass the Minecraft usernames separated by commas via the `OPS` environment variable, such as

	docker run -d -e OPS=user1,user2 ...


### Server icon

A server icon can be configured using the `ICON` variable. The image will be automatically downloaded, scaled, and converted from any other image format:

    docker run -d -e ICON=http://..../some/image.png ...


### Rcon

To use rcon use the `ENABLE_RCON` and `RCON_PASSORD` variables.
By default rcon port will be `25575` but can easily be changed with the `RCON_PORT` variable.

    docker run -d -e ENABLE_RCON=true -e RCON_PASSWORD=testing


### Query

Enabling this will enable the gamespy query protocol.
By default the query port will be `25565` (UDP) but can easily be changed with the `QUERY_PORT` variable.

    docker run -d -e ENABLE_QUERY=true


### Max players

By default max players is 20, you can increase this with the `MAX_PLAYERS` variable.

    docker run -d -e MAX_PLAYERS=50


### Max world size

This sets the maximum possible size in blocks, expressed as a radius, that the world border can obtain.

    docker run -d -e MAX_WORLD_SIZE=10000   


### Allow Nether

Allows players to travel to the Nether.

    docker run -d -e ALLOW_NETHER=true


### Announce Player Achievements

Allows server to announce when a player gets an achievement.

    docker run -d -e ANNOUNCE_PLAYER_ACHIEVEMENTS=true   


### Enable  Command Block

Enables command blocks

     docker run -d -e ENABLE_COMMAND_BLOCK=true


### Force Gamemode

Force players to join in the default game mode.
- false - Players will join in the gamemode they left in.
- true - Players will always join in the default gamemode.

    docker run -d -e FORCE_GAMEMODE=false


### Generate Structures

Defines whether structures (such as villages) will be generated.
- false - Structures will not be generated in new chunks.
- true - Structures will be generated in new chunks.

    docker run -d -e GENERATE_STRUCTURES=true


### Hardcore

If set to true, players will be set to spectator mode if they die.

    docker run -d -e HARDCORE=false


### Max Build Height

The maximum height in which building is allowed. Terrain may still naturally generate above a low height limit.

    docker run -d -e MAX_BUILD_HEIGHT=256


### Max Tick Time

The maximum number of milliseconds a single tick may take before the server watchdog stops the server with the message, A single server tick took 60.00 seconds (should be max 0.05); Considering it to be crashed, server will forcibly shutdown. Once this criteria is met, it calls System.exit(1).
Setting this to -1 will disable watchdog entirely

    docker run -d -e MAX_TICK_TIME=60000


### Spawn Animals

Determines if animals will be able to spawn.

    docker run -d -e SPAWN_ANIMALS=true


### Spawn Monsters

Determines if monsters will be spawned.

    docker run -d -e SPAWN_MONSTERS=true


### Spawn NPCs

Determines if villagers will be spawned.

    docker run -d -e SPAWN_NPCS=true


### View Distance
Sets the amount of world data the server sends the client, measured in chunks in each direction of the player (radius, not diameter).
It determines the server-side viewing distance.

    docker run -d -e VIEW_DISTANCE=10


### Level Seed

If you want to create the Minecraft level with a specific seed, use `SEED`, such as

    docker run -d -e SEED=1785852800490497919 ...


### Game Mode

By default, Minecraft servers are configured to run in Survival mode. You can change the mode using `MODE` where you can either provide the [standard numerical values](http://minecraft.gamepedia.com/Game_mode#Game_modes) or the shortcut values:

* creative
* survival
* adventure
* spectator (only for Minecraft 1.8 or later)

For example:

    docker run -d -e MODE=creative ...


### Message of the Day

The message of the day, shown below each server entry in the UI, can be changed with the `MOTD` environment variable, such as

    docker run -d -e 'MOTD=My Server' ...

If you leave it off, the last used or default message will be used. _The example shows how to specify a server message of the day that contains spaces by putting quotes around the whole thing._


### PVP Mode

By default, servers are created with player-vs-player (PVP) mode enabled. You can disable this with the `PVP` environment variable set to `false`, such as

    docker run -d -e PVP=false ...


### Level Type and Generator Settings

By default, a standard world is generated with hills, valleys, water, etc. A different level type can be configured by setting `LEVEL_TYPE` to

* DEFAULT
* FLAT
* LARGEBIOMES
* AMPLIFIED
* CUSTOMIZED

Descriptions are available at the [gamepedia](http://minecraft.gamepedia.com/Server.properties).

When using a level type of `FLAT` and `CUSTOMIZED`, you can further configure the world generator by passing [custom generator settings](http://minecraft.gamepedia.com/Superflat).
**Since generator settings usually have ;'s in them, surround the -e value with a single quote, like below.**

For example (just the `-e` bits):

    -e LEVEL_TYPE=flat -e 'GENERATOR_SETTINGS=3;minecraft:bedrock,3*minecraft:stone,52*minecraft:sandstone;2;'


### World Save Name

You can either switch between world saves or run multiple containers with different saves by using the `LEVEL` option, where the default is "world":

    docker run -d -e LEVEL=bonus ...

**NOTE:** if running multiple containers be sure to either specify a different `-v` host directory for each
`LEVEL` in use or don't use `-v` and the container's filesystem will keep things encapsulated.


### Online mode

By default, server checks connecting players against Minecraft's account database. If you want to create an offline server or your server is not connected to the internet, you can disable the server to try connecting to minecraft.net to authenticate players with environment variable `ONLINE_MODE`, like this

    docker run -d -e ONLINE_MODE=FALSE ...

## JVM Configuration

### Memory Limit

The Java memory limit can be adjusted using the `JVM_OPTS` environment variable, where the default is the setting shown in the example (max and min at 1024 MB):

    docker run -e 'JVM_OPTS=-Xmx1024M -Xms1024M' ...

### Using the Class Data Sharing feature
IBM SDK, Java Technology Edition provides a feature called [Class data sharing](http://www-01.ibm.com/support/knowledgecenter/SSYKE2_8.0.0/com.ibm.java.lnx.80.doc/diag/understanding/shared_classes.html). This mechanism offers transparent and dynamic sharing of data between multiple Java virtual machines (JVMs) running on the same host thereby reducing the amount of physical memory consumed by each JVM instance. By providing partially verified classes and possibly pre-loaded classes in memory, this mechanism also improves the start up time of the JVM.

    docker run -e 'JVM_OPTS=-Xmx1024M -Xms1024M -Xshareclasses:cacheDir=/shared' -v shared:/shared ...
