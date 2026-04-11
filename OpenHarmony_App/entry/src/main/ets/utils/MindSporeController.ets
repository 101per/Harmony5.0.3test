// import { mindSporeLite } from '@kit.MindSporeLiteKit';
// import { common } from '@kit.AbilityKit';
// import { image } from '@kit.ImageKit';
// import { BusinessError } from '@kit.BasicServicesKit';
//
// export interface DetectObject {
//   label: number;
//   score: number;
//   x: number;
//   y: number;
//   w: number;
//   h: number;
// }
//
// export class AiController {
//   private static instance: AiController;
//   private model: mindSporeLite.Model | undefined = undefined;
//
//   // YOLOv5s 标准输入
//   private readonly INPUT_SIZE: number = 640;
//   // COCO 80 类名
//   private readonly LABELS: string[] = [
//     "Person", "Bicycle", "Car", "Motorcycle", "Airplane", "Bus", "Train", "Truck", "Boat", "Traffic Light",
//     "Fire Hydrant", "Stop Sign", "Parking Meter", "Bench", "Bird", "Cat", "Dog", "Horse", "Sheep", "Cow",
//     "Elephant", "Bear", "Zebra", "Giraffe", "Backpack", "Umbrella", "Handbag", "Tie", "Suitcase", "Frisbee",
//     "Skis", "Snowboard", "Sports Ball", "Kite", "Baseball Bat", "Baseball Glove", "Skateboard", "Surfboard",
//     "Tennis Racket", "Bottle", "Wine Glass", "Cup", "Fork", "Knife", "Spoon", "Bowl", "Banana", "Apple",
//     "Sandwich", "Orange", "Broccoli", "Carrot", "Hot Dog", "Pizza", "Donut", "Cake", "Chair", "Couch",
//     "Potted Plant", "Bed", "Dining Table", "Toilet", "TV", "Laptop", "Mouse", "Remote", "Keyboard",
//     "Cell Phone", "Microwave", "Oven", "Toaster", "Sink", "Refrigerator", "Book", "Clock", "Vase",
//     "Scissors", "Teddy Bear", "Hair Drier", "Toothbrush"
//   ];
//
//   private isSimulationMode: boolean = false;
//
//   public static getInstance(): AiController {
//     if (!AiController.instance) {
//       AiController.instance = new AiController();
//     }
//     return AiController.instance;
//   }
//
//   /**
//    * 便于调试时查看当前是否处于模拟模式
//    */
//   public isSimMode(): boolean {
//     return this.isSimulationMode;
//   }
//
//   /**
//    * 加载 YOLOv5 模型（例如 yolov5s_oh5.ms）
//    */
//   public async loadModel(context: common.UIAbilityContext, modelName: string): Promise<boolean> {
//     if (this.model) {
//       return true;
//     }
//
//     console.info(`AiController: [OH5.0] 准备加载 rawfile/${modelName}`);
//
//     try {
//       const fileData: Uint8Array = await context.resourceManager.getRawFileContent(modelName);
//       const buffer: ArrayBuffer = fileData.buffer.slice(0);
//
//       if (buffer.byteLength === 0) {
//         console.error("AiController: 模型文件为空");
//         this.isSimulationMode = true;
//         return true;
//       }
//
//       const msContext: mindSporeLite.Context = {
//         target: ['cpu'],
//         cpu: {
//           threadNum: 2,
//           threadAffinityMode: mindSporeLite.ThreadAffinityMode.BIG_CORES_FIRST,
//           precisionMode: 'enforce_fp32',
//           threadAffinityCoreList: []
//         }
//       };
//
//       this.model = await mindSporeLite.loadModelFromBuffer(buffer, msContext);
//
//       if (!this.model) {
//         throw new Error("loadModelFromBuffer return null");
//       }
//
//       const inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
//       if (!inputs || inputs.length === 0) {
//         console.warn('AiController: 模型加载成功但 inputs 为空，启用模拟模式。');
//         this.isSimulationMode = true;
//       } else {
//         console.info(
//           `AiController: 模型加载成功! 输入层: ${inputs[0].name}, 尺寸: ${JSON.stringify(inputs[0].shape)}`
//         );
//       }
//       return true;
//
//     } catch (error) {
//       // 【修复】处理 unknown 类型错误
//       const errMsg = (error instanceof Error) ? error.message : JSON.stringify(error);
//       console.error(`AiController: 模型加载异常 (${errMsg})，启用模拟模式`);
//       this.isSimulationMode = true;
//       return true;
//     }
//   }
//
//   /**
//    * 对 rawfile 图片进行检测，返回检测框列表
//    */
//   public async detect(context: common.UIAbilityContext, imageName: string): Promise<DetectObject[]> {
//     if (this.isSimulationMode) {
//       return this.getSimulationResult();
//     }
//
//     try {
//       const imageBytes: Uint8Array = await context.resourceManager.getRawFileContent(imageName);
//       const imageSource: image.ImageSource = image.createImageSource(imageBytes.buffer.slice(0));
//
//       const decodingOptions: image.DecodingOptions = {
//         editable: true,
//         desiredSize: { width: this.INPUT_SIZE, height: this.INPUT_SIZE },
//         desiredPixelFormat: image.PixelMapFormat.RGBA_8888
//       };
//       const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodingOptions);
//
//       const byteCount: number = pixelMap.getPixelBytesNumber();
//       const buf: ArrayBuffer = new ArrayBuffer(byteCount);
//       await pixelMap.readPixelsToBuffer(buf);
//
//       if (!this.model) {
//         throw new Error("Model is null");
//       }
//
//       // 关键修改：根据 input shape 做 NCHW 预处理
//       const inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
//       const inputShape: number[] = inputs[0].shape;
//       const float32Data: Float32Array = this.preprocessYolo(buf, inputShape);
//
//       inputs[0].setData(float32Data.buffer);
//
//       const outputs: mindSporeLite.MSTensor[] = await this.model.predict(inputs);
//
//       // 这里的 getData() 返回 ArrayBuffer，需要转为 Float32Array
//       const outBuffer = outputs[0].getData();
//       // 【修复】显式类型断言，确保安全
//       const outputData: Float32Array = new Float32Array(outBuffer as ArrayBuffer);
//
//       return this.postProcess(outputData, 0.25, 0.5);
//
//     } catch (error) {
//       // 【修复】处理 unknown 类型错误
//       const errMsg = (error instanceof Error) ? error.message : JSON.stringify(error);
//       console.error(`AiController: 推理失败 (${errMsg})，切换模拟结果`);
//       return this.getSimulationResult();
//     }
//   }
//
//   /**
//    * 模拟结果
//    */
//   private async getSimulationResult(): Promise<DetectObject[]> {
//     await new Promise<void>((resolve: () => void) => setTimeout(resolve, 1000));
//
//     return [{
//       label: 0, // Person
//       score: 0.92,
//       x: 100,
//       y: 150,
//       w: 200,
//       h: 300
//     }];
//   }
//
//   /**
//    * 预处理：从 RGBA PixelMap -> NCHW float32（[1,3,640,640]）
//    */
//   private preprocessYolo(buffer: ArrayBuffer, shape: number[]): Float32Array {
//     // shape = [1,3,640,640]
//     if (shape.length !== 4) {
//       throw new Error(`Unsupported input shape: ${JSON.stringify(shape)}`);
//     }
//     const n: number = shape[0];
//     const c: number = shape[1];
//     const h: number = shape[2];
//     const w: number = shape[3];
//
//     if (n !== 1 || c !== 3) {
//       throw new Error(`Only support N=1,C=3, but got N=${n},C=${c}`);
//     }
//
//     const src: Uint8Array = new Uint8Array(buffer); // RGBA8888
//     const dst: Float32Array = new Float32Array(n * c * h * w); // NCHW
//
//     const hw: number = h * w;
//     for (let y = 0; y < h; y++) {
//       for (let x = 0; x < w; x++) {
//         const srcIdx: number = (y * w + x) * 4;
//         const r: number = src[srcIdx] / 255.0;
//         const g: number = src[srcIdx + 1] / 255.0;
//         const b: number = src[srcIdx + 2] / 255.0;
//
//         const pos: number = y * w + x;
//         // NCHW: [0,:,:] = R, [1,:,:] = G, [2,:,:] = B
//         dst[0 * hw + pos] = r;
//         dst[1 * hw + pos] = g;
//         dst[2 * hw + pos] = b;
//       }
//     }
//     return dst;
//   }
//
//   /**
//    * YOLOv5 输出后处理 + NMS
//    */
//   private postProcess(data: Float32Array, confThresh: number, nmsThresh: number): DetectObject[] {
//     const cols: number = 85;                        // x,y,w,h,obj + 80 classes
//     const rows: number = Math.floor(data.length / cols);
//
//     const boxes: DetectObject[] = [];
//
//     for (let i: number = 0; i < rows; i++) {
//       const offset: number = i * cols;
//       const objConf: number = data[offset + 4];
//       if (objConf <= confThresh) {
//         continue;
//       }
//
//       let maxClassScore: number = 0;
//       let maxClassId: number = -1;
//       for (let c: number = 5; c < cols; c++) {
//         const clsScore: number = data[offset + c];
//         if (clsScore > maxClassScore) {
//           maxClassScore = clsScore;
//           maxClassId = c - 5;
//         }
//       }
//
//       const finalScore: number = objConf * maxClassScore;
//       if (finalScore <= confThresh) {
//         continue;
//       }
//
//       const cx: number = data[offset];
//       const cy: number = data[offset + 1];
//       const w: number = data[offset + 2];
//       const h: number = data[offset + 3];
//
//       // 假设模型输出已经是像素坐标
//       const x: number = cx - w / 2;   // 左上角 x
//       const y: number = cy - h / 2;   // 左上角 y
//       const bw: number = w;
//       const bh: number = h;
//
//       boxes.push({
//         label: maxClassId,
//         score: finalScore,
//         x,
//         y,
//         w: bw,
//         h: bh
//       });
//     }
//
//     return this.nms(boxes, nmsThresh);
//   }
//
//   private nms(boxes: DetectObject[], iouThresh: number): DetectObject[] {
//     if (boxes.length === 0) {
//       return [];
//     }
//
//     const sorted: DetectObject[] = [...boxes].sort((a: DetectObject, b: DetectObject) => b.score - a.score);
//     const result: DetectObject[] = [];
//     const isSuppressed: boolean[] = new Array<boolean>(sorted.length).fill(false);
//
//     for (let i: number = 0; i < sorted.length; i++) {
//       if (isSuppressed[i]) {
//         continue;
//       }
//       const a: DetectObject = sorted[i];
//       result.push(a);
//       isSuppressed[i] = true;
//
//       for (let j: number = i + 1; j < sorted.length; j++) {
//         if (isSuppressed[j]) {
//           continue;
//         }
//         const b: DetectObject = sorted[j];
//         if (this.calculateIoU(a, b) > iouThresh) {
//           isSuppressed[j] = true;
//         }
//       }
//     }
//     return result;
//   }
//
//   private calculateIoU(a: DetectObject, b: DetectObject): number {
//     const x1: number = Math.max(a.x, b.x);
//     const y1: number = Math.max(a.y, b.y);
//     const x2: number = Math.min(a.x + a.w, b.x + b.w);
//     const y2: number = Math.min(a.y + a.h, b.y + b.h);
//     const interArea: number = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
//     const unionArea: number = a.w * a.h + b.w * b.h - interArea;
//     if (unionArea <= 0) {
//       return 0;
//     }
//     return interArea / unionArea;
//   }
//
//   public getLabelName(id: number): string {
//     return (id >= 0 && id < this.LABELS.length) ? this.LABELS[id] : "Unknown";
//   }
//
//   /**
//    * 支持直接传入 ArrayBuffer (来自相册文件) 进行检测
//    */
//   public async detectImageBuffer(context: common.UIAbilityContext, buffer: ArrayBuffer): Promise<DetectObject[]> {
//     if (this.isSimulationMode) return this.getSimulationResult();
//
//     let imageSource: image.ImageSource | undefined = undefined;
//     let pixelMap: image.PixelMap | undefined = undefined;
//
//     try {
//       // 1. 使用传入的 buffer 创建 ImageSource
//       imageSource = image.createImageSource(buffer);
//
//       // 2. 解码参数保持一致 (强制 640x640, RGBA)
//       const decodingOptions: image.DecodingOptions = {
//         editable: true,
//         desiredSize: { width: this.INPUT_SIZE, height: this.INPUT_SIZE },
//         desiredPixelFormat: image.PixelMapFormat.RGBA_8888
//       };
//       pixelMap = await imageSource.createPixelMap(decodingOptions);
//
//       // 3. 读取像素数据
//       const byteCount = pixelMap.getPixelBytesNumber();
//       const buf = new ArrayBuffer(byteCount);
//       await pixelMap.readPixelsToBuffer(buf);
//
//       if (!this.model) throw new Error("Model is null");
//
//       // 4. 预处理 (NCHW)
//       const inputs = this.model.getInputs();
//       // 【关键修复】：这里调用 preprocessYolo 而不是 preprocessYoloNCHW
//       // 并且传入 shape 参数
//       const inputShape = inputs[0].shape;
//       const float32Data = this.preprocessYolo(buf, inputShape);
//
//       inputs[0].setData(float32Data.buffer);
//
//       // 5. 推理
//       const outputs = await this.model.predict(inputs);
//
//       // 【修复】显式断言 ArrayBuffer
//       const outBuffer = outputs[0].getData();
//       const outputData = new Float32Array(outBuffer as ArrayBuffer);
//
//       // 6. 后处理
//       return this.postProcess(outputData, 0.25, 0.45);
//
//     } catch (error) {
//       // 【修复】处理 unknown 类型错误
//       const errMsg = (error instanceof Error) ? error.message : JSON.stringify(error);
//       console.error(`AiController: Buffer推理异常: ${errMsg}`);
//       return [];
//     } finally {
//       if (pixelMap) await pixelMap.release();
//       if (imageSource) await imageSource.release();
//     }
//   }
// }


