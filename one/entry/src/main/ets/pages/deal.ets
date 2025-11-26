import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppStorageV2 } from '@kit.ArkUI';

type DetectionMode = 'crack' | 'target';
type ResponsePayload = string | number | boolean | null | object | Array<object>;

interface DetectionRequestOptions {
  remark?: string;
}

interface DetectionRequestPayload {
  type: DetectionMode;
  imageUrl: string;
  apiKey?: string;
  options?: DetectionRequestOptions;
}

interface DetectionApiResponse {
  code?: number;
  success?: boolean;
  message?: string;
  data?: ResponsePayload;
  result?: ResponsePayload;
}

interface DetectionEndpoints {
  crack: string;
  target: string;
}

interface ModeOption {
  value: DetectionMode;
  label: string;
  hint: string;
}

const DETECTION_ENDPOINTS: DetectionEndpoints = {
  crack: '/v1/crack-detection',
  target: '/v1/target-recognition'
};

const MODE_OPTIONS: ModeOption[] = [
  { value: 'crack', label: '裂缝检测', hint: '物体表面裂缝检测' },
  { value: 'target', label: '目标识别', hint: '识别关键设备 / 目标物' }
];

const MODEL_NAME: string = 'DATA · DETECT';
const MODEL_DESC: string = '实时融合裂缝与目标识别能力';
const API_BASE_URL: string = 'https://api.example.com';
const API_KEY: string = ''; // TODO: 在此填入你的真实密钥
const AI_RESULT_STORAGE_KEY: string = 'deal_ai_result';

