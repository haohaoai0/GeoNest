export class SafeMaterialModifier<T extends CommonMethod<T>> implements AttributeModifier<T> {
  private blurFallback: BlurStyle;
  private skipBlur: boolean;

  constructor(blurFallback?: BlurStyle) {
    this.blurFallback = blurFallback ?? BlurStyle.COMPONENT_REGULAR;
    this.skipBlur = blurFallback === undefined;
  }

  applyNormalAttribute(instance: T): void {
    if (!this.skipBlur) {
      try {
        instance.backgroundBlurStyle(this.blurFallback);
      } catch (_e) {
        // backgroundBlurStyle not available
      }
    }
  }
}