//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////



//
//
// import { common } from '@kit.AbilityKit';
// import { image } from '@kit.ImageKit';
// // 引入 deviceInfo 模块
// import { deviceInfo } from '@kit.BasicServicesKit';
//
// // 引入 Native 模块
// // 先判断 模拟机X86_64架构 是否都可以运行原生C++
// // DAYU200设备 是否都不可以运行原生C++ 日志是否一致均为SO文件找不到
// import testNapi from 'libyolo.so';
//
// export interface DetectObject {
//   label: number;
//   score: number;
//   x: number;
//   y: number;
//   w: number;
//   h: number;
// }
//
// export class AiController {
//   private static instance: AiController;
//   private isModelLoaded: boolean = false;
//
//   private readonly INPUT_SIZE: number = 640;
//
//   private readonly LABELS: string[] = [
//     "Person", "Bicycle", "Car", "Motorcycle", "Airplane", "Bus", "Train", "Truck", "Boat", "Traffic Light",
//     "Fire Hydrant", "Stop Sign", "Parking Meter", "Bench", "Bird", "Cat", "Dog", "Horse", "Sheep", "Cow",
//     "Elephant", "Bear", "Zebra", "Giraffe", "Backpack", "Umbrella", "Handbag", "Tie", "Suitcase", "Frisbee",
//     "Skis", "Snowboard", "Sports Ball", "Kite", "Baseball Bat", "Baseball Glove", "Skateboard", "Surfboard",
//     "Tennis Racket", "Bottle", "Wine Glass", "Cup", "Fork", "Knife", "Spoon", "Bowl", "Banana", "Apple",
//     "Sandwich", "Orange", "Broccoli", "Carrot", "Hot Dog", "Pizza", "Donut", "Cake", "Chair", "Couch",
//     "Potted Plant", "Bed", "Dining Table", "Toilet", "TV", "Laptop", "Mouse", "Remote", "Keyboard",
//     "Cell Phone", "Microwave", "Oven", "Toaster", "Sink", "Refrigerator", "Book", "Clock", "Vase",
//     "Scissors", "Teddy Bear", "Hair Drier", "Toothbrush"
//   ];
//
//   public static getInstance(): AiController {
//     if (!AiController.instance) {
//       AiController.instance = new AiController();
//     }
//     return AiController.instance;
//   }
//
//   public getLabelName(id: number): string {
//     return (id >= 0 && id < this.LABELS.length) ? this.LABELS[id] : "Unknown";
//   }
//
//   /**
//    * 【新增 2】获取当前架构下的 so 库路径辅助方法
//    * 如果你需要手动加载其他 so 库（例如 libopencv_java4.so），可以使用这个路径
//    */
//   public getSoLibraryPath(context: common.UIAbilityContext, libName: string): string {
//     // 判断架构
//     let abiPath = deviceInfo.abiList === 'x86_64' ? 'x86_64' : 'arm64';
//     // 获取项目沙箱路径
//     let projectPath = context.bundleCodeDir;
//     // 拼接绝对路径
//     let soPath = `${projectPath}/libs/${abiPath}/${libName}`;
//     return soPath;
//   }
//
//   /**
//    * 1. 加载模型
//    */
//   public async loadModel(context: common.UIAbilityContext, modelName: string): Promise<boolean> {
//     if (this.isModelLoaded) return true;
//
//     try {
//       // 【演示】打印当前运行的架构
//       let currentABI = deviceInfo.abiList === 'x86_64' ? 'Simulator (x86_64)' : 'Device (arm64)';
//       console.info(`AiController: Running on ${currentABI}`);
//
//       console.info(`AiController: Loading ${modelName} to Native...`);
//       const fileData = await context.resourceManager.getRawFileContent(modelName);
//       const buffer = fileData.buffer.slice(0);
//
//       this.isModelLoaded = testNapi.initModel(buffer);
//
//       // 假设 initModel 需要额外的 so 库路径（只是示例，如果没有这个需求可忽略）
//       // let libPath = this.getSoLibraryPath(context, "libopencv_java4.so");
//       // testNapi.setLibraryPath(libPath);
//
//       console.info(`AiController: Native init result: ${this.isModelLoaded}`);
//       return this.isModelLoaded;
//     } catch (e) {
//       console.error(`AiController: Load Failed ${JSON.stringify(e)}`);
//       return false;
//     }
//   }
//
//   /**
//    * 2. 执行检测
//    */
//   public async detectImageBuffer(context: common.UIAbilityContext, buffer: ArrayBuffer): Promise<DetectObject[]> {
//     if (!this.isModelLoaded) {
//       console.error("AiController: Model not loaded yet.");
//       return [];
//     }
//
//     let imageSource: image.ImageSource | undefined = undefined;
//     let pixelMap: image.PixelMap | undefined = undefined;
//
//     try {
//       imageSource = image.createImageSource(buffer);
//
//       const decodingOptions: image.DecodingOptions = {
//         editable: true,
//         desiredSize: { width: this.INPUT_SIZE, height: this.INPUT_SIZE },
//         desiredPixelFormat: image.PixelMapFormat.RGBA_8888
//       };
//       pixelMap = await imageSource.createPixelMap(decodingOptions);
//
//       const byteCount = pixelMap.getPixelBytesNumber();
//       const imgBuf = new ArrayBuffer(byteCount);
//       await pixelMap.readPixelsToBuffer(imgBuf);
//
//       let startTime = new Date().getTime();
//
//       let results = testNapi.detect(imgBuf, this.INPUT_SIZE, this.INPUT_SIZE);
//
//       let endTime = new Date().getTime();
//       console.info(`AiController: Native Inference Time: ${endTime - startTime}ms, Objects: ${results.length}`);
//
//       return results;
//
//     } catch (e) {
//       console.error(`AiController: Native Detect Error ${JSON.stringify(e)}`);
//       return [];
//     } finally {
//       if (pixelMap) await pixelMap.release();
//       if (imageSource) await imageSource.release();
//     }
//   }
//
//   public async detect(context: common.UIAbilityContext, imageName: string): Promise<DetectObject[]> {
//     const fileData = await context.resourceManager.getRawFileContent(imageName);
//     return this.detectImageBuffer(context, fileData.buffer.slice(0));
//   }
// }





