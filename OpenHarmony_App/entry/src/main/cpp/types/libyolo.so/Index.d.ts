export interface DetectObject {
  label: number;
  score: number;
  x: number;
  y: number;
  w: number;
  h: number;
}

export function add(a: number, b: number): number;
export function initModel(buffer: ArrayBuffer): boolean;
export function detect(buffer: ArrayBuffer, width: number, height: number): DetectObject[];

declare const _default: {
  add: typeof add;
  initModel: typeof initModel;
  detect: typeof detect;
};

export default _default;