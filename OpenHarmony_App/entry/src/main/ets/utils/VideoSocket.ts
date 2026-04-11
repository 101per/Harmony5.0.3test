import socket from '@ohos.net.socket';
import image from '@ohos.multimedia.image';
import { BusinessError } from '@ohos.base';

export class VideoSocket {
  private tcpSocket: socket.TCPSocket;
  private isConnected: boolean = false;
  private receiveBuffer: Uint8Array = new Uint8Array(0);

  // 防卡死：正在解码标志位
  private isDecoding: boolean = false;
  // 防卡死：上次解码时间戳
  private lastDecodeTime: number = 0;
  // 最小解码间隔 (30FPS = 33ms, 设为 40ms 保证不卡顿)
  private readonly MIN_DECODE_INTERVAL = 40;

  private onFrameCallback: (pixelMap: image.PixelMap, rawBuffer: ArrayBuffer) => void;

  constructor(callback: (pixelMap: image.PixelMap, rawBuffer: ArrayBuffer) => void) {
    this.tcpSocket = socket.constructTCPSocketInstance();
    this.onFrameCallback = callback;
  }

  connect(ip: string, port: number, topicPath: string) {
    if (this.isConnected) return;
    this.isDecoding = false;
    this.receiveBuffer = new Uint8Array(0);

    let promise = this.tcpSocket.connect({
      address: { address: ip, port: port, family: 1 },
      timeout: 6000
    });

    promise.then(() => {
      console.info('VideoSocket: Connected');
      this.isConnected = true;
      this.sendHttpRequest(ip, port, topicPath);
      this.startListening();
    }).catch((err: BusinessError) => {
      console.error('VideoSocket: Connect Failed', JSON.stringify(err));
    });
  }

  private sendHttpRequest(ip: string, port: number, path: string) {
    const request = `GET ${path} HTTP/1.1\r\n` +
      `Host: ${ip}:${port}\r\n` +
      `Connection: close\r\n\r\n`;
    this.tcpSocket.send({ data: request });
  }

  private startListening() {
    this.tcpSocket.on('message', (value) => {
      if (value.message instanceof ArrayBuffer) {
        let newBuffer = new Uint8Array(value.message);
        // 限制缓存区最大大小，防止OOM
        if (this.receiveBuffer.length + newBuffer.length > 5 * 1024 * 1024) { // 5MB
          console.warn("VideoSocket: Buffer overflow, clearing...");
          this.receiveBuffer = new Uint8Array(0);
        }

        let temp = new Uint8Array(this.receiveBuffer.length + newBuffer.length);
        temp.set(this.receiveBuffer, 0);
        temp.set(newBuffer, this.receiveBuffer.length);
        this.receiveBuffer = temp;

        // 尝试解析
        this.processMjpegData();
      }
    });

    this.tcpSocket.on('close', () => {
      this.isConnected = false;
    });
    this.tcpSocket.on('error', () => {
      this.isConnected = false;
    });
  }

  private processMjpegData() {
    // 如果正在解码，或者数据不够长，直接跳过，等待下一帧
    // 这能极大缓解 UI 线程压力
    if (this.isDecoding) return;

    // 寻找 Header (FF D8)
    let startIndex = -1;
    for (let i = 0; i < this.receiveBuffer.length - 1; i++) {
      if (this.receiveBuffer[i] === 0xFF && this.receiveBuffer[i+1] === 0xD8) {
        startIndex = i;
        break;
      }
    }

    if (startIndex === -1) {
      // 如果缓存太大还没找到头，清空
      if (this.receiveBuffer.length > 1000000) this.receiveBuffer = new Uint8Array(0);
      return;
    }

    // 寻找 Footer (FF D9)
    let endIndex = -1;
    for (let i = startIndex; i < this.receiveBuffer.length - 1; i++) {
      if (this.receiveBuffer[i] === 0xFF && this.receiveBuffer[i+1] === 0xD9) {
        endIndex = i + 2;
        break;
      }
    }

    if (endIndex !== -1) {
      // 检查时间间隔，如果距离上一帧太近，直接丢弃（跳帧策略）
      let now = Date.now();
      if (now - this.lastDecodeTime < this.MIN_DECODE_INTERVAL) {
        // 丢弃这一帧数据，继续看后面的
        this.receiveBuffer = this.receiveBuffer.slice(endIndex);
        // 递归检查下一帧（或者直接return等待下一次socket数据）
        return;
      }

      // 提取数据
      const jpegData = this.receiveBuffer.slice(startIndex, endIndex);
      this.receiveBuffer = this.receiveBuffer.slice(endIndex);

      // 标记开始解码
      this.isDecoding = true;
      this.lastDecodeTime = now;

      // 异步解码
      this.createImage(jpegData.buffer as ArrayBuffer).finally(() => {
        this.isDecoding = false; // 解码结束，释放锁
      });
    }
  }

  private async createImage(buffer: ArrayBuffer) {
    if (!buffer || buffer.byteLength === 0) return;

    try {
      let imageSource = image.createImageSource(buffer);
      // 必须指定解码参数，否则容易产生无效对象
      let decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: 3, // RGBA_8888
      };
      let pixelMap = await imageSource.createPixelMap(decodingOptions);

      if (pixelMap) {
        this.onFrameCallback(pixelMap, buffer);
      }
      imageSource.release(); // 记得释放 Source
    } catch (e) {
      console.error('VideoSocket: Decode Error', JSON.stringify(e));
    }
  }

  disconnect() {
    this.isConnected = false;
    this.isDecoding = false;
    try {
      this.tcpSocket.close();
    } catch(e) {}
    this.receiveBuffer = new Uint8Array(0);
  }
}