import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import testNapi from 'libyolo.so';

// --- 接口定义 ---
export interface DetectObject {
  label: number;
  score: number;
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface InferenceResult {
  objects: DetectObject[];
  enhancedImage?: PixelMap;
}

export enum ModelType {
  YOLO_NATIVE = 'yolov5s_oh5.ms',
  LUIEO_ARKTS = 'LUIEO_OH.ms'
}

export class AiController {
  private static instance: AiController;

  private currentModelType: ModelType = ModelType.YOLO_NATIVE;
  private isNativeModelLoaded = false;
  private msModel: mindSporeLite.Model | undefined = undefined;

  // 默认值 256×256，会在 loadArkTSModel 后根据模型输入 shape 自动更新
  private luieoInputW: number = 256;
  private luieoInputH: number = 256;

  private readonly YOLO_INPUT_SIZE = 640;

  // LUIEO：RUOD 数据集 10 类（索引 0~9）
  // categories  = ['holothurian', 'echinus', 'scallop', 'starfish',
  //                'fish', 'corals', 'diver', 'cuttlefish', 'turtle','jellyfish']
  private readonly LUIEO_CLASSES: string[] = [
    'holothurian', // 0 海参
    'echinus',     // 1 海胆
    'scallop',     // 2 扇贝
    'starfish',    // 3 海星
    'fish',        // 4 鱼
    'corals',      // 5 珊瑚
    'diver',       // 6 潜水员
    'cuttlefish',  // 7 乌贼
    'turtle',      // 8 海龟
    'jellyfish'    // 9 水母
  ];

