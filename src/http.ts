import polka = require("polka");

// MUST be localhost. We don't want to expose this server to the global internet.
const HOST = "localhost";

export class HTTP {
  private server: polka.Polka;
  private port: number;

  private fileUpdates: Array<
    { script: string; type: string } | { path: string; type: string }
  > = [];

  private callback: (() => void) | null = null;

  constructor() {
    this.port = 56748;

    this.server = polka()
      .get("/run-queue", (req, res) => {
        res.writeHead(200, {
          "Content-Type": "application/json",
        });
        res.end(JSON.stringify(this.fileUpdates));
        this.fileUpdates = [];
        this.callback?.();
      })
      .listen(
        {
          port: this.port,
          host: HOST,
        },
        (err: any) => {
          if (err) throw err;
        }
      );
    console.log(this.server);
  }

  get commsUrl() {
    return `http://localhost:${this.port}`;
  }

  onQueueRequested(callback: () => void) {
    this.callback = callback;
  }

  pushFileUpdate(gmodPath: string, type: string) {
    this.fileUpdates.push({ path: gmodPath, type });
  }

  pushScript(script: string, type: string) {
    this.fileUpdates.push({ script, type });
  }

  dispose() {
    //this.server.server.close();
  }
}
