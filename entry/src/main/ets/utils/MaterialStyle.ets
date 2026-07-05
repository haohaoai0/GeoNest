import { deviceInfo } from '@kit.BasicServicesKit';
import { ScrollEffectType } from '@kit.UIDesignKit';
import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { uiMaterial } from '@kit.ArkUI';

const API_LEVEL_HDS: number = 23;
const API_LEVEL_NATIVE: number = 26;

class DetectionState {
  apiLevel: number = 0;
  isHigh: boolean = false;
  supportsImmersive: boolean = false;
  supportsNative: boolean = false;
  detected: boolean = false;
}

const state: DetectionState = new DetectionState();

function ensureDetected(): void {
  if (state.detected) return;
  state.detected = true;
  try {
    state.apiLevel = deviceInfo.distributionOSApiVersion;
  } catch (e) {
    state.apiLevel = 0;
  }
  state.isHigh = state.apiLevel >= API_LEVEL_HDS;
  state.supportsNative = state.apiLevel >= API_LEVEL_NATIVE;
  if (state.supportsNative) {
    try {
      state.supportsNative = uiMaterial.ImmersiveStyle !== undefined;
    } catch (e) {
      state.supportsNative = false;
    }
  }
  if (state.isHigh) {
    try {
      let types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      for (let i = 0; i < types.length; i++) {
        if (types[i] === hdsMaterial.MaterialType.IMMERSIVE) {
          state.supportsImmersive = true;
          break;
        }
      }
    } catch (e) {
      state.supportsImmersive = false;
    }
  }
}

export class SystemMaterialEffectConfig {
  materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.IMMERSIVE;
  materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
}

export class ScrollEffectOptsConfig {
  scrollEffectType: ScrollEffectType = ScrollEffectType.GRADIENT_BLUR;
}

export class TitleBarStyleConfig {
  scrollEffectOpts: ScrollEffectOptsConfig = new ScrollEffectOptsConfig();
  systemMaterialEffect: SystemMaterialEffectConfig = new SystemMaterialEffectConfig();
}

export class MaterialStyle {
  static apiLevel(): number {
    ensureDetected();
    return state.apiLevel;
  }

  static isHigh(): boolean {
    ensureDetected();
    return state.isHigh;
  }

  static supportsNativeMaterial(): boolean {
    ensureDetected();
    return state.supportsNative;
  }

  static canUseSystemMaterial(): boolean {
    ensureDetected();
    return state.supportsNative;
  }

  static navScrollEffectType(): ScrollEffectType {
    ensureDetected();
    if (state.supportsNative) return ScrollEffectType.IMMERSIVE_GRADIENT_BLUR;
    if (state.isHigh) return ScrollEffectType.GRADIENT_BLUR;
    return ScrollEffectType.COMMON_BLUR;
  }

  static systemMaterialEffect(): SystemMaterialEffectConfig | undefined {
    ensureDetected();
    if (!state.isHigh) return undefined;
    let cfg: SystemMaterialEffectConfig = new SystemMaterialEffectConfig();
    cfg.materialType = state.supportsImmersive ?
      hdsMaterial.MaterialType.IMMERSIVE :
      hdsMaterial.MaterialType.ADAPTIVE;
    cfg.materialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    return cfg;
  }

  static getTitleBarStyle(materialEnabled: boolean): TitleBarStyleConfig | undefined {
    ensureDetected();
    if (!state.isHigh || !materialEnabled) return undefined;

    let style: TitleBarStyleConfig = new TitleBarStyleConfig();
    let scrollOpts: ScrollEffectOptsConfig = new ScrollEffectOptsConfig();
    scrollOpts.scrollEffectType = state.supportsNative ?
      ScrollEffectType.IMMERSIVE_GRADIENT_BLUR : ScrollEffectType.GRADIENT_BLUR;
    style.scrollEffectOpts = scrollOpts;

    let materialCfg: SystemMaterialEffectConfig = new SystemMaterialEffectConfig();
    materialCfg.materialType = state.supportsImmersive ?
      hdsMaterial.MaterialType.IMMERSIVE :
      hdsMaterial.MaterialType.ADAPTIVE;
    materialCfg.materialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    style.systemMaterialEffect = materialCfg;

    return style;
  }

  static componentBlurStyle(): BlurStyle {
    ensureDetected();
    if (state.isHigh) return BlurStyle.COMPONENT_THIN;
    return BlurStyle.COMPONENT_REGULAR;
  }

  static panelBlurStyle(): BlurStyle {
    ensureDetected();
    if (state.isHigh) return BlurStyle.COMPONENT_THICK;
    return BlurStyle.COMPONENT_REGULAR;
  }

  static toolbarBlurStyle(): BlurStyle {
    ensureDetected();
    if (state.isHigh) return BlurStyle.COMPONENT_ULTRA_THIN;
    return BlurStyle.COMPONENT_REGULAR;
  }

  static backstageBlurStyle(): BlurStyle {
    ensureDetected();
    if (state.isHigh) return BlurStyle.COMPONENT_ULTRA_THICK;
    return BlurStyle.COMPONENT_REGULAR;
  }

  static blurStyleLegacy(): BlurStyle {
    return BlurStyle.COMPONENT_REGULAR;
  }

  static shouldUseMaterial(materialEnabled: boolean): boolean {
    ensureDetected();
    return state.isHigh && materialEnabled;
  }

  static shouldUseNativeMaterial(materialEnabled?: boolean): boolean {
    ensureDetected();
    if (!state.supportsNative) return false;
    if (materialEnabled !== undefined) return materialEnabled;
    let val: boolean | undefined = AppStorage.get<boolean>('gnMaterialEnabled');
    return val ?? true;
  }

  static nativeMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static nativeImmersiveMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static nativeInteractiveMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        interactive: true,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static panelMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static cardMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static toolbarMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static statusBarMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }

  static backstageMaterial(materialEnabled?: boolean): uiMaterial.Material | undefined {
    if (!MaterialStyle.shouldUseNativeMaterial(materialEnabled)) return undefined;
    try {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        applyShadow: true
      });
    } catch (e) {
      return undefined;
    }
  }
}