  // YOLOv5 COCO 80 类
  private readonly COCO_LABELS: string[] = [
    'Person', 'Bicycle', 'Car', 'Motorcycle', 'Airplane', 'Bus', 'Train', 'Truck', 'Boat', 'Traffic Light',
    'Fire Hydrant', 'Stop Sign', 'Parking Meter', 'Bench', 'Bird', 'Cat', 'Dog', 'Horse', 'Sheep', 'Cow',
    'Elephant', 'Bear', 'Zebra', 'Giraffe', 'Backpack', 'Umbrella', 'Handbag', 'Tie', 'Suitcase', 'Frisbee',
    'Skis', 'Snowboard', 'Sports Ball', 'Kite', 'Baseball Bat', 'Baseball Glove', 'Skateboard', 'Surfboard',
    'Tennis Racket', 'Bottle', 'Wine Glass', 'Cup', 'Fork', 'Knife', 'Spoon', 'Bowl', 'Banana', 'Apple',
    'Sandwich', 'Orange', 'Broccoli', 'Carrot', 'Hot Dog', 'Pizza', 'Donut', 'Cake', 'Chair', 'Couch',
    'Potted Plant', 'Bed', 'Dining Table', 'Toilet', 'TV', 'Laptop', 'Mouse', 'Remote', 'Keyboard',
    'Cell Phone', 'Microwave', 'Oven', 'Toaster', 'Sink', 'Refrigerator', 'Book', 'Clock', 'Vase',
    'Scissors', 'Teddy Bear', 'Hair Drier', 'Toothbrush'
  ];

