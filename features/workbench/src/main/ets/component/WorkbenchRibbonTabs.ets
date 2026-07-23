import { MaterialStyle } from '@geonest/common';

const RIBBON_PROJECT: number = 0;
const RIBBON_MAP: number = 1;
const RIBBON_INSERT: number = 2;
const RIBBON_ANALYSIS: number = 3;
const RIBBON_VIEW: number = 4;
const RIBBON_EDIT: number = 5;
const RIBBON_IMAGERY: number = 6;
const RIBBON_SHARE: number = 7;
const RIBBON_HELP: number = 8;
const ACTION_SHOW_TOOLBOX: number = 34;

@Component
export struct WorkbenchRibbonTabs {
  @Prop activeTab: number = RIBBON_MAP;
  @Prop compactLayout: boolean = false;
  @Prop itemRadius: number = 6;
  @Prop surfaceColor: ResourceColor = Color.Transparent;
  onTabChanged: (tabIndex: number) => void = (tabIndex: number): void => {};
  onOpenBackstage: () => void = (): void => {};
  onOperation: (actionId: number) => void = (actionId: number): void => {};

  @Builder
  symbol(icon: Resource, color: ResourceColor, sizeValue: number) {
    SymbolGlyph(icon).fontSize(sizeValue).fontColor([color])
  }

  @Builder
  ribbonTab(label: ResourceStr, tabIndex: number) {
    Text(label)
      .height(30)
      .padding({ left: 12, right: 12 })
      .fontSize(14)
      .fontWeight(this.activeTab === tabIndex ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.activeTab === tabIndex ? $r('app.color.gn_blue_800') : $r('app.color.gn_text_primary'))
      .border({
        width: { bottom: this.activeTab === tabIndex ? 3 : 0 },
        color: $r('app.color.gn_arc_focus')
      })
      .onClick(() => {
        this.onTabChanged(tabIndex);
      })
  }

  @Builder
  toolsButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 5 }) {
        this.symbol($r('sys.symbol.wrench_arrow_counterclockwise'), $r('app.color.gn_blue_800'), 14)
        Text($r('app.string.gn_workbench_tools_tab'))
          .fontSize(12)
          .fontColor($r('app.color.gn_text_primary'))
      }
    }
    .height(28)
    .padding({ left: 10, right: 10 })
    .borderRadius(this.itemRadius)
    .backgroundColor($r('app.color.gn_pane_alt'))
    .onClick(() => {
      this.onOperation(ACTION_SHOW_TOOLBOX);
    })
  }

  build() {
    Scroll() {
      Row() {
        if (this.compactLayout) {
          Button($r('app.string.gn_backstage_file'), { type: ButtonType.Capsule, stateEffect: true })
            .height(28)
            .fontSize(13)
            .fontColor($r('app.color.gn_text_primary'))
            .backgroundColor($r('app.color.gn_pane_alt'))
            .margin({ right: 4 })
            .onClick(() => {
              this.onOpenBackstage();
            })
        }
        this.ribbonTab($r('app.string.gn_ribbon_tab_project'), RIBBON_PROJECT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_map'), RIBBON_MAP)
        this.ribbonTab($r('app.string.gn_ribbon_tab_insert'), RIBBON_INSERT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_analysis'), RIBBON_ANALYSIS)
        this.ribbonTab($r('app.string.gn_ribbon_tab_view'), RIBBON_VIEW)
        this.ribbonTab($r('app.string.gn_ribbon_tab_edit'), RIBBON_EDIT)
        this.ribbonTab($r('app.string.gn_ribbon_tab_imagery'), RIBBON_IMAGERY)
        this.ribbonTab($r('app.string.gn_ribbon_tab_share'), RIBBON_SHARE)
        this.ribbonTab($r('app.string.gn_ribbon_tab_help'), RIBBON_HELP)
        Blank()
        this.toolsButton()
      }
      .width('100%')
      .height(32)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height(38)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundBlurStyle(MaterialStyle.toolbarBlurStyle())
    .backgroundColor(this.surfaceColor)
    .border({ width: { bottom: 1 }, color: $r('app.color.gn_line') })
  }
}
