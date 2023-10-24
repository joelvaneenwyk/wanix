
export class Task {
  constructor(initfs, pid=0) {
    this.initfs = initfs;
    this.pid = pid;
  }

  async init(path, args, opts={}) {
    const name = `${(path || "task")}.${this.pid}`;

    const blob = new Blob([
      this.initfs["worker.js"], 
      this.initfs["wasm.js"],
      `\n//# sourceURL=${name}\n` // names the worker in logs
    ], { type: 'application/javascript' });
    
    this.worker = new Worker(URL.createObjectURL(blob), {type: "module", name});
    this.worker.onerror = (e) => { throw e };
    this.worker.postMessage({init: {
      pid: this.pid,
      ppid: (globalThis.process) ? globalThis.process.pid : -1,
      fs: this.initfs,
      dir: opts.dir || "/",
    }});
    
    const taskReady = new Promise((resolve) => {
      this.worker.addEventListener("message", (e) => {
        if (e.data.ready) {
          resolve();
        }
      })
    });

    const duplex = await import(URL.createObjectURL(this.initfs["duplex.js"]));
    this.pipe = duplex.open(new duplex.WorkerConn(this.worker), new duplex.CBORCodec());
    this.pipe.respond();

    // if in kernel worker
    if (globalThis.api) {
      this.pipe.handle("fs", duplex.handlerFrom(globalThis.api.fs));
      this.pipe.handle("proc", duplex.handlerFrom(globalThis.api.proc));
      this.pipe.handle("tty", duplex.handlerFrom(globalThis.api.tty));  
    }
    
    await taskReady;

    if (path) {
      this.exec(path, args, opts);
    }
  } 

  call(selector, args) {
    return this.pipe.call(selector, args);
  }

  async exec(path, args, opts={}) {
    if (!this.worker) {
      await this.init();
    }

    const resp = await this.pipe.call("exec", [path, args, opts]);
    return resp.value;
  }

  async stdout() {
    if (!this.worker) {
      throw "no worker";
    }
    const resp = await this.pipe.call("stdout");
    return resp.channel;
  }

  async stderr() {
    if (!this.worker) {
      throw "no worker";
    }
    const resp = await this.pipe.call("stderr");
    return resp.channel;
  }

  async output() {
    if (!this.worker) {
      throw "no worker";
    }
    const resp = await this.pipe.call("output");
    return resp.channel;
  }

  async stdin() {
    if (!this.worker) {
      throw "no worker";
    }
    const resp = await this.pipe.call("stdin");
    return resp.channel;
  }
}
//# sourceURL=task.js