  // LUIEO 检测阈值（根据你现在的分数分布先设低一点）
  private readonly LUIEO_CONF_THRESH = 0.05;  // 原来 0.25，会过滤掉当前所有 0.06 左右的分数
  private readonly LUIEO_NMS_THRESH  = 0.3;   // 和 Python nms(..., 0.3) 对齐

  public static getInstance(): AiController {
    if (!AiController.instance) {
      AiController.instance = new AiController();
    }
    return AiController.instance;
  }

  public getLabelName(id: number): string {
    if (this.currentModelType === ModelType.LUIEO_ARKTS) {
      return id >= 0 && id < this.LUIEO_CLASSES.length ? this.LUIEO_CLASSES[id] : `Class${id}`;
    } else {
      return id >= 0 && id < this.COCO_LABELS.length ? this.COCO_LABELS[id] : 'Unknown';
    }
  }

  // === 模型加载 ===
  public async loadModel(context: common.UIAbilityContext, modelName: string): Promise<boolean> {
    if (modelName === ModelType.YOLO_NATIVE) {
      this.currentModelType = ModelType.YOLO_NATIVE;
      return this.loadNativeYolo(context, modelName);
    } else {
      this.currentModelType = ModelType.LUIEO_ARKTS;
      return this.loadArkTSModel(context, modelName);
    }
  }

