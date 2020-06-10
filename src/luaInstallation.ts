import * as vscode from "vscode";
import * as path from "path";

export const installLua = async (extensionPath: string) => {
  const onDiskPath = vscode.Uri.file(
    path.join(extensionPath, "gmodworkspace.lua")
  );

  const files = await vscode.workspace.findFiles(
    "**/lua/autorun/server/admin_functions.lua"
  );

  const file = files[0];
  if (file) {
    const parentFolder = vscode.Uri.joinPath(file, "..");
    await vscode.workspace.fs.copy(
      onDiskPath,
      vscode.Uri.joinPath(parentFolder, "gmodworkspace.lua"),
      {
        overwrite: true,
      }
    );
    vscode.window.showInformationMessage(
      `Lua module installed! Reload the map to activate.`
    );
    // TODO we could use gmod-workspace itself to reload the script
  } else {
    vscode.window.showErrorMessage(
      `Unable to find GarrysMod root autorun folder (we looked for "lua/autorun/server/admin_functions.lua" in workspace)`
    );
  }

  //vscode.workspace.fs.copy(onDiskPath, )
};
