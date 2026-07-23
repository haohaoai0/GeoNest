import { MaterialStyle } from '@geonest/common';

@Component
export struct WorkbenchTitleArea {
  @Prop projectStateText: string = '';
  @Prop searchText: string = '';
  @Prop userLoggedIn: boolean = false;
  @Prop userAvatarUri: string = '';
  @Prop userNickName: string = '';
  @Prop itemRadius: number = 6;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  onOpenBackstage: () => void = (): void => {};
  onOpenProjectInfo: () => void = (): void => {};
  onOpenQgisCore: () => void = (): void => {};
  onToggleSettings: () => void = (): void => {};
  onSearchClick: () => void = (): void => {};
  onSearchChanged: (value: string) => void = (value: string): void => {};
  onSearchSubmit: (value: string) => void = (value: string): void => {};
  onLogin: () => void = (): void => {};
  onLogout: () => void = (): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  @Builder
  accountMenu() {
    Menu() {
      if (this.userLoggedIn) {
        MenuItem({ content: $r('app.string.gn_huawei_account_logout') })
          .onClick(() => {
            this.onLogout();
          })
      } else {
        MenuItem({ content: $r('app.string.gn_huawei_account_login') })
          .onClick(() => {
            this.onLogin();
          })
      }
    }
  }

  @Builder
  accountButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      if (this.userLoggedIn && this.userAvatarUri.length > 0) {
        Image(this.userAvatarUri)
          .width(28)
          .height(28)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
      } else if (this.userLoggedIn && this.userNickName.length > 0) {
        Stack() {
          Text(this.userNickName.slice(-1))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor($r('app.color.gn_blue_800'))
      } else {
        this.symbol($r('sys.symbol.person_crop_circle_fill'), $r('sys.color.icon_secondary'), 18)
      }
    }
    .width(34)
    .height(34)
    .padding(0)
    .backgroundColor($r('app.color.gn_pane_alt'))
    .borderRadius(this.itemRadius)
    .bindMenu(this.accountMenu)
  }

  build() {
    Row({ space: 10 }) {
      Button($r('app.string.gn_backstage_file'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_text_primary'))
        .backgroundColor($r('app.color.gn_pane_alt'))
        .onClick(() => {
          this.onOpenBackstage();
        })
      this.symbol($r('sys.symbol.map'), $r('app.color.gn_green_700'), 22)
      Column() {
        Text($r('app.string.gn_workbench_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.gn_text_primary'))
        Text(this.projectStateText)
          .fontSize(11)
          .fontColor($r('app.color.gn_text_muted'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width(250)

      Search({ placeholder: $r('app.string.gn_workbench_command_search') })
        .height(34)
        .width(420)
        .backgroundColor($r('app.color.gn_paper'))
        .borderRadius(this.itemRadius)
        .onClick(() => {
          this.onSearchClick();
        })
        .onChange((value: string) => {
          this.onSearchChanged(value);
        })
        .onSubmit((value: string) => {
          this.onSearchSubmit(value);
        })

      Blank()
      Button($r('app.string.gn_project_info'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_blue_800'))
        .backgroundColor($r('app.color.gn_blue_100'))
        .onClick(() => {
          this.onOpenProjectInfo();
        })
      Button($r('app.string.gn_qgis_core_title'), { type: ButtonType.Capsule, stateEffect: true })
        .height(32)
        .fontSize(13)
        .fontColor($r('app.color.gn_green_700'))
        .backgroundColor($r('app.color.gn_pane_alt'))
        .onClick(() => {
          this.onOpenQgisCore();
        })
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        this.symbol($r('sys.symbol.gearshape'), $r('sys.color.icon_secondary'), 18)
      }
      .width(34)
      .height(34)
      .padding(0)
      .backgroundColor($r('app.color.gn_pane_alt'))
      .borderRadius(this.itemRadius)
      .onClick(() => {
        this.onToggleSettings();
      })
      this.accountButton()
    }
    .width('100%')
    .height(54)
    .padding({ left: 14, right: 14 })
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.surfaceColor)
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }
}