  private async loadNativeYolo(context: common.UIAbilityContext, modelName: string): Promise<boolean> {
    if (this.isNativeModelLoaded) return true;
    try {
      const fileData = await context.resourceManager.getRawFileContent(modelName);
      this.isNativeModelLoaded = testNapi.initModel(fileData.buffer.slice(0));
      return this.isNativeModelLoaded;
    } catch (e) {
      console.error(`Native Load Error: ${JSON.stringify(e)}`);
      return false;
    }
  }

  private async loadArkTSModel(context: common.UIAbilityContext, modelName: string): Promise<boolean> {
    if (this.msModel) return true;
    try {
      const fileData = await context.resourceManager.getRawFileContent(modelName);
      const buffer = fileData.buffer.slice(0);

      const msContext: mindSporeLite.Context = {
        target: ['cpu'],
        cpu: {
          threadNum: 2,
          threadAffinityMode: 1,
          precisionMode: 'enforce_fp32'
        }
      };

      this.msModel = await mindSporeLite.loadModelFromBuffer(buffer, msContext);

      const inputs = this.msModel.getInputs();
      console.info(`[DEBUG] LUIEO Model Inputs: ${inputs.length}`);
      inputs.forEach((input, idx) => {
        console.info(
          `[DEBUG] Input[${idx}]: name=${input.name}, shape=${JSON.stringify(input.shape)}`
        );
      });

      // 动态获取 LUIEO 输入尺寸（支持 NCHW / NHWC）
      if (inputs.length > 0 && inputs[0].shape.length === 4) {
        const shape = inputs[0].shape; // e.g. [1,3,256,256] or [1,256,256,3]
        if (shape[1] === 3) {
          // NCHW: [N,C,H,W]
          this.luieoInputH = shape[2];
          this.luieoInputW = shape[3];
        } else if (shape[3] === 3) {
          // NHWC: [N,H,W,C]
          this.luieoInputH = shape[1];
          this.luieoInputW = shape[2];
        }
        console.info(
          `[DEBUG] LUIEO Input Size (from model): ${this.luieoInputW}x${this.luieoInputH}`
        );
      }

      return true;
    } catch (e) {
      console.error(`ArkTS Load Error: ${JSON.stringify(e)}`);
      return false;
    }
  }

  // === 推理入口 ===
  public async detect(context: common.UIAbilityContext, imageName: string): Promise<InferenceResult> {
    const fileData = await context.resourceManager.getRawFileContent(imageName);
    return this.detectImageBuffer(context, fileData.buffer.slice(0));
  }

  public async detectImageBuffer(
    context: common.UIAbilityContext,
    buffer: ArrayBuffer
  ): Promise<InferenceResult> {
    if (this.currentModelType === ModelType.YOLO_NATIVE) {
      return this.runNativeYolo(buffer);
    } else {
      return this.runLUIEO(buffer);
    }
  }

  // === Native YOLO 分支 ===
  private async runNativeYolo(buffer: ArrayBuffer): Promise<InferenceResult> {
    if (!this.isNativeModelLoaded) return { objects: [] };

    let pixelMap: image.PixelMap | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;

    try {
      imageSource = image.createImageSource(buffer);
      const decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredSize: { width: this.YOLO_INPUT_SIZE, height: this.YOLO_INPUT_SIZE },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await imageSource.createPixelMap(decodingOptions);

      const byteCount = pixelMap.getPixelBytesNumber();
      const imgBuf = new ArrayBuffer(byteCount);
      await pixelMap.readPixelsToBuffer(imgBuf);

      const results = testNapi.detect(imgBuf, this.YOLO_INPUT_SIZE, this.YOLO_INPUT_SIZE);
      return { objects: results };
    } catch (e) {
      console.error(`Native Run Error: ${e}`);
      return { objects: [] };
    } finally {
      if (pixelMap) await pixelMap.release();
      if (imageSource) await imageSource.release();
    }
  }

