import { router } from '@kit.ArkUI';
import image from '@ohos.multimedia.image';
import { VideoSocket } from '../utils/VideoSocket';

@Entry
@Component
struct VideoPage {
  @State videoImage: image.PixelMap | undefined = undefined;
  @State fps: number = 0;
  @State statusText: string = "未连接";

  // 【修改点 1】修改为 web_video_server 的默认配置
  @State robotIp: string = "192.168.0.100"; // 你的电脑/机器人 IP
  @State robotPort: number = 8080;          // web_video_server 默认端口
  // ROS 话题路径，需要加 type=mjpeg
  private topicPath: string = "/stream?topic=/camera/color/image_raw&type=mjpeg";

  private videoSocket: VideoSocket | null = null;
  private lastTime: number = 0;
  private frameCount: number = 0;

  aboutToAppear() {
    this.videoSocket = new VideoSocket((pixelMap, rawBuffer) => {
      // 1. 更新 UI
      this.videoImage = pixelMap;

      // 2. 计算 FPS
      this.calculateFps();

      // 3. 预留给 MindSpore
      // MindSporeHandler.detect(rawBuffer);
    });
  }

  aboutToDisappear() {
    if (this.videoSocket) {
      this.videoSocket.disconnect();
    }
  }

  calculateFps() {
    let now = Date.now();
    this.frameCount++;
    if (now - this.lastTime >= 1000) {
      this.fps = this.frameCount;
      this.frameCount = 0;
      this.lastTime = now;
    }
  }

  connectVideo() {
    if (this.videoSocket) {
      this.statusText = "连接中...";
      // 【修改点 2】传入 topicPath
      this.videoSocket.connect(this.robotIp, this.robotPort, this.topicPath);
      this.statusText = "正在接收视频流...";
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.trans_select'))
          .width(24).height(24)
          .onClick(() => router.back())
        Text('实时视频流检测')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F1F3F5')

      // 视频显示区域
      Stack() {
        if (this.videoImage) {
          Image(this.videoImage)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
          // 如果画面倒了，可以用 .rotate({ angle: 180 })
        } else {
          Column() {
            LoadingProgress().width(50).height(50).color(Color.Blue)
            Text('等待视频数据...').margin({ top: 10 }).fontColor(Color.Gray)
          }
          .justifyContent(FlexAlign.Center)
        }

        // FPS 浮层
        Text(`FPS: ${this.fps}`)
          .fontColor(Color.Green)
          .fontSize(14)
          .position({ x: 10, y: 10 })
          .backgroundColor('#80000000')
          .padding(4)
          .borderRadius(4)
      }
      .width('100%')
      .height('60%')
      .backgroundColor(Color.Black)

      // 控制区
      Column({ space: 15 }) {
        Row() {
          Text('IP地址:').fontSize(16)
          TextInput({ text: this.robotIp })
            .onChange((val) => this.robotIp = val)
            .width('40%') // 调整一下宽度
            .height(40)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#ccc', radius: 4 })

          Text('端口:').fontSize(16).margin({left: 10})
          TextInput({ text: this.robotPort.toString() })
            .onChange((val) => {
              let p = parseInt(val);
              if(!isNaN(p)) this.robotPort = p;
            })
            .width('20%')
            .height(40)
            .backgroundColor(Color.White)
            .border({ width: 1, color: '#ccc', radius: 4 })

        }.justifyContent(FlexAlign.Center).width('100%')

        Text(this.statusText).fontSize(14).fontColor(Color.Gray)

        Row({ space: 20 }) {
          Button(this.statusText.includes('接收') ? '已连接' : '连接视频')
            .onClick(() => this.connectVideo())
            .type(ButtonType.Capsule)
            .width('40%')
            .enabled(!this.statusText.includes('接收')) // 防止重复点击

          Button('断开')
            .onClick(() => {
              this.videoSocket?.disconnect();
              this.statusText = "已断开";
              this.videoImage = undefined;
              this.fps = 0;
            })
            .type(ButtonType.Capsule)
            .backgroundColor(Color.Red)
            .width('40%')
        }
      }
      .padding(20)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
