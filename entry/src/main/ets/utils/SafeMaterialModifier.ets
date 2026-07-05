import { uiMaterial } from '@kit.ArkUI';
import { MaterialStyle } from './MaterialStyle';

export class SafeMaterialModifier<T extends CommonMethod<T>> implements AttributeModifier<T> {
  private material: uiMaterial.Material | undefined;
  private blurFallback: BlurStyle;
  private skipBlur: boolean;

  constructor(material: uiMaterial.Material | undefined, blurFallback?: BlurStyle) {
    this.material = material;
    this.blurFallback = blurFallback ?? BlurStyle.COMPONENT_REGULAR;
    this.skipBlur = blurFallback === undefined;
  }

  applyNormalAttribute(instance: T): void {
    if (this.material !== undefined && MaterialStyle.canUseSystemMaterial()) {
      try {
        instance.systemMaterial(this.material);
        return;
      } catch (_e) {
        // .systemMaterial() not available at runtime
      }
    }
    if (!this.skipBlur) {
      try {
        instance.backgroundBlurStyle(this.blurFallback);
      } catch (_e) {
        // backgroundBlurStyle not available
      }
    }
  }
}