  // === LUIEO 分支 ===
  private async runLUIEO(buffer: ArrayBuffer): Promise<InferenceResult> {
    if (!this.msModel) return { objects: [] };

    let pixelMap: image.PixelMap | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;

    try {
      console.info('[DEBUG] Step 1: Decoding Image...');
      imageSource = image.createImageSource(buffer);

      const decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredSize: { width: this.luieoInputW, height: this.luieoInputH },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      pixelMap = await imageSource.createPixelMap(decodingOptions);

      const byteCount = pixelMap.getPixelBytesNumber();
      console.info(
        `[DEBUG] PixelMap Bytes: ${byteCount} (Expected: ${this.luieoInputW * this.luieoInputH * 4})`
      );

      const rgbaBuffer = new ArrayBuffer(byteCount);
      await pixelMap.readPixelsToBuffer(rgbaBuffer);

      // 2. 预处理（和训练端一致：仅 ToTensor()，不做 Normalize）
      console.info('[DEBUG] Step 2: Preprocessing (RGBA -> NCHW Float32, /255)...');
      const inputTensorData = this.preprocessLUIEO(
        rgbaBuffer,
        this.luieoInputW,
        this.luieoInputH
      );

      // 3. 推理
      console.info('[DEBUG] Step 3: Running Inference...');
      const inputs = this.msModel.getInputs();
      inputs[0].setData(inputTensorData.buffer);

      const outputs = await this.msModel.predict(inputs);
      console.info(`[DEBUG] Inference Done. Outputs count: ${outputs.length}`);

      const output0 = outputs[0]; // 增强图 [1,3,H,W]
      const output1 = outputs[1]; // 检测 [1,14,N]

      // 调试增强图原始数据分布（取前 1000 个值做统计）
      const outImgData = new Float32Array(output0.getData() as ArrayBuffer);
      let minVal = 1e9, maxVal = -1e9, avgVal = 0;
      const sampleN = Math.min(outImgData.length, 1000);
      for (let k = 0; k < sampleN; k++) {
        const v = outImgData[k];
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
        avgVal += v;
      }
      avgVal /= sampleN;
      console.info(
        `[DEBUG] Output Image Stats (Sample): Min=${minVal}, Max=${maxVal}, Avg=${avgVal}`
      );

      // 4. 处理增强图
      let enhancedPixelMap: PixelMap | undefined = undefined;
      console.info(
        `[DEBUG] Processing Enhanced Image. Shape: ${JSON.stringify(output0.shape)}`
      );

      if (output0.shape.length === 4 && output0.shape[1] === 3) {
        enhancedPixelMap = await this.postProcessEnhancedImage(
          output0.getData() as ArrayBuffer,
          this.luieoInputW,
          this.luieoInputH
        );
      } else {
        console.warn(`[WARN] Unexpected enhanced image shape: ${JSON.stringify(output0.shape)}`);
      }

      // 5. 处理检测框
      let detectedObjects: DetectObject[] = [];
      const outShape = output1.shape;
      console.info(
        `[DEBUG] Processing Detection Boxes. Shape: ${JSON.stringify(outShape)}`
      );

      const floatData = new Float32Array(output1.getData() as ArrayBuffer);

      if (outShape.length === 3 && outShape[1] === 14) {
        console.info('LUIEO: Detecting format [1, 14, N] (Transposed CxA)');
        detectedObjects = this.postProcessBoxesTransposed(
          floatData,
          14,
          outShape[2],
          this.LUIEO_CONF_THRESH,
          this.LUIEO_NMS_THRESH
        );
      } else if (outShape.length === 3 && outShape[2] === 14) {
        console.info('LUIEO: Detecting format [1, N, 14] (Standard)');
        detectedObjects = this.postProcessBoxesStandard(
          floatData,
          14,
          this.LUIEO_CONF_THRESH,
          this.LUIEO_NMS_THRESH
        );
      } else {
        console.warn(`LUIEO Warning: Unknown detection shape ${JSON.stringify(outShape)}`);
      }

      console.info(`[DEBUG] Final Objects Found: ${detectedObjects.length}`);

      return {
        objects: detectedObjects,
        enhancedImage: enhancedPixelMap
      };
    } catch (e) {
      console.error(`LUIEO Run Error: ${JSON.stringify(e)}`);
      return { objects: [] };
    } finally {
      if (pixelMap) await pixelMap.release();
      if (imageSource) await imageSource.release();
    }
  }

  /**
   * 预处理：RGBA -> NCHW Float32，等价于 Python 的 ToTensor()（不做 Normalize）
   */
  private preprocessLUIEO(
    rgbaBuffer: ArrayBuffer,
    width: number,
    height: number
  ): Float32Array {
    const src = new Uint8Array(rgbaBuffer);
    const elements = width * height;
    const dst = new Float32Array(3 * elements);

    let sumR = 0, sumG = 0, sumB = 0;

    for (let i = 0; i < elements; i++) {
      const pixelIdx = i * 4;

      // 假设 PixelMap 内存顺序为 RGBA：R,G,B,A
      const r8 = src[pixelIdx];
      const g8 = src[pixelIdx + 1];
      const b8 = src[pixelIdx + 2];

      const r = r8 / 255.0;
      const g = g8 / 255.0;
      const b = b8 / 255.0;

      sumR += r8;
      sumG += g8;
      sumB += b8;

      dst[i]                = r;   // R
      dst[i + elements]     = g;   // G
      dst[i + elements * 2] = b;   // B
    }

    console.info(
      `[DEBUG] Input Avg (R+G+B, 0-765): ${(sumR + sumG + sumB) / elements}`
    );
    return dst;
  }

