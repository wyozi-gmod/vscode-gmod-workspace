# gmod-workspace

VSCode plugin to reload/load .lua files on a GarrysMod SRCDS when running a VSCode command.

Basically this is Garry's Mod's own autoreload, except completely controllable by you as the developer
and triggerable remotely.

## Requirements

- **VSCode**
  - [Remote - SSH](https://code.visualstudio.com/docs/remote/ssh) connected to the same server as SRCDS
- **GarrysMod Server**
  - `-allowlocalhttp` startup parameter (so we can query the VSCode server)
  - [LuaDev](https://github.com/Metastruct/luadev) installed to addons
  - `gmodworkspace.lua` installed to `garrysmod/lua/autorun/server`

## Running

Open VSCode instance using Remote SSH and install the extension.

You should see "GMod: Waiting" entry in the VSCode status bar. This means that we have a local HTTP server running to serve the Lua refresh requests.

> ## Troubleshooting
> Having no "GMod: Waiting" means that the activation event for gmod-workspace was not triggered.
>
> Make sure you open the `garrysmod` folder (with addons, gamemodes, etc) in VSCode 

Assuming you have correctly installed `gmodworkspace.lua`, the status bar item should turn into "GMod: Connected" soon. This means that the server is succesfully requesting data from our editor and the workflow should be enabledß.

Now you can start using the extension. Edit something, run one of the commands starting with "GModDev: Run", and you should see the file be refreshed ingame (or an error message in console).

## Architecture

1. VSCode extension detects that we're in Garry's Mod folder and activates a local HTTP server
2. GMod server polls the HTTP server every few seconds
3. You run a VSCode command, the currently active file is appended to an internal list and served by the HTTP server for the next polling. 

HTTP polling was chosen instead of sockets to not require modules and minimize implementation complexity.

## Development

Follow instructions at https://code.visualstudio.com/api/advanced-topics/remote-extensions#installing-a-development-version-of-your-extension to test development version.