@Component
export struct Deal {
  @State detectionMode: DetectionMode = 'crack';
  @State imageUrl: string = '';
  @State remark: string = '';
  @State resultText: string = '等待检测...';
  @State lastLatency: number = 0;
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    this.syncAIResult(this.resultText);
  }

  private resolveEndpoint(mode: DetectionMode): string {
    const trimmedBase = API_BASE_URL.trim().replace(/\/$/, '');
    const path = mode === 'target' ? DETECTION_ENDPOINTS.target : DETECTION_ENDPOINTS.crack;
    return `${trimmedBase}${path}`;
  }

  private stringifyJson(value?: ResponsePayload): string {
    if (value === undefined) {
      return '';
    }

    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }

    if (value === null) {
      return 'null';
    }

    try {
      return JSON.stringify(value, null, 2);
    } catch (_) {
      return '[Unsupported JSON Structure]';
    }
  }

  private formatResponse(response?: DetectionApiResponse, fallback?: string): string {
    if (!response) {
      return fallback ?? 'AI 服务未返回结果';
    }

    const segments: Array<string> = [
      `检测类型: ${this.detectionMode === 'crack' ? '裂缝检测' : '目标识别'}`
    ];

    if (response.code !== undefined) {
      segments.push(`业务码: ${response.code}`);
    }

    if (this.lastLatency > 0) {
      segments.push(`耗时: ${this.lastLatency} ms`);
    }

    if (response.message) {
      segments.push(`消息: ${response.message}`);
    }

    const payloadText = this.stringifyJson(response.data ?? response.result);
    if (payloadText) {
      segments.push('结果:');
      segments.push(payloadText);
    }

    return segments.join('\n');
  }

  private ensureReady(): boolean {
    if (!this.imageUrl.trim()) {
      this.resultText = '请填写需要检测的图片 URL';
      this.syncAIResult(this.resultText);
      return false;
    }

    return true;
  }

  private arrayBufferToString(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let result = '';
    bytes.forEach((value: number) => {
      result += String.fromCharCode(value);
    });
    return result;
  }

  private extractResponseText(result: ResponsePayload | string | ArrayBuffer | undefined): string {
    if (typeof result === 'string') {
      return result;
    }

    if (result instanceof ArrayBuffer) {
      return this.arrayBufferToString(result);
    }

    if (result) {
      try {
        return JSON.stringify(result, null, 2);
      } catch (_) {
        return '[无法解析的响应内容]';
      }
    }

    return '';
  }

  private clearResult(): void {
    if (this.isLoading) {
      return;
    }
    this.resultText = '等待检测...';
    this.lastLatency = 0;
    this.syncAIResult(this.resultText);
  }

  private getModeHint(): string {
    const option = MODE_OPTIONS.find((item: ModeOption) => item.value === this.detectionMode);
    return option ? option.hint : '';
  }

  async triggerDetection(): Promise<void> {
    if (!this.ensureReady() || this.isLoading) {
      return;
    }

    this.isLoading = true;
    this.resultText = '正在调用 AI 服务...';

    const payload: DetectionRequestPayload = {
      type: this.detectionMode,
      imageUrl: this.imageUrl.trim(),
      options: this.remark.trim() ? { remark: this.remark.trim() } : undefined
    };

    if (API_KEY.trim()) {
      payload.apiKey = API_KEY.trim();
    }

    const httpClient = http.createHttp();
    const startedAt = Date.now();

    try {
      const response = await httpClient.request(this.resolveEndpoint(this.detectionMode), {
        method: http.RequestMethod.POST,
        extraData: JSON.stringify(payload),
        connectTimeout: 8000,
        readTimeout: 15000
      });

      this.lastLatency = Date.now() - startedAt;
      const raw = this.extractResponseText(response.result);
      let parsed: DetectionApiResponse | undefined;

      if (raw) {
        try {
          parsed = JSON.parse(raw) as DetectionApiResponse;
        } catch (_) {
          parsed = undefined;
        }
      }

      this.resultText = this.formatResponse(parsed, raw || 'AI 服务未返回文本结果');
      this.syncAIResult(this.resultText);
    } catch (error) {
      const bizError = error as BusinessError;
      this.resultText = `调用失败: ${bizError.message}`;
      this.syncAIResult(this.resultText);
    } finally {
      this.isLoading = false;
      httpClient.destroy();
    }
  }

  private syncAIResult(result: string): void {
    // 使用AppStorageV2存储AI结果
    AppStorageV2.connect(String, AI_RESULT_STORAGE_KEY, () => new String(result));
  }

  build() {
    Scroll() {
      Column() {
        Text(MODEL_NAME)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 24, bottom: 8 })

        Text(MODEL_DESC)
          .fontSize(13)
          .fontColor('#8c8c8c')
          .margin({ bottom: 18 })

        Column() {
          Text('检测模式')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 8 })

          Row() {
            ForEach(MODE_OPTIONS, (option: ModeOption) => {
              Button(option.label)
                .backgroundColor(option.value === this.detectionMode ? '#1890ff' : '#d9d9d9')
                .fontColor(Color.White)
                .borderRadius(18)
                .onClick(() => {
                  if (this.isLoading) {
                    return;
                  }
                  this.detectionMode = option.value;
                })
                .layoutWeight(1)
                .margin({ right: option.value === 'target' ? 0 : 10 });
            }, (item: ModeOption, index: number) => `${item.value}-${index}`);
          }

          Text(this.getModeHint())
            .fontSize(12)
            .fontColor(Color.Gray)
            .margin({ top: 8 })
        }
        .width('90%')
        .padding(16)
        .backgroundColor('#f5f5f5')
        .borderRadius(12)
        .margin({ bottom: 18 })

        Column() {
          Text('数据流通道')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 10 })

          TextInput({ placeholder: '输入需要数据流的URL', text: this.imageUrl })
            .onChange((value: string) => {
              this.imageUrl = value;
            })
            .width('100%')
            .margin({ bottom: 10 })

          TextInput({ placeholder: '可选：补充环境或备注', text: this.remark })
            .onChange((value: string) => {
              this.remark = value;
            })
            .width('100%')
        }
        .width('90%')
        .padding(16)
        .backgroundColor('#fafafa')
        .borderRadius(12)
        .margin({ bottom: 18 })

        Row() {
          Text(`最近耗时: ${this.lastLatency > 0 ? `${this.lastLatency} ms` : '暂无数据'}`)
            .fontSize(12)
            .layoutWeight(1)

          Text(this.isLoading ? '状态: 推理中' : '状态: 空闲')
            .fontSize(12)
            .fontColor(this.isLoading ? '#fa8c16' : '#52c41a')
        }
        .width('90%')
        .margin({ bottom: 12 })

        Row() {
          Button(this.isLoading ? '推理中...' : '启动')
            .backgroundColor('#1890ff')
            .fontColor(Color.White)
            .borderRadius(10)
            .onClick(() => {
              this.triggerDetection();
            })
            .layoutWeight(1)

          Button('清空面板')
            .margin({ left: 10 })
            .backgroundColor('#d9d9d9')
            .fontColor(Color.Black)
            .borderRadius(10)
            .onClick(() => {
              this.clearResult();
            })
            .layoutWeight(1)
        }
        .width('90%')
        .margin({ bottom: 18 })

        Column() {
          Text('AI 分析结果')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 10 })

          Scroll() {
            Text(this.resultText)
              .fontSize(14)
              .textAlign(TextAlign.Start)
              .width('100%')
          }
          .width('100%')
          .height(260)
          .border({ width: 1, color: '#dddddd', style: BorderStyle.Solid })
          .borderRadius(12)
          .padding(12)
        }
        .width('90%')


      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}