  /**
   * 后处理增强图：NCHW -> PixelMap(RGBA_8888)
   * 目前简单做 0~1 clamp 后映射到 0~255
   */
  private async postProcessEnhancedImage(
    buffer: ArrayBuffer,
    width: number,
    height: number
  ): Promise<PixelMap> {
    const src = new Float32Array(buffer);
    const elements = width * height;

    const dst = new ArrayBuffer(elements * 4);
    const dstView = new Uint8Array(dst);

    let minVal = Number.POSITIVE_INFINITY;
    let maxVal = Number.NEGATIVE_INFINITY;

    for (let i = 0; i < elements; i++) {
      let r = src[i];
      let g = src[i + elements];
      let b = src[i + elements * 2];

      if (r < minVal) minVal = r;
      if (r > maxVal) maxVal = r;

      // Clamp 到 [0,1]，避免极端值
      r = Math.min(Math.max(r, 0), 1);
      g = Math.min(Math.max(g, 0), 1);
      b = Math.min(Math.max(b, 0), 1);

      const pixelIdx = i * 4;
      dstView[pixelIdx]     = Math.round(r * 255);
      dstView[pixelIdx + 1] = Math.round(g * 255);
      dstView[pixelIdx + 2] = Math.round(b * 255);
      dstView[pixelIdx + 3] = 255;
    }

    console.info(`[DEBUG] Enhanced raw range (channel0): [${minVal}, ${maxVal}]`);

    const opts: image.InitializationOptions = {
      size: { width, height },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true,
      alphaType: image.AlphaType.PREMUL
    };

    return await image.createPixelMap(dst, opts);
  }

  /**
   * 后处理检测框：格式 [1, C(=14), A]，C=4(box)+10(classes)，内存布局为 CxA
   */
  private postProcessBoxesTransposed(
    data: Float32Array,
    numChannels: number,
    numAnchors: number,
    confThresh: number,
    nmsThresh: number
  ): DetectObject[] {
    const boxes: DetectObject[] = [];
    const debugScores: number[] = [];

    const getVal = (c: number, i: number) => data[c * numAnchors + i];

    for (let i = 0; i < numAnchors; i++) {
      let maxClassScore = 0;
      let maxClassId = -1;

      // 通道 4..13: 10 个类别概率（已 sigmoid）
      for (let c = 4; c < numChannels; c++) {
        const score = getVal(c, i);
        if (score > maxClassScore) {
          maxClassScore = score;
          maxClassId = c - 4;
        }
      }

      debugScores.push(maxClassScore);

      if (maxClassScore <= confThresh) continue;

      const cx = getVal(0, i);
      const cy = getVal(1, i);
      const w  = getVal(2, i);
      const h  = getVal(3, i);

      boxes.push({
        label: maxClassId,
        score: maxClassScore,
        x: cx - w / 2,
        y: cy - h / 2,
        w, h
      });
    }

    debugScores.sort((a, b) => b - a);
    console.info(
      `[DEBUG] Top class scores (first 20): ${debugScores.slice(0, 20).join(', ')}`
    );

    return this.nms(boxes, nmsThresh);
  }

  /**
   * 后处理检测框：格式 [1, N, 14]（备用）
   */
  private postProcessBoxesStandard(
    data: Float32Array,
    cols: number,
    confThresh: number,
    nmsThresh: number
  ): DetectObject[] {
    const rows = data.length / cols;
    const boxes: DetectObject[] = [];

    for (let i = 0; i < rows; i++) {
      const offset = i * cols;

      let maxClassScore = 0;
      let maxClassId = -1;
      for (let c = 4; c < cols; c++) {
        const score = data[offset + c];
        if (score > maxClassScore) {
          maxClassScore = score;
          maxClassId = c - 4;
        }
      }
      if (maxClassScore <= confThresh) continue;

      const cx = data[offset];
      const cy = data[offset + 1];
      const w  = data[offset + 2];
      const h  = data[offset + 3];

      boxes.push({
        label: maxClassId,
        score: maxClassScore,
        x: cx - w / 2,
        y: cy - h / 2,
        w, h
      });
    }

    return this.nms(boxes, nmsThresh);
  }

  // === NMS & IoU ===
  private nms(boxes: DetectObject[], iouThresh: number): DetectObject[] {
    if (boxes.length === 0) return [];
    boxes.sort((a, b) => b.score - a.score);

    const result: DetectObject[] = [];
    const suppressed: boolean[] = new Array(boxes.length).fill(false);

    for (let i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      result.push(boxes[i]);
      for (let j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;
        if (this.iou(boxes[i], boxes[j]) > iouThresh) {
          suppressed[j] = true;
        }
      }
    }
    return result;
  }

  private iou(a: DetectObject, b: DetectObject): number {
    const x1 = Math.max(a.x, b.x);
    const y1 = Math.max(a.y, b.y);
    const x2 = Math.min(a.x + a.w, b.x + b.w);
    const y2 = Math.min(a.y + a.h, b.y + b.h);

    const interW = Math.max(0, x2 - x1);
    const interH = Math.max(0, y2 - y1);
    const interArea = interW * interH;

    const areaA = a.w * a.h;
    const areaB = b.w * b.h;
    const unionArea = areaA + areaB - interArea;

    return unionArea <= 0 ? 0 : interArea / unionArea;
  }
}