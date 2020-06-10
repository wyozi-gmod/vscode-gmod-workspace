// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from "vscode";
import { HTTP } from "./http";
import { pathToGModRelative } from "./gmodPath";
import { installLua } from "./luaInstallation";

let http: HTTP;
let serverStatusBarItem: vscode.StatusBarItem;
let lastCallback: number | null = null;

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
  http = new HTTP();

  serverStatusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  serverStatusBarItem.command = "gmod-workspace.openCommsServer";
  context.subscriptions.push(serverStatusBarItem);

  context.subscriptions.push(
    vscode.commands.registerCommand("gmod-workspace.openCommsServer", () => {
      vscode.window.showInformationMessage(
        `Communications server is running at ${http.commsUrl}`
      );
    })
  );

  // Mark as runnin so menu options show up
  vscode.commands.executeCommand("setContext", "gmod-workspace:running", true);

  serverStatusBarItem.text = "GMod: Waiting";
  serverStatusBarItem.show();

  http.onQueueRequested(() => {
    serverStatusBarItem.text = "GMod: Connected";
    lastCallback = +new Date();
  });
  setInterval(() => {
    if (!lastCallback || lastCallback < +new Date() - 30000) {
      serverStatusBarItem.text = "GMod: Disconnected";
    }
  }, 10000);

  const pushFileCommand = (type: string) => () => {
    const absPath = vscode.window.activeTextEditor?.document.uri.fsPath;
    if (absPath) {
      http.pushFileUpdate(pathToGModRelative(absPath), type);
    }
  };

  context.subscriptions.push(
    vscode.commands.registerCommand("gmod-workspace.installLua", () => {
      installLua(context.extensionPath);
    })
  );

  [
    ["gmod-workspace.runFileOnServer", "file-server"],
    ["gmod-workspace.runFileOnShared", "file-shared"],
    ["gmod-workspace.runFileOnClients", "file-clients"],
    ["gmod-workspace.runFileOnSelf", "file-self"],
  ].forEach(([command, type]) => {
    context.subscriptions.push(
      vscode.commands.registerCommand(command, pushFileCommand(type))
    );
  });

  const pushScriptCommand = (type: string) => () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      return; // No open text editor
    }

    const text = editor.document.getText(editor.selection);
    http.pushScript(text, type);
  };

  [
    ["gmod-workspace.runScriptOnServer", "script-server"],
    ["gmod-workspace.runScriptOnShared", "script-shared"],
    ["gmod-workspace.runScriptOnClients", "script-clients"],
    ["gmod-workspace.runScriptOnSelf", "script-self"],
  ].forEach(([command, type]) => {
    context.subscriptions.push(
      vscode.commands.registerCommand(command, pushScriptCommand(type))
    );
  });
}

// this method is called when your extension is deactivated
export function deactivate() {}
