@Component
export struct WorkbenchWindowTitleBar {
  @Prop isWindowTopmost: boolean = false;
  onMinimize: () => void = (): void => {};
  onToggleTopmost: () => void = (): void => {};
  onClose: () => void = (): void => {};
  onStartDrag: () => void = (): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  build() {
    Row() {
      this.symbol($r('sys.symbol.map'), $r('app.color.gn_green_700'), 14)
      Text('GeoNest')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.gn_text_muted'))
        .margin({ left: 6 })
      if (this.isWindowTopmost) {
        Text('置顶')
          .fontSize(10)
          .fontColor($r('app.color.gn_blue_800'))
          .backgroundColor($r('app.color.gn_blue_100'))
          .borderRadius(4)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .margin({ left: 6 })
      }
      Blank()
      Row({ space: 0 }) {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          this.symbol($r('sys.symbol.minus'), $r('sys.color.icon_secondary'), 12)
        }
        .width(36)
        .height(28)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onMinimize();
        })
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          if (this.isWindowTopmost) {
            this.symbol($r('sys.symbol.pin_slash'), $r('sys.color.icon_secondary'), 12)
          } else {
            this.symbol($r('sys.symbol.pin'), $r('sys.color.icon_secondary'), 12)
          }
        }
        .width(36)
        .height(28)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onToggleTopmost();
        })
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          this.symbol($r('sys.symbol.xmark'), $r('sys.color.icon_secondary'), 12)
        }
        .width(36)
        .height(28)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onClose();
        })
      }
    }
    .width('100%')
    .height(32)
    .padding({ left: 10, right: 4 })
    .backgroundColor($r('app.color.gn_pane'))
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.onStartDrag();
      }
    })
  }
}
